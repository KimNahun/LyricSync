# LyricSync — 1차 목표 엔지니어링 설계서

> **이 문서의 위치**: 하네스 엔지니어링 설계 참고 문서. Planner/Generator/Evaluator가 SPEC.md 생성 전에 참고하는 상위 설계 의도.
> 구체적 구현 요구사항은 `PROJECT_CONTEXT.md`에 있다.

---

## 1차 목표 요약

| 화면 | 진입 방법 | 핵심 기능 |
|------|-----------|-----------|
| 메인 (Top 100 리스트) | 앱 시작 | MusicKit 차트 조회 |
| 노래 상세 | 리스트 탭 | 앨범 아트 + 재생 버튼 |
| 미니 플레이어 (글로벌) | 재생 시작 시 자동 | 모든 화면 하단 고정 |
| 풀 플레이어 | 미니 플레이어 탭 | 슬라이더 + 가사 + 하이라이트 |

---

## 화면 네비게이션 구조

```
App (ZStack or .safeAreaInset 래퍼)
│
├── NavigationStack
│   ├── ChartListView (메인 — Top 100)
│   │   └── [탭] → SongDetailView
│   │               └── [재생 버튼 탭] → 재생 시작
│   │
│   └── (모든 화면 하단) MiniPlayerView  ← .safeAreaInset(edge: .bottom)
│
└── FullPlayerView  ← .fullScreenCover (MiniPlayerView 탭 시 표시)
```

**핵심 결정**: 미니 플레이어는 `NavigationStack` 밖에서 `.safeAreaInset(edge: .bottom)`으로 주입. 이렇게 하면 NavigationStack 내 어떤 화면에서도 하단에 항상 표시됨.

---

## API 사용 전략

### MusicKit — 재생의 실체

- **목적**: 인기 팝 곡 차트 조회 + 실제 음악 재생 + 시간 이동(seek)
- **핵심 타입**: `MusicCatalogChartsRequest`, `ApplicationMusicPlayer`
- **재생 제어**: `ApplicationMusicPlayer.shared`가 실제 재생을 담당
- **구독 미보유 시**: 30초 미리듣기(preview) 자동 제공 — 별도 처리 불필요 (MusicKit이 자동 fallback)
- **시간 이동**: `player.playbackTime = targetTime` (슬라이더 드래그 완료 시에만 호출)
- **현재 시간 폴링**: 0.1초 Timer로 `player.playbackTime` 감시 → 가사 하이라이트 동기화

#### 인기 팝 곡 조회 방법 (결정 완료)

```swift
// 1단계: Pop 장르 객체 fetch (장르 ID "14" = Pop)
let genreRequest = MusicCatalogResourceRequest<Genre>(matching: \.id, equalTo: MusicItemID("14"))
let genreResponse = try await genreRequest.response()
let popGenre = genreResponse.items.first

// 2단계: Pop 필터 + 인기곡 차트 요청
var chartRequest = MusicCatalogChartsRequest(genre: popGenre, kinds: [.mostPlayed], types: [Song.self])
chartRequest.limit = 50
let chartResponse = try await chartRequest.response()
let popularSongs = chartResponse.songCharts.first?.items ?? []
```

- `.mostPlayed`: "가장 많이 재생된" 기준 → 자연스러운 인기곡 리스트
- `.dailyGlobalTop` 대안도 있으나 매일 갱신 특성이 강함 → `.mostPlayed` 선택
- Pop 장르 필터로 K-Pop 등 자동 제외됨 (K-Pop은 별도 장르로 분류)
- 장르 ID "14"는 사용자 지역에 따라 다를 수 있음 → 실기기 테스트 필수

### lrclib.net — 화면에 보이는 가사의 유일한 소스

