import SwiftUI

struct AboutView: View {
    @ObservedObject var viewModel: BlogViewModel

    @State private var loadedArticle: LoadedArticle?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let feedService = FeedService()

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                content
            }
            .navigationTitle(LocalizedStringKey("about.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await loadAbout() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 92)
                    .padding(.horizontal, 16)

                ProgressView(LocalizedStringKey("common.loading"))
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView(
                LocalizedStringKey("about.load_failed"),
                systemImage: "info.circle",
                description: Text(errorMessage)
            )
        } else if let loadedArticle {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loadedArticle.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Divider()

                    AboutMarkdownContentView(markdown: loadedArticle.markdown)

                    Link(LocalizedStringKey("about.open_source"), destination: loadedArticle.resolvedURL)
                        .font(.footnote)
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func loadAbout() async {
        let trimmed = viewModel.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "error.enter_blog_url")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            loadedArticle = try await feedService.loadAbout(baseURLString: trimmed)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AboutMarkdownContentView: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attributed)
                .font(.body)
                .lineSpacing(6)
                .textSelection(.enabled)
                .dynamicTypeSize(.xSmall ... .accessibility3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(markdown)
                .font(.body)
                .lineSpacing(6)
                .textSelection(.enabled)
                .dynamicTypeSize(.xSmall ... .accessibility3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
