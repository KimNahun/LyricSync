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

**파일 생성 위치**: `LyricSync/Sources/` 아래에 직접 생성 (output/ 폴더 없음)

---

## 핵심 컨셉

**Apple Music 구독자가 Top 100 차트에서 노래를 골라 재생하면서, 싱크된 가사를 보고 한국어 번역 가사도 함께 볼 수 있는 앱.**

### 사용자 플로우

```
1. 메인 화면 — Apple Music Top 100 차트 리스트 표시
2. 리스트에서 노래 선택 → 노래 상세 페이지로 이동
3. 재생 버튼 탭 → MusicKit으로 재생 시작
4. 재생 중에는 어떤 화면에서도 맨 아래에 미니 플레이어 표시
5. 미니 플레이어 탭 → 풀 플레이어 화면 (fullScreenCover)
   - 슬라이더로 재생 위치 이동 가능
   - 가사 표시: 번역 가사(Supabase) 우선, 없으면 원본(lrclib.net)
   - 현재 재생 중인 가사 줄 하이라이트
```

---

## 사용 프레임워크 및 API

### 1. MusicKit (필수)

Apple Music 구독 기반 Top 차트 조회 및 재생.

```swift
import MusicKit
```

- **인증**: `MusicAuthorization.request()` → `.authorized` 필수
- **Top 차트**: `MusicCatalogChartsRequest` — Top Songs 100개
- **재생**: `ApplicationMusicPlayer.shared` — play, pause, seek
- **재생 상태 감시**: `ApplicationMusicPlayer.shared.state`, `.queue.currentEntry`
- **Info.plist**: `NSAppleMusicUsageDescription` 추가 필수

### 2. lrclib.net API (fallback)

싱크 가사 조회. 무료, 인증 불필요. Supabase에 번역이 없을 때 fallback으로 사용.

```
GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}&duration={duration}
```

- `syncedLyrics`: LRC 포맷 (`[MM:SS.ss] 가사 줄`)
- `plainLyrics`: 타임스탬프 없는 일반 가사 (fallback)
- `instrumental`: true이면 가사 없는 인스트루멘탈

### 3. Supabase REST API (번역 가사 — 우선)

한국어 번역 가사 조회. 상세 명세: `docs/API.md`, `docs/BACKEND_SPEC.md`

```
GET /songs?apple_music_id=eq.{ID}&select=id,title,artist,lyrics(type,lang,content,format)
```

**공통 헤더:**
```
apikey: {SUPABASE_ANON_KEY}
Authorization: Bearer {SUPABASE_ANON_KEY}
```

**가사 조회 우선순위:**
1. Supabase에서 `type=translated` → 번역 LRC 표시
2. Supabase 없거나 에러 → lrclib.net fallback → 원본 가사 표시
3. lrclib.net도 실패 → "가사를 불러올 수 없습니다" 에러 표시

---

## 디자인 시스템

커스텀 디자인 시스템 SPM 패키지 없음. SwiftUI 기본 시스템 사용.

- **색상**: `.primary`, `.secondary`, `.accentColor`, `Color(.systemBackground)` 등 semantic color
- **폰트**: Dynamic Type 지원 (`.headline`, `.caption` 등)
- **다크모드**: 자동 대응 (semantic color 사용)

---

## 아키텍처 요구사항

### 현재 고정 요구사항

- MVVM: View → ViewModel → Service 단방향 의존
- 모든 ViewModel: `@MainActor` + `@Observable`
- 모든 Service: `actor`
- 모든 Model: `struct` + `Sendable`

### 사용자 추가 요구사항

#### 1. MusicKit 권한 요청

- 앱 시작 시 MusicKit 권한 요청 (`MusicAuthorization.request()`).
- 권한 미승인 시 안내 + 설정 유도.
- 권한 승인 후 메인 화면으로 진입.

#### 2. Top 100 차트 리스트 (메인 화면)

- `MusicCatalogChartsRequest`로 Top Songs 100곡 조회.
- 리스트: 순위, 앨범 아트, 곡명, 아티스트명.
- 로딩 `ProgressView`, 에러 재시도 버튼.
- 곡 탭 → `NavigationStack` push.

#### 3. 노래 상세 페이지

- 앨범 아트, 곡명, 아티스트명, 앨범명.
- 재생/일시정지 버튼.

#### 4. 미니 플레이어 (글로벌 하단 고정)

- 재생 중 모든 화면 하단 표시 (`safeAreaInset`).
- 앨범 아트(소), 곡명, 재생/일시정지, 프로그레스바.
- 탭 → 풀 플레이어 `fullScreenCover`.

#### 5. 풀 플레이어 (가사 + 슬라이더)

