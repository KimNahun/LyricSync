# R1 QA 리포트

## RESULT: pass

## 요약
- 검수한 이슈 수: 15
- 구현 확인: 15 / 15
- 부분 구현: 0
- 미구현/회귀: 0
- 핵심 코멘트:
  - P0 5건과 P1 10건 모두 코드 레벨에서 1대1 매핑 확인. SELF_CHECK 자기보고와 실제 코드 일치.
  - 빌드 통과 + 아키텍처 룰(ViewModel `@MainActor @Observable` / Service `actor` / Model `Sendable`) 위반 없음. ViewModel 어디에도 `import SwiftUI`/UI 타입 노출 없음, `DispatchQueue`/`@Published`/`ObservableObject` 사용 없음.
  - 회귀 위험은 낮은 polish 수준만 잔존 (P0 #5 Asset Catalog 우회, FullPlayer에서 displayMode가 study일 때 자동 보정으로 사용자 모드가 aiSimultaneous로 변경되어 UserDefaults에 저장됨 — 다음 라운드 권장).

---

## 이슈별 검수

### P0
| # | 이슈 | 상태 | 코멘트 |
|---|------|------|--------|
| 1 | 인증 타임아웃 + 재시도 | 구현 | `LyricSyncApp.swift:118-137 checkAuthWithTimeout()` + 파일 하단 `withTimeout` helper(`@Sendable T`로 generic 처리, `withTaskGroup` 기반). `authCheckingView`(L48-69)에 5초 후 "다시 시도" 버튼 노출. `MusicAuthorization.notDetermined` → 자동 request. 권한 게이트는 별도 분기(L29-32)로 빠짐. |
| 2 | SongDetail/FullPlayer 중복 — 옵션 B | 구현 | `PlayerViewModel.swift:59 currentDetailSongID`. `SongDetailView.swift:70-85`에서 onAppear/onChange/onDisappear set·clear. `FloatingPlayerButton.swift:99-107 handleTap()`이 같은 곡 detail 보고 있으면 sheet skip. `LyricScrollView` 추출은 생략됐지만 옵션 B의 핵심 효과는 달성. |
| 3 | 막대형 미니 플레이어 | 구현 | `FloatingPlayerButton.swift` 전면 재작성: 64pt 막대 + 2pt 진행 바, 좌측 40pt 아트 + 곡명/아티스트 + 44x44 재생 버튼. 드래그/스냅 로직 완전 제거(`DragGesture`/`@AppStorage` 키 잔존 없음 — grep 확인). `LyricSyncApp.swift:106-112 safeAreaInset(.bottom)`으로 호스팅. 파일명만 유지(SELF_CHECK가 명시한 pbxproj 안전성). |
| 4 | 가림 모드 다시 가리기 + 폰트 | 구현 | `FullPlayerView.swift:288-319` / `SongDetailView.swift:447-478`. 공개 상태에 `eye.slash` 13pt 아이콘 우측 배치. 미공개 캡션 `caption.weight(.medium) + .secondary` + `Color(.tertiarySystemFill)` 캡슐 (opacity 0.4 제거). `accessibilityLabel("번역 공개"/"번역 다시 가리기")` 명시. |
| 5 | 액센트 컬러 다크 대응 | 구현 (Asset 우회) | `AppColors.swift:5-25`에 `Color(light: UIColor, dark: UIColor)` private init 추가, appAccent/appStudy 둘 다 light/dark 분리 색상. SELF_CHECK이 Asset Catalog 미적용 사유(pbxproj 위험)를 명시했고, 다크 대비 핵심 가치는 달성. High Contrast variant는 없음(P2급). |

### P1
| # | 이슈 | 상태 | 코멘트 |
|---|------|------|--------|
| 6 | .searchable 표준 + ContentUnavailableView | 구현 | `ChartListView.swift:45-54`. 자체 검색바·`HStack(xmark)` 제거. `.searchable(placement: .navigationBarDrawer(displayMode: .always))` + `.searchSuggestions { ... }` 드롭다운. 빈 결과는 `ContentUnavailableView.search(text:)`. ChartViewModel.isSearchActive computed로 단순화 확인. |
| 7 | 권한 거부 게이트 | 구현 | 새 파일 `Views/Auth/MusicPermissionGateView.swift` (88줄, pbxproj 4위치 등록). `LyricSyncApp.swift:29-32`에서 `musicAuthStatus != .authorized` → 게이트 표시. 권한 재요청 + 설정 열기 버튼 + 로딩 상태. `ChartListView.deniedView`도 백업 유지. |
| 8 | 모드 mutually exclusive | 구현 | `Models/TranslationMode.swift:12-42 enum DisplayMode { aiSimultaneous, aiHidden, study }` (Sendable, CaseIterable, Identifiable). `PlayerViewModel.swift:27-35 var displayMode` UserDefaults 동기. `SongDetailView.swift:104-144` 단일 segmented Picker로 통합. AI 모드와 study가 자연스레 상호배타. translationMode 호환은 didSet에서 동기화. |
| 9 | 자동 스크롤 5초 재개 제거 + 칩 | 구현 | `PlayerViewModel.swift:201-212` 5초 타이머 제거, `resumeAutoScroll()` 신규. `FullPlayerView.swift:36-44` / `SongDetailView.swift:50-58` 가사 ZStack 우하단 칩 노출(isUserScrolling 일 때만), 탭 시 `resumeAutoScroll() + proxy.scrollTo`. |
| 10 | TranslationInput detents | 구현 | `TranslationInputView.swift:71-72 [.medium, .large] + dragIndicator(.visible)`. `ScrollView` + `scrollDismissesKeyboard(.interactively)` (L16/47). `lineLimit(3...8)`. |
| 11 | 새 버전 피드백 + 빈 버전 가드 | 구현 | `TranslationVersionsView.swift:16-19 canCreateNewVersion`(latest.lineCount>0). L43 `.disabled(!canCreateNewVersion)` + accessibilityHint. L132-138 햅틱(`UINotificationFeedbackGenerator`) `MainActor.run` 보장. L51-56 `navigationDestination(item:)`로 자동 push. |
| 12 | 가사 에러 retry | 구현 | `PlayerViewModel.swift:248-257 retryLyricFetch()` 신규. `FullPlayerView.swift:326-342` / `SongDetailView.swift:496-512` `ContentUnavailableView { ... } actions: { Button("다시 시도") }`. notFound/error만 retry 노출, instrumental은 비노출. |
| 13 | 슬라이더 라벨/터치 영역 | 구현 | 시간 라벨 `.font(.caption.monospacedDigit())`로 격상(FullPlayer L117·123, SongDetail L273·277). 슬라이더에 `.padding(.top, 4) + .contentShape(Rectangle())` 적용. `accessibilityValue` 양쪽 추가. |
| 14 | sheet + drag indicator + NavStack 제거 | 구현 | `FullPlayerView.swift`: 외곽 NavigationStack 제거(VStack 시작), 자체 DragGesture/dragOffset/chevron.down 제거 확인. `presentationDetents([.large]) + presentationDragIndicator(.visible)`(L48-49). `FloatingPlayerButton.swift:89` sheet로 호스팅. 가사 영역의 `simultaneousGesture(DragGesture)`는 스크롤 의도용으로 유지(정상). |
| 15 | 접근성 라벨 보강 | 구현 | `MyTranslationsListView.swift:104-105 combine + label`, `TranslationVersionsView.swift:44 새 버전 버튼 label/hint + L105-106 versionRow combine`, 슬라이더 accessibilityValue 양 화면, FloatingPlayerButton combine + hint(L64-66), 풀 플레이어 재생/일시정지 label, `MusicPermissionGateView` 두 버튼 label, ChartListView 설정 NavLink label. |

---

## 발견 사항

### Blocker (반드시 수정)
- 없음.

### 권장 (다음 라운드 또는 즉시)
1. **FullPlayerView의 displayMode 자동 보정 부작용**: `FullPlayerView.swift:155-160` `modeBar.onAppear`에서 `displayMode == .study`일 때 `displayMode = .aiSimultaneous`로 강제 변경 → didSet으로 UserDefaults 저장됨. 사용자가 SongDetailView에서 study 선택 후 풀플레이어를 잠깐 열면 모드가 영구 변경되어 SongDetailView 복귀 시에도 study가 아닌 aiSimultaneous로 남음. 풀플레이어에서는 표시만 aiSimultaneous로 하되 displayMode는 그대로 두거나, 풀플레이어 종료 시 원복하는 로컬 state가 권장.
2. **AppColors High Contrast variant 부재**: SPEC P0 #5의 정신은 일부 미달성. SPEC 권고대로 후속 라운드에서 Asset Catalog로 마이그레이션 + High Contrast 추가 권장. 이번 라운드 점수에는 영향 없음.
3. **floatingPlayerX/Y UserDefaults 키**: 이전 빌드 사용자에게 잔존 키. 마이그레이션 미실행. 무해하지만 청소 권장.
4. **SongDetailView의 modeBar `if modes.count >= 2`**: hasTranslation=false + dbUserId 있는 경우 modes=[.study] 1개라 picker가 사라짐. study 모드 자체는 displayMode를 통해 적용되지만, 사용자가 picker가 없어졌다고 모드를 토글 못 한다고 오해할 수 있음. 1개 모드일 때는 라벨 정도 보여주는 변형 권장(P2급).
5. **LyricScrollView 공통 컴포넌트 미추출**: SongDetailView/FullPlayerView 가사 렌더링 코드 중복 존재. 다음 R2/R3 라운드 리팩터링 권장(현재 라운드 스코프에선 의도적 보류 명시됨).

---

## 회귀 위험 평가

- **FloatingPlayerButton 전면 재작성**: 원형→막대형 전환은 SPEC #3의 명시된 요구. 드래그/스냅 로직과 `@AppStorage` 잔존 없음(grep 확인). `safeAreaInset(.bottom)` 호스팅으로 글로벌 위치 일관됨. 회귀 위험 낮음.
- **fullScreenCover→sheet**: SPEC #14가 명시. NavigationStack 외곽 제거로 toolbar API가 단순해짐. 풀플레이어 자체 DragGesture가 sheet 시스템 dismiss와 중복되던 문제 해소. NavigationStack 제거로 navigationTitle 같은 것이 빠졌으나 풀플레이어는 자체 헤더가 있으므로 무관. 회귀 위험 낮음.
- **displayMode 도입**: TranslationMode와 호환 위해 didSet 동기화 유지. 기존 hidden/simultaneous 분기 모두 displayMode로 라우팅(`SongDetailView`/`FullPlayerView`의 `translatedLineView`). 풀플레이어에서 study 미지원 → 자동 보정이 UserDefaults에 영구 저장되는 부작용은 위 권장 1번에 명시.
- **AppColors light/dark 분리**: 모든 사용처가 동일 `Color.appAccent`/`appStudy`이므로 호출부 변경 없음. UIColor 다이나믹 init은 메인 스레드 trait 평가라 안정적. 회귀 위험 낮음.
- **currentDetailSongID 옵션 B**: TabView 비활성 탭에서 onDisappear가 호출되지 않을 가능성을 SELF_CHECK이 명시. 그 경우 미니플레이어 탭에서 sheet가 안 뜨지만 미니플레이어 자체의 재생/일시정지는 동작. 결과적으로 흐름은 막히지 않음. 허용 가능.

## 아키텍처/동시성 위반

없음.

- ViewModel(`PlayerViewModel`/`ChartViewModel`/`MyTranslationsViewModel`) 모두 `@MainActor @Observable final class`. SwiftUI/UIKit import 없음. UI 타입 사용 없음.
- Service 8개 모두 `actor`(AuthService, MusicPlayerService, ChartService, LyricService, UserTranslationService, SearchService, TranslatedLyricService) 또는 그 안의 결과 `struct Sendable`.
- `withTimeout` helper(LyricSyncApp.swift:161-176)는 `T: Sendable` + `@escaping @Sendable () async -> T` + `withTaskGroup`. Swift 6 동시성 적합.
- `UINotificationFeedbackGenerator` 호출은 `MainActor.run` 안에서 수행(TranslationVersionsView.swift:133-135). Sendable 경계 OK.
- `DisplayMode` enum은 `Sendable`. `TranslationMode`도 `Sendable`. 모든 모델 struct/enum.
- `DispatchQueue.main.async` 사용 없음, `@Published`/`ObservableObject` 사용 없음(전 폴더 grep 확인).

## 구체적 개선 지시 (Generator R2 가 받을 입력)

(pass — 비어 있음)
