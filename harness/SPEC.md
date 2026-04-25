# UI/UX 개선 SPEC

## 감사 요약
- 전체 점검한 화면 수: 11개 (Login, ChartList, SongRow, SongDetail, FullPlayer, FloatingPlayerButton, MyTranslationsList, TranslationVersions, TranslationInput, Settings, Components/Cached·LyricLine)
- 발견 이슈 수: P0=5, P1=10, P2=6 (총 21개)
- 핵심 테마:
  1. **재생 흐름의 단절** — `SongDetailView` 와 `FullPlayerView` 가 동일한 정보(아트워크 + 슬라이더 + 가사)를 거의 같은 레이아웃으로 두 번 그린다. 유저 입장에선 어떤 게 풀 플레이어인지 모호하고, 미니 플레이어 역할의 `FloatingPlayerButton` 은 가장자리 스냅 원형이라 iOS 표준 미니 플레이어 패턴(`safeAreaInset`)에서도 벗어나 있다.
  2. **상태 처리의 사일런트 페일** — `LyricSyncApp.checkAuth()`, `MusicAuthorization.request()`, `AuthService.registerUser`, `userTranslationService.save` 등 다수 비동기 경로에 사용자 가시 에러/로딩 피드백이 없다. 네트워크 오프라인이나 권한 거부에서 화면이 텅 비거나 무한 로딩에 멈춘다.
  3. **HIG 이탈 + 접근성 누락** — `Color.appAccent`/`appStudy` 가 RGB 하드코딩 단일 값(다크모드 미대응), 12pt 미만 텍스트(`caption2.opacity(0.4)`)가 가독성 한계, 상당수 상호작용 버튼에 `accessibilityLabel` 누락. Dynamic Type 큰 글씨에서 헤더 줄 깨짐.

## 우선순위 정의
- **P0**: 사용자 흐름이 막히거나 깨지는 수준 (반드시 수정)
- **P1**: 사용성을 명확히 해치지만 흐름은 가능 (강력 권장)
- **P2**: polish, 일관성 개선 (시간 되면)

---

## 이슈 목록

### [P0] #1. 인증·권한 로딩이 영원히 멈출 수 있음 — 타임아웃·실패 피드백 부재
- **화면/파일**: `LyricSync/Sources/App/LyricSyncApp.swift:15-35`
- **현재 상태**: 앱 시작 시 `isCheckingAuth=true` 로 무한 `ProgressView()` 만 뜬다. `authService.checkCredential()` 이 네트워크 의존이고, 네트워크가 죽거나 Supabase 가 5xx 면 `isCheckingAuth` 가 영영 false 가 되지 않는다. `MusicAuthorization.request()` 도 별도 alert/시스템 다이얼로그를 거치는 동안 사용자에게 무엇을 기다리는지 안내가 없음.
- **문제**: 첫 실행에서 화면이 회색 스피너만 도는 데드엔드. 거부/실패 시 재시도 경로 없음.
- **개선 제안**:
  - `checkAuth()` 안의 `authService.checkCredential()` 호출을 `withTimeout(seconds: 8)` 패턴(또는 `Task` + `try? await Task.sleep + cancel`)으로 감싸 8초 후 강제 `invalid` 처리.
  - `isCheckingAuth` 분기에서 `ProgressView("로그인 정보 확인 중…")` + 5초 이상 지속 시 "다시 시도" 버튼 노출(`@State private var checkStartedAt: Date`).
  - `MusicAuthorization.request()` 결과를 `@State` 로 받아 거부 시 `LoginView` 가 아니라 별도 안내(설정 열기) 화면으로 보낸다. 현재는 `ChartListView` 에 들어가야 비로소 `deniedView` 가 나오므로 한 단계 늦다.
- **영향 파일**: `LyricSyncApp.swift`, `Services/AuthService.swift` (타임아웃 wrapping 또는 호출부)
- **예상 작업량**: M

