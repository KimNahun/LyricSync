# LyricSync

Apple Music 차트 곡을 재생하면서 **한국어 번역 가사를 시간 동기화로 표시**하는 iOS 앱.
AI 번역과 직접 번역을 모두 지원하여, 음악 감상과 가사 공부를 동시에 할 수 있습니다.

## 주요 기능

### 차트 & 검색
- Apple Music **Pop / J-Pop Top 50** 차트 브라우징
- 실시간 검색 (300ms 디바운스)
- 번역 제공 여부 · 내 번역 여부 배지 표시

### 음악 재생 & 가사 싱크
- MusicKit 기반 Apple Music 재생
- **LRC 포맷 시간 동기화 가사** — 현재 재생 위치에 맞춰 자동 스크롤
- 가사 탭으로 해당 시간으로 이동 (Tap-to-Seek)
- 드래그 가능한 **플로팅 플레이어 버튼** (프로그레스 링 포함)
- 풀스크린 플레이어 (앨범 아트, 재생 컨트롤, 시크 슬라이더)

### 번역 모드
- **동시 모드**: 원문 + 한국어 번역을 나란히 표시
- **가림 모드**: 번역을 숨기고, 줄마다 "번역 보기" 버튼으로 확인
- 모드 설정은 앱 종료 후에도 유지

### 공부 모드 (내 번역)
- 줄 단위로 직접 한국어 번역 입력
- **번역 버전 관리** — 같은 곡에 여러 번역 버전 저장 (v1, v2, v3…)
- "내 번역" 탭에서 전체 번역 목록 및 버전 히스토리 확인
- Apple 로그인 연동

## 기술 스택

| 영역 | 기술 |
|------|------|
| 언어 | Swift 6 |
| UI | SwiftUI (iOS 17.0+) |
| 아키텍처 | MVVM + `@Observable` |
| 동시성 | Swift Actors, `@MainActor` |
| 음악 | MusicKit |
| 백엔드 | Supabase (PostgreSQL + REST API) |
| 번역 파이프라인 | GPT-4o-mini (로컬 Python 스크립트) |
| 가사 폴백 | lrclib.net |
| 인증 | Apple Sign-In + Keychain |

## 아키텍처

```
Views (SwiftUI struct)
  └── ViewModels (@MainActor @Observable final class)
        └── Services (actor, protocol 기반 DI)
              └── Models (struct Sendable)
```

- **View** — SwiftUI 뷰, ViewModel 주입
- **ViewModel** — 비즈니스 로직, SwiftUI import 금지
- **Service** — 네트워크/시스템 접근, actor로 동시성 안전
- **Model** — 불변 데이터, Sendable 준수

## 프로젝트 구조

```
LyricSync/Sources/
├── App/                  # 앱 진입점, 탭 네비게이션
├── Views/
│   ├── Chart/            # 차트 목록, 곡 행
│   ├── Detail/           # 곡 상세 (재생 + 가사)
│   ├── Player/           # 풀스크린 플레이어, 플로팅 버튼
│   ├── MyTranslations/   # 내 번역 목록, 버전 히스토리
│   ├── Translation/      # 번역 입력 시트
│   ├── Auth/             # 로그인
│   └── Settings/         # 설정, 계정 관리
├── ViewModels/           # Player, Chart, MyTranslations
├── Services/             # MusicPlayer, Chart, Lyric, Auth 등
├── Models/               # Song, LyricLine, TranslationMode 등
└── Shared/               # 색상, 로거, 유틸
```

## 빌드

```bash
xcodebuild -project LyricSync/LyricSync.xcodeproj \
  -scheme LyricSync \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

> iOS 17.0+ / Xcode 16+ / Swift 6 필요

## 가사 조회 파이프라인

```
1. Supabase에서 AI 번역 가사 조회 (원문 + 한국어)
2. 실패 시 → lrclib.net에서 원문 싱크 가사 폴백
3. 싱크 가사 없으면 → 일반 텍스트 가사
4. 모두 실패 → "가사를 찾을 수 없습니다"
```

## 라이선스

Private repository — All rights reserved.
