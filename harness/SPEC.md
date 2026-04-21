# LyricSync

## 개요

Apple Music Top 100 인기 팝 차트에서 곡을 선택하여 재생하고, lrclib.net에서 가져온 싱크 가사를 실시간 하이라이트로 표시하는 iOS 앱. Apple Music 구독자가 슬라이더로 특정 시간으로 이동하면서 가사를 따라갈 수 있다.

## 타겟 플랫폼

- iOS 17.0 이상
- Swift 버전: Swift 6 (엄격 동시성 필수)
- 필요 권한: MusicKit (Apple Music 접근 — `MusicAuthorization.request()`)
- 필요 Capability: MusicKit
- Info.plist: `NSAppleMusicUsageDescription` — "음악 검색 및 재생을 위해 Apple Music 접근이 필요합니다."
- UI 프레임워크: SwiftUI 전용 (UIKit 미사용)
- 번들 ID: com.nahun.LyricSync

## 아키텍처

### 레이어 구조

```
LyricSync/Sources/
├── App/
│   └── LyricSyncApp.swift              # @main, MusicKit 권한 요청, PlayerViewModel 생성 및 @Environment 주입
├── Views/
│   ├── Chart/
│   │   ├── ChartListView.swift         # @MainActor struct — Top 100 리스트, NavigationStack 루트
│   │   └── SongRowView.swift           # @MainActor struct — 개별 곡 행 컴포넌트
│   ├── Detail/
│   │   └── SongDetailView.swift        # @MainActor struct — 노래 상세 + 재생 버튼
│   ├── Player/
│   │   ├── MiniPlayerView.swift        # @MainActor struct — 하단 고정 미니 플레이어
│   │   └── FullPlayerView.swift        # @MainActor struct — 풀 플레이어 (슬라이더 + 가사)
│   └── Components/
│       └── LyricLineView.swift         # @MainActor struct — 가사 한 줄 컴포넌트
├── ViewModels/
│   ├── Chart/
│   │   └── ChartViewModel.swift        # @MainActor final class, @Observable
│   └── Player/
│       └── PlayerViewModel.swift       # @MainActor final class, @Observable (앱 전체 싱글 인스턴스)
├── Models/
│   ├── Song.swift                      # struct, Sendable — MusicKit Song 래핑
│   ├── LyricLine.swift                 # struct, Sendable, Identifiable — 타임스탬프 + 텍스트
│   └── LyricState.swift               # enum, Sendable — synced/plain/instrumental/notFound/loading/error
├── Services/
│   ├── ChartService.swift              # actor — MusicCatalogChartsRequest, Pop 장르 필터
│   ├── MusicPlayerService.swift        # actor — ApplicationMusicPlayer.shared 래핑
│   └── LyricService.swift             # actor — lrclib.net API 호출 + LRC 파싱
└── Shared/
    └── TimeFormatUtil.swift            # "1:23" 포맷 유틸
```

### 동시성 경계

- **View**: `@MainActor` struct — UI 선언만 담당, 비즈니스 로직 없음, 상태 소유 없음
- **ViewModel**: `@MainActor final class` + `@Observable` — UI 상태 소유, `import SwiftUI` 금지 (단, `@Observable`은 Observation 프레임워크이므로 허용)
- **Service**: `actor` — 비동기 데이터 처리, 외부 API 호출. ViewModel/View 참조 금지
- **Model**: `struct` + `Sendable` — 순수 데이터, 부수효과 없음

금지 항목: `DispatchQueue`, `@Published`, `ObservableObject`, UIKit import

### 의존성 흐름

```
View → ViewModel → Service → (MusicKit / lrclib.net)
```

역방향 의존 금지. Service는 ViewModel을 모른다. ViewModel은 View를 모른다.

---

## 기능 목록

### 기능 1: MusicKit 권한 요청