### [P0] #2. `SongDetailView` 와 `FullPlayerView` 가 거의 동일한 화면을 중복 표시
- **화면/파일**: `LyricSync/Sources/Views/Detail/SongDetailView.swift:27-75`, `LyricSync/Sources/Views/Player/FullPlayerView.swift:10-69`
- **현재 상태**: 차트에서 곡을 탭하면 `SongDetailView` 가 push 되어 헤더(아트+곡정보+재생) → 모드바 → 슬라이더 → 가사를 보여준다. 그 상태에서 `FloatingPlayerButton` 을 탭하면 `FullPlayerView` 가 fullScreenCover 로 뜨는데, 헤더+슬라이더+가사 구성이 동일하다(번역 모드 토글 위치만 다름). 동일 정보를 두 번 그리고, 가사 자동 스크롤 로직도 양쪽에 중복.
- **문제**:
  - 사용자: "이게 풀 플레이어인가? 방금 본 화면이랑 뭐가 달라?"
  - 코드: `lyricSection`, `syncedLyricView`, 모드 토글 등 같은 로직이 두 파일에 복붙되어 유지보수 부채.
- **개선 제안** (둘 중 택1):
  - **(A) 역할 분리** — `SongDetailView` 는 "곡 정보 카드 + 큰 아트워크 + 재생 트리거 + 짧은 가사 미리보기 3줄" 로 축소. 재생을 누르면 자동으로 `FullPlayerView` 를 fullScreenCover 로 띄움. 가사 본격 학습은 풀 플레이어에서만.
  - **(B) `SongDetailView` 안에 가사 통합 유지** 하되 `FloatingPlayerButton` 동작을 "이미 같은 곡 SongDetailView 가 push 된 상태면 fullScreenCover 띄우지 말고 NavigationStack 의 그 화면으로 popTo." 로 변경. 즉 fullScreenCover 는 다른 탭(내 번역) 또는 백그라운드 진입 후 복귀 시에만 등장.
  - 어느 쪽이든 가사 렌더링 코드는 `LyricScrollView` 같은 공용 컴포넌트로 추출.
- **영향 파일**: `SongDetailView.swift`, `FullPlayerView.swift`, 새 `Views/Player/LyricScrollView.swift`(컴포넌트 분리 시), `FloatingPlayerButton.swift`(B안 시 환경 도입)
- **예상 작업량**: L

### [P0] #3. 미니 플레이어가 원형 플로팅 버튼이라 표준 패턴 위배 + 가사를 가림
- **화면/파일**: `LyricSync/Sources/Views/Player/FloatingPlayerButton.swift:1-131`, `LyricSync/Sources/App/LyricSyncApp.swift:68-75`
- **현재 상태**: 재생 중에는 56pt 원형 버튼이 화면 모서리에 떠 있고, 드래그로 위치 변경, 탭하면 fullScreenCover. PROJECT_CONTEXT.md #4 가 명시한 "미니 플레이어 (글로벌 하단 고정, `safeAreaInset`)" 와 다른 구조다.
- **문제**:
  - HIG: 원형 플로팅은 Apple 음악 앱 패턴이 아님. 가사 화면에선 우하단/우상단에 떠서 마지막 줄을 가린다.
  - 접근성: VoiceOver 가 위치를 알기 어렵고 Dynamic Type/큰 손가락 사용자에게 작음.
  - 정보 밀도: 곡명·아티스트가 안 보임. 진행률은 얇은 링이라 보기 어려움.
- **개선 제안**: `LyricSyncApp.mainContent` 에 `.safeAreaInset(edge: .bottom)` 으로 64pt 높이의 가로 막대형 미니 플레이어 추가 (`MiniPlayerBar` 새 컴포넌트). 구성: 좌측 아트(40pt) + 곡명/아티스트(2줄) + 재생/일시정지 버튼(44pt). 막대 전체 탭 → fullScreenCover. 막대 위에 얇은 진행 바(2pt). 드래그-이동 기능은 제거. 기존 `FloatingPlayerButton` 파일은 삭제.
- **영향 파일**: `LyricSyncApp.swift`, 새 `Views/Player/MiniPlayerBar.swift`, `FloatingPlayerButton.swift`(삭제)
- **예상 작업량**: M

