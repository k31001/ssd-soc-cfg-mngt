# Executive Summary — AI 기반 SoC 산출물 관리 전환

> 본 보고서는 SoC 설계·검증 프로세스를 AI 친화적으로 전환하기 위한
> **산출물(deliverables) 관리 전략**을 제안한다. 핵심은 단 한 줄로 요약된다:
>
> **"RTL · Doc · FW의 3개 저장소로 분리하고, FW가 Doc를 단방향 submodule로
> 끌어온다. 모든 산출물은 마크다운, RTL은 single source of truth, 정합성은
> 저장소별 CI invariant가 강제한다. 검증은 FW + Python coverif가 FPGA ·
> Veloce · Zebu 위에서 실제 SSD Controller 시나리오를 수행한다."**

---

## 한 장 요약

| 축 | 우리의 선택 | 대안 (배제 사유) |
|---|---|---|
| 저장소 토폴로지 | **RTL Repo · Doc Repo · FW Repo의 3-repo + FW→Doc 단방향 submodule** | 단일 super-repo (권한 분리 곤란), 양방향 submodule (의존 순환) |
| 문서 포맷 | **Markdown + Mermaid + WaveDrom** | Confluence (lock-in, diff 불가), DOCX/PDF (정합성 검증 불가) |
| 검색·검증 | **grep / ripgrep + 저장소별 CI invariant** | RAG / Vector DB (재인덱싱·청크 손실·환각) |
| AI 컨텍스트 주입 | **FW Repo의 `doc/` submodule 직접 read** | MCP 문서검색 (토큰 폭증·latency) |
| 단일 진실 원천 | **Verilog RTL Repo** (Doc Repo가 CI로 미러) | 별도 spec 문서 (RTL과 정합성 깨짐) |
| 산출물 5종 (Doc Repo) | HLD / DLD / Programmer's Guide / SFR (IP-XACT 1685-2022) / HAL.h | 일원화된 단일 문서 (역할 혼재) |
| 검증 방식 | **FW + Python coverif on FPGA · Veloce · Zebu** (HW/SW coverif) | SV TB만 (실제 NVMe 펌웨어 흐름 미반영) |

---

## 왜 지금 이 방향인가

1. **AI 코딩 도구의 패러다임 전환**. Anthropic Claude Code는 초기 RAG/벡터DB 방식을 폐기하고 grep 기반 agentic search로 전환했다. Cursor·Devin·DeepWiki도 같은 방향이다.[^1] 이유는 명확하다: 코드와 SoC 산출물은 **정확한 심볼** (SFR 이름·비트필드·함수 시그너처)에 의존하므로, 의미적 유사도는 잡음을 만든다.
2. **임베딩 RAG의 비용 한계**. RAG 시스템 실패의 대부분은 retrieval recall이 아니라 **context quality**에서 비롯되며,[^2] SoC 같이 변경이 잦은 도메인에서는 재인덱싱 비용과 청킹 손실이 결정적이다.
3. **국제 표준이 갖춰져 있다**. IP-XACT는 **IEEE 1685-2022**로 표준화되었고,[^3] register/SFR 자동화의 정해진 출구가 이미 있다. 별도 포맷을 발명할 필요가 없다.
4. **Docs-as-Code는 산업 표준**. Diátaxis 프레임워크와 git 기반 docs-as-code는 수백 개 프로젝트에서 검증되었다.[^4] SoC 산출물 5종은 이 프레임워크의 자연스러운 특화이다.

---

## 기대 효과 (산업 평균 기준)

- **AI 코딩 생산성**: well-defined task에서 20–45% 향상 (McKinsey 2025). 단, **컨텍스트가 충분히 주어졌을 때**의 수치이며, 우리 방식은 그 전제조건을 git submodule로 결정론적으로 만든다.
- **임베딩·검색 인프라 비용**: 0. 벡터DB·재인덱싱 파이프라인이 필요 없다.
- **문서 ↔ RTL 정합성 결함**: harness가 6종 invariant를 PR 시점에 차단 → 0 누출 목표.
- **신규 SoC 부트스트랩 시간**: Base SoC submodule pin → 변경 RTL만 PR → 자동 산출물 재생성. 사람이 만지는 페이지 수가 한 자릿수로 줄어든다.

---

## 다음 액션 (요약)

1. **Phase 1 (0–3개월)**: 본 워크플로우의 참조 IP(`irq_ctrl`, `trng`)를 모든 신규 IP의 템플릿으로 표준화. 모든 IP 폴더가 9-stage 산출물 구조를 따르도록 강제.
2. **Phase 2 (3–6개월)**: SFR/HAL/Header 자동 생성기를 `tools/ipflow.py`에 흡수, AI 어시스턴트가 Programmer's Guide → HAL 코드를 1-shot으로 생성하도록 컨텍스트 패키지를 정형화.
3. **Phase 3 (6–12개월)**: 기존 in-house IP를 점진적으로 본 구조로 마이그레이션. EDA 벤더 AI 솔루션 락인을 회피하면서 동등 효과 확보.

세부 내용은 다음 11개 챕터에서 단계별로 정당화한다.

---

[^1]: Boris Cherny (Anthropic Claude Code 창설자) 증언: "Early versions did use RAG with a local vector database, but the team found agentic search consistently outperformed it." — [Why Claude Code Chose ripgrep Over Vector Search](https://rust-trends.com/posts/ripgrep-claude-code/)
[^2]: [Context Engine vs RAG — Unblocked](https://getunblocked.com/blog/context-engine-vs-rag/)
[^3]: [IEEE 1685-2022 Standard](https://ieeexplore.ieee.org/document/10054520), 2022-09 IEEE SA Board 승인.
[^4]: [Diátaxis](https://diataxis.fr/), [Docs-as-Code — BrainGu](https://www.braingu.com/news/docs-as-code).
