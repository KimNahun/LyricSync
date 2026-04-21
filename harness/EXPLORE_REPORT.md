# 탐색 보고서 — LyricSync 프로젝트

생성일: 2026-04-09

---

## 요약

LyricSync는 Apple Music Top 100 차트에서 곡을 선택하여 재생하고, 동기화된 가사를 슬라이더 시크와 함께 표시하는 iOS 앱입니다. 현재 초기 프레임워크만 구성되어 있으며, 핵심 Views, ViewModels, Services, Models가 구현되어야 합니다.

---

## 파일 구조

### LyricSync/Sources/ 현황

```
LyricSync/Sources/
├── App/
│   ├── LyricSyncApp.swift              — 앱 진입점 (@main)
│   └── ContentView.swift               — 임시 빈 뷰 ("LyricSync" 텍스트만 표시)
├── Views/
│   ├── Chart/                          — [TODO] 차트 리스트 관련 뷰
│   ├── Detail/                         — [TODO] 곡 상세 뷰
│   ├── Player/                         — [TODO] 미니 플레이어, 풀 플레이어
│   └── Components/                     — [TODO] 재사용 가능한 UI 컴포넌트
├── ViewModels/
│   ├── Chart/                          — [TODO] ChartViewModel
│   └── Player/                         — [TODO] PlayerViewModel
├── Models/                             — [TODO] Song, LyricLine, LyricState 모델
├── Services/                           — [TODO] ChartService, MusicPlayerService, LyricService
├── Shared/                             — [TODO] TimeFormatUtil 등 유틸리티
├── Info.plist                          — 앱 메타데이터 (NSAppleMusicUsageDescription 필요)
└── LyricSync.entitlements              — 권한 설정
```

### docs/ 폴더

```
docs/
├── musickit_notes.md                   — MusicKit 프레임워크 사용 가이드
│   (권한, 차트, 재생, 감시, 주의사항)
│
└── lrclib_api_notes.md                 — lrclib.net API 가이드
    (엔드포인트, 응답 구조, LRC 형식, 파싱 예제, 폴백 전략)
```

---

## 현재 상태

### 구현된 파일 (2개)

1. **LyricSyncApp.swift** — 기본 @main 구조
   - WindowGroup으로 ContentView 래핑
   - MusicKit 권한 요청 로직 없음
   - ViewModel 주입 없음

2. **ContentView.swift** — 임시 placeholder
   - "LyricSync" 텍스트만 표시 (.largeTitle 폰트)
   - 실제 기능 없음
   - 상세 화면/플레이어 구조 없음

### 구현 필요 (11개 파일, 3개 폴더)

#### Views/ (5개 파일)

- **Views/Chart/ChartListView.swift** — Top 100 곡 리스트 표시
  - MusicCatalogChartsRequest로 차트 데이터 표시
  - 로딩/에러/데이터 상태 처리
  - 곡 탭 시 SongDetailView로 네비게이션
  - @State private var navigationPath
  - NavigationStack 사용

- **Views/Chart/SongRowView.swift** — 개별 곡 행 컴포넌트
  - 순위, 앨범 아트(썸네일), 곡명, 아티스트명 표시
  - HStack 레이아웃
  - 재사용 가능한 컴포넌트

- **Views/Detail/SongDetailView.swift** — 곡 상세 페이지
  - 큰 앨범 아트, 곡명, 아티스트, 앨범명
  - 재생/일시정지 버튼
  - 현재 재생 여부에 따라 버튼 상태 전환
  - PlayerViewModel 바인딩

- **Views/Player/MiniPlayerView.swift** — 글로벌 하단 미니 플레이어
  - .safeAreaInset(edge: .bottom)으로 모든 화면 하단 표시
  - 앨범 아트(작음), 곡명, 아티스트, 재생/일시정지 버튼, 프로그레스바
  - 탭 시 fullScreenCover로 FullPlayerView 표시
  - PlayerViewModel 구독

