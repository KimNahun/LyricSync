# QA Report — LyricSync

**평가 일시**: 2026-04-09
**평가 대상**: `LyricSync/Sources/` 전체 Swift 파일 (16개)

---

## 1단계: 파일 구조 분석

### 파일 목록 및 레이어 분류

| 파일 경로 | 레이어 | SPEC 일치 |
|-----------|--------|-----------|
| `App/LyricSyncApp.swift` | App | O |
| `Views/Chart/ChartListView.swift` | View | O |
| `Views/Chart/SongRowView.swift` | View | O |
| `Views/Detail/SongDetailView.swift` | View | O |
| `Views/Player/MiniPlayerView.swift` | View | O |
| `Views/Player/FullPlayerView.swift` | View | O |
| `Views/Components/LyricLineView.swift` | View | O |
| `ViewModels/Chart/ChartViewModel.swift` | ViewModel | O |
| `ViewModels/Player/PlayerViewModel.swift` | ViewModel | O |
| `Models/Song.swift` | Model | O |
| `Models/LyricLine.swift` | Model | O |
| `Models/LyricState.swift` | Model | O |
| `Services/ChartService.swift` | Service | O |
| `Services/MusicPlayerService.swift` | Service | O |
| `Services/LyricService.swift` | Service | O |
| `Shared/TimeFormatUtil.swift` | Shared | O |

**파일 구조 판정**: SPEC.md에 명시된 모든 파일이 존재하며, `output/` 폴더 없이 `LyricSync/Sources/` 하위에 직접 배치되어 있다. 구조 일치.

---

## 2단계: SPEC 기능 검증

### 기능 1: MusicKit 권한 요청
- **[PASS]** `LyricSyncApp.swift` 라인 23~25: `.task { _ = await MusicAuthorization.request() }`로 앱 시작 시 권한 요청 구현.
- **[PASS]** `ChartListView.swift` 라인 91~112: 권한 거부 시 "Apple Music 접근 권한이 필요합니다" 안내 + "설정 열기" 버튼 구현.
- **[PASS]** `ChartListView.swift` 라인 28~32: 권한 승인 후 자동으로 차트 데이터 fetch.

### 기능 2: Top 100 인기 팝 차트 리스트
- **[PASS]** `ChartService.swift` 라인 28~68: `MusicCatalogResourceRequest<Genre>` + `MusicCatalogChartsRequest` 구현. Pop 장르 ID "14", kinds: `.mostPlayed`, limit: 50.
- **[PASS]** `ChartListView.swift` 라인 39~41: 로딩 중 `ProgressView` 표시.
- **[PASS]** `ChartListView.swift` 라인 66~87: 에러 시 재시도 버튼 표시.
- **[PASS]** `SongRowView.swift`: 순위, 앨범 아트, 곡명, 아티스트명 표시.
- **[PASS]** `ChartListView.swift` 라인 50~62: `NavigationLink(value:)` + `.navigationDestination(for:)` 패턴으로 상세 페이지 이동.
- **[MINOR]** SPEC에 "Top 100"이라 했으나 limit=50으로 설정. PROJECT_CONTEXT.md에도 "Top Songs 100개"라 했으나 ENGINEERING.md에서 limit=50으로 결정됨. SPEC.md에서도 limit=50으로 명시되어 있으므로 SPEC 기준으로는 적합.

### 기능 3: 노래 상세 페이지
- **[PASS]** `SongDetailView.swift`: 큰 앨범 아트(280x280), 곡명, 아티스트명, 앨범명 표시.
- **[PASS]** `SongDetailView.swift` 라인 61~78: 재생/일시정지 버튼. isPlaying 상태에 따라 아이콘 전환.
- **[PASS]** 이미 재생 중인 곡이면 resume, 다른 곡이면 play, 재생 중이면 pause 분기 처리.

