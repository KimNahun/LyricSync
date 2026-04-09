import Foundation

/// 가사 로딩 상태를 나타내는 enum.
/// lrclib.net API 응답 결과에 따라 FullPlayerView가 분기 표시에 사용한다.
enum LyricState: Sendable {
    /// 가사를 불러오는 중
    case loading
    /// 타임스탬프 기반 싱크 가사 (LRC 파싱 완료)
    case synced([LyricLine])
    /// 타임스탬프 없는 일반 가사 (syncedLyrics 없을 때 폴백)
    case plain(String)
    /// 인스트루멘탈 곡 (가사 없음)
    case instrumental
    /// 가사를 찾을 수 없음 (404)
    case notFound
    /// 에러 발생 (429 등 네트워크 문제)
    case error(String)
}