- **Views/Player/FullPlayerView.swift** — 풀 스크린 플레이어
  - 앨범 아트(큼), 곡명, 아티스트
  - **슬라이더**: 현재 시간 / 전체 시간, 드래그로 seek
    - isDragging 상태로 seek 최소화
  - **가사 표시**: ScrollView + ScrollViewReader로 자동 스크롤
    - isUserScrolling 상태로 스크롤 제어
    - 5초 타이머로 자동 스크롤 복귀
  - **가사 하이라이트**: 현재 재생 줄은 .primary (밝음), 나머지는 .secondary
  - syncedLyrics 없으면 plainLyrics 정적 표시
  - instrumental이면 "인스트루멘탈" 안내
  - 닫기 버튼

- **Views/Components/LyricLineView.swift** — 가사 한 줄 컴포넌트
  - 활성/비활성 상태에 따라 색상, 굵기 변경
  - .primary vs .secondary 적용
  - Animation(.easeInOut(duration: 0.2)) 적용

#### ViewModels/ (2개 파일)

- **ViewModels/Chart/ChartViewModel.swift** — @MainActor @Observable
  - ChartService와 통신
  - songs: [Song] — 차트 데이터
  - isLoading: Bool
  - errorMessage: String?
  - fetchCharts() async — 함수

- **ViewModels/Player/PlayerViewModel.swift** — @MainActor @Observable
  - MusicPlayerService, LyricService와 통신
  - currentSong: Song?
  - isPlaying: Bool
  - currentTime: TimeInterval
  - duration: TimeInterval
  - lyricState: LyricState (enum)
  - currentLyricIndex: Int? (계산 프로퍼티)
  - isDragging: Bool (슬라이더)
  - isUserScrolling: Bool (가사 스크롤)
  - Timer: 0.1초 주기로 playbackTime 폴링
  - 메서드: play(song:), pause(), seek(to:), fetchLyrics(song:)

#### Models/ (3개 파일)

- **Models/Song.swift** — struct Sendable
  - Wrapper for MusicKit Song
  - id: MusicItemID
  - title: String
  - artistName: String
  - albumTitle: String?
  - artwork: Artwork?
  - duration: TimeInterval?
  - rank: Int? (차트 순위)

- **Models/LyricLine.swift** — struct Sendable, Identifiable
  - id: UUID (Identifiable 준수)
  - timestamp: TimeInterval (초 단위)
  - text: String

- **Models/LyricState.swift** — enum Sendable
  - case synced([LyricLine])
  - case plain(String)
  - case instrumental
  - case notFound
  - case loading
  - case error(String)

#### Services/ (3개 파일)

- **Services/ChartService.swift** — actor
  - MusicCatalogChartsRequest 호출
  - Pop 장르 필터 (장르 ID "14")
  - kinds: [.mostPlayed]
  - limit: 50~100
  - fetchChart() async throws -> [Song]
  - 에러 처리: MusicAuthorization 미승인 시 throws

- **Services/MusicPlayerService.swift** — actor
  - ApplicationMusicPlayer.shared 래핑
  - play(song:) async throws
  - pause()
  - seek(to:) async throws
  - playbackTime: TimeInterval (getter)
  - duration: TimeInterval (getter)
  - playbackStatus (getter)
  - state (getter)

- **Services/LyricService.swift** — actor
  - lrclib.net API 호출 (URLSession)
  - GET 요청: https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}
  - LRC 파싱 (정규식: /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/)
  - 타임스탬프 변환: MM*60 + SS.ss = 초
  - fetchLyrics(artist:track:duration:) async -> LyricState
  - 폴백: syncedLyrics → plainLyrics → instrumental → error

#### Shared/ (1개 파일)

- **Shared/TimeFormatUtil.swift**
  - format(timeInterval:) -> String ("1:23" 형식)
  - 분:초 포맷팅

---

## 핵심 기술 스택

### MusicKit
- **인증**: MusicAuthorization.request() → .authorized 필수
  - Info.plist: NSAppleMusicUsageDescription
- **차트 조회**: MusicCatalogChartsRequest
  - genre: Pop (ID "14") or nil
  - kinds: [.mostPlayed]
  - types: [Song.self]
  - limit: 50~100
- **재생**: ApplicationMusicPlayer.shared
  - queue = [song]
  - play(), pause()
  - playbackTime (TimeInterval)
  - state, playbackStatus
