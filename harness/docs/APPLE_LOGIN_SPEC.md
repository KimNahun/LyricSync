# Apple 로그인 구현 명세

## Overview

Apple Sign In으로 유저를 식별하고, Supabase에 user_id를 저장하는 최소 인증 시스템.
Supabase Auth는 사용하지 않음. anon key로 요청하면서 user_id 필드만 채우는 방식.

---

## 1. 전체 흐름

```
[앱 첫 실행]
    │
    ├─ Keychain에서 userIdentifier 확인
    │   ├─ 없음 → 로그인 화면 표시
    │   └─ 있음 → credentialState 확인
    │              ├─ .authorized → 메인 화면 진입
    │              ├─ .revoked   → Keychain 삭제 → 로그인 화면
    │              └─ .notFound  → Keychain 삭제 → 로그인 화면
    │
    ▼
[로그인 화면]
    │
    ├─ "Apple로 계속하기" 버튼 탭
    ├─ ASAuthorizationController 실행
    │
    ▼
[Apple 로그인 성공]
    │
    ├─ userIdentifier 받음 (앱별 고유 문자열)
    ├─ email, fullName 받음 (첫 로그인 때만)
    ├─ Keychain에 userIdentifier 저장
    ├─ Supabase에 유저 등록 (upsert)
    │
    ▼
[메인 화면 진입]
    │
    ├─ 이후 모든 유저별 요청에 apple_user_id 포함
    │
    ▼
[계정 삭제 시] (설정 화면)
    │
    ├─ Supabase에서 유저 데이터 삭제
    ├─ Keychain 삭제
    └─ 로그인 화면으로 전환
```

---

## 2. DB 스키마

### users 테이블

```sql
CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,
    apple_user_id   TEXT UNIQUE NOT NULL,
    email           TEXT,
    display_name    TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_login_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_select" ON users FOR SELECT USING (true);
CREATE POLICY "users_insert" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "users_delete" ON users FOR DELETE USING (true);
```

### Supabase API

**유저 등록 (upsert):**
```
POST /users
Headers:
  apikey: {ANON_KEY}
  Authorization: Bearer {ANON_KEY}
  Content-Type: application/json
  Prefer: resolution=merge-duplicates
Body:
{
  "apple_user_id": "001234.abcdef...",
  "email": "user@privaterelay.appleid.com",
  "display_name": "홍길동"
}
```
- `Prefer: resolution=merge-duplicates` → apple_user_id가 이미 있으면 업데이트, 없으면 생성
- email과 display_name은 첫 로그인 때만 전송 (이후에는 Apple이 안 줌)

**유저 삭제:**
```
DELETE /users?apple_user_id=eq.{APPLE_USER_ID}
Headers:
  apikey: {ANON_KEY}
  Authorization: Bearer {ANON_KEY}
```

---

## 3. iOS 구현

### 3-1. 파일 구조

```
신규:
├── Views/Auth/LoginView.swift           — Apple 로그인 버튼 화면
├── Services/AuthService.swift           — Apple 로그인 + credential 확인
├── Services/KeychainService.swift       — userIdentifier Keychain CRUD

수정:
├── App/LyricSyncApp.swift               — 인증 분기 추가
├── Services/TranslatedLyricService.swift — (변경 없음, 나중에 user_id 추가 시)
```

### 3-2. KeychainService

```swift
/// Keychain에 Apple userIdentifier를 저장/조회/삭제하는 유틸리티.
enum KeychainService {
    private static let key = "apple_user_id"

    /// 저장
    static func saveUserId(_ userId: String) { ... }

    /// 조회 (없으면 nil)
    static func getUserId() -> String? { ... }

    /// 삭제
    static func deleteUserId() { ... }
}
```

- `kSecClassGenericPassword` 사용
- `kSecAttrService`는 Bundle ID (`com.nahun.LyricSync`)
- 앱 삭제 시 같이 삭제됨 (iOS 10.3+) → 재설치하면 다시 로그인 필요
- 같은 Apple ID로 로그인하면 동일한 `userIdentifier` 반환 → 기존 유저로 매칭

### 3-3. AuthService

```swift
/// Apple 로그인 및 credential 상태 확인을 담당하는 Service.
actor AuthService {

    /// Apple 로그인 credential 상태를 확인한다.
    /// 매 앱 실행 시 호출하여 유저가 로그인을 취소했는지 확인.
    func checkCredentialState(userId: String) async -> CredentialState {
        // ASAuthorizationAppleIDProvider().credentialState(forUserID:)
        // .authorized → .valid
        // .revoked / .notFound → .invalid
    }

    /// Supabase에 유저를 등록한다 (upsert).
    func registerUser(appleUserId: String, email: String?, displayName: String?) async { ... }

    /// Supabase에서 유저를 삭제한다.
    func deleteUser(appleUserId: String) async { ... }
}
```

