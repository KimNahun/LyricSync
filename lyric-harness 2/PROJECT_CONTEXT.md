# 프로젝트 컨텍스트

Planner, Generator, Evaluator가 **반드시 먼저 읽어야 하는** 프로젝트 고정 요구사항.
이 파일에 적힌 내용은 사용자 프롬프트보다 우선한다.

---

## 대상 프로젝트

- **앱 이름**: LyricSync
- **번들 ID**: com.nahun.LyricSync
- **최소 타겟 iOS**: 17.0
- **Swift 버전**: Swift 6 (엄격 동시성 필수)
- **UI 프레임워크**: SwiftUI 전용 (UIKit 미사용)

**파일 생성 위치**: 프로젝트 루트 (output/ 폴더 없이 직접 생성)
- `App/`, `Views/`, `ViewModels/`, `Models/`, `Services/`, `Shared/` 등을 프로젝트 루트에 직접 생성
- Xcode 프로젝트에 드래그&드롭으로 추가할 수 있는 상태

---

## 핵심 컨셉

**Apple Music 구독자가 Top 100 차트에서 노래를 골라 재생하면서, 싱크된 가사를 보고, 슬라이더로 특정 시간으로 이동할 수 있는 앱.**

### 사용자 플로우 (1차 목표)

```
1. 메인 화면 — Apple Music Top 100 차트 리스트 표시
   (MusicKit MusicCatalogChartsRequest 사용)
2. 리스트에서 노래 선택 → 노래 상세 페이지로 이동
   (앨범 아트 크게 표시 + 곡명/아티스트 + 재생 버튼)
3. 재생 버튼 탭 → MusicKit으로 재생 시작
4. 재생 중에는 어떤 화면에서도 맨 아래에 미니 플레이어 표시
   (현재 곡명 + 재생/일시정지 버튼 + 간단한 프로그레스바)
5. 미니 플레이어 탭 → 풀 플레이어 화면 (fullScreenCover)
   - 슬라이더로 재생 위치 이동 가능
   - lrclib.net에서 가져온 가사 표시
   - 현재 재생 중인 가사 줄 하이라이트 (더 밝게/흰색으로)
```

---

## 사용 프레임워크 및 API

### 1. MusicKit (필수)

Apple Music 구독 기반 Top 차트 조회 및 재생.

```swift
import MusicKit
```

- **인증**: `MusicAuthorization.request()` → `.authorized` 필수 (앱 시작 시 바로 요청)
- **Top 차트**: `MusicCatalogChartsRequest` — Top Songs 100개 (iOS 16+)
- **재생**: `ApplicationMusicPlayer.shared` — play, pause, seek
- **재생 상태 감시**: `ApplicationMusicPlayer.shared.state`, `.queue.currentEntry`
- **Info.plist**: `NSAppleMusicUsageDescription` 추가 필수

### 2. lrclib.net API (필수)

싱크 가사 조회. 무료, 인증 불필요. **화면에 표시되는 가사는 이 API 데이터만 사용.**

```
GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}
```

**응답 핵심 필드:**
- `syncedLyrics`: `"[MM:SS.ss] 가사 줄"` 형식의 LRC 포맷 문자열
- `plainLyrics`: 타임스탬프 없는 일반 가사 (syncedLyrics 없을 때 폴백)
- `duration`: 곡 길이 (초)
- `instrumental`: true이면 가사 없는 인스트루멘탈

**LRC 파싱 규칙:**
```
[00:15.07] You know you love me, I know you care
→ 시간: 15.07초, 가사: "You know you love me, I know you care"
```

**가사 하이라이트 규칙:**
- 현재 재생 시간 기준으로 가장 최근 타임스탬프의 가사 줄이 활성 가사
- 활성 가사: `.primary` (밝음), 비활성 가사: `.secondary` (어두움/흐림)
- 다크모드에서 활성 가사가 더 흰색으로 자연스럽게 보이도록 semantic color 활용