### [P0] #4. 가림 모드의 "번역 보기" 버튼이 한 번 누르면 다시 숨길 방법이 없음에 가까움 + 폰트 흐림
- **화면/파일**: `LyricSync/Sources/Views/Player/FullPlayerView.swift:264-293`, `LyricSync/Sources/Views/Detail/SongDetailView.swift:376-401`
- **현재 상태**: 가림 모드에서 번역을 한 번 공개하면 그 자리에 번역 텍스트가 그려진다. 다시 가리려면 그 텍스트를 정확히 탭해야 하는데, 텍스트는 가운데 정렬이고 별도 시각 단서(가림 아이콘)가 없다. 또한 "번역 보기" 캡션은 `caption2 + .secondary.opacity(0.4)` 로 약 11pt × 알파 0.4 ≈ 사실상 잘 안 보인다.
- **문제**: 학습 흐름의 핵심 인터랙션. "한 번 보고 다시 외우려고 가리기" 가 사실상 막힘.
- **개선 제안**:
  - 공개 상태에서도 우측 끝에 작은 `eye.slash` 아이콘(systemImage, 16pt) 배치. 탭 영역은 줄 전체.
  - 미공개 상태의 "번역 보기" 텍스트 → `Text("번역 보기").font(.caption.weight(.medium)).foregroundStyle(.secondary)` 로 가독성 회복(opacity 0.4 제거). 캡슐 배경은 `Color(.tertiarySystemFill)`.
  - `accessibilityLabel` 을 "번역 공개" / "번역 다시 가리기" 로 명시.
- **영향 파일**: `FullPlayerView.swift`, `SongDetailView.swift`
- **예상 작업량**: S

### [P0] #5. 액센트 컬러가 RGB 하드코딩 단일 값 — 다크모드/접근성 대비 미대응
- **화면/파일**: `LyricSync/Sources/Shared/AppColors.swift:1-11`
- **현재 상태**:
  ```
  static let appAccent = Color(red: 1.0, green: 0.42, blue: 0.42)   // 코랄
  static let appStudy  = Color(red: 0.31, green: 0.80, blue: 0.77)  // 민트
  ```
  라이트/다크 동일 색. 다크모드에선 코랄이 너무 형광에 가깝고, 민트 텍스트(`Color.appStudy` 위에 흰 배경)가 명도 대비 4.5:1 미달.
- **문제**: 다크모드 대비 미달 + 다른 화면에서 `.tint(Color.appAccent)` 가 시스템 컴포넌트(슬라이더 thumb 등)에서 부자연스럽게 튀어 보임.
- **개선 제안**:
  - `AppColors.swift` 에서 두 색을 `Color("AppAccent")`/`Color("AppStudy")` 로 변경하고, `LyricSync/Assets.xcassets` 에 동명 Color Set 추가. 라이트=현재 값, 다크=명도 보정 (코랄: 약간 어둡게 + 채도 ↓ → `R 0.95 G 0.50 B 0.50`, 민트: 다크에선 `R 0.40 G 0.85 B 0.80`).
  - 접근성: Color Set 의 "High Contrast" variant 도 채워 `.accessibilityContrast(.increased)` 환경에서 대비 강화.
- **영향 파일**: `AppColors.swift`, `Assets.xcassets/AppAccent.colorset/Contents.json` 신규, `Assets.xcassets/AppStudy.colorset/Contents.json` 신규
- **예상 작업량**: S

---

