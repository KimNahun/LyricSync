# 유저 번역 기능 구현 명세

## Overview

유저가 가사를 직접 한 줄씩 번역하고, 저장하고, 나중에 다시 볼 수 있는 기능.
기존 AI 번역(lyrics 테이블)과 별개로, 유저 개인 번역(user_translations 테이블)에 저장.

---

## 1. 핵심 플로우

```
[가사 화면 — 곡 재생 중]
    │
    ├─ 가사 줄을 탭 (또는 길게 누름)
    │
    ▼
[번역 입력 모드]
    │
    ├─ 원본 가사 줄이 상단에 표시
    ├─ 아래에 텍스트 입력 필드
    ├─ 유저가 번역 입력 → "저장" 탭
    │
    ▼
[Supabase에 저장]
    │
    ├─ user_translations 테이블에 INSERT/UPDATE
    │
    ▼
[가사 화면으로 복귀]
    │
    ├─ 해당 줄에 유저 번역이 표시됨
    ├─ AI 번역과 유저 번역이 구분되어 보임
```

---

## 2. DB (이미 생성됨)

### user_translations 테이블

```sql
CREATE TABLE user_translations (
    id              BIGSERIAL PRIMARY KEY,
    user_id         BIGINT REFERENCES users(id) ON DELETE CASCADE,
    apple_music_id  TEXT NOT NULL,
    title           TEXT NOT NULL,
    artist          TEXT NOT NULL,
    lines           JSONB NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_trans_lookup ON user_translations(user_id, apple_music_id);
```

### lines JSONB 형식

```json
[
    {
        "index": 0,
        "original": "You know you love me, I know you care",
        "translated": "날 사랑하는 거 알잖아, 신경 쓰는 거 알아",
        "timestamp": 14.34
    },
    {
        "index": 3,
        "original": "And we will never, ever, ever be apart",
        "translated": "우리는 절대 헤어지지 않을 거야",
        "timestamp": 25.45
    }
]
```

- 모든 줄이 아니라 **유저가 번역한 줄만** 저장 (sparse)
- `index`: 원본 가사의 줄 번호 (0-based)
- `timestamp`: 해당 줄의 LRC 타임스탬프 (초)

---

## 3. Supabase API

### 3-1. 유저 번역 저장 (upsert)

```
POST /user_translations
Headers:
    apikey: {ANON_KEY}
    Authorization: Bearer {ANON_KEY}
    Content-Type: application/json
    Prefer: resolution=merge-duplicates
Body:
{
    "user_id": 1,
    "apple_music_id": "1440661545",
    "title": "Baby",
    "artist": "Justin Bieber",
    "lines": [
        {"index": 0, "original": "...", "translated": "...", "timestamp": 14.34},
        {"index": 3, "original": "...", "translated": "...", "timestamp": 25.45}
    ]
}
```

- 같은 user_id + apple_music_id 조합이 이미 있으면 lines를 덮어씀
- → `UNIQUE(user_id, apple_music_id)` 제약조건 추가 필요:

```sql
ALTER TABLE user_translations ADD CONSTRAINT uq_user_trans UNIQUE (user_id, apple_music_id);
```

### 3-2. 유저 번역 조회

```
GET /user_translations?user_id=eq.{USER_ID}&apple_music_id=eq.{APPLE_MUSIC_ID}&select=lines
```

**응답:**
```json
[
    {
        "lines": [
            {"index": 0, "original": "...", "translated": "...", "timestamp": 14.34},
            {"index": 3, "original": "...", "translated": "...", "timestamp": 25.45}
        ]
    }
]
```

빈 배열이면 해당 곡에 대한 유저 번역 없음.

### 3-3. 유저가 번역한 곡 목록 조회

```
GET /user_translations?user_id=eq.{USER_ID}&select=apple_music_id,title,artist,created_at&order=created_at.desc
```

---

## 4. iOS 구현

### 4-1. 파일 구조

```
신규:
├── Services/UserTranslationService.swift   — Supabase 유저 번역 CRUD
├── ViewModels/Translation/TranslationViewModel.swift — 번역 입력 상태 관리
├── Views/Translation/TranslationInputView.swift — 줄별 번역 입력 UI
├── Views/Translation/MyTranslationsView.swift   — 내가 번역한 곡 목록

수정:
├── Views/Detail/SongDetailView.swift       — 가사 줄 탭 시 번역 입력 진입
├── Views/Settings/SettingsView.swift       — "내 번역" 메뉴 추가
```

### 4-2. UserTranslationService

```swift
actor UserTranslationService {
    /// 특정 곡의 유저 번역을 조회한다.
    func fetch(userId: Int, appleMusicID: String) async -> [UserTranslationLine]?

    /// 유저 번역을 저장한다 (upsert).
    func save(userId: Int, appleMusicID: String, title: String, artist: String, lines: [UserTranslationLine]) async

    /// 유저가 번역한 곡 목록을 조회한다.
    func fetchMyTranslations(userId: Int) async -> [MyTranslationSummary]
}
```

