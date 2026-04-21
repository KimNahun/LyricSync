# 탐색 보고서: MusicPlayerService 빌드 에러 분석

## 빌드 에러 요약

**파일**: `/Users/haesuyoun/Desktop/NahunPersonalFolder/MusicStudy/LyricSync/Sources/Services/MusicPlayerService.swift`

**에러 상황**:
- Line 39: `sending value of non-Sendable type 'ApplicationMusicPlayer' risks causing data races`
- Line 55: `sending value of non-Sendable type 'ApplicationMusicPlayer' risks causing data races`

---

## 핵심 문제 분석

### 문제의 근본 원인

```swift
// Line 21-22: actor 내에 non-Sendable 타입 저장
actor MusicPlayerService {
    private let player = ApplicationMusicPlayer.shared
    // ^ ApplicationMusicPlayer는 Sendable을 준수하지 않음
```

### 에러 발생 지점

#### 에러 1: Line 39 (play 메서드)
```swift
func play(song: Song) async throws {
    // ...
    player.queue = [musicKitSong]
    try await player.play()  // ← 에러: actor 경계에서 non-Sendable 값 전송
}
```

**이유**: `player.play()`는 async 함수이며, actor 경계를 넘어 호출된다. `player`(ApplicationMusicPlayer)가 Sendable이 아니므로 Swift 6 동시성 체커가 데이터 레이스 위험을 감지.

#### 에러 2: Line 55 (resume 메서드)
```swift
func resume() async throws {
    do {
        try await player.play()  // ← 에러: actor 경계에서 non-Sendable 값 전송
    } catch {
        throw MusicPlayerError.playbackFailed(error)
    }
}
```

**이유**: 동일하게 `player.play()`를 호출할 때 actor 경계에서 non-Sendable 타입이 async 경계를 넘음.

---

## 파일 구조 및 관련 파일

### 주요 파일
- **MusicPlayerService.swift** (Line 1-75): MusicKit의 ApplicationMusicPlayer를 래핑하는 actor
  - Line 22: `private let player = ApplicationMusicPlayer.shared` (문제 지점)
  - Line 39: `try await player.play()` (에러 1)
  - Line 55: `try await player.play()` (에러 2)

### MusicPlayerService 구조
```
MusicPlayerService (actor)
├── 프로퍼티
│   └── private let player: ApplicationMusicPlayer ← non-Sendable
├── 메서드
│   ├── play(song:) - Line 25-45 ← 에러 발생
│   ├── pause() - Line 48-50
│   ├── resume() - Line 53-59 ← 에러 발생
│   ├── seek(to:) - Line 62-64
│   ├── playbackTime (계산 프로퍼티) - Line 67-69
│   └── playbackStatus (계산 프로퍼티) - Line 72-74
```

---

## 핵심 코드 위치 상세

| 라인 범위 | 설명 | 심각도 |
|----------|------|--------|
| 21 | `actor MusicPlayerService` 선언 | - |
| 22 | `private let player = ApplicationMusicPlayer.shared` | 🔴 근본 원인 |
| 39 | `try await player.play()` in play() | 🔴 에러 1 |
| 55 | `try await player.play()` in resume() | 🔴 에러 2 |

---

## 추가 정보

### ApplicationMusicPlayer와 동시성
- `ApplicationMusicPlayer`는 Apple의 MusicKit 프레임워크 클래스
- Sendable 프로토콜을 준수하지 않음 (UI 상태 관리 때문)
- `shared` 싱글톤 인스턴스는 메인 스레드에서만 안전하게 접근 가능

### 현재 구조의 한계
- actor로 래핑했지만, `ApplicationMusicPlayer` 자체가 non-Sendable이므로 근본적인 해결이 필요
- `player.queue` 할당 (line 38)도 잠재적 데이터 레이스 가능성

---

## 결론

MusicPlayerService 내 두 async 호출 지점에서 non-Sendable 타입인 ApplicationMusicPlayer를 actor 경계 너머로 전달하려고 할 때 Swift 6 동시성 체커가 경고를 발생시킵니다. Line 22의 프로퍼티 저장 방식을 재검토하거나, async 호출 시 격리(isolation) 처리가 필요합니다.
