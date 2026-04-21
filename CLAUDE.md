# LyricSync

Swift 6 + SwiftUI + MVVM iOS 음악 가사 앱. iOS 17.0+.
Apple Music 팝/J-Pop 차트 곡을 재생하면서, 한국어 번역 가사를 시간 동기화로 표시.

## 아키텍처 규칙 (절대 변경 금지)

- **뷰**: SwiftUI struct, `@Observable` ViewModel 사용
- **ViewModel**: `@MainActor @Observable final class`, SwiftUI import 금지
- **Service**: `actor`, 프로토콜 기반 (DI + 테스트 목킹)
- **Model**: `struct Sendable`
- **디자인**: SwiftUI 기본 semantic color + Dynamic Type (커스텀 디자인 시스템 없음)

## 빌드

```bash
xcodebuild -project LyricSync/LyricSync.xcodeproj \
  -scheme LyricSync \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```

## 주요 파일 위치

| 역할 | 경로 |
|------|------|
| 앱 진입점 | `LyricSync/Sources/App/LyricSyncApp.swift` |
| 차트 조회 | `LyricSync/Sources/Services/ChartService.swift` |
| 가사 조회 | `LyricSync/Sources/Services/LyricService.swift` |
| 음악 재생 | `LyricSync/Sources/Services/MusicPlayerService.swift` |
| 플레이어 VM | `LyricSync/Sources/ViewModels/Player/PlayerViewModel.swift` |
| 풀 플레이어 | `LyricSync/Sources/Views/Player/FullPlayerView.swift` |
| 백엔드 스펙 | `harness/docs/BACKEND_SPEC.md` |
| API 명세 | `harness/docs/API.md` |

## 백엔드 연동

- **DB/API**: Supabase (무료 tier) — REST API 자동 생성
- **번역 파이프라인**: 로컬 Python 스크립트 (GPT-4o-mini)
- **iOS 호출**: Supabase REST → 번역 가사 조회, 실패 시 lrclib.net fallback
- 상세: `harness/docs/BACKEND_SPEC.md`, `harness/docs/API.md`

## 하네스 파이프라인

신규 기능 개발은 하네스 파이프라인으로 실행.
버그 수정/피드백 반영(기존 파일 Edit)은 하네스 불필요.

## 커밋 컨벤션

```
harness: [단계N] {설명}   ← 하네스 파이프라인 단계
feedback R{N}-{#}: {설명}  ← 사용자 피드백 반영
fix: {설명}                ← 버그 수정
chore: {설명}              ← 의존성/설정 변경
```

## 주의사항

- `harness/output/` 폴더는 사용하지 않음 — Swift 파일은 `LyricSync/Sources/` 직하에 생성
- Supabase anon key는 앱에 포함 가능 (RLS로 읽기만 허용)
- Supabase service_role key는 절대 앱에 넣지 않음
