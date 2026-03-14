import Foundation

struct BlogDetectService {
    private let candidatePaths = ["/atom.xml", "/rss.xml", "/feed.xml"]

    func detectFeed(baseURLString: String) async throws -> URL {
        guard let normalized = normalize(baseURLString), var components = URLComponents(url: normalized, resolvingAgainstBaseURL: false) else {
            throw BlogDetectError.invalidURL
        }

        components.path = ""
        components.query = nil
        components.fragment = nil

        guard let baseURL = components.url else {
            throw BlogDetectError.invalidURL
        }

        for path in candidatePaths {
            guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200..<300).contains(httpResponse.statusCode) {
                    return url
                }
            } catch {
                continue
            }
        }

        throw BlogDetectError.feedNotFound
    }

    private func normalize(_ baseURLString: String) -> URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }

        return URL(string: "https://\(trimmed)")
    }
}

enum BlogDetectError: LocalizedError {
    case invalidURL
    case feedNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Please enter a valid blog URL."
        case .feedNotFound:
            return "No supported feed found at /atom.xml, /rss.xml, or /feed.xml."
        }
    }
}
