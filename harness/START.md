# 실행 방법

## 디렉토리 구조

```
lyric-harness/                    ← 하네스 디렉토리 (별도)
├── CLAUDE.md                      ← 오케스트레이터 (Claude Code가 자동으로 읽음)
├── PROJECT_CONTEXT.md             ← 프로젝트 고정 요구사항
├── agents/
│   ├── evaluation_criteria.md     ← 공용 평가 기준
│   ├── planner.md                 ← Planner 서브에이전트 지시서
│   ├── generator.md               ← Generator 서브에이전트 지시서
│   └── evaluator.md               ← Evaluator 서브에이전트 지시서
├── docs/
│   ├── musickit_notes.md          ← MusicKit API 레퍼런스
│   └── lrclib_api_notes.md        ← lrclib.net API 레퍼런스
├── SPEC.md                        ← Planner가 생성 (실행 후 생김)
├── SELF_CHECK.md                  ← Generator가 생성 (실행 후 생김)
├── QA_REPORT.md                   ← Evaluator가 생성 (실행 후 생김)
└── START.md                       ← 지금 이 파일

(프로젝트 루트)/                   ← 실제 Xcode 프로젝트 루트
├── App/                           ← Generator가 생성 (실행 후 생김)
│   └── LyricSyncApp.swift
├── Views/
│   ├── Auth/
│   ├── Search/
│   ├── Player/
│   └── Components/
├── ViewModels/
│   ├── Auth/
│   ├── Search/
│   └── Player/
├── Models/
├── Services/
└── Shared/
```

**중요**: Generator가 생성한 Swift 파일들은 `lyric-harness/` 바깥쪽 프로젝트 루트에 직접 저장됩니다!

---

## 실행 방법

### 1단계: 하네스 폴더에서 Claude Code를 실행합니다

```bash
cd lyric-harness
claude
```

Claude Code가 CLAUDE.md를 자동으로 읽고 오케스트레이터 역할을 합니다.

### 2단계: 프롬프트 한 줄을 입력합니다

```
Apple Music 구독자가 노래를 검색하고 재생하면서, 싱크 가사를 보고 특정 가사를 탭하면 해당 시간으로 이동하는 앱을 만들어줘
```

이것만 치면 됩니다.
CLAUDE.md의 지시에 따라 자동으로:

1. Planner 서브에이전트가 SPEC.md를 생성합니다 (lyric-harness/ 안)
2. Generator 서브에이전트가 **프로젝트 루트**에 Swift 파일들을 생성합니다 (App/, Views/, ViewModels/, Models/, Services/, Shared/)
3. Evaluator 서브에이전트가 QA_REPORT.md를 생성합니다 (lyric-harness/ 안)
4. 불합격이면 Generator가 피드백을 반영하여 재작업합니다
5. 합격이면 완료 보고가 나옵니다

### 3단계: 결과를 Xcode에 추가합니다

프로젝트 루트에 생성된 **App/, Views/, ViewModels/, Models/, Services/, Shared/** 폴더들을 Xcode 프로젝트에 드래그&드롭으로 추가합니다.

**경로 확인:**
- ✅ 프로젝트 루트 (Xcode 프로젝트와 같은 수준)
- ❌ output/ 폴더 내부가 아님

---

## 앱 핵심 기능

- **Apple 로그인** + Apple Music 권한 요청
- **노래 검색**: MusicKit으로 Apple Music 카탈로그 검색
- **음악 재생**: 재생/일시정지, 시크바, 현재 시간 표시
- **싱크 가사**: lrclib.net API로 LRC 가사 fetch → 현재 시간에 맞춰 하이라이트
- **탭-투-시크**: 가사 줄 탭 → 해당 타임스탬프로 음악 이동
- **미니 플레이어**: 다른 화면에서도 현재 재생 곡 제어

---

## 프롬프트를 바꿔서 실행해보기

```
가사에 번역 기능을 추가해줘. 영어 가사를 한국어로 번역해서 아래에 같이 보여줘
```

```
최근 재생한 곡 히스토리 기능을 추가해줘
```

기능을 추가하거나 구조를 바꾸고 싶으면 **PROJECT_CONTEXT.md**의 `사용자 추가 요구사항` 섹션에 항목을 추가하세요.

---

## Solo 비교 실험을 하고 싶다면

하네스 없이 Solo로 실행한 결과를 비교하고 싶으면:

```bash
# 다른 폴더에서 Claude Code 실행 (CLAUDE.md가 없는 곳)
mkdir solo-test && cd solo-test
claude

# 같은 프롬프트 입력
> Apple Music 구독자가 노래를 검색하고 재생하면서, 싱크 가사를 보고 특정 가사를 탭하면 해당 시간으로 이동하는 SwiftUI 앱을 만들어줘
```

Solo 결과와 하네스 결과를 비교하면 차이가 명확히 보입니다.