- 설명: 앱 시작 시 Apple Music 접근 권한을 요청하고, 결과에 따라 메인 화면 진입 또는 안내 문구 표시
- 사용자 스토리: 사용자가 앱을 처음 실행하면 Apple Music 권한 요청 다이얼로그가 나타난다. 승인하면 Top 100 리스트를 볼 수 있고, 거부하면 "Apple Music 접근 권한이 필요합니다. 설정에서 허용해 주세요." 안내가 표시된다.
- 관련 파일:
  - View: `LyricSyncApp.swift` (앱 진입점에서 `.task`로 권한 요청)
  - View: `ChartListView.swift` (권한 미승인 시 안내 문구 표시)
- 사용 API: MusicKit — `MusicAuthorization.request()`
- HIG 패턴: 시스템 권한 다이얼로그 (OS 기본), 별도 온보딩 화면 없음

### 기능 2: Top 100 인기 팝 차트 리스트 (메인 화면)

- 설명: Apple Music Pop 장르 기준 Most Played 차트 곡 목록을 리스트로 표시
- 사용자 스토리: 사용자가 메인 화면에서 순위, 앨범 아트 썸네일, 곡명, 아티스트명이 포함된 인기 팝 차트 리스트를 스크롤하며 탐색한다. 로딩 중에는 ProgressView가 표시되고, 에러 발생 시 재시도 버튼이 나타난다.
- 관련 파일:
  - View: `ChartListView.swift`, `SongRowView.swift`
  - ViewModel: `ChartViewModel.swift`
  - Service: `ChartService.swift`
  - Model: `Song.swift`
- 사용 API: MusicKit — `MusicCatalogResourceRequest<Genre>` (Pop 장르 ID "14" fetch), `MusicCatalogChartsRequest` (genre: popGenre, kinds: [.mostPlayed], types: [Song.self], limit: 50)
- HIG 패턴: `NavigationStack` + `List`, 로딩 시 `ProgressView`, 에러 시 재시도 `Button`

### 기능 3: 노래 상세 페이지

- 설명: 차트에서 선택한 곡의 상세 정보를 표시하고 재생을 시작할 수 있는 화면
- 사용자 스토리: 사용자가 리스트에서 곡을 탭하면 상세 페이지로 이동한다. 큰 앨범 아트, 곡명, 아티스트명, 앨범명이 표시되고, 재생 버튼을 탭하면 음악이 재생된다. 재생 중이면 버튼이 일시정지 아이콘으로 전환된다.
- 관련 파일:
  - View: `SongDetailView.swift`
  - ViewModel: `PlayerViewModel.swift` (공유 — 별도 VM 불필요)
  - Service: `MusicPlayerService.swift`
  - Model: `Song.swift`
- 사용 API: MusicKit — `ApplicationMusicPlayer.shared` (play, pause)
- HIG 패턴: `NavigationStack` push, 큰 이미지 + 메타데이터 + 액션 버튼 레이아웃

### 기능 4: 미니 플레이어 (글로벌 하단 고정)

- 설명: 재생 중인 곡이 있을 때 모든 화면 하단에 고정 표시되는 소형 플레이어
- 사용자 스토리: 사용자가 곡을 재생하면 화면 하단에 미니 플레이어가 나타난다. 앨범 아트(소), 곡명, 아티스트명, 재생/일시정지 버튼, 프로그레스바가 표시된다. 다른 화면(차트, 상세)으로 이동해도 미니 플레이어는 항상 하단에 보인다. 미니 플레이어를 탭하면 풀 플레이어가 열린다.
- 관련 파일:
  - View: `MiniPlayerView.swift`
  - ViewModel: `PlayerViewModel.swift` (공유)
  - Service: `MusicPlayerService.swift`
- 사용 API: MusicKit — `ApplicationMusicPlayer.shared` (playbackTime, state)
- HIG 패턴: `.safeAreaInset(edge: .bottom)` — NavigationStack 밖에서 주입하여 모든 하위 화면에 표시. 탭 시 `.fullScreenCover`로 FullPlayerView 표시

### 기능 5: 풀 플레이어 (가사 싱크 하이라이트 + 슬라이더)

