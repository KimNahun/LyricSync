import Foundation

/// LyricService가 사용하는 내부 에러 타입.
enum LyricServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .decodingError(let error):
            return "데이터 파싱 오류: \(error.localizedDescription)"
        }
    }
}

/// lrclib.net API에서 가사를 조회하고 LRC 형식을 파싱하는 Service.
actor LyricService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 아티스트명과 곡명으로 가사를 조회하여 LyricState를 반환한다.
    /// 이 메서드는 throws 대신 LyricState로 에러를 포함하여 반환한다 (재생 블로킹 방지).
    func fetchLyrics(artist: String, track: String, duration: TimeInterval?) async -> LyricState {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else {
            return .error("잘못된 URL입니다.")
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: track)
        ]
        if let duration = duration {
            queryItems.append(URLQueryItem(name: "duration", value: "\(Int(duration))"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            return .error("URL 생성에 실패했습니다.")
        }

        var request = URLRequest(url: url)
        request.setValue("LyricSync v1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("서버 응답을 받지 못했습니다.")
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 404:
                return .notFound
            case 429:
                return .error("요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.")
            default:
                return .error("서버 오류가 발생했습니다. (코드: \(httpResponse.statusCode))")
            }

            let lrcResponse = try JSONDecoder().decode(LrcLibResponse.self, from: data)

            if lrcResponse.instrumental {
                return .instrumental
            }

            if let syncedLyrics = lrcResponse.syncedLyrics, !syncedLyrics.isEmpty {
                let lines = parseLRC(syncedLyrics)
                return lines.isEmpty ? .notFound : .synced(lines)
            }

            if let plainLyrics = lrcResponse.plainLyrics, !plainLyrics.isEmpty {
                return .plain(plainLyrics)
            }

            return .notFound
        } catch {
            return .error("가사를 불러오지 못했습니다: \(error.localizedDescription)")
        }
    }

    /// LRC 형식 문자열을 파싱하여 LyricLine 배열로 반환한다.
    /// 정규식: [MM:SS.ss] 텍스트
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        let pattern = /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/
        return lrc.components(separatedBy: "\n").compactMap { line in
            guard let match = line.firstMatch(of: pattern) else { return nil }
            let minutes = Double(match.1) ?? 0
            let seconds = Double(match.2) ?? 0
            let timestamp = minutes * 60 + seconds
            let text = String(match.3)
            return LyricLine(timestamp: timestamp, text: text)
        }
    }

    // MARK: - lrclib.net 응답 구조체

    private struct LrcLibResponse: Decodable {
        let id: Int
        let trackName: String
        let artistName: String
        let albumName: String?
        let duration: Double
        let instrumental: Bool
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}