### 기능 4: 미니 플레이어
- **[PASS]** `LyricSyncApp.swift` 라인 16~21: `.safeAreaInset(edge: .bottom)` + `currentSong != nil` 조건 표시.
- **[PASS]** `MiniPlayerView.swift`: 앨범 아트(소), 곡명, 아티스트명, 재생/일시정지 버튼, 프로그레스바 표시.
- **[PASS]** `MiniPlayerView.swift` 라인 78~79: 탭 시 `showFullPlayer = true`.
- **[PASS]** `MiniPlayerView.swift` 라인 84~86: `.fullScreenCover(isPresented:)` 바인딩.

### 기능 5: 풀 플레이어
- **[PASS]** `FullPlayerView.swift`: 앨범 아트, 곡명, 아티스트명, 슬라이더, 재생/일시정지 버튼, 가사 영역 구현.
- **[PASS]** 슬라이더 `onEditingChanged`로 드래그 시작/완료 처리. 드래그 완료 시에만 seek 호출.
- **[PASS]** 시간 표시: `TimeFormatUtil.format()` 사용.
- **[PASS]** 닫기 버튼(chevron.down) toolbar에 배치.
- **[PASS]** 가사 상태별 분기: synced, plain, instrumental, notFound, error, loading.

### 기능 6: 가사 Fetch 및 LRC 파싱
- **[PASS]** `LyricService.swift` 라인 31~89: lrclib.net API 호출. artist_name, track_name, duration 파라미터.
- **[PASS]** `LyricService.swift` 라인 93~103: LRC 파싱. 정규식 `/\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/`.
- **[PASS]** syncedLyrics → synced, plainLyrics → plain, instrumental → instrumental, 404 → notFound, 429 → error 폴백 구현.
- **[PASS]** User-Agent 헤더 설정 ("LyricSync v1.0").
- **[PASS]** URLComponents로 URL 인코딩 자동 처리.

### 기능 7: 재생 시간 폴링 및 가사 하이라이트
- **[PASS]** `PlayerViewModel.swift` 라인 127~134: 0.1초 Timer 폴링 구현.
- **[PASS]** `PlayerViewModel.swift` 라인 26~29: `currentLyricIndex` computed property. `lines.indices.last(where:)` 방식.
- **[PASS]** `FullPlayerView.swift` 라인 28~35: `.onChange(of: currentLyricIndex)`로 자동 스크롤.
- **[PASS]** `FullPlayerView.swift` 라인 210~218: `DragGesture`로 사용자 수동 스크롤 감지.
- **[PASS]** `PlayerViewModel.swift` 라인 115~123: 5초 후 자동 스크롤 재개.

---

## 3단계: evaluation_criteria 채점

### 1. Swift 6 동시성: 8 / 10

**합격 사항:**
- 모든 ViewModel: `@MainActor` + `@Observable` 선언 확인.
  - `ChartViewModel.swift` 라인 6~8: `@MainActor @Observable final class ChartViewModel`
  - `PlayerViewModel.swift` 라인 6~8: `@MainActor @Observable final class PlayerViewModel`
- 모든 Service: `actor` 선언 확인.
  - `ChartService.swift` 라인 23: `actor ChartService`
  - `MusicPlayerService.swift` 라인 21: `actor MusicPlayerService`
  - `LyricService.swift` 라인 22: `actor LyricService`
- 모든 Model: `struct` + `Sendable` 준수 확인.
  - `Song.swift` 라인 6: `struct Song: Identifiable, Sendable, Hashable`
  - `LyricLine.swift` 라인 5: `struct LyricLine: Identifiable, Sendable, Hashable`
  - `LyricState.swift` 라인 5: `enum LyricState: Sendable`
- `DispatchQueue`, `@Published`, `ObservableObject` 미사용 확인.
- ViewModel에서 `import SwiftUI` 미사용. `import Observation` 사용.

**감점 사항:**