- 설명: 전체 화면 플레이어로 슬라이더 seek과 실시간 가사 하이라이트를 제공
- 사용자 스토리: 사용자가 미니 플레이어를 탭하면 풀 플레이어가 fullScreenCover로 열린다. 큰 앨범 아트, 곡명, 아티스트명이 상단에 표시되고, 슬라이더로 재생 위치를 조절할 수 있다(현재 시간 / 전체 시간 표시). 가사 영역에서는 현재 재생 중인 줄이 밝게(`.primary`, `.semibold`) 하이라이트되고 나머지는 흐리게(`.secondary`) 표시된다. 가사는 자동으로 스크롤되며, 사용자가 수동 스크롤하면 5초 후 자동 스크롤이 재개된다. 닫기 버튼으로 dismiss한다.
- 관련 파일:
  - View: `FullPlayerView.swift`, `LyricLineView.swift`
  - ViewModel: `PlayerViewModel.swift` (공유)
  - Service: `MusicPlayerService.swift`, `LyricService.swift`
  - Model: `LyricLine.swift`, `LyricState.swift`
- 사용 API: MusicKit — `ApplicationMusicPlayer.shared` (seek via `playbackTime` 할당), lrclib.net — `GET /api/get`
- HIG 패턴: `.fullScreenCover`, `ScrollView` + `ScrollViewReader` 자동 스크롤, `Slider`, 닫기 버튼

### 기능 6: 가사 Fetch 및 LRC 파싱

- 설명: lrclib.net API에서 가사를 조회하고 LRC 형식을 파싱하여 타임스탬프 배열로 변환
- 사용자 스토리: 사용자가 곡을 재생하면 백그라운드에서 자동으로 가사를 가져온다. syncedLyrics가 있으면 시간 동기화 가사를, plainLyrics만 있으면 정적 가사를, instrumental이면 "이 곡은 인스트루멘탈입니다"를, 가사를 찾을 수 없으면 "가사를 찾을 수 없습니다"를 표시한다.
- 관련 파일:
  - Service: `LyricService.swift`
  - Model: `LyricLine.swift`, `LyricState.swift`
  - ViewModel: `PlayerViewModel.swift` (fetchLyrics 호출)
- 사용 API: lrclib.net — `GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}`
- HIG 패턴: 비동기 로딩 (재생을 블록하지 않음), 상태별 안내 문구

### 기능 7: 재생 시간 폴링 및 가사 하이라이트 동기화

- 설명: 0.1초 Timer로 현재 재생 시간을 감시하여 활성 가사 줄을 결정하고 자동 스크롤
- 사용자 스토리: 음악이 재생되는 동안 가사 영역에서 현재 줄이 자동으로 하이라이트되고, 스크롤이 현재 줄을 따라간다. 슬라이더를 드래그하면 드래그 완료 시 해당 위치로 seek하고 가사도 재동기화된다.
- 관련 파일:
  - ViewModel: `PlayerViewModel.swift` (Timer, currentLyricIndex 계산, isDragging/isUserScrolling 상태)
  - Service: `MusicPlayerService.swift` (playbackTime 제공)
- 사용 API: MusicKit — `ApplicationMusicPlayer.shared.playbackTime`
- HIG 패턴: 부드러운 애니메이션 (`.easeInOut(duration: 0.2)`), 사용자 스크롤 존중 (5초 후 자동 복귀)

---

## API 활용 계획

### MusicKit

- 사용 타입:
  - `MusicAuthorization` — 권한 요청
  - `MusicCatalogResourceRequest<Genre>` — Pop 장르 객체 fetch (장르 ID "14")
  - `MusicCatalogChartsRequest` — Top Songs 차트 조회 (genre: popGenre, kinds: [.mostPlayed], types: [Song.self], limit: 50)
  - `ApplicationMusicPlayer` — 싱글톤 (`shared`), 재생/일시정지/seek
  - `Song` (MusicKit) — id, title, artistName, albumTitle, artwork, duration
  - `Artwork` — `url(width:height:)` 로 이미지 URL 획득
- 권한 요청 시점: `LyricSyncApp.swift`의 `.task` modifier에서 앱 시작 즉시 요청
- 연동 기능:
  - 차트 조회 → ChartService → ChartViewModel → ChartListView
  - 재생/일시정지/seek → MusicPlayerService → PlayerViewModel → SongDetailView, MiniPlayerView, FullPlayerView
  - 재생 시간 폴링 → PlayerViewModel의 0.1초 Timer → currentLyricIndex 계산

