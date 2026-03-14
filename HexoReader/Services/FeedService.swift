import FeedKit
import Foundation

struct LoadedArticle {
    let html: String
    let resolvedURL: URL
}

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
            let posts = map(feed: feed, sourceURL: feedURL)
            if posts.isEmpty {
                throw FeedServiceError.noPosts
            }
            return posts.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
        case .failure:
            throw FeedServiceError.parseFailed
        }
    }

    func loadArticle(from url: URL) async throws -> LoadedArticle {
        let candidates = buildCandidateArticleURLs(from: url)

        for candidate in candidates {
            var request = URLRequest(url: candidate)
            request.timeoutInterval = 15

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    continue
                }

                let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .unicode)
                    ?? String(decoding: data, as: UTF8.self)

                if !html.isEmpty {
                    return LoadedArticle(html: html, resolvedURL: candidate)
                }
            } catch {
                continue
            }
        }

        throw FeedServiceError.articleLoadFailed
    }

    private func map(feed: Feed, sourceURL: URL) -> [Post] {
        switch feed {
        case .rss(let rss):
            return rss.items?.compactMap { item in
                guard let title = item.title,
                      let linkString = item.link,
                      let link = resolveArticleURL(linkString, sourceURL: sourceURL) else {
                    return nil
                }

                return Post(
                    title: title,
                    publishDate: item.pubDate,
                    summary: item.description ?? item.content?.contentEncoded ?? String(localized: "article.no_summary"),
                    link: link
                )
            } ?? []

        case .atom(let atom):
            return atom.entries?.compactMap { entry in
                guard let title = entry.title,
                      let href = entry.links?.first?.attributes?.href,
                      let link = resolveArticleURL(href, sourceURL: sourceURL) else {
                    return nil
                }

                return Post(
                    title: title,
                    publishDate: entry.updated,
                    summary: entry.summary?.value ?? String(localized: "article.no_summary"),
                    link: link
                )
            } ?? []

        case .json:
            return []
        }
    }

    private func resolveArticleURL(_ linkString: String, sourceURL: URL) -> URL? {
        if let absoluteURL = URL(string: linkString), absoluteURL.scheme != nil {
            return absoluteURL
        }

        return URL(string: linkString, relativeTo: sourceURL)?.absoluteURL
    }

    private func buildCandidateArticleURLs(from url: URL) -> [URL] {
        var candidates: [URL] = [url]

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? ""
        let hasHTMLExtension = path.lowercased().hasSuffix(".html")

        if !hasHTMLExtension {
            var normalizedPath = path
            if !normalizedPath.hasSuffix("/") {
                normalizedPath += "/"
            }

            if let pathComponents = articlePathComponents(from: normalizedPath), pathComponents.count >= 4 {
                // Matches paths like /2026/02/13/pg11/ and appends index.html fallback.
                components?.path = normalizedPath + "index.html"
                components?.query = nil
                components?.fragment = nil
                if let dynamicURL = components?.url {
                    candidates.append(dynamicURL)
                }
            } else {
                components?.path = normalizedPath + "index.html"
                components?.query = nil
                components?.fragment = nil
                if let fallbackURL = components?.url {
                    candidates.append(fallbackURL)
                }
            }
        }

        return Array(NSOrderedSet(array: candidates)) as? [URL] ?? candidates
    }

    private func articlePathComponents(from path: String) -> [String]? {
        let components = path
            .split(separator: "/")
            .map(String.init)

        guard components.count >= 4 else { return nil }

        let yearPattern = /^\d{4}$/
        let monthPattern = /^\d{2}$/
        let dayPattern = /^\d{2}$/

        if components[0].contains(yearPattern),
           components[1].contains(monthPattern),
           components[2].contains(dayPattern) {
            return components
        }

        return nil
    }
}

enum FeedServiceError: LocalizedError {
    case invalidResponse
    case parseFailed
    case noPosts
    case articleLoadFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "error.feed_invalid_response")
        case .parseFailed:
            return String(localized: "error.feed_parse_failed")
        case .noPosts:
            return String(localized: "error.feed_no_posts")
        case .articleLoadFailed:
            return String(localized: "error.article_load_failed")
        }
    }
}
