# Executive Summary — AI 기반 SoC 산출물 관리 전환

> 본 보고서는 SoC 설계·검증 프로세스를 AI 친화적으로 전환하기 위한
> **산출물(deliverables) 관리 전략**을 제안한다. 핵심은 단 한 줄로 요약된다:
>
> **"RTL · Doc · FW · Test 4개 저장소로 분리하고, FW와 Test는 각자 Doc를
> 단방향 submodule로 끌어온다. 모든 문서는 마크다운, SFR은 SystemRDL(또는
> IP-XACT XML), RTL은 single source of truth, 정합성은 저장소별 CI
> invariant가 강제한다. 검증은 FW가 FPGA · Veloce · Zebu 위에서 실행되는
> 동안 SSD Host의 Python scenarios가 NVMe/PCIe로 그 펌웨어를 구동한다."**

---

## 한 장 요약

| 축 | 우리의 선택 | 대안 (배제 사유) |
|---|---|---|
| 저장소 토폴로지 | **RTL · Doc · FW · Test 4-repo + Doc→{FW,Test} fan-out submodule** | 단일 super-repo (권한 분리 곤란), 3-repo (FW와 Test 분리 안 됨) |
| 문서 포맷 | **Markdown + Mermaid + WaveDrom** | Word·DOCX (정합성 검증 불가), Confluence (lock-in) |
| SFR 포맷 | **SystemRDL `.rdl`** author + **IP-XACT 1685-2022 XML** interchange (peakrdl emit) | Excel (현재 상태 — diff·CI 검증 불가), XML 직접 편집 (비친화적) |
| 검색·검증 | **grep / ripgrep + 저장소별 CI invariant** | RAG / Vector DB (재인덱싱·청크 손실·환각) |
| AI 컨텍스트 주입 | **FW · Test 각자의 `doc/` submodule 직접 read** | MCP 문서검색 (토큰 폭증·latency) |
| 단일 진실 원천 | **Verilog RTL Repo** (Doc Repo가 CI로 미러) | 별도 spec 문서 (RTL과 정합성 깨짐) |
| 산출물 5종 (Doc Repo) | HLD / DLD / Programmer's Guide / SFR (SystemRDL+IP-XACT) / HAL.h | 일원화된 단일 문서 (역할 혼재) |
| 펌웨어 실행 위치 | **FPGA · Veloce · Zebu에 FW binary 로드** | RTL TB만 (실제 펌웨어 흐름 미반영) |
| 검증 시나리오 실행 위치 | **SSD Host (Linux 서버)의 Python**, NVMe/PCIe로 SoC 구동 | SoC 안의 self-check (실제 환경과 괴리) |

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

0. **Phase 0 (0–2개월 · 마이그레이션 prerequisite)**: 현재 Word 문서 (HLD/DLD)와 Excel SFR 표를 **마크다운 + SystemRDL `.rdl`** 로 일괄 변환. Pandoc + 자동 변환 스크립트로 사람이 만지는 페이지 최소화.
1. **Phase 1 (2–5개월)**: 4-repo (RTL · Doc · FW · Test) 토폴로지 셋업. Doc Repo의 D1–D5 invariant, FW Repo의 F1–F3, Test Repo의 T1–T4 CI 가동. 참조 IP 1–2종을 신규 IP의 카피러프트 템플릿으로 표준화.
2. **Phase 2 (5–8개월)**: AI 어시스턴트가 Programmer's Guide → HAL.c (FW Repo), Programmer's Guide → Python scenarios (Test Repo)를 1-shot으로 생성하도록 컨텍스트 패키지를 정형화. Release gate R1 (`FW.doc-SHA == Test.doc-SHA`) 자동화.
3. **Phase 3 (8–12개월)**: 기존 in-house IP를 점진적으로 본 구조로 마이그레이션. EDA 벤더 AI 솔루션 락인을 회피하면서 동등 효과 확보.

세부 내용은 다음 11개 챕터에서 단계별로 정당화한다.

---

[^1]: Boris Cherny (Anthropic Claude Code 창설자) 증언: "Early versions did use RAG with a local vector database, but the team found agentic search consistently outperformed it." — [Why Claude Code Chose ripgrep Over Vector Search](https://rust-trends.com/posts/ripgrep-claude-code/)
[^2]: [Context Engine vs RAG — Unblocked](https://getunblocked.com/blog/context-engine-vs-rag/)
[^3]: [IEEE 1685-2022 Standard](https://ieeexplore.ieee.org/document/10054520), 2022-09 IEEE SA Board 승인.
[^4]: [Diátaxis](https://diataxis.fr/), [Docs-as-Code — BrainGu](https://www.braingu.com/news/docs-as-code).