### [P1] #6. 차트 리스트 검색 종료 UX — Cancel 버튼 없음 + 키보드 가린 채 결과 0 표시
- **화면/파일**: `LyricSync/Sources/Views/Chart/ChartListView.swift:59-90`
- **현재 상태**: 자체 제작한 검색바(TextField + xmark 아이콘). 표준 `.searchable` modifier 가 아니라서 좌측 "Cancel" 버튼이 없고, X 버튼만 있다. 검색 중에는 차트 리스트 자체가 사라지고 (`if viewModel.isSearchActive { searchResultsList } else { songList }`) 결과 0건이면 한참 빈 화면.
- **문제**: PROJECT_CONTEXT.md #7 의 "미리보기는 드롭다운/오버레이" 와 어긋남(전체 화면 점령). 사용자가 차트로 돌아가는 명시적 길이 X 한 개뿐.
- **개선 제안**:
  - 자체 검색바 제거 → `NavigationStack` 의 `.searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always))` 사용. 표준 cancel/clear 버튼 자동 제공.
  - 검색 결과는 차트 리스트를 덮어쓰지 말고 `.searchSuggestions { ... }` 또는 `overlay` 로 상단 5개만 드롭다운. 검색 종료 시 자동으로 차트 복귀.
  - 빈 결과 시: `ContentUnavailableView.search(text: searchText)` (iOS 17+).
- **영향 파일**: `ChartListView.swift`, `ChartViewModel.swift`(`isSearchActive` 로직 단순화)
- **예상 작업량**: M

### [P1] #7. 권한 거부 화면이 차트 탭 안에서만 노출되어 사용자가 "내 번역" 탭으로 가면 권한 안내 안 보임
- **화면/파일**: `LyricSync/Sources/Views/Chart/ChartListView.swift:11-32`, `LyricSync/Sources/App/LyricSyncApp.swift:37-78`
- **현재 상태**: `ChartListView.deniedView` 만 권한 거부 시 안내. 사용자가 다른 탭(내 번역)으로 가면 그 탭에선 권한이 없어 재생 불가지만 알림 없음. 또 `MusicAuthorization` 거부면 차트 자체가 비어 있어야 정상이지만, 재생 시도 시점까지 갈 때까지 모름.
- **문제**: 진입점 분기가 늦음.
- **개선 제안**: `LyricSyncApp.mainContent` 단계에서 `MusicAuthorization.currentStatus != .authorized` 면 `MusicPermissionGateView` 로 전체 화면 대체(설정 열기 버튼 포함). 권한 승인 후에만 `TabView` 진입. `ChartViewModel.authorizationStatus` 분기는 백업으로 남기되 거의 안 탐.
- **영향 파일**: `LyricSyncApp.swift`, 새 `Views/Auth/MusicPermissionGateView.swift`
- **예상 작업량**: M

### [P1] #8. `SongDetailView` 의 "공부 모드" 와 "AI 번역 모드" 가 상호배타라는 점이 UI 로 안 드러남
- **화면/파일**: `LyricSync/Sources/Views/Detail/SongDetailView.swift:79-121, 282-300`
- **현재 상태**: 공부 모드 ON 이면 AI 번역(동시/가림)이 완전히 숨고 내 번역만, 공부 모드 OFF 면 내 번역이 숨고 AI 번역만. 두 토글이 가로로 병렬 배치만 되어 있어 사용자가 둘이 함께 켜진다고 오해. 동시·가림 Picker 가 회색이 되거나 사라지지 않음.
- **문제**: 공부 모드 ON 인데 동시/가림 Picker 도 그대로 활성화되어 보여 인지 부조화.
- **개선 제안**:
  - 공부 모드 ON 일 때 동시/가림 Picker `.disabled(true).opacity(0.4)` 또는 아예 hidden.
  - 모드 바를 단일 segmented control 3가지(`AI 동시 / AI 가림 / 공부`)로 통합 — 자연스럽게 mutually exclusive 표현.
  - PlayerViewModel 에 `displayMode: enum { aiSimultaneous, aiHidden, study }` 도입(저장 keep).
