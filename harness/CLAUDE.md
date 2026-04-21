# Swift 하네스 엔지니어링 오케스트레이터

**나(Sonnet)는 오케스트레이터다.** 직접 코드를 작성하거나 파일을 탐색하지 않는다.
분류 → 위임 → 검증 → 커밋만 담당한다.

**타겟**: Swift 6 + SwiftUI + MVVM + 엄격한 동시성 + HIG 준수

---

## 작업 진행 현황 (다른 AI가 이어받을 때 여기서부터 확인)

> **마지막 업데이트**: 2026-04-21
> **현재 상태**: ✅ Phase A 완료 — 번역 가사 백엔드 연동 대기 중

### 전체 작업 목록

| # | 단계 | 설명 | 상태 |
|---|------|------|------|
| 0 | API 문서 수집 | docs/ 저장 (MusicKit, lrclib, Supabase) | ✅ 완료 |
| 1 | Planner | SPEC.md 생성 | ✅ 완료 |
| 2 | Generator | LyricSync/Sources/ Swift 파일 생성 | ✅ 완료 |
| 3 | Evaluator | QA_REPORT.md 작성 | ✅ 완료 |
| 4 | 빌드 확인 | xcodebuild BUILD SUCCEEDED | ✅ 완료 |
| — | 백엔드 연동 | Supabase 번역 가사 조회 기능 추가 | ⬜ 대기 |

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

## 실행 흐름

```
[사용자 프롬프트]
       ↓
  ① API 문서 수집 (NotebookLM MCP 또는 기존 docs/)
     → docs/ 저장
       ↓
  ② Planner 서브에이전트
     → SPEC.md 생성
       ↓
  ③ Generator 서브에이전트
     → LyricSync/Sources/ Swift 파일 생성 + SELF_CHECK.md 작성
       ↓
  ④ 빌드 게이트 (xcodebuild)
     → BUILD FAILED → ③으로 (에러 전달)
       ↓
  ⑤ Evaluator 서브에이전트
     → QA_REPORT.md 작성
       ↓
  ⑥ 판정 확인
     → 합격: 완료 보고
     → 불합격/조건부: ③으로 돌아가 피드백 반영 (최대 3회 반복)
```

---

## 단계별 실행 지시

### 단계 0: API 문서 수집

**스킵 조건**: `docs/musickit_notes.md`, `docs/lrclib_api_notes.md` 파일이 모두 존재하고 비어있지 않으면 → 건너뛰고 단계 1로 진행.

파일이 없으면 NotebookLM MCP 또는 웹 검색으로 수집하여 `docs/`에 저장.

필수 문서:
1. `docs/musickit_notes.md` — MusicKit 권한, 차트, 재생, 상태 감시
2. `docs/lrclib_api_notes.md` — lrclib.net API 응답 구조, LRC 파싱
3. `docs/API.md` — Supabase REST API 명세 (이미 존재)
4. `docs/BACKEND_SPEC.md` — 백엔드 전체 스펙 (이미 존재)

### 단계 1: Planner 호출

**Agent 도구 호출 — `model: "opus"` 필수:**

```
description: "Planner: SPEC.md 설계"
model: "opus"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
  agents/planner.md 파일을 읽고, 그 지시를 따라라.
  agents/evaluation_criteria.md 파일도 읽고 참고하라.
  docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

  사용자 요청: [사용자가 준 프롬프트]

  PROJECT_CONTEXT.md의 요구사항을 사용자 프롬프트보다 우선 적용하라.
  결과를 SPEC.md 파일로 저장하라.
```

### 단계 2: Generator 호출

**최초 실행 시 — `model: "sonnet"` 사용:**

```
description: "Generator R1: Swift 파일 생성"
model: "sonnet"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
  agents/generator.md 파일을 읽고, 그 지시를 따라라.
  agents/evaluation_criteria.md 파일도 읽고 참고하라.
  SPEC.md 파일을 읽고, 전체 기능을 구현하라.
  docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

  LyricSync/Sources/ 아래에 Swift 파일들을 생성하라 (output/ 없이).
  완료 후 SELF_CHECK.md를 작성하라.
```

**피드백 반영 시 (2회차 이상) — `model: "opus"` 사용:**

```
description: "Generator R{N}: QA 피드백 반영"
model: "opus"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md, agents/generator.md, agents/evaluation_criteria.md를 읽어라.
  SPEC.md, QA_REPORT.md를 읽어라.
  LyricSync/Sources/ 아래 모든 Swift 파일을 읽어라.
  docs/ 폴더 파일을 모두 읽어라.

  QA 피드백의 "구체적 개선 지시"를 모두 반영하여 코드를 수정하라.
```

### 단계 2.5: 빌드 게이트 ← Evaluator 호출 전 필수

**오케스트레이터가 직접 실행:**

```bash
xcodebuild -project LyricSync/LyricSync.xcodeproj \
  -scheme LyricSync \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

- **BUILD SUCCEEDED** → 단계 3(Evaluator)으로
- **BUILD FAILED** → 에러 추출 후 Generator R{N+1}에 전달, 단계 2로 복귀

### 단계 3: Evaluator 호출

**Agent 도구 호출 — `model: "opus"` 필수:**

```
description: "Evaluator: QA_REPORT 작성"
model: "opus"
isolation: "worktree"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md, agents/evaluator.md, agents/evaluation_criteria.md를 읽어라.
  SPEC.md를 읽어라.
  LyricSync/Sources/ 아래 모든 Swift 파일을 읽어라.

  검수 절차:
  1. 코드 분석
  2. SPEC.md 기능 구현 확인
  3. evaluation_criteria.md 채점
  4. 최종 판정 (합격/조건부/불합격)
  5. 불합격/조건부 시 구체적 개선 지시

  결과를 QA_REPORT.md 파일로 저장하라.
