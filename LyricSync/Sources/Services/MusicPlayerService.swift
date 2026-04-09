import Foundation
import MusicKit

/// MusicPlayerService가 던지는 에러 타입.
enum MusicPlayerError: Error, LocalizedError {
    case songNotFound
    case playbackFailed(Error)

    var errorDescription: String? {
        switch self {
        case .songNotFound:
            return "곡을 찾을 수 없습니다."
        case .playbackFailed(let error):
            return "재생에 실패했습니다: \(error.localizedDescription)"
        }
    }
}

/// ApplicationMusicPlayer.shared를 래핑하는 재생 Service.
/// actor로 선언하여 Swift 6 동시성 경계를 안전하게 유지한다.
actor MusicPlayerService {
    private let player = ApplicationMusicPlayer.shared

    /// 지정한 Song을 재생한다. MusicKit Song을 재조회하여 큐에 설정한다.
    func play(song: Song) async throws {
        do {
            var request = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id,
                equalTo: song.musicKitID
            )
            request.limit = 1
            let response = try await request.response()

            guard let musicKitSong = response.items.first else {
                throw MusicPlayerError.songNotFound
            }

            player.queue = [musicKitSong]
            try await player.play()
        } catch let error as MusicPlayerError {
            throw error
        } catch {
            throw MusicPlayerError.playbackFailed(error)
        }
    }

    /// 현재 재생을 일시정지한다.
    func pause() {
        player.pause()
    }

    /// 일시정지된 재생을 재개한다.
    func resume() async throws {
        do {
            try await player.play()
        } catch {
            throw MusicPlayerError.playbackFailed(error)
        }
    }

    /// 지정한 시간으로 재생 위치를 이동한다.
    func seek(to time: TimeInterval) {
        player.playbackTime = time
    }

    /// 현재 재생 시간을 반환한다.
    var playbackTime: TimeInterval {
        player.playbackTime
    }

    /// 현재 재생 상태를 반환한다.
    var playbackStatus: MusicPlayer.PlaybackStatus {
        player.state.playbackStatus
    }
}