### lrclib.net

- 엔드포인트: `GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}`
- 요청 파라미터:
  - `artist_name` (필수): MusicKit Song의 artistName
  - `track_name` (필수): MusicKit Song의 title
  - `duration` (선택, 정확도 향상): MusicKit Song의 duration (초 단위, Int 변환)
- 응답 파싱:
  - `syncedLyrics` (nullable String) → LRC 파싱 → `[LyricLine]` 배열
  - LRC 정규식: `/\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/`
  - 타임스탬프 변환: `MM * 60 + SS.ss` = 초 단위 `TimeInterval`
- 폴백 전략:
  1. `syncedLyrics` 있음 → `.synced([LyricLine])` — 타임스탬프 기반 하이라이트
  2. `syncedLyrics` null + `plainLyrics` 있음 → `.plain(String)` — 정적 표시
  3. `instrumental == true` → `.instrumental` — "이 곡은 인스트루멘탈입니다"
  4. 404 or 네트워크 에러 → `.notFound` — "가사를 찾을 수 없습니다"
  5. 429 Too Many Requests → `.error(String)` — rate limit 안내
- URL 인코딩: `URLComponents`를 사용하여 자동 인코딩
- User-Agent 헤더: `LyricSync v1.0` (rate limit 완화용)

### AuthenticationServices

- 1차 목표에서 제외. MusicKit 권한 요청으로 대체.
- 추후 2차 목표에서 Apple 로그인 추가 예정.

---

## 뷰 계층 (Navigation Flow)

```
LyricSyncApp (@main)
│
├── [.task] MusicKit 권한 요청 (MusicAuthorization.request())
├── [@State] PlayerViewModel 생성
├── [@Environment] PlayerViewModel 하위 뷰에 주입
│
└── ZStack / overlay 구조
    │
    ├── NavigationStack
    │   │
    │   ├── ChartListView (루트 — Top 100 인기 팝 리스트)
    │   │   ├── 권한 미승인 시: 안내 문구 + 설정 유도
    │   │   ├── 로딩 중: ProgressView
    │   │   ├── 에러: 에러 메시지 + 재시도 버튼
    │   │   └── 데이터: List > SongRowView (순위, 앨범아트, 곡명, 아티스트)
    │   │       └── [탭] → NavigationLink → SongDetailView
    │   │
    │   └── SongDetailView (push)
    │       ├── 큰 앨범 아트
    │       ├── 곡명, 아티스트명, 앨범명
    │       └── 재생/일시정지 버튼 → PlayerViewModel.play(song:) / .pause()
    │
    ├── .safeAreaInset(edge: .bottom)
    │   └── MiniPlayerView (재생 중일 때만 표시)
    │       ├── 앨범 아트(소), 곡명, 아티스트명
    │       ├── 재생/일시정지 버튼
    │       ├── 프로그레스바 (ProgressView linear)
    │       └── [탭] → showFullPlayer = true
    │
    └── .fullScreenCover(isPresented: $showFullPlayer)
        └── FullPlayerView
            ├── 닫기 버튼 (chevron.down)
            ├── 큰 앨범 아트
            ├── 곡명, 아티스트명
            ├── 슬라이더 + 현재시간/전체시간 (TimeFormatUtil)
            │   ├── 드래그 시작 → isDragging = true → 가사 스크롤 freeze
            │   ├── 드래그 중 → sliderValue UI만 업데이트
            │   └── 드래그 완료 → MusicPlayerService.seek(to:) 1회 → isDragging = false
            ├── 재생/일시정지 버튼
            └── 가사 영역 (ScrollView + ScrollViewReader)
                ├── LyricLineView x N
                │   ├── 활성: .primary + .body.weight(.semibold) + animation
                │   └── 비활성: .secondary + .body + animation
                ├── syncedLyrics: 자동 스크롤 (currentLyricIndex 기준)
                ├── plainLyrics: 정적 텍스트 표시
                ├── instrumental: "이 곡은 인스트루멘탈입니다"
                └── notFound: "가사를 찾을 수 없습니다"
```