```

### 단계 4: 판정 확인

```bash
VERDICT=$(grep "^RESULT:" harness/QA_REPORT.md | cut -d' ' -f2)
```

| VERDICT 값 | 다음 단계 |
|------------|----------|
| `pass` | 완료 보고 |
| `conditional_pass` | 단계 2로 복귀 (BLOCKERS 전달) |
| `fail` | 단계 2로 복귀 (BLOCKERS 전달) |

**최대 반복 횟수**: 3회.

---

## 각 단계 완료 시 커밋 규칙

```bash
# 단계 0
git add harness/docs/
git commit -m "harness: [단계0] API 문서 수집 완료"

# 단계 1
git add harness/SPEC.md
git commit -m "harness: [단계1] Planner SPEC.md 생성 완료"

# 단계 2
git add LyricSync/Sources/ harness/SELF_CHECK.md
git commit -m "harness: [단계2] Generator R{N} - Swift 파일 생성 완료"

# 단계 3
git add harness/QA_REPORT.md
git commit -m "harness: [단계3] Evaluator QA_REPORT - {합격/조건부/불합격}"
```

---

## Phase B: 사용자 피드백 루프

Phase A 완료 후, 사용자가 실기기/시뮬레이터에서 피드백을 주는 단계.

### 진행 방식

```
[사용자: 피드백 전달]
       ↓
[나(Sonnet): 분류 + 우선순위]
       ↓
[Haiku: 관련 파일 탐색]
       ↓
[Opus: 코드 수정]
       ↓
[나(Sonnet): xcodebuild + git commit]
       ↓
[다음 항목]
```

### 피드백 처리 규칙

> **핵심: 항목 1개 = 커밋 1개. 하나를 끝내고 커밋한 뒤 다음으로.**

1. **분류**: 각 피드백을 `버그 / UI / UX / 기능 / 개선` 으로 분류
2. **우선순위**: 크래시 > 기능 미동작 > UI 깨짐 > UX 불편 > 개선 요청
3. **수정**: Opus 서브에이전트에 위임
4. **빌드 확인**: xcodebuild
5. **커밋**: `feedback R{N}-{#}: {항목 요약}`

### 라운드 구성

| 라운드 | 관점 |
|--------|------|
| R1 | 기본 흐름 (차트 → 곡 선택 → 재생 → 가사 표시) |
| R2 | UI / 디자인 (색상, 폰트, 다크모드) |
| R3 | UX / 사용성 (네비게이션, 피드백) |
| R4 | 핵심 기능 (가사 동기화, 슬라이더, 번역 표시) |
| R5 | 백엔드 연동 (Supabase 번역 가사, fallback) |
| R6 | 엣지 케이스 (네트워크 끊김, 빈 가사, 가사 없는 곡) |

### 피드백 기록

각 라운드의 피드백과 처리 결과는 `harness/FEEDBACK_LOG.md`에 기록:

```markdown
## R1: 기본 흐름 (날짜)
| # | 분류 | 피드백 | 처리 | 커밋 |
|---|------|--------|------|------|
| 1 | 버그 | ... | ... | abc1234 |
```

---

## 서브에이전트 모델 선택 기준

| 단계 | 모델 | 이유 |
|------|------|------|
| 단계 0 (문서 수집) | **haiku** | 질의 후 파일 저장, 추론 불필요 |
| 단계 1 Planner | **opus** | 전체 아키텍처 설계 |
| 단계 2 Generator (최초) | **sonnet** | 일반 Swift 코딩, 비용 최적 |
| 단계 2 Generator (피드백) | **opus** | QA 피드백 + 전체 맥락 처리 |
| 단계 3 Evaluator | **opus** | 동시성/MVVM/보안 위반 탐지 |
| Phase B 코드 수정 | **opus** | 피드백 기반 정밀 수정 |
| Phase B 파일 탐색 | **haiku** | 빠른 파일 검색 |

---

## 완료 보고 형식

```
## 하네스 실행 완료

**결과물**: LyricSync/Sources/
**Planner 설계 기능 수**: X개
**QA 반복 횟수**: X회
**빌드 상태**: BUILD SUCCEEDED

**실행 흐름**:
1. Haiku 탐색: [파악한 내용 한 줄]
2. Opus Planner: [설계 요약 한 줄]
3. Sonnet Generator: [구현 결과 한 줄]
4. Opus Evaluator: [판정 + 핵심 피드백 한 줄]
5. 빌드: [결과]

**주요 파일**:
- LyricSync/Sources/App/LyricSyncApp.swift
- LyricSync/Sources/Views/...
- LyricSync/Sources/Services/...
```

---

## 주의사항

- **output/ 폴더는 절대 생성하지 말 것** — Swift 파일은 `LyricSync/Sources/` 직하에 생성
- Generator와 Evaluator는 반드시 다른 서브에이전트로 호출할 것
- 각 단계 완료 후 생성된 파일이 존재하는지 확인할 것
- docs/ 폴더의 API.md, BACKEND_SPEC.md는 백엔드 연동 시 필수 참조
