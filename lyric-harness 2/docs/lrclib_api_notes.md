# lrclib.net API 가이드

## 개요

lrclib.net은 무료 싱크 가사(LRC) 데이터베이스.
인증 불필요. Rate limit 주의.

---

## 엔드포인트

### 가사 조회 (GET)

```
GET https://lrclib.net/api/get?artist_name={artist}&track_name={track}
```

**쿼리 파라미터:**
- `artist_name` (필수): 아티스트명
- `track_name` (필수): 곡명
- `album_name` (선택): 앨범명 — 동명곡 구분 시 사용
- `duration` (선택): 곡 길이(초) — 정확도 향상

**예시:**
```
https://lrclib.net/api/get?artist_name=justin%20bieber&track_name=baby
```

---

## 응답 구조

```json
{
    "id": 1151679,
    "name": "Baby",
    "trackName": "Baby",
    "artistName": "Justin Bieber",
    "albumName": "My World 2.0",
    "duration": 219.0,
    "instrumental": false,
    "plainLyrics": "Oh whoa, oh whoa, oh whoa\nYou know you love me...",
    "syncedLyrics": "[00:01.11] Oh whoa, oh whoa, oh whoa\n[00:15.07] You know you love me, I know you care\n..."
}
```

**필드 설명:**
- `id`: 가사 고유 ID
- `trackName`: 곡명
- `artistName`: 아티스트명
- `albumName`: 앨범명
- `duration`: 곡 길이 (초, Float)
- `instrumental`: true이면 인스트루멘탈 (가사 없음)
- `plainLyrics`: 타임스탬프 없는 일반 가사 (줄바꿈으로 구분)
- `syncedLyrics`: LRC 형식 싱크 가사 (nullable — 없을 수 있음)

---

## LRC 형식

```
[MM:SS.ss] 가사 텍스트
```

**예시:**
```
[00:01.11] Oh whoa, oh whoa, oh whoa
[00:09.13]
[00:15.07] You know you love me, I know you care
[00:18.22] Just shout whenever and I'll be there
```

**파싱 규칙:**
1. 각 줄을 `\n`으로 분리
2. 정규식 `\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)` 로 매칭
3. MM * 60 + SS.ss = 초 단위 타임스탬프
4. 빈 가사 줄(`[00:09.13] `)도 유효 — 인터루드/간주 구간

**Swift 파싱 예시:**
```swift
struct LyricLine: Identifiable, Sendable {
    let id = UUID()
    let timestamp: TimeInterval  // 초 단위
    let text: String
}

func parseLRC(_ lrc: String) -> [LyricLine] {
    let pattern = /\[(\d{2}):(\d{2}\.\d{2})\]\s?(.*)/
    return lrc.components(separatedBy: "\n").compactMap { line in
        guard let match = line.firstMatch(of: pattern) else { return nil }
        let minutes = Double(match.1) ?? 0
        let seconds = Double(match.2) ?? 0
        let timestamp = minutes * 60 + seconds
        let text = String(match.3)
        return LyricLine(timestamp: timestamp, text: text)
    }
}
```

---

## 에러 처리

**404 Not Found:**
가사가 데이터베이스에 없음. → plainLyrics가 없을 수 있음.

**429 Too Many Requests:**
Rate limit 초과. → 재시도 로직 또는 사용자 안내.

**폴백 전략:**
1. `syncedLyrics`가 있으면 → LRC 파싱, 탭-투-시크 활성화
2. `syncedLyrics`가 null이고 `plainLyrics`가 있으면 → 정적 가사 표시, 탭-투-시크 비활성
3. `instrumental == true` → "이 곡은 인스트루멘탈입니다" 표시
4. 404 → "가사를 찾을 수 없습니다" 표시

---

## 요청 헤더

특별한 헤더 불필요. 단, User-Agent를 설정하면 rate limit 완화 가능:

```
User-Agent: LyricSync v1.0 (https://github.com/yourapp)
```

---

## 주의사항

- URL 인코딩 필수 (아티스트명/곡명에 공백, 특수문자 가능)
- `URLComponents`를 사용하면 자동 인코딩됨
- 곡명이 정확하지 않으면 결과 없을 수 있음 — MusicKit에서 받은 정확한 title/artist 사용
- duration을 함께 보내면 정확도 향상 (동명곡 구분)