1. **`MusicPlayerService.swift` 라인 22: `nonisolated(unsafe) private let player = ApplicationMusicPlayer.shared`**
   - `nonisolated(unsafe)`는 Swift 6 동시성 검사를 명시적으로 우회하는 어노테이션이다. `ApplicationMusicPlayer.shared`는 `@MainActor`로 격리되어 있을 수 있으며, 이를 actor 내부에서 `nonisolated(unsafe)`로 접근하는 것은 잠재적 데이터 레이스 위험이 있다. 정당한 이유(MusicKit API 한계)가 있을 수 있으나, 안전성 측면에서 감점 대상이다. **(-1점)**
   - 수정 방안: `ApplicationMusicPlayer.shared` 접근을 각 메서드 내부에서 `@MainActor` 컨텍스트로 호핑하거나, `MusicPlayerService` 자체를 `@MainActor` 클래스로 변경하는 것을 검토할 수 있다. 다만 MusicKit의 `ApplicationMusicPlayer`가 `Sendable`을 준수하지 않는 문제가 근본 원인이므로, 현 시점에서 `nonisolated(unsafe)`가 현실적 타협일 수 있다. 그러나 이 결정에 대한 코드 주석이 없다.

2. **`PlayerViewModel.swift` 라인 129~133: Timer 콜백 내 `Task { @MainActor ... }`**
   - `Timer.scheduledTimer` 콜백은 RunLoop 기반이며, 콜백 내부에서 `Task { @MainActor }` 생성 패턴을 사용하고 있다. 이는 동작하지만, `Timer.publish` + Combine이 아닌 이상 콜백이 MainActor 컨텍스트 밖에서 실행될 수 있다. 실제로는 MainRunLoop에서 실행되므로 문제가 발생하지 않을 가능성이 높으나, Swift 6 strict concurrency에서 `Timer` 콜백의 Sendable 준수 여부에 따라 경고가 발생할 수 있다. **(-0.5점)**

3. **`PlayerViewModel.swift` 라인 117~123: `onUserScrollEnded()` 동일 이슈** — Timer 콜백 내 `Task { @MainActor }` 패턴. 위와 동일 문제. **(-0.5점, 위와 중복이므로 추가 감점 없음)**

### 2. MVVM 아키텍처 분리: 9 / 10

**합격 사항:**
- View 파일에 URLSession / Service 직접 호출 없음. 모든 비즈니스 로직은 ViewModel 경유.
- ViewModel 파일에 `import SwiftUI` 없음. `import Foundation` + `import Observation`만 사용.
- ViewModel에 UI 타입(Color, Font, Image 등) 없음.
- Service가 ViewModel이나 View를 참조하지 않음.
- 의존성 방향: View -> ViewModel -> Service 단방향 흐름 확인.
- LRC 파싱 로직이 `LyricService` (Service 레이어)에 위치.

**감점 사항:**

1. **Protocol 기반 Service 주입 미구현 (-1점)**
   - `ChartViewModel.swift` 라인 15: `init(chartService: ChartService = ChartService())` — 구체 타입 직접 주입.
   - `PlayerViewModel.swift` 라인 36~41: `init(musicPlayerService: MusicPlayerService = MusicPlayerService(), lyricService: LyricService = LyricService())` — 구체 타입 직접 주입.
   - evaluation_criteria.md에 "Protocol 기반 Service 주입 (테스트 가능성)"이 합격 기준으로 명시되어 있다. 프로토콜 없이 구체 actor 타입을 직접 주입하고 있어 테스트 시 Mock 교체가 불가능하다.
   - 수정 방안: `ChartServiceProtocol`, `MusicPlayerServiceProtocol`, `LyricServiceProtocol` 프로토콜을 정의하고 ViewModel이 프로토콜에 의존하도록 변경.

### 3. HIG 준수 + UX 품질: 8.5 / 10

