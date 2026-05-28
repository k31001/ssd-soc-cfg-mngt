# AI 친화 SoC 산출물 관리 — 제안 보고서

## 한 줄 명제

> **모든 산출물은 Markdown·SystemRDL 로 작성해 8개 git 저장소에 둔다. Claude Code 가 Phase 1/2 로 RTL 변경을 전파하고, CI invariant 가 정합성을 강제한다.**

## 9 챕터 목차

| # | 챕터 | 1줄 요약 |
|---|---|---|
| [00](00-executive-summary.md) | Executive Summary | 1페이지 요약 + 정량 효과 + 12주 컷오버 |
| [01](01-problem.md) | 문제 정의 | Word/Excel/Confluence/RAG/MCP 의 3대 비효율 |
| [02](02-proposal.md) | 아키텍처 | 8-repo · Phase 1/2 · 4 빌딩블록 |
| [03](03-artifact-taxonomy.md) | 산출물 분류 | 5종 문서 + 3종 코드 + 1종 외부 + 마크다운 시각화 |
| [04](04-rtl-doc-consistency.md) | CI invariants | Authored/Shadow Zone + 저장소별 invariant 매트릭스 |
| [05](05-ai-automation.md) | AI 자동화 | Claude dev-verifier + 참조 위계 + Spec PDF 결정 |
| [06](06-workflow-e2e.md) | Phase 1/2 전파 | RTL 변경의 1주 흐름 (Phase 1 + Phase 2) |
| [07](07-roadmap.md) | 로드맵 + 리스크 | 3개월(12주) 일제 전환 step-by-step + Top 5 리스크 |
| [08](08-conclusion.md) | 결론 | Day 90 도달 상태 + 기회비용 |

## 부속

- [`_research-notes.md`](_research-notes.md) — 외부 1차 자료 인용 부록
- 발표 슬라이드: [`../../web/present/`](../../web/present/index.html)
- 라이브 대시보드: [`../../web/`](../../web/) (9-stage concept proof + 25×8 status matrix)
- 운영 워크플로우 정의: [`../WORKFLOW.md`](../WORKFLOW.md)
- 실증 보고: [`../VERIFICATION_REPORT.md`](../VERIFICATION_REPORT.md)
- 형상관리 4전략 비교: [`../../cm-strategies/README.md`](../../cm-strategies/README.md)

## 청중별 권장 읽기 순서

### 임원·사업부장 (10분)
1. [00 Executive Summary](00-executive-summary.md)
2. [07 Roadmap §7.3 12주 step-by-step](07-roadmap.md#73-12주-step-by-step)
3. [08 Day 90 도달 상태](08-conclusion.md#82-day-90-도달-상태)

### SoC 실무자 (30분)
1. [01 문제](01-problem.md) · [02 아키텍처](02-proposal.md)
2. [04 CI invariants](04-rtl-doc-consistency.md)
3. [06 Phase 1/2 전파](06-workflow-e2e.md)

### SW · DV · FW 엔지니어 (25분)
1. [03 산출물 분류](03-artifact-taxonomy.md)
2. [05 AI 자동화](05-ai-automation.md)
3. [06 Phase 1/2 전파](06-workflow-e2e.md)

### DevOps · Infra (25분)
1. [02 아키텍처 §2.2 저장소 카드](02-proposal.md)
2. [04 CI invariants](04-rtl-doc-consistency.md)
3. [07 로드맵 + 리스크](07-roadmap.md)