- 슬라이더: 재생 위치 + 드래그 seek.
- 가사: `ScrollView` + `ScrollViewReader` 자동 스크롤.
- 하이라이트: 현재 줄 `.primary`, 나머지 `.secondary`.
- `syncedLyrics` 없으면 `plainLyrics`, `instrumental`이면 안내 문구.
- **번역 표시 모드** (번역 가사가 있는 곡에서만 활성화):
  - 풀 플레이어 상단에 모드 토글 버튼 (2가지 모드).
  - **동시 표시 모드** (기본값): 원본 가사 아래에 번역 가사가 항상 같이 보임.
    ```
    [00:15.30] I walk a lonely road        ← 원본 (밝게)
               나는 외로운 길을 걸어         ← 번역 (약간 흐리게, 작은 폰트)
    ```
  - **가림 모드**: 원본 가사만 보이고, 번역은 숨겨져 있음.
    - 각 가사 줄 옆에 눈 아이콘(👁) 버튼이 표시됨.
    - 해당 버튼을 탭하면 **그 줄의 번역만** 토글로 보임/숨김.
    - 다른 줄의 가사는 영향 없음 (줄 단위 독립 토글).
    - 유저가 스스로 해석해보고, 모르는 줄만 눌러서 확인하는 학습 용도.
  - **모드 상태**: `PlayerViewModel`에서 관리. 앱 종료 시 마지막 선택 모드 유지 (UserDefaults).
  - **번역 없는 곡**: 모드 토글 버튼 자체가 숨겨짐. 원본 가사만 표시.
  - **가림 모드 — 눈 버튼 탭과 자동 스크롤 분리**: 눈 버튼 탭은 자동 스크롤을 중지시키지 않음. 버튼 탭과 스크롤 드래그 제스처를 분리 처리할 것. (예: 버튼은 `Button` 액션, 스크롤 중지는 `DragGesture`에서만)
  - **가림 모드 — 줄 토글 상태 리셋**: 곡이 바뀌면 전부 리셋. 같은 곡 재재생 / 풀 플레이어 닫았다 열기 → 리셋 (매번 새로 시작).

#### 6. 번역 가사 연동 (Supabase)

- `TranslatedLyricService` (actor): Supabase REST API 조회.
- Apple Music ID로 조회 → `type=translated` 가사 추출.
- **에러 처리**: Supabase 실패 → lrclib.net fallback. 앱이 깨지지 않아야 함.
- **표시**: Supabase 응답에서 original + translated 둘 다 가져옴 (한 번의 API). 번역 가사가 있으면 풀 플레이어에서 모드 선택 가능.
- **키 관리**: anon key는 앱 포함 가능 (RLS 읽기 전용). service_role key 절대 포함 금지.

#### 7. 곡 검색 기능

- `MusicCatalogSearchRequest`로 Apple Music 카탈로그 검색.
- **검색 UI**: 메인 화면(차트 리스트) 상단에 검색바 (`.searchable` modifier).
- **Debounce**: 유저가 타이핑을 멈추고 300ms 후 검색 실행. 타이핑 중에는 API 호출하지 않음.
- **미리보기**: 검색 결과 상위 5개를 드롭다운/오버레이로 표시 (앨범 아트, 곡명, 아티스트명 + 번역 여부 배지).
- **탭 시 동작**: 검색 결과 곡을 탭하면 해당 곡의 노래 상세 페이지로 `NavigationStack` push.
- **검색 취소**: 빈 텍스트이거나 Cancel 탭 시 미리보기 닫고 차트 리스트로 복귀.

#### 8. 번역 여부 배지 (모든 곡 리스트 공통)

- **차트 리스트, 검색 결과** 등 곡이 표시되는 모든 곳에서 번역 여부를 표시.
- **구현 방식**:
  - 화면에 표시되는 곡들의 `apple_music_id` 목록을 Supabase에 배치 조회.
    ```
    GET /songs?apple_music_id=in.("id1","id2","id3")&select=apple_music_id,lyrics(type,lang)
    ```
  - `type=translated` 레코드가 있는 곡 → 번역 배지 표시 (예: "한" 또는 "번역" 뱃지).
  - 없는 곡 → 배지 없음.
- **타이밍**: 차트 로드 완료 후 / 검색 결과 받은 후, 비동기로 번역 여부 조회. 곡 리스트는 먼저 표시하고 배지는 뒤늦게 나타나도 OK (로딩 차단하지 않음).
- **캐시**: 한 세션 내에서 이미 조회한 `apple_music_id`는 재조회하지 않음 (인메모리 딕셔너리).
- **배치 크기**: 100개를 한 번에 조회 (`in.(...)` 쿼리). 청크 분할 불필요.

---

## 이 파일 수정 방법

기능을 추가하거나 구조를 바꾸고 싶으면:
1. `## 사용자 추가 요구사항` 섹션에 항목을 추가한다
2. 하네스를 실행한다
3. 한 줄 프롬프트를 입력한다
