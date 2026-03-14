import FeedKit
import Foundation

struct FeedService {
    func fetchPosts(feedURL: URL) async throws -> [Post] {
        let (data, response) = try await URLSession.shared.data(from: feedURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw FeedServiceError.invalidResponse
        }

        let result = FeedParser(data: data).parse()

        switch result {
        case .success(let feed):
            let posts = map(feed: feed)
            if posts.isEmpty {
                throw FeedServiceError.noPosts
            }
            return posts.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
        case .failure:
            throw FeedServiceError.parseFailed
        }
    }

    private func map(feed: Feed) -> [Post] {
        switch feed {
        case .rss(let rss):
            return rss.items?.compactMap { item in
                guard let title = item.title,
                      let linkString = item.link,
                      let link = URL(string: linkString) else {
                    return nil
                }

                return Post(
                    title: title,
                    publishDate: item.pubDate,
                    summary: item.description ?? item.content?.contentEncoded ?? "No summary available.",
                    link: link
                )
            } ?? []

        case .atom(let atom):
            return atom.entries?.compactMap { entry in
                guard let title = entry.title,
                      let href = entry.links?.first?.attributes?.href,
                      let link = URL(string: href) else {
                    return nil
                }

                return Post(
                    title: title,
                    publishDate: entry.updated,
                    summary: entry.summary?.value ?? "No summary available.",
                    link: link
                )
            } ?? []

        case .json:
            return []
        }
    }
}

enum FeedServiceError: LocalizedError {
    case invalidResponse
    case parseFailed
    case noPosts

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Feed server returned an unexpected response."
        case .parseFailed:
            return "Could not parse feed data."
        case .noPosts:
            return "Feed loaded successfully, but no posts were found."
        }
    }
}