### 4-3. 번역 입력 UI 흐름

```
가사 화면에서 줄 길게 누름 (Long Press)
    │
    ▼
Sheet로 TranslationInputView 표시
    │
    ├─ 상단: 원본 가사 줄 (읽기 전용)
    ├─ 중앙: 텍스트 입력 필드 (번역 입력)
    ├─ 하단: [취소] [저장] 버튼
    │
    ├─ 이미 번역한 줄이면 기존 번역이 미리 채워짐
    │
    ▼
저장 탭 → Supabase에 저장 → Sheet 닫기 → 가사 화면에 반영
```

### 4-4. 가사 표시 우선순위

번역이 여러 소스에서 올 수 있음. 우선순위:

```
1순위: 유저 번역 (user_translations) — 유저가 직접 쓴 것
2순위: AI 번역 (lyrics 테이블 type=translated) — GPT-4o-mini 번역
3순위: 없음 — 원본 가사만 표시
```

같은 줄에 유저 번역과 AI 번역이 모두 있으면 **유저 번역을 우선** 표시.
유저가 번역하지 않은 줄은 AI 번역으로 fallback.

### 4-5. 가사 화면 UI 변경

```
[동시 표시 모드일 때]

원본: You know you love me, I know you care
유저: 날 사랑하는 거 알잖아, 신경 쓰는 거 알아 ✏️  ← 유저 번역 (편집 가능 표시)

원본: Just shout whenever, and I'll be there
AI:   불러주기만 해, 바로 갈게                     ← AI 번역 (편집 없음)

원본: You are my love, you are my heart
      [번역 추가]                                  ← 유저/AI 번역 둘 다 없는 줄
```

- 유저 번역이 있는 줄: ✏️ 아이콘 + 다른 색상 (AI 번역과 구분)
- AI 번역이 있는 줄: 기존과 동일
- 번역 없는 줄: "번역 추가" 버튼 → 탭하면 입력 Sheet

### 4-6. 내가 번역한 곡 목록 (MyTranslationsView)

설정 화면에서 접근. 유저가 번역한 곡들을 최신순으로 표시.

```
┌─────────────────────────────────┐
│ 내 번역                     편집 │
├─────────────────────────────────┤
│ 🎵 Baby - Justin Bieber        │
│    3줄 번역 · 2026.04.21       │
├─────────────────────────────────┤
│ 🎵 APT. - ROSÉ                 │
│    12줄 번역 · 2026.04.20      │
└─────────────────────────────────┘
```

탭하면 해당 곡 가사 화면으로 이동 (유저 번역 포함).

---

## 5. user_id 매핑

현재 Apple 로그인으로 `apple_user_id` (문자열)를 가지고 있지만,
`user_translations.user_id`는 `users.id` (BIGINT)를 참조함.

→ 앱에서 로그인 후 Supabase에서 `users` 테이블의 `id`를 가져와서 메모리에 보관:

```
GET /users?apple_user_id=eq.{APPLE_USER_ID}&select=id
→ [{"id": 1}]
```

이 `id`를 앱 세션 동안 보관하고, user_translations 요청에 사용.

---

## 6. 오프라인 대응

유저가 번역을 입력하는 시점에 네트워크가 없을 수 있음.

```
저장 시:
1. 로컬에 즉시 반영 (메모리)
2. Supabase에 비동기 저장 시도
3. 실패 시 → 로컬에만 유지, 다음에 앱 열 때 재시도 (UserDefaults에 pending 저장)
```

MVP에서는 오프라인 대응 생략 가능. 네트워크 실패 시 "저장에 실패했습니다" 토스트만 표시.

---

## 7. 구현 순서

```
Phase 1 (필수):
1. Supabase에 UNIQUE 제약조건 추가
2. UserTranslationService 구현 (조회/저장)
3. TranslationInputView 구현 (줄별 번역 입력 Sheet)
4. SongDetailView 수정 (Long Press → 입력 Sheet, 유저 번역 표시)

Phase 2 (후속):
5. MyTranslationsView 구현 (내 번역 목록)
6. SettingsView에 "내 번역" 메뉴 추가
7. 유저 번역 + AI 번역 혼합 표시 로직
8. 번역 삭제/편집 기능
```

---

## 8. 주의사항

- `lines` JSONB는 유저가 번역한 줄만 sparse하게 저장 → 전체 가사 줄 수와 무관
- 같은 곡을 재번역하면 기존 lines를 덮어씀 (upsert)
- user_id가 없으면 (비로그인) 번역 기능 비활성화
- 가사가 없는 곡 (notFound/instrumental)에서는 번역 입력 불가
