import SwiftUI

struct ArticleView: View {
    let url: URL

    @State private var loadedArticle: LoadedArticle?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let feedService = FeedService()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            content
        }
        .navigationTitle(LocalizedStringKey("article.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .glassEffect()
        .task {
            await loadArticleIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView(LocalizedStringKey("common.loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView(
                LocalizedStringKey("article.load_failed"),
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
        } else if let loadedArticle {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(loadedArticle.title)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if let publishDate = loadedArticle.publishDate {
                        Text(Self.dateFormatter.string(from: publishDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Keep markdown as raw text for readability/debugging.
                    Text(loadedArticle.markdown)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dynamicTypeSize(.xSmall ... .accessibility3)

                    Link(LocalizedStringKey("article.open_source"), destination: loadedArticle.resolvedURL)
                        .font(.footnote)
                        .foregroundStyle(.blue)
                        .padding(.top, 8)
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .glassEffect()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func loadArticleIfNeeded() async {
        guard loadedArticle == nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            loadedArticle = try await feedService.loadArticle(from: url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