- **영향 파일**: `SongDetailView.swift`, `PlayerViewModel.swift`, `Models/TranslationMode.swift`(or 새 enum)
- **예상 작업량**: M

### [P1] #9. 가사 자동 스크롤 정지가 5초 후 자동 재개 — 사용자가 스크롤한 의도 무시
- **화면/파일**: `LyricSync/Sources/ViewModels/Player/PlayerViewModel.swift:184-192`
- **현재 상태**: `onUserScrollEnded()` 가 5초 타이머로 `isUserScrolling=false`. 의도적으로 다른 줄을 보던 사용자가 5초 후 갑자기 현재 줄로 점프되어 보던 자리를 잃는다.
- **문제**: 학습 앱 특성상 "한 줄을 보면서 외우는" 시간이 5초보다 김.
- **개선 제안**:
  - 자동 재개를 제거하고, 대신 가사 영역 우하단에 "현재 줄로 이동" 플로팅 칩(`Button { proxy.scrollTo(currentLyricIndex, anchor: .center) }`) 표시. 사용자가 스크롤한 상태일 때만 등장.
  - 또는 30초로 늘리고, 사용자가 다시 같은 곡을 처음부터 듣는 게 아니면 무한 유지.
- **영향 파일**: `PlayerViewModel.swift`, `FullPlayerView.swift`/`SongDetailView.swift`(칩 추가)
- **예상 작업량**: M

### [P1] #10. 번역 입력(`TranslationInputView`) 시트가 medium detent 고정 — 키보드 + 긴 가사에서 입력란 가림
- **화면/파일**: `LyricSync/Sources/Views/Translation/TranslationInputView.swift:14-70`
- **현재 상태**: `.presentationDetents([.medium])`. 한국어 키보드 올라오면 medium 영역의 절반 이상이 키보드. 원문이 2줄 넘으면 입력 필드가 보이지 않게 됨.
- **개선 제안**:
  - `.presentationDetents([.medium, .large])` + `.presentationDragIndicator(.visible)`.
  - 입력 필드를 `ScrollView` 안에 넣어 키보드에 가려지지 않게(자동 스크롤). 또는 `.scrollDismissesKeyboard(.interactively)`.
  - `submitLabel(.done)` 추가, 줄바꿈은 Shift+Enter 안내.
- **영향 파일**: `TranslationInputView.swift`
- **예상 작업량**: S

### [P1] #11. `TranslationVersionsView` — 빈 상태/새 버전 생성 후 결과 피드백 부족
- **화면/파일**: `LyricSync/Sources/Views/MyTranslations/TranslationVersionsView.swift:13-110`
- **현재 상태**: `+` 버튼 누르면 빈 버전이 생성되고 `loadVersions()` 다시 호출. 그러나 새 행으로 강조되지 않고, 사용자에게 "버전 N 생성됨" 피드백이 없음. 또 빈 버전(라인 0) 이 여러 개 생기면 의미 없음.
- **문제**: 같은 버튼 연타 → 라인 0 버전 양산.
- **개선 제안**:
  - 새 버전 생성 후 `Haptic.success()` (`UINotificationFeedbackGenerator`).
  - 가장 최근 버전이 lineCount=0 이면 `+` 버튼 `.disabled(true)` + 툴팁 "마지막 버전을 먼저 채우세요".
  - 새 버전 직후 자동 push → `SongDetailView(translationVersion: nextVer)`.
- **영향 파일**: `TranslationVersionsView.swift`
- **예상 작업량**: S