- **목적**: 가사 텍스트 + 타임스탬프 데이터 제공
- **호출 시점**: 재생 시작 직후 (비동기, 재생을 블록하지 않음)
- **파라미터**: `artist_name`, `track_name`, `duration` (MusicKit Song에서 추출)
- **우선순위**:
  1. `syncedLyrics` 있음 → LRC 파싱 → 타임스탬프 기반 하이라이트
  2. `syncedLyrics` null + `plainLyrics` 있음 → 정적 표시 (하이라이트 없음)
  3. `instrumental == true` → "이 곡은 인스트루멘탈입니다" 표시
  4. 404 or 에러 → "가사를 찾을 수 없습니다" 표시

**MusicKit 가사 기능은 사용하지 않는다.** 화면에 보이는 가사는 lrclib.net 데이터만 사용.

---

## 아키텍처 레이어

```
Views/
├── Chart/
│   ├── ChartListView.swift          — Top 100 리스트
│   └── SongRowView.swift            — 개별 곡 행 컴포넌트
├── Detail/
│   └── SongDetailView.swift         — 노래 상세 + 재생 버튼
├── Player/
│   ├── MiniPlayerView.swift         — 하단 고정 미니 플레이어
│   └── FullPlayerView.swift         — 풀 플레이어 (슬라이더 + 가사)
└── Components/
    └── LyricLineView.swift          — 가사 한 줄 컴포넌트 (하이라이트 처리)

ViewModels/
├── Chart/
│   └── ChartViewModel.swift         — @MainActor @Observable, 차트 데이터
├── Player/
│   └── PlayerViewModel.swift        — @MainActor @Observable, 재생 상태 + 가사 상태
└── (SongDetailView는 PlayerViewModel을 공유 — 별도 VM 불필요)

Models/
├── Song.swift                        — struct Sendable (MusicKit Song 래핑)
├── LyricLine.swift                   — struct Sendable (timestamp + text)
└── LyricState.swift                  — enum (synced / plain / instrumental / notFound)

Services/
├── ChartService.swift                — actor, MusicCatalogChartsRequest
├── MusicPlayerService.swift          — actor, ApplicationMusicPlayer 래핑
└── LyricService.swift                — actor, lrclib.net API + LRC 파싱

Shared/
└── TimeFormatUtil.swift              — "1:23" 포맷 유틸
```

---

## 동시성 경계

```
ChartListView (View, @MainActor)
    ↓ await
ChartViewModel (@MainActor @Observable)
    ↓ await actor hop
ChartService (actor)
    ↓ async
MusicCatalogChartsRequest (MusicKit, network)

MiniPlayerView / FullPlayerView (View, @MainActor)
    ↓ 바인딩
PlayerViewModel (@MainActor @Observable)
    ├── Timer (0.1s) → playbackTime 폴링 → currentLyricIndex 계산
    ↓ await actor hop
MusicPlayerService (actor) → ApplicationMusicPlayer.shared
LyricService (actor) → URLSession → lrclib.net
```

**PlayerViewModel은 앱 전체에서 단일 인스턴스** — `@State`로 App 루트에서 생성 후 `@Environment`로 주입. 미니 플레이어와 풀 플레이어가 같은 상태를 공유.

---

## 가사 자동 스크롤 로직 (결정 완료)

Apple Music 방식 채택. Spotify 방식(수동 스크롤 강제 override)은 유저 불만이 크므로 배제.

```
사용자 터치/드래그 감지 → isUserScrolling = true → 자동 스크롤 정지
사용자 손 뗌 → 5초 타이머 시작
5초 경과 → isUserScrolling = false → 현재 재생 가사로 자동 스크롤 재개
새 곡 시작 → isUserScrolling 강제 false → 처음부터 자동 스크롤
```

SwiftUI 구현: `ScrollViewReader` + `DragGesture` + `Timer` 조합.

---

## 슬라이더 seek 처리 (결정 완료)

Spotify / Apple Music 공통 표준 동작 채택: **드래그 완료 시에만 seek 1회 호출.**

