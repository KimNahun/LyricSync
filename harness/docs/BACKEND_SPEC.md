# LyricSync Backend Spec

## Overview

Apple Music 팝송/J-Pop 곡의 가사를 한국어로 번역하여 저장하고, iOS 앱에서 조회하는 시스템.

```
iOS 앱 ──REST──▶ Supabase (DB + Auto REST API)
                        ▲
                 로컬 Python 스크립트 (번역 파이프라인)
```

---

## 1. Database (Supabase PostgreSQL)

### 1-1. songs 테이블

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | BIGSERIAL (PK) | 내부 ID |
| apple_music_id | TEXT (UNIQUE, NOT NULL) | Apple Music 곡 ID |
| title | TEXT (NOT NULL) | 곡 제목 |
| artist | TEXT (NOT NULL) | 아티스트명 |
| duration_ms | INTEGER | 곡 길이 (밀리초) |
| source_storefront | TEXT (NOT NULL) | 수집 출처: `'us'`, `'jp'` |
| source_lang | TEXT | 원본 가사 언어: `'en'`, `'ja'`, `'ko'` (자동 감지) |
| lyrics_status | TEXT (DEFAULT 'pending') | `'found'`, `'not_found'`, `'pending'` |
| created_at | TIMESTAMPTZ | 생성 시각 |

### 1-2. lyrics 테이블

| 컬럼 | 타입 | 설명 |
|---|---|---|
| id | BIGSERIAL (PK) | 내부 ID |
| song_id | BIGINT (FK → songs.id) | 곡 참조 |
| type | TEXT (NOT NULL) | `'original'` 또는 `'translated'` |
| lang | TEXT (NOT NULL) | 언어 코드: `'en'`, `'ko'`, `'ja'` |
| format | TEXT (NOT NULL) | `'synced'` 또는 `'plain'` |
| content | TEXT (NOT NULL) | LRC 형식 가사 본문 |
| translator | TEXT | `'gpt-4o-mini'`, `'gpt-4o'`, `'manual'` |
| version | INTEGER (DEFAULT 1) | 번역 버전 |
| created_at | TIMESTAMPTZ | 생성 시각 |

**UNIQUE 제약조건:** `(song_id, type, lang, format, version)`

### 1-3. DDL

```sql
CREATE TABLE songs (
    id                  BIGSERIAL PRIMARY KEY,
    apple_music_id      TEXT UNIQUE NOT NULL,
    title               TEXT NOT NULL,
    artist              TEXT NOT NULL,
    duration_ms         INTEGER,
    source_storefront   TEXT NOT NULL,
    source_lang         TEXT,
    lyrics_status       TEXT DEFAULT 'pending',
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lyrics (
    id              BIGSERIAL PRIMARY KEY,
    song_id         BIGINT REFERENCES songs(id) ON DELETE CASCADE,
    type            TEXT NOT NULL,
    lang            TEXT NOT NULL,
    format          TEXT NOT NULL,
    content         TEXT NOT NULL,
    translator      TEXT,
    version         INTEGER DEFAULT 1,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(song_id, type, lang, format, version)
);

CREATE INDEX idx_lyrics_lookup ON lyrics(song_id, type, lang);

ALTER TABLE songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE lyrics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "songs_read" ON songs FOR SELECT USING (true);
CREATE POLICY "lyrics_read" ON lyrics FOR SELECT USING (true);
```

---

## 2. 곡 수집 전략 (Apple Music API)

| 대상 | Storefront | Genre ID | 결과 |
|---|---|---|---|
| 팝송 | `us` | 14 (Pop) | 영어 팝 |
| J-Pop | `jp` | 27 (J-Pop) | 일본어 곡 |

한국어 곡 자동 감지 후 스킵:
```python
def detect_lang(lyrics: str) -> str:
    if re.search(r'[가-힣]', lyrics): return 'ko'
    if re.search(r'[\u3040-\u309F\u30A0-\u30FF]', lyrics): return 'ja'
    return 'en'
```

---

## 3. API 명세

### 3-1. 곡 + 가사 조회 (API 1개)

```
GET /songs?apple_music_id=eq.{APPLE_MUSIC_ID}&select=id,title,artist,lyrics(type,lang,content,format)
```

상세: `docs/API.md`

---

## 4. iOS 앱 에러 처리 정책

| 상황 | iOS 앱 동작 |
|---|---|
| Supabase 정상 + 번역 있음 | 번역 LRC 표시 |
| Supabase 정상 + 번역 없음 | lrclib fallback (원본 표시) |
| Supabase 타임아웃/다운 | lrclib fallback (원본 표시) |
| lrclib도 실패 | "가사를 불러올 수 없습니다" 에러 |

---

## 5. 번역 파이프라인 (Python 스크립트)

로컬 맥에서 수동 실행. 3단계 순차:

```bash
python 1_collect_songs.py   # Apple Music 차트 → songs 테이블
python 2_fetch_lyrics.py    # lrclib → lyrics (type=original)
python 3_translate.py       # GPT-4o-mini → lyrics (type=translated)
```

### 번역 줄 수 불일치 처리

```
1차 시도 → 줄 수 일치 → synced LRC 저장
         → 줄 수 불일치 → 2차 시도 (줄 수 명시)
                        → 불일치 → plain fallback 저장
```

---

## 6. 키/시크릿 관리

| 키 | 노출 범위 |
|---|---|
| Supabase anon key | 앱 포함 가능 (RLS 보호) |
| Supabase service_role key | 로컬만, 앱 절대 불가 |
| OpenAI API key | 로컬만 |
| Apple Developer Token | 로컬만 |

---

## 7. Supabase 무료 tier 제한

| 항목 | 제한 |
|---|---|
| 스토리지 | 500MB |
| 비활성 pause | 1주일 비활성 시 자동 pause |
| 프로젝트 수 | 2개 |

---

## 8. 확장 계획

```
Phase 1 (MVP): Supabase 무료 + 로컬 스크립트, 500곡 미만, ~$0.15
Phase 2: Oracle Cloud 무료 VM + FastAPI, 크론 자동화
Phase 3: 만 단위 곡, 다국어, Redis 캐시
```