**합격 사항:**
- Dynamic Type: 모든 뷰에서 `.font(.body)`, `.font(.headline)`, `.font(.subheadline)`, `.font(.caption)` 등 semantic font size 사용. 하드코딩 폰트 크기 없음.
- Semantic color: `.primary`, `.secondary`, `.tertiary`, `Color(.systemFill)`, `Color(.systemBackground)` 등 사용. 하드코딩 색상 없음 (단, `.red` 사용 1건 — 아래 감점).
- 터치 영역: `LyricLineView.swift` 라인 24: `.frame(minHeight: 44)` + `.contentShape(Rectangle())` — 44pt 보장. 버튼들도 44pt 이상 프레임 확인.
- 로딩/에러 상태: `ChartListView`에서 `ProgressView`, 에러 뷰, 재시도 버튼 구현. `FullPlayerView`에서 가사 로딩 중 `ProgressView`.
- 접근성: `SongRowView`에 `.accessibilityElement(children: .combine)` + `.accessibilityLabel`. `LyricLineView`에 `.accessibilityLabel` + `.accessibilityHint`. 버튼들에 `.accessibilityLabel`. `SongDetailView`에 `.accessibilityAddTraits(.isHeader)`.
- 내비게이션: `NavigationStack` + `NavigationLink(value:)` + `.navigationDestination(for:)` 패턴. `.fullScreenCover` 사용.
- 가사 자동 스크롤: `ScrollViewReader` + `.onChange(of: currentLyricIndex)` + `withAnimation(.easeInOut)` 구현.
- 미니 플레이어: `.safeAreaInset(edge: .bottom)` 적절히 사용.
- pull-to-refresh: `ChartListView.swift` 라인 59~61: `.refreshable` 구현.

**감점 사항:**

1. **`SongDetailView.swift` 라인 83: `.foregroundStyle(.red)` — 하드코딩 색상 (-0.5점)**
   - 에러 메시지에 `.red`를 직접 사용. semantic color가 아니다.
   - 수정 방안: `Color(.systemRed)` 또는 `.foregroundStyle(.secondary)` 사용. 또는 에러 전용 semantic 스타일 정의.

2. **`SongDetailView.swift` 라인 29: `.font(.system(size: 60))` — 하드코딩 폰트 크기 (-0.5점)**
   - 플레이스홀더 music.note 아이콘에 `.system(size: 60)` 하드코딩.
   - `FullPlayerView.swift` 라인 65에도 `.font(.system(size: 40))` 동일 패턴.
   - `FullPlayerView.swift` 라인 142에 `.font(.system(size: 60))` — 재생 버튼 아이콘.
   - `SongDetailView.swift` 라인 72에 `.font(.system(size: 72))` — 재생 버튼 아이콘.
   - 이들은 아이콘 크기 지정이므로 semantic font로 대체하기 어려운 면이 있으나, HIG 엄격 해석 시 감점 대상.
   - 수정 방안: 가능하면 `.font(.largeTitle)` 등 semantic size 활용 또는 심볼 크기를 `.imageScale`로 조절.

3. **가사 줄 탭 시 해당 위치로 seek하는 기능 미활용 (-0.5점)**
   - `LyricLineView`에 `onTap` 클로저가 있으나, `FullPlayerView.swift`의 `syncedLyricView`에서 `onTap`을 전달하지 않고 있다. `LyricLineView(line:isActive:)`만 호출하고 `onTap`은 nil.
   - 이는 HIG "직접 조작" 원칙상 사용자가 가사 줄을 탭하여 해당 시점으로 이동하는 것이 자연스러운 인터랙션이나 구현되지 않았다.
   - 수정 방안: `FullPlayerView`의 `syncedLyricView`에서 `onTap: { Task { await playerViewModel.seek(to: line.timestamp) } }` 전달.

### 4. API 활용: 9 / 10

**합격 사항:**

**MusicKit:**
- `MusicAuthorization.request()` 호출: `LyricSyncApp.swift` 라인 24.
- `MusicCatalogResourceRequest<Genre>`: `ChartService.swift` 라인 37~42.
- `MusicCatalogChartsRequest`: `ChartService.swift` 라인 45~53.
- `ApplicationMusicPlayer` play/pause/seek: `MusicPlayerService.swift`.
- 재생 상태 감시: `PlayerViewModel.swift` Timer 0.1초 폴링.
- 권한 거부 시 안내 UI: `ChartListView.swift` `deniedView`.
- Service 레이어에서만 MusicKit 호출 (단, `ChartListView.swift`에서 `MusicAuthorization.currentStatus` 직접 접근 — 아래 감점).

