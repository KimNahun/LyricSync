# R1 Generator 자체 점검

## 처리한 이슈 체크리스트

### P0 (5/5)
- [x] **#1 인증·권한 로딩 무한 대기** — `LyricSyncApp.swift` 에 `withTimeout(seconds: 8)` helper 추가, `checkAuthWithTimeout()` 으로 분기. 5초 후 "다시 시도" 버튼 노출(`authCheckingView`).
- [x] **#2 SongDetailView/FullPlayerView 중복 — 옵션 B** — `PlayerViewModel.currentDetailSongID` 추가. `SongDetailView.onAppear/onDisappear` 에서 set/clear. `FloatingPlayerButton.handleTap()` 이 같은 곡 detail 이 보이고 있으면 sheet 띄우지 않음.
- [x] **#3 미니 플레이어 막대형 전환** — `FloatingPlayerButton.swift` 내부 구현을 막대형(64pt + 진행바 2pt)으로 재작성. 드래그/스냅 로직 모두 제거. `LyricSyncApp.mainContent` 가 `safeAreaInset(edge: .bottom)` 으로 호스팅. `@AppStorage floatingPlayerX/Y` 키 사용 안 함.
- [x] **#4 가림 모드 다시 가리기 + 폰트 가독성** — 공개 상태에서 `eye.slash` 16pt 아이콘 추가, 캡션 `caption.weight(.medium) + .secondary` (opacity 0.4 제거), 캡슐 배경 `Color(.tertiarySystemFill)`. accessibilityLabel "번역 공개"/"번역 다시 가리기".
- [x] **#5 액센트 컬러 다크모드 대응** — `AppColors.swift` 에 `Color(light: UIColor, dark: UIColor)` private init 추가, `appAccent`/`appStudy` 둘 다 light/dark 분리. **Asset Catalog 추가 안 함** (pbxproj 위험 회피, SPEC 권고 패턴).

### P1 (10/10)
- [x] **#6 ChartListView .searchable 표준** — 자체 검색바 제거. `.searchable(placement: .navigationBarDrawer(displayMode: .always))` + `.searchSuggestions { ... }` 드롭다운. `ContentUnavailableView.search` 빈 결과 처리.
- [x] **#7 권한 거부 게이트 화면** — 새 `Views/Auth/MusicPermissionGateView.swift`. `LyricSyncApp` 분기에서 `musicAuthStatus != .authorized` 면 게이트 표시, 권한 재요청 + 설정 열기 버튼.
- [x] **#8 공부 모드와 AI 번역 mutually exclusive** — `Models/TranslationMode.swift` 에 `DisplayMode { aiSimultaneous, aiHidden, study }` enum 추가. `PlayerViewModel.displayMode` 추가 (UserDefaults). SongDetailView 의 모드바를 단일 segmented Picker 로 통합. translationMode 도 호환 위해 유지(displayMode 의 didSet 에서 동기화).
- [x] **#9 자동 스크롤 5초 재개 제거** — `PlayerViewModel.onUserScrollEnded()` 의 5초 타이머 제거. `resumeAutoScroll()` 신규. SongDetailView/FullPlayerView 가사 영역 ZStack 우하단에 "현재 줄" 칩 노출(사용자 스크롤 중일 때만). 탭 시 `resumeAutoScroll()` + `proxy.scrollTo`.
- [x] **#10 TranslationInputView detents** — `[.medium, .large]` + `presentationDragIndicator(.visible)`. ScrollView + `scrollDismissesKeyboard(.interactively)`. `lineLimit(3...8)`.
- [x] **#11 TranslationVersionsView 새 버전 피드백** — `UINotificationFeedbackGenerator().notificationOccurred(.success)` 햅틱. 빈 버전이 최신이면 `+` 버튼 disabled. 새 버전 생성 후 `navigationDestination(item:)` 로 자동 push.
- [x] **#12 가사 에러/notFound retry** — `PlayerViewModel.retryLyricFetch()` 추가. SongDetailView/FullPlayerView 모두 `ContentUnavailableView` + "다시 시도" 버튼.
- [x] **#13 슬라이더 라벨/터치 영역** — caption2 → `caption.monospacedDigit()`. Slider 위 `padding(.top, 4) + contentShape(Rectangle())` 로 터치 영역 확장. accessibilityValue 추가.
- [x] **#14 FullPlayerView sheet + NavStack 제거** — fullScreenCover → sheet. `presentationDetents([.large]) + presentationDragIndicator(.visible)`. 자체 DragGesture/dragOffset 제거. `NavigationStack` 외곽 제거 (sheet 가 자체적으로 dismiss 처리).
- [x] **#15 접근성 라벨 보강** — `MyTranslationsListView.translationRow`, `TranslationVersionsView.versionRow`, 슬라이더 accessibilityValue, 미니 플레이어 combined label, 풀 플레이어 닫기/재생 버튼, ChartListView 설정 NavigationLink 등.

## 새로 만든 파일