### [P1] #12. 빈 가사 / 인스트루멘탈 / 에러 상태가 정보 부족 — 재시도 버튼 없음
- **화면/파일**: `LyricSync/Sources/Views/Player/FullPlayerView.swift:193-201, 296-308`, `LyricSync/Sources/Views/Detail/SongDetailView.swift:255-265, 412-422`
- **현재 상태**: `lyricMessageView` 가 아이콘+메시지만. `.error("...")` 케이스는 lrclib 5xx/timeout 도 모두 같은 모양으로 fallback 의 사용자 액션 없음.
- **개선 제안**:
  - `.error` 케이스 한정으로 "다시 시도" 버튼 노출 → `playerViewModel.retryLyricFetch()` 신규 메서드.
  - iOS 17 `ContentUnavailableView` 사용:
    ```
    ContentUnavailableView {
      Label("가사를 찾을 수 없어요", systemImage: "text.slash")
    } description: {
      Text("이 곡에 대한 싱크 가사가 lrclib 와 Supabase 모두에 없습니다.")
    } actions: {
      Button("다시 시도") { ... }
    }
    ```
- **영향 파일**: `FullPlayerView.swift`, `SongDetailView.swift`, `PlayerViewModel.swift`(retryLyricFetch)
- **예상 작업량**: S

### [P1] #13. 슬라이더 라벨/터치 영역 — 끝점 시간이 작고 thumb 가 작음
- **화면/파일**: `LyricSync/Sources/Views/Detail/SongDetailView.swift:200-230`, `LyricSync/Sources/Views/Player/FullPlayerView.swift:117-148`
- **현재 상태**: `.font(.caption2)` 시간 라벨(약 11pt), 기본 SwiftUI `Slider` thumb 는 약 28pt 라 큰 손가락에서 잘 못 잡음.
- **개선 제안**:
  - 시간 라벨 `.font(.caption2.monospacedDigit())` → `.font(.caption.monospacedDigit())` 로 격상.
  - Slider 위쪽에 약 8pt 의 invisible padding (`.padding(.top, 4).contentShape(Rectangle())`) 으로 터치 영역 확대.
  - 드래그 중 현재 시간이 thumb 위에 캡션으로 띄움(`overlay`) → 즉각적 피드백.
- **영향 파일**: `SongDetailView.swift`, `FullPlayerView.swift`
- **예상 작업량**: S

### [P1] #14. `FullPlayerView` 의 NavigationStack + 풀스크린 cover 조합 + 드래그 dismiss 가 시스템 dismiss 와 중복
- **화면/파일**: `LyricSync/Sources/Views/Player/FullPlayerView.swift:13-69`
- **현재 상태**: `fullScreenCover` 안에 `NavigationStack` 을 한 번 더 두고, 좌상단 chevron.down 버튼 + 직접 `DragGesture` 로 dismiss. 그러나 `fullScreenCover` 는 기본 dismiss 제스처가 없는데, 직접 구현된 드래그가 가사 영역의 `simultaneousGesture(DragGesture)` 와 충돌 가능 (가사 스크롤하다가 풀 플레이어가 닫히는 사례).
- **문제**: 의도치 않은 dismiss + 이중 NavigationStack 으로 toolbar API 가 어색.
- **개선 제안**:
  - `fullScreenCover` → `sheet(isPresented:onDismiss:)` + `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)`. 시스템이 드래그 dismiss 를 안전하게 처리.
  - 직접 `DragGesture` 와 `dragOffset` 로직 제거.
  - 외곽 `NavigationStack` 도 제거(Detail 의 NavigationStack 안에 fullScreenCover/sheet 가 떠 있음. 풀 플레이어는 자체 제목 필요 없음).
- **영향 파일**: `FullPlayerView.swift`, `FloatingPlayerButton.swift`/`MiniPlayerBar.swift`(presentation 변경)
- **예상 작업량**: M

