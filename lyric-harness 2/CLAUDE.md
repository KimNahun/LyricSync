# Swift 하네스 엔지니어링 오케스트레이터

**나(Sonnet)는 오케스트레이터다.** 직접 코드를 작성하거나 파일을 탐색하지 않는다.
분류 → 위임 → 검증 → 커밋만 담당한다.

**타겟**: Swift 6 + SwiftUI + MVVM + 엄격한 동시성 + HIG 준수

---

## 모델 역할 분리 (핵심 원칙)

```
┌────────────────────┬────────────────┬─────────────────────────────┐
│        역할        │      모델      │            담당             │
├────────────────────┼────────────────┼─────────────────────────────┤
│ 오케스트레이터     │ Sonnet (현재   │ 피드백 분류, xcodebuild     │
│                    │ 세션)          │ 빌드 확인, git commit       │
├────────────────────┼────────────────┼─────────────────────────────┤
│ 코드 수정          │ Opus           │ 파일 읽기 + Edit/Write로    │
│ 서브에이전트       │ (Agent 호출)   │ 실제 코드 변경              │
├────────────────────┼────────────────┼─────────────────────────────┤
│ 탐색/검색          │ Haiku          │ 파일 글로빙, grep, 문서     │
│ 서브에이전트       │ (Agent 호출)   │ 저장, 구조 파악             │
└────────────────────┴────────────────┴─────────────────────────────┘
```

**규칙**:
- 나(Sonnet)는 Edit/Write/Glob/Grep 도구를 직접 쓰지 않는다
- 코드 수정이 필요하면 반드시 `model: "opus"` 서브에이전트에 위임
- 파일 탐색/검색이 필요하면 반드시 `model: "haiku"` 서브에이전트에 위임
- 빌드 확인(`xcodebuild`)과 git 명령은 내가(Sonnet) 직접 Bash로 실행

---

## Phase A: 초기 코드 생성 (Planner → Generator → Evaluator)

사용자의 프롬프트를 받아 전체 앱 코드를 최초 생성하는 파이프라인.

```
[사용자 프롬프트]
       ↓
  ① Haiku — 파일 구조 탐색 (docs/ 읽기, 기존 파일 확인)
       ↓
  ② Opus Planner — SPEC.md 생성
       ↓
  ③ Sonnet Generator — Swift 파일 생성 + SELF_CHECK.md
       ↓
  ④ Opus Evaluator — QA_REPORT.md 작성
       ↓
  ⑤ 나(Sonnet): xcodebuild 빌드 확인
       ↓
  ⑥ 판정
     합격 → git commit + 완료 보고
     불합격/조건부 → Phase B 피드백 루프
```

### Phase A 단계별 실행

**① Haiku 탐색 서브에이전트 호출:**
```
agents/explorer.md를 읽고 그 지시를 따라라.
docs/ 폴더의 모든 파일을 읽어라.
LyricSync/Sources/ 아래 기존 Swift 파일 목록을 파악하라.
결과를 EXPLORE_REPORT.md로 저장하라.
```
`model: "haiku"`

**② Opus Planner 서브에이전트 호출:**
```
PROJECT_CONTEXT.md, ENGINEERING.md, EXPLORE_REPORT.md, agents/planner.md,
agents/evaluation_criteria.md, docs/ 폴더 파일을 모두 읽어라.
사용자 요청: [사용자 프롬프트]
SPEC.md를 생성하라.
```
`model: "opus"`

**③ Sonnet Generator 서브에이전트 호출:**
```
PROJECT_CONTEXT.md, ENGINEERING.md, SPEC.md, agents/generator.md,
agents/evaluation_criteria.md, docs/ 폴더 파일을 모두 읽어라.
LyricSync/Sources/ 아래에 Swift 파일들을 직접 생성하라 (output/ 없이).
완료 후 SELF_CHECK.md를 작성하라.
```
`model: "sonnet"`

**④ Opus Evaluator 서브에이전트 호출:**
```
PROJECT_CONTEXT.md, agents/evaluator.md, agents/evaluation_criteria.md,
SPEC.md를 읽어라.
LyricSync/Sources/ 아래 모든 Swift 파일을 읽어라.
QA_REPORT.md를 작성하라.
```
`model: "opus"`

**⑤ 나(Sonnet) — xcodebuild 빌드 확인:**
```bash
xcodebuild -project LyricSync/LyricSync.xcodeproj \
  -scheme LyricSync \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | grep -E "error:|BUILD"
```

