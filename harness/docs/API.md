# LyricSync API 명세

## Base URL

```
https://REDACTED_SUPABASE_HOST/rest/v1
```

## 인증 (공통 헤더)

모든 요청에 아래 헤더 필요:

```
apikey: {SUPABASE_ANON_KEY}
Authorization: Bearer {SUPABASE_ANON_KEY}
```

---

## 1. 곡 + 가사 조회

Apple Music ID로 곡 정보 + 원본/번역 가사를 한 번에 조회.

### Request

```
GET /songs?apple_music_id=eq.{APPLE_MUSIC_ID}&select=id,title,artist,lyrics(type,lang,content,format)
```

### 예시

```bash
curl "https://REDACTED_SUPABASE_HOST/rest/v1/songs?apple_music_id=eq.1440661545&select=id,title,artist,lyrics(type,lang,content,format)" \
  -H "apikey: {ANON_KEY}" \
  -H "Authorization: Bearer {ANON_KEY}"
```

### Response — 번역 있음

```json
[
  {
    "id": 6,
    "title": "Baby (feat. Ludacris)",
    "artist": "Justin Bieber",
    "lyrics": [
      {
        "type": "original",
        "lang": "en",
        "format": "synced",
        "content": "[00:14.34] You know you love me, I know you care\n[00:17.96] Just shout whenever, and I'll be there\n..."
      },
      {
        "type": "translated",
        "lang": "ko",
        "format": "synced",
        "content": "[00:14.34] 날 사랑하는 거 알잖아, 신경 쓰는 거 알아\n[00:17.96] 불러주기만 해, 바로 갈게\n..."
      }
    ]
  }
]
```

### Response — 곡은 있지만 번역 없음

```json
[
  {
    "id": 1,
    "title": "APT.",
    "artist": "ROSÉ",
    "lyrics": []
  }
]
```

### Response — DB에 곡 없음

```json
[]
```

---

## 2. 전체 곡 목록 조회

```
GET /songs?select=id,apple_music_id,title,artist,source_storefront,source_lang,lyrics_status
```

### 페이지네이션

```
GET /songs?select=...&limit=20&offset=0&order=id.asc
```

---

## 3. 번역된 곡만 조회

```
GET /songs?lyrics_status=eq.found&source_lang=neq.ko&select=id,apple_music_id,title,artist,lyrics(type,lang,format)
```

---

## 4. 번역 여부 배치 조회 (iOS 앱 → 곡 리스트 배지용)

여러 곡의 번역 여부를 한 번에 확인. 차트/검색 결과에서 배지 표시용.

```
GET /songs?apple_music_id=in.("1440661545","1709456823","1698234511")&select=apple_music_id,lyrics(type,lang)
```

### Response

```json
[
  {
    "apple_music_id": "1440661545",
    "lyrics": [
      {"type": "original", "lang": "en"},
      {"type": "translated", "lang": "ko"}
    ]
  },
  {
    "apple_music_id": "1709456823",
    "lyrics": []
  }
]
```

- `lyrics`에 `type=translated`가 있으면 → 번역 배지 표시
- `lyrics`가 빈 배열이거나 곡이 응답에 없으면 → 배지 없음
- content는 포함하지 않음 (가볍게 type/lang만 조회)

---

## 5. 특정 storefront 곡만 조회

```
# US Pop만
GET /songs?source_storefront=eq.us&select=id,apple_music_id,title,artist

# JP J-Pop만
GET /songs?source_storefront=eq.jp&select=id,apple_music_id,title,artist
```

---

## 데이터 모델

### songs

| 필드 | 타입 | 설명 |
|---|---|---|
| id | integer | 내부 ID |
| apple_music_id | string | Apple Music 곡 ID |
| title | string | 곡 제목 |
| artist | string | 아티스트명 |
| duration_ms | integer | 곡 길이 (밀리초) |
| source_storefront | string | `us` 또는 `jp` |
| source_lang | string | `en`, `ja`, `ko` |
| lyrics_status | string | `pending`, `found`, `not_found` |

### lyrics

| 필드 | 타입 | 설명 |
|---|---|---|
| type | string | `original` 또는 `translated` |
| lang | string | 언어 코드: `en`, `ja`, `ko` |
| format | string | `synced` (LRC 타임스탬프) 또는 `plain` |
| content | string | 가사 본문 (LRC 형식) |

---

## LRC 형식 설명

`format: "synced"`인 경우, content는 LRC 타임스탬프 포함:

```
[00:14.34] 날 사랑하는 거 알잖아, 신경 쓰는 거 알아
[00:17.96] 불러주기만 해, 바로 갈게
[00:21.89] 넌 내 사랑이야, 넌 내 심장이야
```

`format: "plain"`인 경우, 타임스탬프 없이 텍스트만:

```
날 사랑하는 거 알잖아, 신경 쓰는 거 알아
불러주기만 해, 바로 갈게
넌 내 사랑이야, 넌 내 심장이야
```

---

## iOS 앱 호출 흐름

```
1. 유저가 곡 선택
2. apple_music_id로 조회 (API 1번)
3. 응답 분기:
   ├─ lyrics에 type="translated" 있음 → LRC 파싱 → 번역 가사 표시
   ├─ lyrics가 빈 배열             → lrclib.net fallback → 원본 가사 표시
   └─ 곡 자체가 없음 ([] 응답)     → lrclib.net fallback → 원본 가사 표시
4. 네트워크 에러 시                → lrclib.net fallback → 원본 가사 표시
```

---

## 현재 데이터 현황

- 총 200곡 (US Pop 100 + JP J-Pop 100)
- 원본 가사 수집: 183곡
- 한국어 번역 완료: 10곡
