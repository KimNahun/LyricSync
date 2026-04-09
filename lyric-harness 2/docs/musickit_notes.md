# MusicKit 사용 가이드

## 개요

MusicKit은 Apple Music 카탈로그 접근, 음악 검색, 재생을 위한 프레임워크.
Apple Music 구독자만 전체 재생 가능.

---

## 권한 요청

```swift
import MusicKit

let status = await MusicAuthorization.request()
switch status {
case .authorized:
    // Apple Music 접근 가능
case .denied, .restricted, .notDetermined:
    // 접근 불가 — 안내 필요
@unknown default:
    break
}
```

**Info.plist 필수:**
```xml
<key>NSAppleMusicUsageDescription</key>
<string>음악 검색 및 재생을 위해 Apple Music 접근이 필요합니다.</string>
```

---

## Top 차트 조회 (1차 목표 핵심)

```swift
// iOS 16+ 필수
var request = MusicCatalogChartsRequest(genre: nil, kinds: [.mostPlayed], types: [Song.self])
request.limit = 100
let response = try await request.response()
let topSongs: MusicItemCollection<Song> = response.songCharts.first?.items ?? []
```

**주요 포인트:**
- `kinds`: `.mostPlayed`, `.cityTop`, `.dailyGlobalTop` 등 — `.mostPlayed`가 일반적인 Top 100
- `genre`: nil이면 전체 장르
- `limit`: 최대 100 (API 제한 확인 필요)
- iOS 16 미만 기기에서는 사용 불가 — 최소 타겟 iOS 17이므로 문제 없음
- 지역(storefront)은 사용자의 Apple Music 계정 기준 자동 설정

---

## 음악 검색 (참고용 — 1차 목표에서는 미사용)

```swift
var request = MusicCatalogSearchRequest(term: "justin bieber baby", types: [Song.self])
request.limit = 25
let response = try await request.response()
let songs = response.songs  // MusicItemCollection<Song>
```

**Song 주요 프로퍼티:**
- `id`: MusicItemID
- `title`: String
- `artistName`: String
- `albumTitle`: String?
- `artwork`: Artwork? — `artwork?.url(width:height:)` 로 이미지 URL 획득
- `duration`: TimeInterval?

---

## 음악 재생

```swift
let player = ApplicationMusicPlayer.shared

// 큐에 곡 설정 및 재생
player.queue = [song]  // MusicPlayer.Queue.Entry 자동 변환
try await player.play()

// 일시정지
player.pause()

// 시크 (특정 시간으로 이동)
player.playbackTime = 45.0  // 45초 지점으로 이동
```

---

## 재생 상태 감시

```swift
let player = ApplicationMusicPlayer.shared

// 재생 상태
player.state.playbackStatus  // .playing, .paused, .stopped, etc.

// 현재 재생 시간
player.playbackTime  // TimeInterval (초)

// 현재 재생 중인 곡
player.queue.currentEntry?.title
player.queue.currentEntry?.subtitle
```

**ViewModel에서 Timer로 주기적 감시:**
```swift
// 0.1초~0.5초 간격 Timer로 playbackTime 폴링
// 가사 싱크에는 0.1초 권장
```

---

## 주의사항

- `ApplicationMusicPlayer.shared`는 싱글톤 — Service에서 래핑하여 사용
- Apple Music 구독이 없으면 미리듣기(30초)만 재생 가능
- 시뮬레이터에서는 MusicKit 재생 불가 — 실기기 테스트 필수
- `MusicCatalogSearchRequest`는 네트워크 호출 — async/await 필수
