import FeedKit
import Foundation

struct LoadedArticle {
    let title: String
    let markdown: String
    let publishDate: Date?
    let resolvedURL: URL
    let twikooEnvID: String?
    let pagePath: String
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
        let markdownCandidates = buildMarkdownCandidateURLs(from: url)

        for candidate in markdownCandidates {
            if let markdown = try await fetchMarkdownIfAvailable(from: candidate), !markdown.isEmpty {
                let normalizedMarkdown = sanitizeMarkdownForDisplay(markdown)
                return LoadedArticle(
                    title: extractTitleFromMarkdown(normalizedMarkdown) ?? titleFromURL(candidate),
                    markdown: normalizedMarkdown,
                    publishDate: extractDate(from: candidate.path),
                    resolvedURL: candidate,
                    twikooEnvID: nil,
                    pagePath: candidate.path
                )
            }
        }

        let htmlCandidates = buildCandidateArticleURLs(from: url)
        for candidate in htmlCandidates {
            do {
                let html = try await fetchHTML(from: candidate)
                let cleanHTML = removeNoiseSections(from: html)

                if let mdSourceURL = extractMarkdownSourceURL(from: cleanHTML, sourceURL: candidate),
                   let sourceMarkdown = try await fetchMarkdownIfAvailable(from: mdSourceURL),
                   !sourceMarkdown.isEmpty {
                    let normalized = sanitizeMarkdownForDisplay(sourceMarkdown)
                    return LoadedArticle(
                        title: extractTitleFromMarkdown(normalized) ?? extractTitle(from: cleanHTML) ?? titleFromURL(candidate),
                        markdown: normalized,
                        publishDate: extractDate(from: candidate.path),
                        resolvedURL: candidate,
                        twikooEnvID: extractTwikooEnvID(from: cleanHTML),
                        pagePath: candidate.path
                    )
                }

                let articleHTML = extractArticleHTML(from: cleanHTML) ?? cleanHTML
                let markdown = sanitizeMarkdownForDisplay(htmlToMarkdown(articleHTML))
                let title = extractTitle(from: cleanHTML) ?? titleFromURL(candidate)

                if !markdown.isEmpty {
                    return LoadedArticle(
                        title: title,
                        markdown: markdown,
                        publishDate: extractDate(from: candidate.path),
                        resolvedURL: candidate,
                        twikooEnvID: extractTwikooEnvID(from: cleanHTML),
                        pagePath: candidate.path
                    )
                }
            } catch {
                continue
            }
        }