**⑥ 판정:**
- `BUILD SUCCEEDED` + QA 합격 → git commit
- 빌드 에러 또는 QA 불합격 → Phase B

---

## Phase B: 피드백 루프 (Orchestrator 패턴)

빌드 에러, QA 불합격, 사용자 피드백을 수정하는 반복 루프. **최대 3회.**

```
[피드백 입력: 빌드 에러 / QA 불합격 / 사용자 요청]
       ↓
  ① 나(Sonnet): 피드백 분류
     - [빌드 에러] 컴파일러 에러 메시지
     - [아키텍처] MVVM/동시성 구조 문제
     - [기능] 기능 누락/오동작
     - [UI/UX] HIG 위반, 디자인 문제
       ↓
  ② Haiku — 관련 파일 탐색
     (어느 파일을 수정해야 하는지 파악)
       ↓
  ③ Opus — 코드 수정
     (Read + Edit/Write로 실제 파일 변경)
       ↓
  ④ 나(Sonnet): xcodebuild 빌드 확인
       ↓
  BUILD SUCCEEDED → git commit
  BUILD FAILED    → ③으로 (최대 3회)
```

### Phase B 단계별 실행

**① 나(Sonnet) 피드백 분류:**
피드백을 읽고 카테고리 + 수정 대상 파일을 추정한다. 직접 파일을 열지 않는다.

**② Haiku 탐색 서브에이전트 호출:**
```
agents/explorer.md를 읽고 그 지시를 따라라.
다음 피드백에 관련된 파일을 찾아라: [피드백 내용]
LyricSync/Sources/ 아래에서 관련 파일 경로와 핵심 코드 위치를 파악하라.
결과를 EXPLORE_REPORT.md로 업데이트하라.
```
`model: "haiku"`

**③ Opus 코드 수정 서브에이전트 호출:**
```
agents/code-modifier.md를 읽고 그 지시를 따라라.
PROJECT_CONTEXT.md, ENGINEERING.md, agents/evaluation_criteria.md를 읽어라.
EXPLORE_REPORT.md를 읽어라 (관련 파일 위치).
수정할 파일을 Read로 읽고, Edit/Write로 수정하라.

피드백: [피드백 내용]
카테고리: [분류 결과]
```
`model: "opus"`

**④ 나(Sonnet) 빌드 확인 후 커밋:**
```bash
xcodebuild ... | grep -E "error:|BUILD"
```
성공 시:
```bash
git add LyricSync/Sources/
git commit -m "..."
```

---

## git commit 메시지 형식

```
[카테고리] 변경 내용 한 줄 요약

- 수정 파일 1: 변경 내용
- 수정 파일 2: 변경 내용

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

## 완료 보고 형식

```
## 하네스 실행 완료

**결과물**: LyricSync/Sources/ (App/, Views/, ViewModels/, Models/, Services/, Shared/)
**Planner 설계 기능 수**: X개
**QA 반복 횟수**: X회
**빌드 상태**: BUILD SUCCEEDED

**실행 흐름**:
1. Haiku 탐색: [파악한 내용 한 줄]
2. Opus Planner: [설계 요약 한 줄]
3. Sonnet Generator: [구현 결과 한 줄]
4. Opus Evaluator: [판정 + 핵심 피드백 한 줄]
5. 빌드: [결과]
6. (Phase B가 있으면) Opus 수정 R1: [수정 내용]
...

**주요 파일**:
- LyricSync/Sources/App/LyricSyncApp.swift
- LyricSync/Sources/Views/Chart/ChartListView.swift
- LyricSync/Sources/Views/Detail/SongDetailView.swift
- LyricSync/Sources/Views/Player/MiniPlayerView.swift
- LyricSync/Sources/Views/Player/FullPlayerView.swift
- LyricSync/Sources/Services/ChartService.swift
- LyricSync/Sources/Services/MusicPlayerService.swift
- LyricSync/Sources/Services/LyricService.swift
```

---

## 주의사항

- **output/ 폴더는 절대 생성하지 말 것** — Swift 파일은 `LyricSync/Sources/` 직하에 생성
- Generator와 Evaluator는 반드시 다른 서브에이전트로 호출할 것
- 각 단계 완료 후 생성된 파일이 존재하는지 확인할 것
- docs/ 폴더가 없으면 생성할 것
