import Foundation

/// TranslatedLyricService의 프로토콜.
protocol TranslatedLyricServiceProtocol: Sendable {
    func fetchLyrics(appleMusicID: String) async -> TranslatedLyricResult
    func fetchTranslationStatus(appleMusicIDs: [String]) async -> Set<String>
}

/// Supabase 가사 조회 결과.
struct TranslatedLyricResult: Sendable {
    let originalLRC: String?
    let translatedLRC: String?
}

/// Supabase REST API에서 번역 가사를 조회하는 Service.
actor TranslatedLyricService: TranslatedLyricServiceProtocol {
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

    /// Apple Music ID로 원본 + 번역 가사를 조회한다.
    func fetchLyrics(appleMusicID: String) async -> TranslatedLyricResult {
        let urlString = "\(baseURL)/songs?apple_music_id=eq.\(appleMusicID)&select=id,title,artist,lyrics(type,lang,content,format)"

        guard let url = URL(string: urlString) else {
            return TranslatedLyricResult(originalLRC: nil, translatedLRC: nil)
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return TranslatedLyricResult(originalLRC: nil, translatedLRC: nil)
            }

            let songs = try JSONDecoder().decode([SupabaseSongResponse].self, from: data)
            guard let song = songs.first else {
                return TranslatedLyricResult(originalLRC: nil, translatedLRC: nil)
            }

            let original = song.lyrics.first(where: { $0.type == "original" && $0.format == "synced" })?.content
            let translated = song.lyrics.first(where: { $0.type == "translated" && $0.lang == "ko" && $0.format == "synced" })?.content

            return TranslatedLyricResult(originalLRC: original, translatedLRC: translated)
        } catch {
            return TranslatedLyricResult(originalLRC: nil, translatedLRC: nil)
        }
    }

    /// 여러 곡의 번역 여부를 배치 조회하여, 번역이 있는 apple_music_id 집합을 반환한다.
    func fetchTranslationStatus(appleMusicIDs: [String]) async -> Set<String> {
        guard !appleMusicIDs.isEmpty else { return [] }

        let idList = appleMusicIDs.map { "\"\($0)\"" }.joined(separator: ",")
        let urlString = "\(baseURL)/songs?apple_music_id=in.(\(idList))&select=apple_music_id,lyrics(type,lang)"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let songs = try JSONDecoder().decode([SupabaseSongStatusResponse].self, from: data)

            return Set(songs.compactMap { song in
                let hasTranslation = song.lyrics.contains { $0.type == "translated" && $0.lang == "ko" }
                return hasTranslation ? song.appleMusicID : nil
            })
        } catch {
            return []
        }
    }

    // MARK: - Supabase 응답 모델

    private struct SupabaseSongResponse: Decodable {
        let id: Int
        let title: String
        let artist: String
        let lyrics: [SupabaseLyricResponse]
    }

    private struct SupabaseLyricResponse: Decodable {
        let type: String
        let lang: String
        let content: String
        let format: String
    }

    private struct SupabaseSongStatusResponse: Decodable {
        let appleMusicID: String
        let lyrics: [SupabaseLyricStatusResponse]

        enum CodingKeys: String, CodingKey {
            case appleMusicID = "apple_music_id"
            case lyrics
        }
    }

    private struct SupabaseLyricStatusResponse: Decodable {
        let type: String
        let lang: String
    }
}
