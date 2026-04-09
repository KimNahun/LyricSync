# 자체 점검

## SPEC 기능 체크

- [x] 기능 1 - MusicKit 권한 요청: `LyricSyncApp.swift`의 `.task`에서 `MusicAuthorization.request()` 호출. `ChartListView`에서 currentStatus 분기로 거부 시 안내 + 설정 이동 버튼 표시.
- [x] 기능 2 - Top 100 인기 팝 차트 리스트: `ChartService.fetchChart()` → `ChartViewModel.fetchCharts()` → `ChartListView`. Genre ID "14"(Pop) + `.mostPlayed` + limit 50. 로딩 ProgressView, 에러 재시도 버튼 구현.
- [x] 기능 3 - 노래 상세 페이지: `SongDetailView`. 큰 앨범 아트, 곡명/아티스트명/앨범명, 재생/일시정지 버튼 (재생 중이면 pause 아이콘으로 전환).
- [x] 기능 4 - 미니 플레이어 (글로벌 하단 고정): `MiniPlayerView`. `.safeAreaInset(edge: .bottom)`으로 NavigationStack 밖에서 주입. currentSong != nil일 때만 표시. 탭 → fullScreenCover.
- [x] 기능 5 - 풀 플레이어 (가사 싱크 + 슬라이더): `FullPlayerView`. Slider + 드래그 완료 시 seek 1회. ScrollViewReader 자동 스크롤. currentLyricIndex 기준 하이라이트. 닫기 버튼.
- [x] 기능 6 - 가사 Fetch + LRC 파싱: `LyricService.fetchLyrics()`. syncedLyrics/plainLyrics/instrumental/notFound/error 5가지 상태 처리. parseLRC() 정규식 `/\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/`.
- [x] 기능 7 - 재생 시간 폴링 + 가사 하이라이트 동기화: `PlayerViewModel` 0.1초 Timer로 playbackTime 폴링. `currentLyricIndex` computed property. `isDragging` true이면 폴링 결과 무시. 5초 후 자동 스크롤 재개.

---

## Swift 6 동시성 체크

- [x] 모든 ViewModel이 @MainActor + @Observable인가?
  - `ChartViewModel`: `@MainActor @Observable final class` ✓
  - `PlayerViewModel`: `@MainActor @Observable final class` ✓
- [x] 모든 Service가 actor인가?
  - `ChartService`: `actor ChartService` ✓
  - `MusicPlayerService`: `actor MusicPlayerService` ✓
  - `LyricService`: `actor LyricService` ✓
- [x] 모든 Model이 struct + Sendable인가?
  - `Song`: `struct Song: Identifiable, Sendable, Hashable` ✓
  - `LyricLine`: `struct LyricLine: Identifiable, Sendable, Hashable` ✓
  - `LyricState`: `enum LyricState: Sendable` ✓
- [x] DispatchQueue 사용 없음?
  - 전 파일 DispatchQueue 미사용 ✓
- [x] Sendable 경계 위반 없음?
  - actor 경계 넘어 전달되는 모든 타입(Song, LyricLine, LyricState)이 Sendable 준수 ✓

---

## MVVM 분리 체크

- [x] View에 비즈니스 로직 없음?
  - 모든 View는 ViewModel 메서드 호출 또는 상태 표시만 담당 ✓
  - URLSession, MusicKit API 직접 호출 없음 ✓
- [x] ViewModel에 SwiftUI import 없음?
  - `ChartViewModel`: `import Foundation`, `import Observation` ✓
  - `PlayerViewModel`: `import Foundation`, `import Observation` ✓
- [x] Service가 ViewModel을 참조하지 않음?
  - ChartService, MusicPlayerService, LyricService 모두 ViewModel 참조 없음 ✓
- [x] 의존성이 단방향 (View→VM→Service)인가?
  - View → ViewModel(Environment 주입) → Service(init 주입) → 외부 API ✓

---

## HIG 체크

- [x] Dynamic Type 지원?
  - 모든 폰트가 `.body`, `.headline`, `.subheadline`, `.caption`, `.title2`, `.title3` 등 semantic size 사용 ✓
- [x] Semantic color 사용?
  - `.primary`, `.secondary`, `.accentColor`, `Color(.systemFill)`, `.regularMaterial` 사용 ✓
  - 하드코딩 색상 없음 ✓
- [x] 터치 영역 44pt 이상?
  - `LyricLineView`: `frame(minHeight: 44)` ✓
  - 재생 버튼들: `frame(minWidth: 44, minHeight: 44)` ✓
  - 미니 플레이어 버튼: `frame(width: 44, height: 44)` ✓
- [x] 접근성 레이블 추가?
  - 주요 인터랙션 요소 모두 `.accessibilityLabel` + `.accessibilityHint` 추가 ✓
  - `LyricLineView`: isActive 상태를 hint로 제공 ✓
  - 미니 플레이어 전체에 `.accessibilityElement(children: .contain)` ✓

---

## API 활용 체크

- [x] MusicKit: 권한 요청 (`MusicAuthorization.request()`), 차트 조회 (`MusicCatalogChartsRequest`), 재생 (`ApplicationMusicPlayer.shared`), seek (`player.playbackTime = time`) 모두 구현
- [x] lrclib.net: `GET /api/get` 호출, LRC 파싱 정확 (정규식 `/\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/`), syncedLyrics/plainLyrics 폴백, instrumental 처리, 404/429 에러 처리
- [x] AuthenticationServices: 1차 목표 제외 (SPEC 명시) — MusicKit 권한 요청으로 대체

---

## 파일 구조

```
LyricSync/Sources/
├── App/
│   └── LyricSyncApp.swift          ✓
├── Models/
│   ├── Song.swift                   ✓
│   ├── LyricLine.swift              ✓
│   └── LyricState.swift             ✓
├── Shared/
│   └── TimeFormatUtil.swift         ✓
├── Services/
│   ├── ChartService.swift           ✓
│   ├── MusicPlayerService.swift     ✓
│   └── LyricService.swift           ✓
├── ViewModels/
│   ├── Chart/
│   │   └── ChartViewModel.swift     ✓
│   └── Player/
│       └── PlayerViewModel.swift    ✓
└── Views/
    ├── Components/
    │   └── LyricLineView.swift      ✓
    ├── Chart/
    │   ├── SongRowView.swift        ✓
    │   └── ChartListView.swift      ✓
    ├── Detail/
    │   └── SongDetailView.swift     ✓
    └── Player/
        ├── MiniPlayerView.swift     ✓
        └── FullPlayerView.swift     ✓
```

총 15개 파일 생성 완료 (ContentView.swift 삭제).