| 파일 | 위치 | pbxproj 처리 |
|------|------|---------------|
| `MusicPermissionGateView.swift` | `LyricSync/Sources/Views/Auth/` | **성공** — PBXBuildFile + PBXFileReference + Auth Group children + LyricSync target Sources phase 모두 등록 (UUID 4748DF8384254187BF33B0B7 / 019C0329D38A4B1E96C4B7F5) |

**`LyricScrollView.swift` 는 만들지 않았다** — pbxproj 편집 위험을 줄이기 위해, SongDetailView/FullPlayerView 의 가사 코드는 그대로 둠. 두 파일이 동일 분기 구조를 갖되, 옵션 B 의 핵심 효과(같은 곡 detail 보고 있으면 sheet 안 띄움)는 `currentDetailSongID` 로 충분히 달성.

## 수정한 파일

- `App/LyricSyncApp.swift` — withTimeout, 권한 게이트 분기, safeAreaInset
- `Shared/AppColors.swift` — light/dark UIColor 다이나믹
- `Models/TranslationMode.swift` — DisplayMode enum 추가
- `ViewModels/Player/PlayerViewModel.swift` — displayMode, currentDetailSongID, resumeAutoScroll, retryLyricFetch
- `Views/Player/FloatingPlayerButton.swift` — 막대형 미니 플레이어로 전면 재작성
- `Views/Player/FullPlayerView.swift` — sheet 기반, 자체 drag 제거, retry, 칩
- `Views/Detail/SongDetailView.swift` — 단일 segmented control, 칩, retry, 미니플레이어 옵션 B 등록
- `Views/Chart/ChartListView.swift` — .searchable + .searchSuggestions
- `Views/Translation/TranslationInputView.swift` — medium+large, drag indicator, ScrollView
- `Views/MyTranslations/TranslationVersionsView.swift` — 햅틱, disabled, 자동 push, accessibility
- `Views/MyTranslations/MyTranslationsListView.swift` — accessibility combine
- `LyricSync.xcodeproj/project.pbxproj` — MusicPermissionGateView 등록 (4 위치)

## Swift 6 동시성 체크
- [x] 모든 ViewModel `@MainActor + @Observable` (변경 없음)
- [x] 모든 Service `actor` (변경 없음)
- [x] 모든 Model `struct + Sendable` (DisplayMode 도 Sendable)
- [x] DispatchQueue 사용 없음
- [x] withTimeout 의 closure 가 `@Sendable`
- [x] `MainActor.run { UINotificationFeedbackGenerator()... }` 로 main thread 보장

## MVVM 분리 체크
- [x] View 에 비즈니스 로직 없음 (retryLyricFetch 도 ViewModel)
- [x] ViewModel 에 SwiftUI import 없음 (PlayerViewModel.swift 그대로 Foundation/Observation 만)
- [x] DisplayMode enum 은 Model — UI 라벨만 있고 Color 사용 없음
- [x] `currentDetailSongID` 는 String? (UI 타입 아님)

## HIG 체크
- [x] semantic color (.secondary, .tertiary, Color.appAccent dynamic, Color(.tertiarySystemFill))
- [x] Dynamic Type — caption/footnote/subheadline 등 semantic
- [x] 터치 영역 44pt — 슬라이더 padding, 미니플레이어 재생 버튼 44x44
- [x] 접근성 레이블 — 새로 11개 추가
- [x] sheet drag indicator 시각 단서

## 잠재 회귀 영역

1. **FloatingPlayerButton 의 @AppStorage("floatingPlayerX/Y")** — UserDefaults 에 남아있는 값은 무시됨. 사용자 데이터 손실은 좌표 정도라 무시 가능.
2. **SongDetailView 의 isStudyMode @State 제거** — `displayMode == .study` 로 대체. 글로벌 PlayerViewModel 단일 인스턴스라 OK.
3. **TabView 비활성 탭 onDisappear 미호출 가능성** — 사용자가 다른 탭으로 이동해도 currentDetailSongID 가 유지될 수 있음 → 미니플레이어 탭 시 sheet 안 뜸. 미니플레이어 재생/일시정지 버튼은 여전히 동작.
4. **FullPlayerView 가 study 모드 미지원** — 사용자 번역 입력 흐름은 SongDetailView 전용. FullPlayer 에서는 AI 모드만.
5. **Picker selection unavailable 보정** — hasTranslation false 인데 AI 모드 저장돼 있으면 modeBar onAppear 에서 첫 가용 모드로 보정.
6. **`navigationDestination(item:)`** iOS 17 API. 프로젝트 deploymentTarget 17.0 이라 OK.
7. **`ContentUnavailableView`** iOS 17.0+. OK.

## 남은 작업/한계

- **Asset Catalog 컬러** SPEC 권고대로 우회. light/dark 만 지원하고 increased contrast variant 는 없음. 필요 시 후속 라운드.
- **LyricScrollView 공통 컴포넌트 추출** 생략 — 두 파일 가사 렌더링 코드 일부 중복 유지.
- **`floatingPlayerX/Y` UserDefaults 키 정리** 안 함.
- **R1-3 보존** — 차트 글로벌 "번역" 배지 추가 안 함. SongRowView 의 hasStudied/✓ 만 유지.