### [P1] #15. 접근성 라벨 누락 — 차트/번역 리스트의 메인 인터랙션
- **화면/파일**: `LyricSync/Sources/Views/Chart/SongRowView.swift:48-50`, `LyricSync/Sources/Views/MyTranslations/MyTranslationsListView.swift:51-104`
- **현재 상태**: `SongRowView` 는 combine 으로 한 줄 라벨 있음(OK). 그러나 `MyTranslationsListView.translationRow` 는 라벨 통합 없음 → VoiceOver 가 "버전 N개", "M줄", "4월 25일" 을 따로 읽어 사용자 혼란. `+` 버튼, 모드 토글 픽커, 슬라이더 등도 hint 부족.
- **개선 제안**:
  - `translationRow` 에 `.accessibilityElement(children: .combine).accessibilityLabel("\(title), \(artist), 버전 \(versionCount)개, \(lineCount)줄")`.
  - `TranslationVersionsView` 의 `+` 툴바 버튼 `accessibilityLabel("새 번역 버전 만들기")`.
  - 슬라이더 `.accessibilityValue("\(currentTime), 총 \(duration)")`.
- **영향 파일**: `MyTranslationsListView.swift`, `TranslationVersionsView.swift`, `FullPlayerView.swift`, `SongDetailView.swift`
- **예상 작업량**: S

---

### [P2] #16. 컬러 캡슐 배지(`x개`, `M줄`) 의 시각 무게가 비슷해 우선순위 안 잡힘
- **화면/파일**: `LyricSync/Sources/Views/MyTranslations/MyTranslationsListView.swift:71-90`
- **현재 상태**: 같은 행에 코랄 캡슐("2개")과 민트 캡슐("12줄") 이 동시에. 둘 다 `caption2.weight(.semibold)` + 동일 padding.
- **개선 제안**: 줄 수만 캡슐로 강조, 버전 수는 텍스트만(`Text("v\(n)").font(.caption2).foregroundStyle(.secondary)`) — 시각 위계 명확화.
- **영향 파일**: `MyTranslationsListView.swift`
- **예상 작업량**: S

### [P2] #17. `SettingsView` — Apple ID 표시가 raw user ID 의 prefix 12 자 → 의미 없는 문자열
- **화면/파일**: `LyricSync/Sources/Views/Settings/SettingsView.swift:15-23`
- **현재 상태**: `Text(String(userId.prefix(12)) + "...")` — 사용자에게 의미 없는 hash 문자열.
- **개선 제안**: 가능하면 email 표시(Keychain/AuthService 에서 받아옴). 없으면 항목 자체 제거하고 "로그인됨" 표시. 이메일 보관 안 한다면 "Apple로 로그인됨" 정적 텍스트.
- **영향 파일**: `SettingsView.swift`, `KeychainService.swift`/`AuthService.swift`(이메일 캐시 추가 시)
- **예상 작업량**: S

### [P2] #18. `LoginView` 헤딩 카피가 앱 핵심 가치(Apple Music 차트 + 번역) 를 안 보여줌
- **화면/파일**: `LyricSync/Sources/Views/Auth/LoginView.swift:18-30`
- **현재 상태**: "팝송 가사를 번역하며 / 영어를 배워보세요". 차트, 동시·가림 모드, 내 번역 등 핵심 기능이 안 드러남.
- **개선 제안**: 3-항목 bullet:
  - `Image(systemName: "music.note.list")` "Apple Music 인기 차트로 따라 부르기"
  - `Image(systemName: "rectangle.split.2x1")` "원문과 번역을 동시에 보기"
  - `Image(systemName: "pencil.line")` "내가 직접 번역해 외우기"
- **영향 파일**: `LoginView.swift`
- **예상 작업량**: S

