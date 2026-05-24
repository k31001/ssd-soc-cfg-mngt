# AI 친화 SoC 산출물 관리 — 제안 보고서

본 디렉터리는 SoC 설계·검증 프로세스를 AI 기반으로 전환하기 위한
**산출물 관리 전략 제안서**의 본문이다. 임원/리더 및 실무자 혼합
청중을 대상으로 한다.

## 한 줄 명제

> **모든 산출물은 마크다운으로 작성하여 git에 둔다. 문서 저장소는
> submodule로 직접 연결하고, RTL을 single source of truth로 삼아
> 정합성을 CI가 강제한다.**

---

## 챕터 목차

| # | 챕터 | 핵심 질문 |
|---|---|---|
| [00](00-executive-summary.md) | Executive Summary | 한 장으로 본 제안의 전부 |
| [01](01-problem.md) | 문제 정의 | 기존 Confluence/RAG/MCP의 3대 비효율 |
| [02](02-proposal.md) | 제안 | Markdown · Git · Submodule · RTL-Grounded 통합 워크플로우 |
| [03](03-artifact-taxonomy.md) | 산출물 5종 분류 | HLD / DLD / Programmer's Guide / SFR / HAL과 Diátaxis 매핑 |
| [04](04-rtl-doc-consistency.md) | 정합성 CI | 6 invariant로 정합성을 빌드 시스템에 위임 |
| [05](05-ai-automation.md) | AI 자동화 | 4가지 자동 생성 시나리오와 submodule 직접 read |
| [06](06-workflow-e2e.md) | End-to-End 워크플로우 | Base SoC → 신규 SoC 8단계 |
| [07](07-llmwiki-benchmark.md) | LLM Wiki / DeepWiki 벤치마크 | 6개 산업 트렌드와의 비교 |
| [08](08-quantitative-impact.md) | 정량 효과 | 산업 평균 기준 ROI 추정 |
| [09](09-risks-migration.md) | 리스크와 마이그레이션 | 3-lane 점진적 이행 |
| [10](10-roadmap.md) | 로드맵 | 3·6·12개월 마일스톤 |
| [11](11-conclusion.md) | 결론 | 임원/리더에게 요청하는 3가지 결정 |

## 부속 자료

- [`_research-notes.md`](_research-notes.md) — 외부 1차 자료 인용 원본 (작업용 부록)
- 발표용 웹앱: [`../../web/present/`](../../web/present/)
- 본 워크플로우의 라이브 대시보드: [`../../web/`](../../web/) (Stage matrix · invariant status)
- 운영 워크플로우 정의: [`../WORKFLOW.md`](../WORKFLOW.md)
- 실증 보고: [`../VERIFICATION_REPORT.md`](../VERIFICATION_REPORT.md)
- 형상관리 4전략 비교: [`../../cm-strategies/README.md`](../../cm-strategies/README.md)

---

## 빠른 진입 — 청중별 권장 읽기 순서

### 임원 / 사업부장 (15분)
1. [00 Executive Summary](00-executive-summary.md)
2. [02 제안 §2.4 Before/After](02-proposal.md#24-무엇이-달라지는가--before--after-한눈에)
3. [08 정량 효과 §8.8 ROI 요약](08-quantitative-impact.md#88-roi-요약-12개월-시점)
4. [11 결론 §11.1 3가지 결정](11-conclusion.md#111-임원리더에게-요청하는-3가지-결정)

### SoC 실무자 / RTL designer (45분)
1. [01 문제 정의](01-problem.md)
2. [02 제안](02-proposal.md)
3. [04 정합성 CI](04-rtl-doc-consistency.md)
4. [06 End-to-End 워크플로우](06-workflow-e2e.md)

### SW / DV 엔지니어 (30분)
1. [03 산출물 5종 분류](03-artifact-taxonomy.md)
2. [05 AI 자동화](05-ai-automation.md)
3. [06 End-to-End 워크플로우](06-workflow-e2e.md)

### DevOps / Infra (30분)
1. [04 정합성 CI](04-rtl-doc-consistency.md)
2. [09 리스크와 마이그레이션](09-risks-migration.md)
3. [10 로드맵](10-roadmap.md)
