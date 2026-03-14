import SwiftUI
import WebKit

struct ArticleView: View {
    let url: URL

    @State private var loadedArticle: LoadedArticle?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let feedService = FeedService()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            content
                .padding(.top, 2)
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
            WebView(html: formattedHTML(from: loadedArticle.html), baseURL: loadedArticle.resolvedURL)
                .ignoresSafeArea(edges: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
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

    private func formattedHTML(from html: String) -> String {
        let styleBlock = """
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"> 
        <style>
        :root { color-scheme: light dark; }
        body {
            font: -apple-system-body;
            line-height: 1.65;
            margin: 0;
            padding: 16px;
            background: transparent;
            word-wrap: break-word;
        }
        p, li, span { font-size: 1rem; }
        h1, h2, h3, h4 { line-height: 1.3; }
        img, video, iframe { max-width: 100%; height: auto; }
        a { color: #0A84FF; text-decoration: none; }
        pre, code {
            white-space: pre-wrap;
            word-break: break-word;
        }
        </style>
        """

        if html.localizedCaseInsensitiveContains("<head") {
            return html.replacingOccurrences(of: "</head>", with: "\(styleBlock)</head>")
        }

        return "<html><head>\(styleBlock)</head><body>\(html)</body></html>"
    }
}

private struct WebView: UIViewRepresentable {
    let html: String
    let baseURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: baseURL)
    }
}