**lrclib.net:**
- URL 구성: `LyricService.swift` 라인 32~43 — `URLComponents` + `artist_name`, `track_name`, `duration` 쿼리 파라미터.
- syncedLyrics LRC 파싱: `LyricService.swift` 라인 93~103 — 정규식 `/\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/` + 타임스탬프 변환.
- plainLyrics 폴백: `LyricService.swift` 라인 81~83.
- instrumental 처리: `LyricService.swift` 라인 72~74.
- 404/429 처리: `LyricService.swift` 라인 62~67.
- 가사 fetch가 재생을 블록하지 않음: `PlayerViewModel.swift` 라인 74~76 — `Task { await fetchLyrics(song:) }` 별도 Task.

**가사 하이라이트:**
- 현재 재생 시간 기준 올바른 가사 줄 계산: `PlayerViewModel.swift` 라인 26~29.
- `.primary` / `.secondary` semantic color: `LyricLineView.swift` 라인 19.
- `ScrollViewReader` 자동 스크롤: `FullPlayerView.swift` 라인 28~35.

**감점 사항:**

1. **`ChartListView.swift` 라인 9, 29: `MusicAuthorization.currentStatus` View에서 직접 접근 (-1점)**
   - `import MusicKit`가 View 파일에 있고, `MusicAuthorization.currentStatus`를 View에서 직접 호출한다. MVVM 원칙상 이런 API 호출은 ViewModel 또는 Service를 거쳐야 한다.
   - 단, 이것은 순수 상태 조회이므로 심각한 위반은 아니며, `LyricSyncApp.swift`에서도 `MusicAuthorization.request()`를 직접 호출하는 것은 App 진입점이라 허용 가능.
   - 수정 방안: `ChartViewModel`에 `authorizationStatus` 프로퍼티를 추가하고 ViewModel을 통해 접근.

### 5. 기능성 및 코드 가독성: 8.5 / 10

**합격 사항:**
- SPEC의 모든 7개 기능이 구현됨.
- 접근 제어자 명시: `private(set)`, `private` 적절히 사용.
- 에러 타입: `ChartServiceError`, `MusicPlayerError`, `LyricServiceError` — 모두 `enum: Error, LocalizedError`로 정의 + `errorDescription` 구현.
- 파일명이 SPEC 컨벤션 일치.
- 코드 중복 최소화: `LyricLineView` 재사용 컴포넌트 분리, `lyricMessageView` 함수로 반복 UI 추출.
- 불필요한 주석 없음. 필요한 곳에 doc comment 적절히 작성.

**감점 사항:**

1. **`LyricLineView`의 `onTap` 미활용 (-0.5점)**
   - init에 `onTap` 파라미터가 있으나 실제 사용처에서 nil로 전달. 사용되지 않는 코드는 dead code이다.
   - 가사 탭-to-seek 기능을 구현하거나, 사용하지 않을 것이면 제거해야 한다.

2. **`MusicPlayerService.swift`의 `nonisolated(unsafe)` 주석 부재 (-0.5점)**
   - 왜 `nonisolated(unsafe)`를 사용했는지 코드 주석이 없다. 향후 유지보수 시 의도를 파악하기 어렵다.

3. **`PlayerViewModel`의 `isDragging`, `sliderValue`, `isUserScrolling`, `showFullPlayer`에 접근 제어자 미명시 (-0.5점)**
   - 라인 17~23: `var isDragging`, `var sliderValue`, `var isUserScrolling`, `var showFullPlayer`가 `private(set)` 없이 internal 기본값. View에서 양방향 바인딩이 필요하므로 의도적일 수 있으나, `isDragging`과 `isUserScrolling`은 ViewModel 내부에서만 변경되어야 하는 상태다. `isDragging`은 `sliderSection`의 `onEditingChanged`에서 직접 설정(`playerViewModel.isDragging = true`)하고 있어 View에서 직접 변이하고 있다.
   - 수정 방안: `isDragging`은 `onSliderEditingChanged(editing:)` 같은 ViewModel 메서드를 통해 변경하도록 리팩토링.

---

## Swift 6 동시성 검증 체크리스트

