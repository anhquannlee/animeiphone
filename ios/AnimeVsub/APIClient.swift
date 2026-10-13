import Foundation
import WebKit

enum APIError: Error, CustomStringConvertible {
    case invalidURL
    case invalidResponse
    case server(statusCode: Int)
    case emptyResponse
    case decoding(Error)
    case transport(Error)
    case unsupportedResponse

    var description: String {
        switch self {
        case .server(let statusCode):
            return "Máy chủ trả HTTP \(statusCode). Domain có thể đang chuyển hướng hoặc bị Cloudflare chặn."
        case .transport(let error):
            return "Lỗi kết nối: \(error.localizedDescription)"
        case .invalidURL: return "URL máy chủ không hợp lệ."
        case .invalidResponse: return "Phản hồi máy chủ không hợp lệ."
        case .emptyResponse: return "Máy chủ trả dữ liệu rỗng."
        case .decoding(let error): return "Không đọc được dữ liệu: \(error.localizedDescription)"
        case .unsupportedResponse: return "Định dạng phản hồi chưa được hỗ trợ."
        }
    }
}

struct SearchSuggestion {
    let id: String
    let name: String
    let image: String?
}

/// Client for the same HTML/POST API used by the Android hidden module and desktop-web.
final class APIClient {
    static let shared = APIClient()

    /// The canonical domain used by the AnimeVsub desktop application.
    var baseURL = URL(string: "https://animevietsub.pl")!
    private let fallbackBaseURLs = [
        URL(string: "https://animevietsub.pl")!,
        URL(string: "https://animevietsub.pro")!,
        URL(string: "https://animevietsub.tv")!,
        URL(string: "https://animevietsub.xyz")!,
        URL(string: "https://animevietsub.link")!,
        URL(string: "https://animevietsub.nl")!
    ]

    func setBaseURL(_ value: String) -> Bool {
        var raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw), let scheme = url.scheme, let host = url.host else { return false }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port
        guard let origin = components.url else { return false }
        baseURL = origin
        return true
    }
    var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        return URLSession(configuration: configuration)
    }()

    func home(completion: @escaping (Result<HomeData, APIError>) -> Void) {
        requestHTML(path: "/", method: "GET", parameters: [:]) { result in
            completion(result.flatMap {
                let data = HTMLParser.home(from: $0)
                return data.lastUpdate.isEmpty && data.thisSeason.isEmpty
                    ? .failure(.unsupportedResponse)
                    : .success(data)
            })
        }
    }

    func search(keyword: String, page: Int = 1, completion: @escaping (Result<CategoryPage, APIError>) -> Void) {
        let path = "/tim-kiem/\(HTMLParser.slug(keyword))/trang-\(page).html"
        requestHTML(path: path, method: "GET", parameters: [:]) { result in
            completion(result.flatMap {
                let pageData = HTMLParser.category(from: $0, page: page)
                return pageData.items.isEmpty
                    ? .failure(.unsupportedResponse)
                    : .success(pageData)
            })
        }

    }

    func episodes(animeID: String, completion: @escaping (Result<[ChapterInfo], APIError>) -> Void) {
        let path = "/phim/\(HTMLParser.slug(animeID))/xem-phim.html"
        requestHTML(path: path, method: "GET", parameters: [:]) { result in
            completion(result.flatMap {
                let chapters = HTMLParser.episodes(from: $0)
                return chapters.isEmpty ? .failure(.unsupportedResponse) : .success(chapters)
            })
        }
    }

    func suggestions(keyword: String, completion: @escaping (Result<[SearchSuggestion], APIError>) -> Void) {
        requestHTML(
            path: "/ajax/suggest",
            method: "POST",
            parameters: ["ajaxSearch": "1", "keysearch": keyword]
        ) { result in
            completion(result.map { HTMLParser.suggestions(from: $0) })
        }
    }

    func homeWidget(type: String, completion: @escaping (Result<[AnimeCard], APIError>) -> Void) {
        requestHTML(
            path: "/ajax/item",
            method: "POST",
            parameters: ["widget": "list-film", "type": type]
        ) { result in
            completion(result.map { HTMLParser.cards(from: $0) })
        }
    }

    func player(episodeID: String, completion: @escaping (Result<PlayerData, APIError>) -> Void) {
        requestHTML(
            path: "/ajax/player?v=2019a",
            method: "POST",
            parameters: ["episodeId": episodeID, "backup": "1"]
        ) { result in
            completion(result.flatMap { HTMLParser.player(from: $0) })
        }
    }

    /// Low-level endpoint for detail, comments, follow and notification APIs.
    /// These endpoints return HTML/JSON depending on the server version.
    func requestRaw(
        path: String,
        method: String = "GET",
        parameters: [String: String] = [:],
        completion: @escaping (Result<Data, APIError>) -> Void
    ) {
        requestRaw(
            path: path,
            method: method,
            parameters: parameters,
            baseURLs: [baseURL] + fallbackBaseURLs.filter { $0 != baseURL },
            index: 0,
            completion: completion
        )
    }

    private func requestRaw(
        path: String,
        method: String,
        parameters: [String: String],
        baseURLs: [URL],
        index: Int,
        completion: @escaping (Result<Data, APIError>) -> Void
    ) {
        guard index < baseURLs.count else {
            completion(.failure(.server(statusCode: 503)))
            return
        }
        let currentBaseURL = baseURLs[index]
        guard let url = URL(string: path, relativeTo: currentBaseURL)?.absoluteURL else {
            completion(.failure(.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpShouldHandleCookies = true
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 12_5 like Mac OS X) AppleWebKit/605.1.15 Mobile Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(currentBaseURL.absoluteString, forHTTPHeaderField: "Referer")
        if method == "POST" {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = parameters
                .map { "\(HTMLParser.escape($0.key))=\(HTMLParser.escape($0.value))" }
                .joined(separator: "&")
                .data(using: .utf8)
        } else if !parameters.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let queryURL = components?.url { request.url = queryURL }
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.transport(error))) }
                return
            }
            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(.invalidResponse)) }
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                self.requestRaw(
                    path: path,
                    method: method,
                    parameters: parameters,
                    baseURLs: baseURLs,
                    index: index + 1,
                    completion: completion
                )
                return
            }
            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async { completion(.failure(.emptyResponse)) }
                return
            }
            DispatchQueue.main.async { completion(.success(data)) }
        }.resume()
    }

    private func requestHTML(
        path: String,
        method: String,
        parameters: [String: String],
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        requestRaw(path: path, method: method, parameters: parameters) { result in
            completion(result.flatMap {
                guard let html = String(data: $0, encoding: .utf8) else {
                    return .failure(.unsupportedResponse)
                }
                return .success(html)
            })
        }
    }
}