### 3-4. LoginView

```swift
/// Apple 로그인 화면.
struct LoginView: View {
    var onLoginSuccess: () -> Void

    var body: some View {
        VStack {
            // 앱 로고 / 설명

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                // 성공: userIdentifier, email, fullName 추출
                // → Keychain 저장
                // → Supabase 등록
                // → onLoginSuccess()
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)
        }
    }
}
```

- `SignInWithAppleButton`은 SwiftUI 네이티브 컴포넌트 (`AuthenticationServices` import)
- `requestedScopes`: `.email`, `.fullName` (첫 로그인 때만 실제 값 반환)

### 3-5. LyricSyncApp 수정

```swift
@main
struct LyricSyncApp: App {
    @State private var playerViewModel = PlayerViewModel()
    @State private var isAuthenticated = false

    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                // 기존 메인 화면
                NavigationStack { ChartListView() }
                    .safeAreaInset(edge: .bottom) { ... MiniPlayerView }
                    .environment(playerViewModel)
            } else {
                LoginView {
                    isAuthenticated = true
                }
            }
        }
    }
}
```

- `.task`에서 Keychain 확인 + credentialState 확인
- 유효하면 `isAuthenticated = true`로 바로 메인
- 무효하면 LoginView 표시

---

## 4. 주의사항

### 4-1. 첫 로그인 때만 email/이름 제공

Apple은 `userIdentifier`는 매번 주지만, `email`과 `fullName`은 **최초 1회만** 제공.
→ 첫 로그인 성공 시 반드시 Supabase에 저장.
→ 놓치면 다시 못 받음 (유저가 설정 → Apple ID → 앱 삭제 후 재연동해야 리셋).

### 4-2. credentialState 확인 필수

매 앱 실행 시 `ASAuthorizationAppleIDProvider().credentialState(forUserID:)` 호출:
- `.authorized` → 정상
- `.revoked` → 유저가 설정에서 앱 연동을 해제함. Keychain 삭제 + 로그인 화면으로.
- `.notFound` → 유저를 찾을 수 없음. Keychain 삭제 + 로그인 화면으로.

이거 안 하면 **취소한 유저가 계속 로그인 상태로 남는 버그** 발생.

### 4-3. 계정 삭제 기능 (App Store 심사 필수)

Apple 로그인을 쓰면 **계정 삭제 기능이 반드시 있어야** App Store 심사를 통과함.
설정 화면에 "계정 삭제" 버튼 추가:

```
탭 → 확인 Alert ("정말 삭제하시겠습니까?")
   → Supabase DELETE /users?apple_user_id=eq.{id}
   → Keychain 삭제
   → isAuthenticated = false → 로그인 화면
```

### 4-4. Keychain은 앱 삭제 시 같이 삭제됨

iOS 10.3+ 기본 동작. 앱 재설치 시:
- Keychain 비어있음 → 로그인 화면 표시
- 같은 Apple ID로 로그인 → 동일한 `userIdentifier` 반환
- Supabase에 이미 등록된 유저와 매칭됨 → 데이터 유지

### 4-5. 보안 — 현재 단계에서는 충분

현재 Supabase에 유저별 민감 데이터가 없음 (가사는 공유 데이터).
나중에 즐겨찾기/학습 기록 등 유저별 데이터 추가 시 RLS 강화 필요:

```sql
-- 나중에 필요할 때 추가
CREATE POLICY "own_data_only" ON favorites
    FOR ALL USING (apple_user_id = current_setting('request.headers')::json->>'x-user-id');
```

---

## 5. 현재 앱에 미치는 영향

| 기존 기능 | 영향 |
|---|---|
| 차트 조회 | 없음 — MusicKit은 Apple 로그인과 무관 |
| 가사 조회 (Supabase) | 없음 — anon key로 읽기, user_id 불필요 |
| 가사 조회 (lrclib) | 없음 |
| 검색 | 없음 |
| 번역 배지 | 없음 |
| 번역 표시 모드 | 없음 |

**유일한 변경: 앱 시작 시 로그인 분기가 추가되는 것.**
기존 기능은 전혀 수정하지 않음.

---

## 6. 구현 순서

```
1. Supabase에 users 테이블 생성 (SQL 실행)
2. KeychainService 구현
3. AuthService 구현 (credential 확인 + Supabase 유저 등록/삭제)
4. LoginView 구현 (SignInWithAppleButton)
5. LyricSyncApp 수정 (인증 분기)
6. 설정 화면에 계정 삭제 버튼 추가
```