| 항목 | 결과 | 비고 |
|------|------|------|
| ViewModel: @MainActor + @Observable | **PASS** | ChartViewModel, PlayerViewModel 모두 적용 |
| Service: actor 선언 | **PASS** | ChartService, MusicPlayerService, LyricService 모두 actor |
| Model: struct + Sendable | **PASS** | Song, LyricLine, LyricState 모두 준수 |
| DispatchQueue.main 사용 없음 | **PASS** | 미사용 확인 |
| @Published + ObservableObject 사용 없음 | **PASS** | 미사용 확인 |
| Task {} 내부 불필요한 MainActor 호핑 없음 | **WARN** | Timer 콜백 → Task { @MainActor } 패턴. 필요한 호핑이긴 하나 Timer 자체의 Sendable 경계 문제 잠재 |
| Sendable 경계 위반 없음 | **WARN** | `nonisolated(unsafe)` 사용으로 명시적 우회 |
| nonisolated 남용 없음 | **WARN** | `nonisolated(unsafe)` 1건 — `MusicPlayerService.swift` 라인 22 |

## MVVM 분리 검증 체크리스트

| 항목 | 결과 | 비고 |
|------|------|------|
| View에 URLSession / Service 직접 호출 없음 | **PASS** | |
| View에 비즈니스 로직 없음 | **PASS** | |
| ViewModel에 SwiftUI import 없음 | **PASS** | `import Observation` + `import Foundation`만 사용 |
| ViewModel에 UI 타입 없음 | **PASS** | |
| Service가 ViewModel/View 참조 없음 | **PASS** | |
| 의존성 단방향 흐름 | **WARN** | ChartListView에서 MusicKit API 직접 접근 (MusicAuthorization.currentStatus) |

## HIG 검증 체크리스트

| 항목 | 결과 | 비고 |
|------|------|------|
| Dynamic Type | **WARN** | 대부분 semantic font 사용. `.system(size:)` 아이콘 4건 |
| Semantic color | **WARN** | `.red` 하드코딩 1건 (SongDetailView 에러 표시) |
| 터치 영역 44pt | **PASS** | LyricLineView `minHeight: 44`, 버튼 44pt+ |
| Safe Area | **PASS** | 불필요한 `.ignoresSafeArea` 없음 |
| 접근성 | **PASS** | 주요 인터랙션에 `.accessibilityLabel` 추가 |
| 내비게이션 패턴 | **PASS** | NavigationStack, fullScreenCover |
| 오류 처리 UI | **PASS** | 차트/가사/재생 모두 에러 UI 제공 |
| 로딩 상태 | **PASS** | 차트/가사 로딩 ProgressView |

## API 활용 검증

### MusicKit

| 항목 | 결과 | 비고 |
|------|------|------|
| MusicAuthorization.request() | **PASS** | LyricSyncApp.swift |
| MusicCatalogChartsRequest | **PASS** | ChartService.swift |
| ApplicationMusicPlayer 재생/일시정지/시크 | **PASS** | MusicPlayerService.swift |
| 재생 상태 감시 | **PASS** | Timer 0.1초 폴링 |
| Service에서만 MusicKit 호출 | **WARN** | ChartListView에서 MusicAuthorization.currentStatus 직접 접근 |
| 권한 거부 시 안내 UI | **PASS** | ChartListView deniedView |

### lrclib.net

| 항목 | 결과 | 비고 |
|------|------|------|
| URL 구성 | **PASS** | URLComponents + 올바른 쿼리 파라미터 |
| syncedLyrics LRC 파싱 | **PASS** | 정규식 정확, 타임스탬프 변환 올바름 |
| plainLyrics 폴백 | **PASS** | |
| instrumental 처리 | **PASS** | |
| 네트워크 에러 처리 (404, 429) | **PASS** | |
| 재생 블록 안 함 | **PASS** | 별도 Task로 비동기 fetch |

### 가사 하이라이트

| 항목 | 결과 | 비고 |
|------|------|------|
| 올바른 가사 줄 계산 | **PASS** | `lines.indices.last(where:)` |
| .primary / .secondary semantic color | **PASS** | LyricLineView |
| 하드코딩 색상 없음 | **PASS** | |
| ScrollViewReader 자동 스크롤 | **PASS** | FullPlayerView onChange |

---

## 4단계: 최종 판정 + 피드백