- **현재 시간**: player.playbackTime (0.1초 Timer 폴링)
- **시크**: player.playbackTime = targetTime (드래그 완료 시에만)

### lrclib.net API
- **엔드포인트**: GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}
- **응답**:
  - syncedLyrics: "[MM:SS.ss] 가사" LRC 형식
  - plainLyrics: 타임스탬프 없는 일반 가사
  - instrumental: boolean
  - duration: 곡 길이 (초)
- **LRC 파싱**:
  - 정규식: /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/
  - MM*60 + SS.ss 변환
- **폴백 전략**:
  - syncedLyrics (있으면) → LRC 파싱
  - syncedLyrics (없으면) + plainLyrics → 정적 표시
  - instrumental == true → "인스트루멘탈" 안내
  - 404 → "가사를 찾을 수 없습니다"
- **에러**: 404, 429 Too Many Requests

### Swift 6 & SwiftUI
- **MVVM**: View → ViewModel → Service (단방향)
- **동시성**:
  - @MainActor @Observable (ViewModel)
  - actor (Service)
  - struct Sendable (Model)
- **UI**: SwiftUI 전용, semantic color
  - .primary (활성, 밝음)
  - .secondary (비활성, 어두움)
- **네비게이션**:
  - NavigationStack (메인 → 상세)
  - fullScreenCover (미니 → 풀 플레이어)
- **스크롤**:
  - ScrollViewReader (가사 자동 스크롤)
  - DragGesture (사용자 스크롤 감지)
  - Timer (5초 복귀)

---

## 관련 파일 매핑

### 기능별 파일 관계도

```
App 시작
  ↓
LyricSyncApp.swift
  ├── MusicKit 권한 요청 (MusicAuthorization.request())
  ├── PlayerViewModel 생성 (@State)
  ├── @Environment로 하위 View에 주입
  │
  └── NavigationStack
      ├── ChartListView (Top 100 리스트)
      │   ├── ChartViewModel 사용 (ChartService)
      │   ├── SongRowView × N (곡 행)
      │   │   └── 탭 → SongDetailView (NavigationStack push)
      │   │       ├── 앨범 아트, 곡명, 아티스트
      │   │       ├── 재생 버튼
      │   │       └── PlayerViewModel.play(song:) 호출
      │   │
      │   └── .safeAreaInset(edge: .bottom)
      │       └── MiniPlayerView (PlayerViewModel 구독)
      │           ├── 앨범 아트, 곡명, 아티스트
      │           ├── 재생/일시정지 버튼
      │           ├── 프로그레스바
      │           └── 탭 → fullScreenCover
      │
      └── FullPlayerView (fullScreenCover)
          ├── 큰 앨범 아트, 곡명, 아티스트
          ├── 슬라이더 (isDragging 상태 + seek 제어)
          ├── 가사 표시 (ScrollView + ScrollViewReader)
          │   └── LyricLineView × N (현재 가사 하이라이트)
          │       - 활성: .primary + .semibold
          │       - 비활성: .secondary + .regular
          ├── 재생/일시정지 버튼
          └── 닫기 버튼

PlayerViewModel (글로벌 @MainActor @Observable)
  ├── Timer: 0.1초 주기
  │   └── currentTime 업데이트 → currentLyricIndex 재계산
  ├── MusicPlayerService (actor)
  │   ├── play(song:)
  │   ├── pause()
  │   └── seek(to:)
  └── LyricService (actor)
      └── fetchLyrics(artist:track:duration:) → LyricState

ChartViewModel (@MainActor @Observable)
  └── ChartService (actor)
      └── fetchChart() → [Song]

Services
  ├── ChartService: MusicCatalogChartsRequest
  │   └── MusicKit API
  ├── MusicPlayerService: ApplicationMusicPlayer.shared
  │   └── MusicKit API
  └── LyricService: URLSession
      └── lrclib.net API
```

---

## docs/ 파일 내용 요약

### musickit_notes.md (107줄)

**핵심 내용:**
- 권한 요청: MusicAuthorization.request() → .authorized
- Info.plist: NSAppleMusicUsageDescription 필수
- Top 차트: MusicCatalogChartsRequest
  ```swift
  var request = MusicCatalogChartsRequest(genre: nil, kinds: [.mostPlayed], types: [Song.self])
  request.limit = 100
  let response = try await request.response()
  let topSongs = response.songCharts.first?.items ?? []
  ```
