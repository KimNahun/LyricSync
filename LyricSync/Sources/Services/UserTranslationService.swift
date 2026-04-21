import Foundation

/// 유저 번역 Supabase CRUD Service.
actor UserTranslationService {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession

    init(
        baseURL: String = SupabaseConfig.baseURL,
        apiKey: String = SupabaseConfig.anonKey,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// 특정 곡의 유저 번역을 조회한다.
    func fetch(userId: Int, appleMusicID: String) async -> [UserTranslationLine] {
        let urlString = "\(baseURL)/user_translations?user_id=eq.\(userId)&apple_music_id=eq.\(appleMusicID)&select=lines"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            let rows = try JSONDecoder().decode([LinesRow].self, from: data)
            guard let lines = rows.first?.lines else { return [] }

            AppLogger.info("유저 번역 조회: \(lines.count)줄", category: .supabase)
            return lines
        } catch {
            AppLogger.error("유저 번역 조회 실패: \(error.localizedDescription)", category: .supabase)
            return []
        }
    }

    /// 유저 번역을 저장한다 (upsert).
    func save(userId: Int, appleMusicID: String, title: String, artist: String, lines: [UserTranslationLine]) async {
        guard let url = URL(string: "\(baseURL)/user_translations") else { return }

        let body: [String: Any] = [
            "user_id": userId,
            "apple_music_id": appleMusicID,
            "title": title,
            "artist": artist,
            "lines": lines.map { line in
                [
                    "index": line.index,
                    "original": line.original,
                    "translated": line.translated,
                    "timestamp": line.timestamp,
                ] as [String: Any]
            },
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            AppLogger.info("유저 번역 저장: status=\(status), \(lines.count)줄", category: .supabase)
        } catch {
            AppLogger.error("유저 번역 저장 실패: \(error.localizedDescription)", category: .supabase)
        }
    }

    // MARK: - 응답 모델

    private struct LinesRow: Decodable {
        let lines: [UserTranslationLine]
    }
}
