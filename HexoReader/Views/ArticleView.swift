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

                    MarkdownContentView(markdown: loadedArticle.markdown)

                    Link(LocalizedStringKey("article.open_source"), destination: loadedArticle.resolvedURL)
                        .font(.footnote)
                        .foregroundStyle(.blue)
                        .padding(.top, 8)

                    if let envID = loadedArticle.twikooEnvID, !envID.isEmpty {
                        Divider()
                            .padding(.top, 8)

                        Text(LocalizedStringKey("article.comments"))
                            .font(.headline)

                        TwikooCommentsView(envID: envID, pagePath: loadedArticle.pagePath)
                            .frame(minHeight: 420)
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

private struct MarkdownContentView: View {
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
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(.xSmall ... .accessibility3)
        } else {
            Text(markdown)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(.xSmall ... .accessibility3)
        }
    }
}

private struct TwikooCommentsView: UIViewRepresentable {
    let envID: String
    let pagePath: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
}

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlTemplate, baseURL: URL(string: "https://twikoo.js.org"))
    }

    private var htmlTemplate: String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset='utf-8'>
          <meta name='viewport' content='width=device-width, initial-scale=1'>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; background: transparent; }
            #twikoo { margin: 0; }
          </style>
          <script src='https://cdn.staticfile.net/twikoo/1.6.39/twikoo.all.min.js'></script>
        </head>
        <body>
          <div id='twikoo'></div>
          <script>
            twikoo.init({
              envId: '\(envID)',
              el: '#twikoo',
              path: '\(pagePath)'
            })
          </script>
        </body>
        </html>
        """
    }
}