---

## 데이터 모델 상세

### Song (Models/Song.swift)

```
struct Song: Identifiable, Sendable
├── id: String (MusicItemID에서 변환)
├── title: String
├── artistName: String
├── albumTitle: String?
├── artworkURL: URL? (artwork?.url(width:height:)로 추출)
├── duration: TimeInterval?
├── rank: Int? (차트 순위, 1-based)
└── musicKitID: MusicItemID (재생 시 MusicKit Song 재조회용)
```

### LyricLine (Models/LyricLine.swift)

```
struct LyricLine: Identifiable, Sendable
├── id: UUID
├── timestamp: TimeInterval (초 단위)
└── text: String
```

### LyricState (Models/LyricState.swift)

```
enum LyricState: Sendable
├── case loading
├── case synced([LyricLine])
├── case plain(String)
├── case instrumental
├── case notFound
└── case error(String)
```

---

## ViewModel 상세

### ChartViewModel (ViewModels/Chart/ChartViewModel.swift)

```
@MainActor @Observable final class ChartViewModel
├── private(set) var songs: [Song] = []
├── private(set) var isLoading: Bool = false
├── private(set) var errorMessage: String? = nil
├── private let chartService: ChartService
│
├── init(chartService: ChartService)
└── func fetchCharts() async
    └── chartService.fetchChart() → songs 또는 errorMessage 설정
```

### PlayerViewModel (ViewModels/Player/PlayerViewModel.swift)

**앱 전체 단일 인스턴스** — `LyricSyncApp`에서 `@State`로 생성, `@Environment`로 주입.

```
@MainActor @Observable final class PlayerViewModel
├── private(set) var currentSong: Song? = nil
├── private(set) var isPlaying: Bool = false
├── private(set) var currentTime: TimeInterval = 0
├── private(set) var duration: TimeInterval = 0
├── private(set) var lyricState: LyricState = .loading
├── var isDragging: Bool = false (슬라이더 드래그 상태)
├── var sliderValue: TimeInterval = 0 (슬라이더 UI 값)
├── var isUserScrolling: Bool = false (사용자 수동 스크롤 상태)
├── var showFullPlayer: Bool = false (fullScreenCover 바인딩)
│
├── var currentLyricIndex: Int? (computed)
│   └── guard case .synced(let lines) = lyricState
│       return lines.indices.last(where: { lines[$0].timestamp <= currentTime })
│
├── private let musicPlayerService: MusicPlayerService
├── private let lyricService: LyricService
├── private var timer: Timer? (0.1초 폴링)
├── private var userScrollTimer: Timer? (5초 복귀)
│
├── init(musicPlayerService: MusicPlayerService, lyricService: LyricService)
├── func play(song: Song) async
│   ├── musicPlayerService.play(song:)
│   ├── lyricState = .loading
│   ├── fetchLyrics(song:) (비동기, 재생 블록 안 함)
│   ├── startTimer()
│   └── isUserScrolling = false (새 곡 → 자동 스크롤 초기화)
├── func pause() async
├── func resume() async
├── func seek(to time: TimeInterval) async
│   └── musicPlayerService.seek(to:) → isDragging = false → 가사 재동기화
├── func onUserScrollBegan()
│   └── isUserScrolling = true, userScrollTimer 취소
├── func onUserScrollEnded()
│   └── 5초 타이머 시작 → isUserScrolling = false
├── private func startTimer()
│   └── Timer 0.1초: isDragging이 false일 때만 currentTime 업데이트
├── private func stopTimer()
├── private func fetchLyrics(song: Song) async
│   └── lyricService.fetchLyrics(artist:track:duration:) → lyricState 업데이트
└── deinit → stopTimer()
```

---

## Service 상세

### ChartService (Services/ChartService.swift)

