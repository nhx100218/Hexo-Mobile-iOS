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
            WebView(html: loadedArticle.html, baseURL: loadedArticle.resolvedURL)
                .ignoresSafeArea(edges: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
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