private enum HTMLParser {
    static func home(from html: String) -> HomeData {
        let all = cards(from: html)
        return HomeData(
            thisSeason: Array(all.prefix(12)),
            carousel: Array(all.prefix(6)),
            lastUpdate: Array(all.prefix(24)),
            preRelease: [],
            nominate: Array(all.dropFirst(12).prefix(12)),
            hotUpdate: Array(all.dropFirst(24).prefix(12))
        )
    }

    static func category(from html: String, page: Int) -> CategoryPage {
        CategoryPage(items: cards(from: html), totalPages: 1, currentPage: page, name: nil, title: nil)
    }

    static func cards(from html: String) -> [AnimeCard] {
        let pattern = #"<a[^>]+href=["']([^"']*(?:/phim/|/xem-phim/)[^"']*)["'][^>]*>[\s\S]*?</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var result = [AnimeCard]()
        var seen = Set<String>()
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let match = match, let hrefRange = Range(match.range(at: 1), in: html) else { return }
            let href = String(html[hrefRange])
            guard href.contains("/phim/") || href.contains("/xem-phim/") else { return }
            let id = href.split(separator: "/").last.map(String.init) ?? href
            guard !seen.contains(id) else { return }
            let region = String(html[Range(match.range, in: html)!])
            let image = attribute("data-src", in: region)
                ?? attribute("src", in: region)
                ?? attribute("data-original", in: region)
                ?? ""
            let titlePattern = #"<(?:div|span|a)[^>]+class=["'][^"']*\bTitle\b[^"']*["'][^>]*>([\s\S]*?)</(?:div|span|a)>"#
            let name = firstCapture(titlePattern, in: region)
                .map { text(in: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
                ?? attribute("title", in: region)
                ?? ""
            guard !name.isEmpty else { return }
            let episode = firstCapture(#"<span[^>]+class=["'][^"']*\bmli-eps\b[^"']*["'][^>]*>([\s\S]*?)</span>"#, in: region)
                .flatMap { firstCapture(#"<i[^>]*>([^<]+)</i>"#, in: $0) }
                .map { text(in: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
            seen.insert(id)
            result.append(AnimeCard(
                animeId: id, image: absolute(image), name: name,
                lastEpisode: episode.map { ChapterInfo(id: id, name: $0, extra: nil) },
                rate: 0, views: nil, quality: nil, process: nil, year: nil
            ))
        }
        return result
    }

    static func suggestions(from html: String) -> [SearchSuggestion] {
        cards(from: html).map { SearchSuggestion(id: $0.animeId, name: $0.name, image: $0.image) }
    }

    static func episodes(from html: String) -> [ChapterInfo] {
        let pattern = #"<a[^>]+(?:data-id|data-play)=["']([^"']+)["'][^>]*>([^<]+)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: html),
                  let nameRange = Range(match.range(at: 2), in: html) else { return nil }
            let id = String(html[idRange])
            let name = text(in: String(html[nameRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !name.isEmpty else { return nil }
            return ChapterInfo(id: id, name: name, extra: nil)
        }
    }

    static func player(from response: String) -> Result<PlayerData, APIError> {
        if let data = response.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let json = object["html"] as? String {
            return player(from: json)
        }
        let candidates = [
            #"https?://[^"' ]+\.m3u8[^"' ]*"#,
            #"https?://[^"' ]+\.(?:mp4|m3u8)[^"' ]*"#
        ]
        for pattern in candidates {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..<response.endIndex, in: response)),
               let range = Range(match.range, in: response) {
                return .success(PlayerData(link: String(response[range]), type: "hls", headers: nil, isContent: false))
            }
        }
        return .failure(.unsupportedResponse)
    }

    static func slug(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased().replacingOccurrences(of: " ", with: "-")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    static func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func attribute(_ name: String, in html: String) -> String? {
        let pattern = "\(name)=[\"']([^\"']+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }

    private static func firstCapture(_ pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }

    private static func text(in html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private static func absolute(_ value: String) -> String {
        if value.hasPrefix("http") { return value }
        if value.hasPrefix("/") { return APIClient.shared.baseURL.absoluteString + value }
        return "https:" + value
    }
}
