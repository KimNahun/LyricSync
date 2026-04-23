import Foundation

/// UserTranslationService의 프로토콜. 테스트 시 Mock 주입을 위해 사용한다.
protocol UserTranslationServiceProtocol: Sendable {
    func fetch(userId: Int, appleMusicID: String, version: Int) async -> [UserTranslationLine]
    func save(userId: Int, appleMusicID: String, title: String, artist: String, lines: [UserTranslationLine], version: Int) async
    func fetchAll(userId: Int) async -> [MyTranslationSummary]
    func fetchVersions(userId: Int, appleMusicID: String) async -> [TranslationVersion]
    func fetchStudiedSongIDs(userId: Int) async -> Set<String>
    func nextVersion(userId: Int, appleMusicID: String) async -> Int
}

/// 유저 번역 Supabase CRUD Service.
actor UserTranslationService: UserTranslationServiceProtocol {
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

    /// 특정 곡의 특정 버전 유저 번역을 조회한다.
    func fetch(userId: Int, appleMusicID: String, version: Int = 1) async -> [UserTranslationLine] {
        let urlString = "\(baseURL)/user_translations?user_id=eq.\(userId)&apple_music_id=eq.\(appleMusicID)&version=eq.\(version)&select=lines"
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

            AppLogger.info("유저 번역 조회: \(lines.count)줄 (v\(version))", category: .supabase)
            return lines
        } catch {
            AppLogger.error("유저 번역 조회 실패: \(error.localizedDescription)", category: .supabase)
            return []
        }
    }

    /// 유저 번역을 저장한다 (upsert).
    func save(userId: Int, appleMusicID: String, title: String, artist: String, lines: [UserTranslationLine], version: Int = 1) async {
        guard let url = URL(string: "\(baseURL)/user_translations") else { return }

        let body: [String: Any] = [
            "user_id": userId,
            "apple_music_id": appleMusicID,
            "title": title,
            "artist": artist,
            "version": version,
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
            AppLogger.info("유저 번역 저장: status=\(status), \(lines.count)줄, v\(version)", category: .supabase)
        } catch {
            AppLogger.error("유저 번역 저장 실패: \(error.localizedDescription)", category: .supabase)
        }
    }

    /// 유저의 모든 번역을 곡별로 그룹화하여 조회한다. 각 곡의 최신 버전 기준.
    func fetchAll(userId: Int) async -> [MyTranslationSummary] {
        let urlString = "\(baseURL)/user_translations?user_id=eq.\(userId)&select=apple_music_id,title,artist,lines,version,updated_at&order=updated_at.desc"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            let rows = try JSONDecoder().decode([AllRow].self, from: data)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // 곡별 그룹화 — 가장 최근 updated_at 버전만 표시
            var seen = Set<String>()
            var results: [MyTranslationSummary] = []

            for row in rows {
                guard !seen.contains(row.apple_music_id) else { continue }
                seen.insert(row.apple_music_id)
                results.append(MyTranslationSummary(
                    appleMusicID: row.apple_music_id,
                    title: row.title,
                    artist: row.artist,
                    lineCount: row.lines.count,
                    createdAt: formatter.date(from: row.updated_at ?? ""),
                    versionCount: rows.filter { $0.apple_music_id == row.apple_music_id }.count
                ))
            }

            return results
        } catch {
            AppLogger.error("내 번역 전체 조회 실패: \(error.localizedDescription)", category: .supabase)
            return []
        }
    }

    /// 특정 곡의 모든 번역 버전을 조회한다.
    func fetchVersions(userId: Int, appleMusicID: String) async -> [TranslationVersion] {
        let urlString = "\(baseURL)/user_translations?user_id=eq.\(userId)&apple_music_id=eq.\(appleMusicID)&select=version,lines,updated_at&order=version.desc"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            let rows = try JSONDecoder().decode([VersionRow].self, from: data)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            return rows.map { row in
                TranslationVersion(
                    version: row.version,
                    lineCount: row.lines.count,
                    updatedAt: formatter.date(from: row.updated_at ?? "")
                )
            }
        } catch {
            AppLogger.error("번역 버전 조회 실패: \(error.localizedDescription)", category: .supabase)
            return []
        }
    }

    /// 유저가 번역한 곡의 apple_music_id 집합을 반환한다 (배지용).
    func fetchStudiedSongIDs(userId: Int) async -> Set<String> {
        let urlString = "\(baseURL)/user_translations?user_id=eq.\(userId)&select=apple_music_id"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return [] }

            let rows = try JSONDecoder().decode([[String: String]].self, from: data)
            return Set(rows.compactMap { $0["apple_music_id"] })
        } catch {
            AppLogger.error("공부 곡 ID 조회 실패: \(error.localizedDescription)", category: .supabase)
            return []
        }
    }

    /// 다음 버전 번호를 계산한다.
    func nextVersion(userId: Int, appleMusicID: String) async -> Int {
        let versions = await fetchVersions(userId: userId, appleMusicID: appleMusicID)
        return (versions.map(\.version).max() ?? 0) + 1
    }

    // MARK: - 응답 모델

    private struct LinesRow: Decodable {
        let lines: [UserTranslationLine]
    }

    private struct AllRow: Decodable {
        let apple_music_id: String
        let title: String
        let artist: String
        let lines: [UserTranslationLine]
        let version: Int
        let updated_at: String?
    }

    private struct VersionRow: Decodable {
        let version: Int
        let lines: [UserTranslationLine]
        let updated_at: String?
    }
}