- Song 프로퍼티: id, title, artistName, albumTitle, artwork, duration
- 재생: player.queue = [song], play(), pause()
- 시크: player.playbackTime = 45.0
- 감시: Timer로 playbackTime 폴링 (0.1~0.5초)
- 주의: 시뮬레이터에서 재생 불가 (실기기 테스트)

### lrclib_api_notes.md (134줄)

**핵심 내용:**
- 엔드포인트: GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}
- 응답: id, trackName, artistName, albumName, duration, instrumental, plainLyrics, syncedLyrics
- LRC 형식: [MM:SS.ss] 가사 텍스트
- 파싱 예제 (정규식 + LyricLine struct)
  ```swift
  let pattern = /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/
  let minutes = Double(match.1) ?? 0
  let seconds = Double(match.2) ?? 0
  let timestamp = minutes * 60 + seconds
  ```
- 폴백: syncedLyrics → plainLyrics → instrumental → 404
- 에러: 404 Not Found, 429 Too Many Requests
- URL 인코딩 필수 (URLComponents 추천)

---

## 주요 결정 사항 (PROJECT_CONTEXT.md + ENGINEERING.md)

### 1. 차트 종류
- **.mostPlayed** 선택 (일반적인 Top 100)
- 지역은 사용자 Apple Music 계정 기준 자동 설정

### 2. 가사 소스
- **lrclib.net만 사용** (화면에 표시되는 가사는 이 API만)
- MusicKit 가사 기능은 미사용

### 3. 가사 하이라이트
- **현재 재생 시간 기준** 가장 최근 타임스탬프의 줄 활성
- currentLyricIndex: 현재 시간 ≤ 타임스탬프 중 마지막 인덱스
- `.primary` (밝음/흰색) vs `.secondary` (어두움)
- 다크모드 자동 대응 (semantic color)

### 4. 슬라이더 seek 처리
- **드래그 완료 시에만 seek 1회 호출** (Spotify/Apple Music 표준)
- 드래그 시작: isDragging = true → 가사 자동 스크롤 정지 (freeze)
- 드래그 중: sliderValue UI만 업데이트, seek 호출 없음
- 드래그 완료: MusicPlayerService.seek(to:) 1회 호출 → isDragging = false

### 5. 가사 자동 스크롤
- 사용자 터치 감지 (DragGesture): isUserScrolling = true → 자동 스크롤 정지
- 사용자 손 뗌: 5초 타이머 시작
- 5초 경과: isUserScrolling = false → 자동 스크롤 재개
- 새 곡 시작: isUserScrolling 강제 false
- 구현: ScrollViewReader + DragGesture + Timer

### 6. 권한 미승인 시
- 별도 화면 없음
- ChartListView 내부에서 "Apple Music 접근 권한이 필요합니다" 안내만 표시
- 설정 이동 버튼은 추후 필요 시 추가

### 7. 구독 미보유 시
- 30초 미리듣기(preview) 자동 제공 (MusicKit이 자동 fallback)
- 별도 처리 불필요

### 8. lrclib.net 매칭 실패 시
- 404 또는 매칭 실패 시 "가사를 찾을 수 없습니다" 안내
- 재시도 로직, 퍼지 매칭은 추후 실제 테스트 후 필요하면 추가

---

## 예상 구현 순서 (Generator 참고)

1. **Models** (LyricState, LyricLine, Song)
2. **Services** (ChartService, MusicPlayerService, LyricService)
3. **ViewModels** (ChartViewModel, PlayerViewModel)
4. **Views/Components** (LyricLineView)
5. **Views/Chart** (SongRowView, ChartListView)
6. **Views/Detail** (SongDetailView)
7. **Views/Player** (MiniPlayerView, FullPlayerView)
8. **App** (LyricSyncApp 권한 요청 + PlayerViewModel 주입)
9. **Shared** (TimeFormatUtil)

---

## 검증 체크리스트

