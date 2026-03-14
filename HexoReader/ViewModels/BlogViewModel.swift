import Foundation

@MainActor
final class BlogViewModel: ObservableObject {
    @Published var baseURL: String
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: StorageKeys.language)
        }
    }
    @Published private(set) var detectedFeedURL: URL?
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let blogDetectService: BlogDetectService
    private let feedService: FeedService

    private enum StorageKeys {
        static let baseURL = "HexoReader.baseURL"
        static let language = "HexoReader.language"
    }

    init(
        blogDetectService: BlogDetectService = BlogDetectService(),
        feedService: FeedService = FeedService()
    ) {
        self.blogDetectService = blogDetectService
        self.feedService = feedService
        self.baseURL = UserDefaults.standard.string(forKey: StorageKeys.baseURL) ?? ""

        let rawLanguage = UserDefaults.standard.string(forKey: StorageKeys.language) ?? AppLanguage.chinese.rawValue
        self.selectedLanguage = AppLanguage(rawValue: rawLanguage) ?? .chinese
    }

    func loadPosts() async {
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "error.enter_blog_url")
            posts = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let feedURL = try await blogDetectService.detectFeed(baseURLString: baseURL)
            let loadedPosts = try await feedService.fetchPosts(feedURL: feedURL)
            detectedFeedURL = feedURL
            posts = loadedPosts
        } catch {
            detectedFeedURL = nil
            posts = []
            errorMessage = error.localizedDescription
        }
    }

    func saveBaseURL() {
        UserDefaults.standard.set(baseURL, forKey: StorageKeys.baseURL)
    }
}