```
드래그 시작 → isDragging = true, 가사 자동 스크롤 정지 (freeze)
드래그 중   → sliderValue UI만 업데이트 (seek 호출 없음, 가사 현재 위치 freeze)
드래그 완료 → MusicPlayerService.seek(to: sliderValue) 1회 호출
              → isDragging = false → 가사 재동기화
```

드래그 중 가사 미리보기는 주요 음악 앱 어느 것도 구현하지 않음. 빠른 드래그 시 가사가 너무 빠르게 튀어서 오히려 혼란스럽기 때문.

---

## 가사 하이라이트 로직

```swift
// PlayerViewModel 내부 (0.1초 Timer 콜백)
var currentLyricIndex: Int? {
    guard case .synced(let lines) = lyricState else { return nil }
    // 현재 시간보다 작거나 같은 타임스탬프 중 가장 마지막 인덱스
    return lines.indices.last(where: { lines[$0].timestamp <= currentTime })
}

// LyricLineView
Text(line.text)
    .foregroundStyle(isActive ? .primary : .secondary)
    .font(isActive ? .body.weight(.semibold) : .body)
    .animation(.easeInOut(duration: 0.2), value: isActive)
```

- `.primary` = 다크모드에서 거의 흰색, 라이트모드에서 거의 검정색 → HIG semantic color로 자동 대응
- `.secondary` = 흐린 버전 → 비활성 가사가 자연스럽게 배경에 묻힘

---

## 슬라이더 seek 처리

```
사용자 드래그 시작 → isDragging = true (Timer 폴링 일시 중단 or 무시)
사용자 드래그 중   → sliderValue 업데이트 (UI만 반영, seek 호출 안 함)
사용자 드래그 완료 → MusicPlayerService.seek(to: sliderValue) 호출
                    → isDragging = false → Timer 폴링 재개
```

드래그 중 seek을 매 프레임 호출하면 MusicKit 내부 상태가 불안정해질 수 있으므로, 드래그 완료 시점에만 한 번 호출.

---

## 파일 생성 위치 (Generator 참고)

```
(프로젝트 루트)/
├── App/
│   └── LyricSyncApp.swift
├── Views/
│   ├── Chart/
│   │   ├── ChartListView.swift
│   │   └── SongRowView.swift
│   ├── Detail/
│   │   └── SongDetailView.swift
│   ├── Player/
│   │   ├── MiniPlayerView.swift
│   │   └── FullPlayerView.swift
│   └── Components/
│       └── LyricLineView.swift
├── ViewModels/
│   ├── Chart/
│   │   └── ChartViewModel.swift
│   └── Player/
│       └── PlayerViewModel.swift
├── Models/
│   ├── Song.swift
│   ├── LyricLine.swift
│   └── LyricState.swift
├── Services/
│   ├── ChartService.swift
│   ├── MusicPlayerService.swift
│   └── LyricService.swift
└── Shared/
    └── TimeFormatUtil.swift
```

---

## 기술적 결정 사항 (모두 완료)

### [결정 1] Pop 장르 ID
- 타겟이 한국이므로 storefront 지역 문제 없음
- 단, 한국 전용 제약은 두지 않음 — 장르 ID "14" 그대로 사용
- 실기기 테스트 시 실제 결과 확인 후 필요하면 수정

### [결정 2] MusicKit 권한 거부 시 처리
- 별도 화면 없음 — ChartListView 내부에서 안내 문구만 표시
- 예: "Apple Music 접근 권한이 필요합니다. 설정에서 허용해 주세요."
- 추가 액션(설정 이동 버튼 등)은 추후 필요 시 추가

### [결정 3] lrclib.net 매칭 실패 처리
- 404 또는 매칭 실패 시 모달로 안내 문구만 표시
- 예: "가사를 찾을 수 없습니다"
- 재시도 로직, 퍼지 매칭 등은 추후 실제 테스트 후 필요하면 추가