- [ ] Info.plist에 NSAppleMusicUsageDescription 추가
- [ ] LyricSyncApp에서 MusicKit 권한 요청 구현 (MusicAuthorization.request())
- [ ] PlayerViewModel을 @State로 생성하여 @Environment로 주입 확인
- [ ] 모든 ViewModel이 @MainActor @Observable
- [ ] 모든 Service가 actor
- [ ] 모든 Model이 struct Sendable (또는 Identifiable)
- [ ] Timer 0.1초로 playbackTime 폴링
- [ ] LRC 파싱 정규식 검증 (/\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/)
- [ ] 가사 하이라이트 .primary/.secondary 적용 + Animation
- [ ] 슬라이더 드래그 완료 시에만 seek 호출 (isDragging 상태 활용)
- [ ] 가사 스크롤: DragGesture로 isUserScrolling 감지, 5초 타이머로 복귀
- [ ] MiniPlayerView가 .safeAreaInset으로 모든 화면 하단에 표시
- [ ] 실기기에서 MusicKit 권한/차트/재생 테스트

---

## 핵심 코드 위치

**현재 구현 상태:**
- LyricSyncApp.swift:3-10 — @main 진입점, MusicKit 권한 요청 필요
- ContentView.swift:3-8 — 임시 placeholder, ChartListView로 교체 필요

**docs/ 참고:**
- musickit_notes.md:36-41 — Top 차트 조회 코드 예제
- musickit_notes.md:92-96 — LRC 파싱 예제 (정규식)
- lrclib_api_notes.md:73-98 — Swift 파싱 함수 예제

---

## 빌드 에러 분석 (2026-04-09 업데이트)

### 에러 요약
PlayerViewModel.swift에서 @MainActor 격리 위반으로 인한 컴파일 에러 2개 발생

### 에러 1: Line 45
- **파일**: `/Users/haesuyoun/Desktop/NahunPersonalFolder/MusicStudy/LyricSync/Sources/ViewModels/Player/PlayerViewModel.swift`
- **라인**: 45
- **함수**: `deinit` (라인 44-47)
- **에러 메시지**: `main actor-isolated property 'timer' can not be referenced from a nonisolated context`
- **원인**: `deinit`은 MainActor로 격리되지 않은 nonisolated 메서드인데, timer 프로퍼티는 @MainActor로 격리됨
- **코드**:
  ```swift
  deinit {
      timer?.invalidate()        // ← Line 45: 에러
      userScrollTimer?.invalidate()
  }
  ```

### 에러 2: Line 46
- **파일**: `/Users/haesuyoun/Desktop/NahunPersonalFolder/MusicStudy/LyricSync/Sources/ViewModels/Player/PlayerViewModel.swift`
- **라인**: 46
- **함수**: `deinit` (라인 44-47)
- **에러 메시지**: `main actor-isolated property 'userScrollTimer' can not be referenced from a nonisolated context`
- **원인**: `deinit`은 nonisolated 메서드인데, userScrollTimer 프로퍼티는 @MainActor로 격리됨
- **코드**:
  ```swift
  deinit {
      timer?.invalidate()
      userScrollTimer?.invalidate()  // ← Line 46: 에러
  }
  ```

### 근본 원인
- **클래스 선언** (Line 6-8): `@MainActor @Observable final class PlayerViewModel`
- **프로퍼티 선언** (Line 33-34):
  ```swift
  private var timer: Timer?
  private var userScrollTimer: Timer?
  ```
- **Deinit 메서드** (Line 44-47): 명시적 격리 지정 없음 → nonisolated로 기본 처리
- **Swift 6 strict concurrency**: @MainActor 클래스의 모든 프로퍼티는 @MainActor로 격리되지만, deinit은 기본 nonisolated → 접근 불가

### 해결책 (참고용, 수정 대상 아님)
1. **Option A**: `deinit` 앞에 `nonisolated` 제거 또는 `@MainActor` 명시 추가
   ```swift
   @MainActor deinit {
       timer?.invalidate()
       userScrollTimer?.invalidate()
   }
   ```
2. **Option B**: MainActor 작업으로 분리
   ```swift
   deinit {
       Task { @MainActor in
           timer?.invalidate()
           userScrollTimer?.invalidate()
       }
   }
   ```

---

생성자: Haiku Explorer (2026-04-09)