### [P2] #19. 동시 모드 — 비활성 줄의 번역이 `Color.primary.opacity(0.4)` 라 다크모드에서 잘 안 보임
- **화면/파일**: `LyricSync/Sources/Views/Player/FullPlayerView.swift:256-261`, `LyricSync/Sources/Views/Detail/SongDetailView.swift:368-373`
- **현재 상태**: `foregroundStyle(isActive ? Color.appAccent : Color.primary.opacity(0.4))`.
- **개선 제안**: 비활성을 `.secondary` (자체적으로 라이트/다크 적응) 로 교체. opacity 사용 시 라이트모드 흰 배경에서 회색이 흐리게 보이는 패턴 통일.
- **영향 파일**: `FullPlayerView.swift`, `SongDetailView.swift`
- **예상 작업량**: S

### [P2] #20. `SongDetailView.notPlayingView` — "재생 준비 중…" 만 띄우고 액션 없음
- **화면/파일**: `LyricSync/Sources/Views/Detail/SongDetailView.swift:403-410`
- **현재 상태**: `isCurrentSong == false` 일 때 `notPlayingView` 만. 곡 정보를 push 한 시점에 자동 재생되지 않음(R1 피드백). 그래서 사용자는 헤더의 ▶ 를 눌러야 하는데, 그 사이 가사 영역이 그냥 "재생 준비 중" 만 표시되어 잘못된 신호.
- **개선 제안**: `isCurrentSong == false` 일 땐 가사 영역에 "재생을 시작하면 가사가 표시됩니다" + 큰 ▶ 버튼(중앙) 노출. 또는 가사 미리보기 첫 5줄을 회색으로 표시(데이터가 미리 fetch 됐다면).
- **영향 파일**: `SongDetailView.swift`, `PlayerViewModel.swift`(가사 prefetch 옵션 시)
- **예상 작업량**: S

### [P2] #21. 텍스트 truncation — 곡명/아티스트 `.lineLimit(1)` 가 과한 경우 (한 줄 풀 플레이어 헤더)
- **화면/파일**: `LyricSync/Sources/Views/Player/FullPlayerView.swift:84-93`, `LyricSync/Sources/Views/Detail/SongDetailView.swift:166-177`
- **현재 상태**: 풀 플레이어의 컴팩트 바에서 곡명/아티스트가 1줄 truncation. Dynamic Type 가장 큰 글씨에서 "Espresso..." "Sabrina Ca..." 처럼 정보 손실.
- **개선 제안**: `.lineLimit(1...2).minimumScaleFactor(0.85)` + 풀 플레이어는 곡명만 2줄까지 허용.
- **영향 파일**: `FullPlayerView.swift`, `SongDetailView.swift`
- **예상 작업량**: S

---

## 제외/이월 항목

- **새 기능 추가** (예: 즐겨찾기, 가사 공유, 듣기 기록) — 이번 라운드 스코프 밖 (제약 #3).
- **차트 리스트 글로벌 "AI 번역 있음" 배지 복원** — PROJECT_CONTEXT.md #8 가 명시적으로 제거 결정. 이번에도 유지(R1-3 보존, 제약 #4).
- **다국어/번역 외 언어 지원** — 백엔드 API 변경 필요 (제약 #5).
- **위젯/Live Activities** — 별도 capability + iOS 16.1 이슈, 신규 기능에 해당.
- **`@AppStorage` 기반 FloatingPlayer 위치 마이그레이션** — #3 채택 시 자동 무효화.

## 후속 라운드 권장 사항

1. **온보딩 flow** — 권한, 로그인, 첫 곡 선택 가이드 (3-step 시트).
2. **가사 학습 진척도** — 한 곡당 번역 줄 수/총 줄 수 progress bar, 매 줄 완료 햅틱.
3. **에러 텔레메트리** — Supabase 5xx, lrclib timeout 발생률 로컬 카운터 → 사용자에게 "오프라인일 수 있어요" 안내.
4. **검색 히스토리** — 최근 검색어 5개 저장/표시 (UserDefaults).
5. **공유 액션** — 번역한 가사를 텍스트로 내보내기 (`ShareLink`).
6. **가사 폰트 크기 슬라이더** — Dynamic Type 외 풀 플레이어 전용 가독성 옵션.