```
actor ChartService
├── func fetchChart() async throws -> [Song]
│   ├── 1단계: MusicCatalogResourceRequest<Genre>(matching: \.id, equalTo: MusicItemID("14"))
│   │   → Pop 장르 객체 fetch
│   ├── 2단계: MusicCatalogChartsRequest(genre: popGenre, kinds: [.mostPlayed], types: [Song.self])
│   │   limit = 50
│   │   → chartResponse.songCharts.first?.items
│   └── MusicKit Song → 앱 Song 모델 변환 (rank 부여: 1-based index)
│
└── enum ChartServiceError: Error
    ├── case authorizationDenied
    ├── case chartEmpty
    └── case networkError(Error)
```

### MusicPlayerService (Services/MusicPlayerService.swift)

```
actor MusicPlayerService
├── private let player = ApplicationMusicPlayer.shared
│
├── func play(song: Song) async throws
│   ├── MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, equalTo: MusicItemID(song.musicKitID))
│   │   → MusicKit Song 객체 재조회
│   ├── player.queue = [musicKitSong]
│   └── try await player.play()
├── func pause()
│   └── player.pause()
├── func seek(to time: TimeInterval)
│   └── player.playbackTime = time
├── var playbackTime: TimeInterval
│   └── player.playbackTime
├── var playbackStatus: MusicPlayer.PlaybackStatus
│   └── player.state.playbackStatus
│
└── enum MusicPlayerError: Error
    ├── case songNotFound
    └── case playbackFailed(Error)
```

### LyricService (Services/LyricService.swift)

```
actor LyricService
├── private let session: URLSession (기본 URLSession.shared)
│
├── func fetchLyrics(artist: String, track: String, duration: TimeInterval?) async -> LyricState
│   ├── URLComponents로 URL 구성
│   │   baseURL: "https://lrclib.net/api/get"
│   │   queryItems: artist_name, track_name, duration (Int 변환)
│   ├── URLRequest + User-Agent: "LyricSync v1.0"
│   ├── URLSession.shared.data(for: request)
│   ├── HTTP 404 → return .notFound
│   ├── HTTP 429 → return .error("요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.")
│   ├── JSON 디코딩 (LrcLibResponse)
│   ├── instrumental == true → return .instrumental
│   ├── syncedLyrics != nil → parseLRC() → return .synced([LyricLine])
│   ├── plainLyrics != nil → return .plain(plainLyrics)
│   └── 그 외 → return .notFound
│
├── private func parseLRC(_ lrc: String) -> [LyricLine]
│   ├── lrc.components(separatedBy: "\n")
│   ├── 정규식: /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/
│   ├── MM * 60 + SS.ss → timestamp: TimeInterval
│   └── LyricLine(timestamp:text:) 배열 반환
│
├── private struct LrcLibResponse: Decodable
│   ├── id: Int
│   ├── trackName: String
│   ├── artistName: String
│   ├── albumName: String?
│   ├── duration: Double
│   ├── instrumental: Bool
│   ├── plainLyrics: String?
│   └── syncedLyrics: String?
│
└── enum LyricServiceError: Error
    ├── case invalidURL
    ├── case networkError(Error)
    └── case decodingError(Error)
```

---

## 핵심 동작 상세

### 가사 하이라이트 로직

- PlayerViewModel의 `currentLyricIndex` computed property:
  - `lyricState`가 `.synced(lines)`일 때만 계산
  - `lines.indices.last(where: { lines[$0].timestamp <= currentTime })` — 현재 시간보다 작거나 같은 타임스탬프 중 가장 마지막
- LyricLineView 표시:
  - 활성 (isActive == true): `.foregroundStyle(.primary)` + `.font(.body.weight(.semibold))`
  - 비활성 (isActive == false): `.foregroundStyle(.secondary)` + `.font(.body)`
  - 전환 애니메이션: `.animation(.easeInOut(duration: 0.2), value: isActive)`
- semantic color로 다크모드 자동 대응

### 가사 자동 스크롤 로직