**전체 판정**: 조건부 합격
**가중 점수**: 8.45 / 10.0

```
가중 점수 = (8 × 0.30) + (9 × 0.25) + (8.5 × 0.20) + (9 × 0.15) + (8.5 × 0.10)
         = 2.40 + 2.25 + 1.70 + 1.35 + 0.85
         = 8.55
```

**항목별 점수**:
- Swift 6 동시성: **8/10** — `nonisolated(unsafe)` 사용으로 동시성 검사 명시적 우회 1건. Timer 콜백의 Sendable 경계 잠재 문제.
- MVVM 분리: **9/10** — Protocol 기반 Service 주입 미구현. 테스트 가능성 저하.
- HIG 준수: **8.5/10** — `.red` 하드코딩 1건, `.system(size:)` 아이콘 크기 하드코딩 4건, 가사 탭-to-seek 미활용.
- API 활용: **9/10** — ChartListView에서 MusicAuthorization 직접 접근. 그 외 모든 API 올바르게 활용.
- 기능성/가독성: **8.5/10** — dead code(onTap 미활용), `nonisolated(unsafe)` 주석 부재, 일부 접근 제어자 미명시.

**구체적 개선 지시**:

1. **`MusicPlayerService.swift` `player` 프로퍼티**: `nonisolated(unsafe)` 사용 이유를 코드 주석으로 명시하라. ApplicationMusicPlayer.shared가 Sendable을 준수하지 않아 actor 경계를 넘길 수 없는 MusicKit 한계를 설명하는 주석이 필요하다. 가능하다면 각 메서드 내부에서 `ApplicationMusicPlayer.shared`를 직접 참조하는 방식으로 변경하여 `nonisolated(unsafe)` 의존을 제거하라.

2. **`ChartViewModel.swift`, `PlayerViewModel.swift` 생성자**: Protocol 기반 Service 주입으로 변경하라. `ChartServiceProtocol`, `MusicPlayerServiceProtocol`, `LyricServiceProtocol` 프로토콜을 정의하고, ViewModel이 프로토콜 타입에 의존하도록 수정. 테스트 시 Mock 주입이 가능해야 한다.

3. **`ChartListView.swift` 라인 2, 9, 29**: `import MusicKit` 및 `MusicAuthorization.currentStatus` 직접 접근을 제거하라. `ChartViewModel`에 `authorizationStatus: MusicAuthorization.Status` 프로퍼티를 추가하고 ViewModel에서 권한 상태를 관리하도록 변경. View는 ViewModel의 프로퍼티만 참조해야 한다.

4. **`SongDetailView.swift` 라인 83**: `.foregroundStyle(.red)`를 `.foregroundStyle(Color(.systemRed))` 또는 `.foregroundStyle(.secondary)`로 변경하라.

5. **`FullPlayerView.swift` `syncedLyricView(lines:proxy:)` 함수**: `LyricLineView`에 `onTap` 클로저를 전달하여 가사 줄 탭 시 해당 타임스탬프로 seek하는 기능을 구현하라. 또는 이 기능을 구현하지 않을 것이면 `LyricLineView`에서 `onTap` 파라미터를 제거하라.

6. **`PlayerViewModel.swift` `isDragging` 프로퍼티**: View에서 `playerViewModel.isDragging = true`로 직접 변이하고 있다. `func onSliderEditingChanged(_ editing: Bool)` 메서드를 추가하여 ViewModel 메서드를 통해서만 상태를 변경하도록 리팩토링하라. `isDragging`은 `private(set)`으로 변경.

7. **`.system(size:)` 하드코딩 아이콘 크기 4건**: `SongDetailView.swift` 라인 29(`.system(size: 60)`), 라인 72(`.system(size: 72)`), `FullPlayerView.swift` 라인 65(`.system(size: 40)`), 라인 142(`.system(size: 60)`). 가능한 범위에서 `.font(.largeTitle)` 등 semantic size로 교체하거나, `.imageScale(.large)` 활용을 검토하라.

**방향 판단**: 현재 방향 유지. 아키텍처 기반은 건전하며, 위 7개 항목은 기존 구조 내에서 수정 가능하다.