### 3. AuthenticationServices (1차 목표에서 제외)

1차 목표에서는 Apple 로그인 불필요. MusicKit 권한 요청으로 대체.
(추후 2차 목표에서 추가 예정)

---

## 디자인 시스템

이 프로젝트는 커스텀 디자인 시스템 SPM 패키지를 사용하지 않는다.
SwiftUI 기본 시스템 컬러와 HIG를 준수하여 디자인한다.

- **색상**: `.primary`, `.secondary`, `.accentColor`, `Color(.systemBackground)` 등 semantic color 사용
- **폰트**: `.font(.headline)`, `.font(.caption)` 등 Dynamic Type 지원
- **다크모드**: 자동 대응 (semantic color 사용하면 자동)

---

## 아키텍처 요구사항

### 현재 고정 요구사항

- MVVM: View → ViewModel → Service 단방향 의존
- 모든 ViewModel: `@MainActor` + `@Observable`
- 모든 Service: `actor`
- 모든 Model: `struct` + `Sendable`

### 사용자 추가 요구사항 (1차 목표)

#### 1. MusicKit 권한 요청

- 앱 시작 시 MusicKit 권한을 요청한다 (`MusicAuthorization.request()`).
- 권한 미승인 시 "Apple Music 접근 권한이 필요합니다" 안내와 함께 설정으로 이동 유도.
- 권한 승인 후 자동으로 메인 화면(Top 100 리스트)으로 진입.

#### 2. Top 100 차트 리스트 (메인 화면)

- `MusicCatalogChartsRequest`로 Apple Music Top Songs 차트 100곡 조회.
- 리스트로 표시: 순위, 앨범 아트, 곡명, 아티스트명.
- 로딩 중 `ProgressView` 표시, 에러 시 재시도 버튼 표시.
- 리스트에서 곡 탭 → 노래 상세 페이지로 이동 (`NavigationStack` push).

#### 3. 노래 상세 페이지

- 상단에 앨범 아트 크게 표시.
- 곡명, 아티스트명, 앨범명.
- 재생 버튼 — 탭하면 `ApplicationMusicPlayer`로 해당 곡 재생 시작.
- 재생 중이면 버튼이 일시정지 버튼으로 전환.

#### 4. 미니 플레이어 (글로벌 하단 고정)

- 재생 중인 곡이 있으면 **모든 화면 하단에** 미니 플레이어 표시 (`safeAreaInset`).
- 표시 내용: 앨범 아트(소), 곡명, 아티스트명, 재생/일시정지 버튼, 프로그레스바.
- 탭 시 풀 플레이어 화면이 `fullScreenCover`로 표시됨.

#### 5. 풀 플레이어 (가사 + 슬라이더)

- 상단: 앨범 아트, 곡명, 아티스트명.
- **슬라이더**: 현재 재생 위치 표시 + 드래그로 `seek` 가능. 현재 시간 / 전체 시간 표시.
- 재생/일시정지 버튼.
- **가사 표시**: `lrclib.net` API로 fetch한 가사. `ScrollView` + `ScrollViewReader` 자동 스크롤.
- **가사 하이라이트**: 현재 재생 줄은 `.primary` (밝음/흰색), 나머지는 `.secondary` (흐림).
- `syncedLyrics` 없으면 `plainLyrics` 정적 표시, `instrumental`이면 안내 문구 표시.
- 닫기 버튼으로 dismiss.

---

## 이 파일 수정 방법

기능을 추가하거나 구조를 바꾸고 싶으면:
1. `## 사용자 추가 요구사항` 섹션에 항목을 추가한다
2. 하네스를 실행한다 (`claude` 명령어)
3. 한 줄 프롬프트를 입력한다

**한 줄 프롬프트**: 만들고 싶은 앱/기능을 간단히 설명
**PROJECT_CONTEXT.md**: 항상 적용되어야 하는 구조적 요구사항, 기술 스택, 제약