- Apple Music 방식 채택 (사용자 스크롤 존중)
- `ScrollViewReader` + `scrollTo(id:, anchor: .center)` — currentLyricIndex 변경 시 실행
- 사용자 터치/드래그 감지 → `isUserScrolling = true` → 자동 스크롤 정지
- 사용자 손 뗌 → 5초 타이머 시작
- 5초 경과 → `isUserScrolling = false` → 현재 재생 가사로 자동 스크롤 재개
- 새 곡 시작 → `isUserScrolling` 강제 `false` → 처음부터 자동 스크롤
- 슬라이더 드래그 중 (`isDragging == true`) → 가사 스크롤도 freeze

### 슬라이더 seek 처리

- Spotify / Apple Music 표준: 드래그 완료 시에만 seek 1회 호출
- 드래그 시작 → `isDragging = true` → Timer 폴링 결과 무시 (sliderValue가 currentTime을 덮어쓰지 않음)
- 드래그 중 → `sliderValue` UI만 업데이트 (seek 호출 없음)
- 드래그 완료 → `MusicPlayerService.seek(to: sliderValue)` 1회 호출 → `isDragging = false` → Timer 폴링 재개 → 가사 재동기화

### 미니 플레이어 표시 조건

- `PlayerViewModel.currentSong != nil` — 재생 중인 곡이 있을 때만 표시
- `.safeAreaInset(edge: .bottom)` — NavigationStack 밖에서 주입
- NavigationStack 내 어떤 화면(ChartListView, SongDetailView)에서도 하단에 항상 표시

---

## 에러 처리

### ChartServiceError

- `authorizationDenied` → ChartListView에서 "Apple Music 접근 권한이 필요합니다. 설정에서 허용해 주세요." 표시
- `chartEmpty` → "차트 데이터를 불러올 수 없습니다." + 재시도 버튼
- `networkError` → "네트워크 오류가 발생했습니다." + 재시도 버튼

### MusicPlayerError

- `songNotFound` → "곡을 찾을 수 없습니다." 표시
- `playbackFailed` → "재생에 실패했습니다." 표시

### LyricServiceError

- 에러 시 `LyricState.error(message)` 또는 `.notFound`로 처리
- 사용자에게 적절한 안내 문구 표시 (FullPlayerView 가사 영역)

---

## 코드 컨벤션 (Generator가 따를 것)

- 뷰 파일: `[Feature]View.swift` — body만 갖는 순수 뷰, 비즈니스 로직 없음
- 뷰모델 파일: `[Feature]ViewModel.swift` — `@Observable`, `@MainActor final class`
- 서비스 파일: `[Feature]Service.swift` — `actor`
- 모든 `public`/`internal` 프로퍼티에 접근 제어자 명시
- `private(set)`으로 외부 변이 차단 (ViewModel의 상태 프로퍼티)
- 에러 타입은 `enum [Domain]Error: Error`로 정의
- ViewModel에서 `import SwiftUI` 금지 — `import Observation`만 허용 (또는 `import Foundation`)
- `DispatchQueue`, `@Published`, `ObservableObject` 사용 금지
- semantic color만 사용: `.primary`, `.secondary`, `.accentColor`, `Color(.systemBackground)`
- semantic font만 사용: `.font(.headline)`, `.font(.body)` 등 Dynamic Type 지원
- 접근성: 주요 인터랙션 요소에 `.accessibilityLabel` 추가
- 터치 영역: 44x44pt 이상 보장 (특히 가사 줄, 버튼)

---

## 제약 사항 및 주의 사항

- 시뮬레이터에서 MusicKit 재생 불가 — 실기기 테스트 필수
- Apple Music 구독 미보유 시 30초 미리듣기(preview) 자동 제공 — 별도 처리 불필요
- Pop 장르 ID "14"는 사용자 지역에 따라 다를 수 있음 — 실기기 테스트 후 필요 시 수정
- lrclib.net은 인증 불필요하나 rate limit 존재 — 429 에러 처리 필수
- MusicKit 가사 기능은 사용하지 않음 — 화면에 보이는 가사는 lrclib.net 데이터만 사용
- `ApplicationMusicPlayer.shared`는 싱글톤 — `MusicPlayerService` actor에서 래핑
- 파일 생성 위치: `LyricSync/Sources/` 하위 (output/ 폴더 없이 직접 생성)
