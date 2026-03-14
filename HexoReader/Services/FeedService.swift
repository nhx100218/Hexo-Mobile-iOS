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

    func fetchPostsFromHexoHTML(baseURL: URL) async throws -> [Post] {
        let html = try await fetchHTML(from: baseURL)
        let extractedPosts = extractHexoPosts(from: html, baseURL: baseURL)

        guard !extractedPosts.isEmpty else {
            throw FeedServiceError.noPosts
        }

        return extractedPosts
    }

    func loadArticle(from url: URL) async throws -> LoadedArticle {
        let candidates = buildCandidateArticleURLs(from: url)

        for candidate in candidates {
            do {
                let html = try await fetchHTML(from: candidate)
                if !html.isEmpty {
                    return LoadedArticle(html: html, resolvedURL: candidate)
                }
            } catch {
                continue
            }
        }

        throw FeedServiceError.articleLoadFailed
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FeedServiceError.invalidResponse
        }

        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
            ?? String(decoding: data, as: UTF8.self)
    }

    private func extractHexoPosts(from html: String, baseURL: URL) -> [Post] {
        let pattern = #"<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        var posts: [Post] = []
        var seen = Set<String>()

        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let rawHref = String(html[hrefRange])
            guard let url = resolveArticleURL(rawHref, sourceURL: baseURL) else { continue }
            guard isLikelyHexoArticlePath(url.path) else { continue }

            let titleHTML = String(html[titleRange])
            let cleanTitle = stripHTMLTags(from: titleHTML)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanTitle.isEmpty else { continue }

            let dedupeKey = url.absoluteString
            guard !seen.contains(dedupeKey) else { continue }
            seen.insert(dedupeKey)

            posts.append(
                Post(
                    title: cleanTitle,
                    publishDate: extractDate(from: url.path),
                    summary: String(localized: "article.no_summary"),
                    link: url
                )
            )
        }

        return posts.sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
    }

    private func isLikelyHexoArticlePath(_ path: String) -> Bool {
        let segments = path.split(separator: "/").map(String.init)
        guard segments.count >= 4 else { return false }

        let year = segments[0]
        let month = segments[1]
        let day = segments[2]
        return year.range(of: #"^\d{4}$"#, options: .regularExpression) != nil
            && month.range(of: #"^\d{2}$"#, options: .regularExpression) != nil
            && day.range(of: #"^\d{2}$"#, options: .regularExpression) != nil
    }

    private func stripHTMLTags(from html: String) -> String {
        html.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func extractDate(from path: String) -> Date? {
        let segments = path.split(separator: "/")
        guard segments.count >= 3 else { return nil }

        let yyyy = String(segments[0])
        let mm = String(segments[1])
        let dd = String(segments[2])
        let dateString = "\(yyyy)-\(mm)-\(dd)"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
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

        if !path.lowercased().hasSuffix(".html") {
            var normalizedPath = path
            if !normalizedPath.hasSuffix("/") {
                normalizedPath += "/"
            }

            components?.path = normalizedPath + "index.html"
            components?.query = nil
            components?.fragment = nil
            if let fallbackURL = components?.url {
                candidates.append(fallbackURL)
            }
        }

        return Array(NSOrderedSet(array: candidates)) as? [URL] ?? candidates
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