        throw FeedServiceError.articleLoadFailed
    }

    func loadAbout(baseURLString: String) async throws -> LoadedArticle {
        let baseURL = try normalizedURL(from: baseURLString)
        let aboutURL = URL(string: "about/", relativeTo: baseURL)?.absoluteURL ?? baseURL

        let markdownCandidates = [
            URL(string: "about/index.md", relativeTo: baseURL)?.absoluteURL,
            URL(string: "about.md", relativeTo: baseURL)?.absoluteURL,
            URL(string: "about/README.md", relativeTo: baseURL)?.absoluteURL
        ].compactMap { $0 }

        for candidate in markdownCandidates {
            if let markdown = try await fetchMarkdownIfAvailable(from: candidate), !markdown.isEmpty {
                return LoadedArticle(
                    title: String(localized: "about.title"),
                    markdown: sanitizeMarkdownForDisplay(markdown),
                    publishDate: nil,
                    resolvedURL: candidate,
                    twikooEnvID: nil,
                    pagePath: candidate.path
                )
            }
        }

        let htmlCandidates = buildCandidateArticleURLs(from: aboutURL)
        for candidate in htmlCandidates {
            do {
                let html = try await fetchHTML(from: candidate)
                let cleanHTML = removeNoiseSections(from: html)
                let articleHTML = extractArticleHTML(from: cleanHTML) ?? cleanHTML
                let title = extractTitle(from: cleanHTML) ?? String(localized: "about.title")

                return LoadedArticle(
                    title: title,
                    markdown: sanitizeMarkdownForDisplay(htmlToMarkdown(articleHTML)),
                    publishDate: nil,
                    resolvedURL: candidate,
                    twikooEnvID: extractTwikooEnvID(from: cleanHTML),
                    pagePath: candidate.path
                )
            } catch {
                continue
            }
        }

        throw FeedServiceError.articleLoadFailed
    }

    private func normalizedURL(from string: String) throws -> URL {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw URLError(.badURL) }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        if let httpsURL = URL(string: "https://\(trimmed)") {
            return httpsURL
        }

        throw URLError(.badURL)
    }

    private func fetchMarkdownIfAvailable(from url: URL) async throws -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("text/markdown,text/plain;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let markdown = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
            ?? String(decoding: data, as: UTF8.self)

        if markdown.localizedCaseInsensitiveContains("<html") || markdown.localizedCaseInsensitiveContains("<!DOCTYPE html") {
            return nil
        }

        return markdown
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

    private func removeNoiseSections(from html: String) -> String {
        var cleaned = html

        let noisyBlocks = [
            #"<script[^>]*>.*?</script>"#,
            #"<style[^>]*>.*?</style>"#,
            #"<noscript[^>]*>.*?</noscript>"#,
            #"<footer[^>]*>.*?</footer>"#,
            #"<section[^>]*(id|class)=[\"'][^\"']*(comment|comments|comment-box|vcomment|vcomments|waline|twikoo|giscus)[^\"']*[\"'][^>]*>.*?</section>"#,
            #"<div[^>]*(id|class)=[\"'][^\"']*(comment|comments|comment-box|vcomment|vcomments|waline|twikoo|giscus|post-meta|post-copyright|toc|pagination)[^\"']*[\"'][^>]*>.*?</div>"#
        ]

        for pattern in noisyBlocks {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        return cleaned
    }

    private func extractArticleHTML(from html: String) -> String? {
        let candidates = [
            #"<article[^>]*>(.*?)</article>"#,
            #"<main[^>]*>(.*?)</main>"#,
            #"<div[^>]*class=[\"'][^\"']*(post-content|article-entry|entry-content|page-content)[^\"']*[\"'][^>]*>(.*?)</div>"#
        ]

        for pattern in candidates {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range) else { continue }

            let captureIndex = match.numberOfRanges > 2 ? 2 : 1
            guard let capture = Range(match.range(at: captureIndex), in: html) else { continue }

            let value = String(html[capture]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }

        return nil
    }

    private func extractTitle(from html: String) -> String? {
        let candidates = [
            #"<h1[^>]*class=[\"'][^\"']*(post-title|article-title|page-title)[^\"']*[\"'][^>]*>(.*?)</h1>"#,
            #"<h1[^>]*>(.*?)</h1>"#,
            #"<title[^>]*>(.*?)</title>"#
        ]

        for pattern in candidates {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range) else { continue }

            let captureIndex = match.numberOfRanges > 2 ? 2 : 1
            guard let titleRange = Range(match.range(at: captureIndex), in: html) else { continue }

            let title = stripHTMLTags(from: String(html[titleRange]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private func htmlToMarkdown(_ html: String) -> String {
        var output = html

        let replacementRules: [(String, String)] = [
            (#"<h1[^>]*>(.*?)</h1>"#, "\n# $1\n\n"),
            (#"<h2[^>]*>(.*?)</h2>"#, "\n## $1\n\n"),
            (#"<h3[^>]*>(.*?)</h3>"#, "\n### $1\n\n"),
            (#"<h4[^>]*>(.*?)</h4>"#, "\n#### $1\n\n"),
            (#"<h5[^>]*>(.*?)</h5>"#, "\n##### $1\n\n"),
            (#"<h6[^>]*>(.*?)</h6>"#, "\n###### $1\n\n"),
            (#"<strong[^>]*>(.*?)</strong>"#, "**$1**"),
            (#"<b[^>]*>(.*?)</b>"#, "**$1**"),
            (#"<em[^>]*>(.*?)</em>"#, "*$1*"),
            (#"<i[^>]*>(.*?)</i>"#, "*$1*"),
            (#"<code[^>]*>(.*?)</code>"#, "`$1`"),
            (#"<pre[^>]*>(.*?)</pre>"#, "\n```\n$1\n```\n\n"),
            (#"<blockquote[^>]*>(.*?)</blockquote>"#, "\n> $1\n\n"),
            (#"<li[^>]*>(.*?)</li>"#, "- $1\n"),
            (#"</(ul|ol)>"#, "\n"),
            (#"<p[^>]*>(.*?)</p>"#, "$1\n\n"),
            (#"<div[^>]*>(.*?)</div>"#, "$1\n"),
            (#"<br\s*/?>"#, "\n")
        ]

        for (pattern, template) in replacementRules {
            output = output.replacingOccurrences(of: pattern, with: template, options: [.regularExpression, .caseInsensitive])
        }

        if let anchorRegex = try? NSRegularExpression(pattern: #"<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            let matches = anchorRegex.matches(in: output, options: [], range: range).reversed()

            for match in matches {
                guard let hrefRange = Range(match.range(at: 1), in: output),
                      let textRange = Range(match.range(at: 2), in: output),
                      let fullRange = Range(match.range(at: 0), in: output) else { continue }

                let href = String(output[hrefRange])
                let text = stripHTMLTags(from: String(output[textRange])).trimmingCharacters(in: .whitespacesAndNewlines)
                output.replaceSubrange(fullRange, with: text.isEmpty ? href : "[\(text)](\(href))")
            }
        }

        output = stripHTMLTags(from: output)
        output = decodeHTMLEntities(in: output)

        return output
    }

    private func sanitizeMarkdownForDisplay(_ text: String) -> String {
        var output = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Remove low-value non-content lines often found in comment/footer widgets.
        let noiseLinePatterns = [
            #"^\s*评论.*$"#,
            #"^\s*匿名评论.*$"#,
            #"^\s*隐私政策.*$"#,
            #"^\s*归档.*$"#,
            #"^\s*网站资讯.*$"#,
            #"^\s*文章总数.*$"#,
            #"^\s*建站天数.*$"#,
            #"^\s*archives?.*$"#,
            #"^\s*site info.*$"#,
            #"^\s*comments?.*$"#
        ]

        output = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                !noiseLinePatterns.contains { pattern in
                    line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
                }
            }
            .joined(separator: "\n")

        // Normalize heading markers and ensure heading starts on a new line.
        output = output.replacingOccurrences(of: #"(?<!\n)(#{1,6}\s*)"#, with: "\n$1", options: .regularExpression)
        output = output.replacingOccurrences(of: #"(^|\n)(#{1,6})([^\s#])"#, with: "$1$2 $3", options: .regularExpression)

        // Ensure list items and quote lines start on a new line for markdown parsing.
        output = output.replacingOccurrences(of: #"(?<!\n)([-*>]\s+)"#, with: "\n$1", options: .regularExpression)

        // If heading line accidentally duplicates (e.g. 关于此博客关于此博客), dedupe it.
        output = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .map(deduplicateHeadingIfNeeded)
            .joined(separator: "\n")

        // Remove inline trailing boilerplate if content was collapsed into one line.
        let inlineNoisePatterns = [
            #"网站资讯.*$"#,
            #"文章总数\s*[:：].*$"#,
            #"建站天数\s*[:：].*$"#,
            #"欢迎光临.*$"#
        ]
        for pattern in inlineNoisePatterns {
            output = output.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        // Create paragraph spacing so content doesn't collapse into a single block.
        output = output.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicateHeadingIfNeeded(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return line }

        let headingBody = trimmed.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
        guard headingBody.count >= 4, headingBody.count % 2 == 0 else { return line }

        let halfIndex = headingBody.index(headingBody.startIndex, offsetBy: headingBody.count / 2)
        let left = String(headingBody[..<halfIndex])
        let right = String(headingBody[halfIndex...])

        if left == right {
            let prefix = trimmed.prefix { $0 == "#" }
            return "\(prefix) \(left)"
        }

        return line
    }

    private func extractTitleFromMarkdown(_ markdown: String) -> String? {
        for line in markdown.split(separator: "\n").map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("#") {
                let title = trimmed.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
                if !title.isEmpty { return title }
            }
        }

        return nil
    }


    private func extractMarkdownSourceURL(from html: String, sourceURL: URL) -> URL? {
        if let regex = try? NSRegularExpression(pattern: #"<a[^>]*href=[\"']([^\"']+\.md)[\"'][^>]*>"#, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
           let hrefRange = Range(match.range(at: 1), in: html) {
            let href = String(html[hrefRange])
            return resolveArticleURL(href, sourceURL: sourceURL)
        }

        return nil
    }

    private func extractTwikooEnvID(from html: String) -> String? {
        let patterns = [
            #"envId\s*:\s*[\"']([^\"']+)[\"']"#,
            #"data-env-id=[\"']([^\"']+)[\"']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
                  let envRange = Range(match.range(at: 1), in: html) else { continue }

            let env = String(html[envRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !env.isEmpty { return env }
        }

        return nil
    }

    private func decodeHTMLEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
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
    }

    private func titleFromURL(_ url: URL) -> String {
        let components = url.pathComponents.filter { $0 != "/" }
        if let raw = components.last {
            let cleaned = raw
                .replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".html", with: "")

            if cleaned == "index", components.count >= 2 {
                return components[components.count - 2]
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized
            }

            return cleaned
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }

        return String(localized: "article.title")
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

    private func buildMarkdownCandidateURLs(from url: URL) -> [URL] {
        var candidates = [URL]()
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? ""

        if path.lowercased().hasSuffix(".md") {
            return [url]
        }

        if path.lowercased().hasSuffix(".html") {
            components?.path = path.replacingOccurrences(of: ".html", with: ".md")
            if let mdURL = components?.url { candidates.append(mdURL) }
        } else {
            var normalizedPath = path
            if !normalizedPath.hasSuffix("/") {
                normalizedPath += "/"
            }

            components?.path = normalizedPath + "index.md"
            if let indexMD = components?.url { candidates.append(indexMD) }

            components?.path = String(normalizedPath.dropLast()) + ".md"
            if let flatMD = components?.url { candidates.append(flatMD) }
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
