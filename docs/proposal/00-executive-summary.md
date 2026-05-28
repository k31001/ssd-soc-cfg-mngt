# Executive Summary — AI 기반 SoC 산출물 관리 전환

> 본 보고서는 SoC 설계·검증 프로세스를 AI 친화적으로 전환하기 위한
> **산출물(deliverables) 관리 전략**을 제안한다. 핵심은 단 한 줄로 요약된다:
>
> **"RTL · Design · RDL · PG · HAL · Spec · FW · Test 8개 저장소.
> 문서는 작성 의존 순서대로 RTL → Design → RDL → PG, 그리고 Phase 2 에서
> Claude Code 가 HAL · FW · Test 를 작성하고 자체 검증한다. FW/Test 는
> PG · RDL 만 primary 로 보고 RTL 은 절대 직접 참조하지 않는다. 정합성은
> 8개 CI invariant + Release gate 가 강제하며, 검증은 FW 가 FPGA·Veloce·Zebu
> 에서 실행되는 동안 SSD Host 의 Python 이 NVMe/PCIe 로 그 펌웨어를 구동한다."**

---

## 한 장 요약

| 축 | 우리의 선택 | 대안 (배제 사유) |
|---|---|---|
| 저장소 토폴로지 | **8-repo**: RTL · Design (HLD+DLD) · RDL · PG · HAL · Spec · FW · Test | 단일 super-repo (권한 분리), 단일 Doc Repo (작성자·생애주기 충돌) |
| 문서 작성 의존 | **RTL → Design → RDL → PG** (체인 단방향) | 임의 작성 (정합성 깨짐) |
| AI 역할 | **Claude Code = 개발자 + 자체 검증자** | AI = 보조 도구 (활용 한계) |
| 참조 위계 | **PG/RDL primary, DLD fallback, RTL 금지** (CI 강제) | 자유 참조 (RTL 의존 발생, 문서 무용지물화) |
| 수동 vs 자동 정합성 | **Hybrid: authored zone (자유) + shadow zone (자동, 수동 차단)** | 전면 자동 (사람 지식 소멸), 전면 수동 (drift 불가피) |
| 표준 spec (NVMe/PCIe) | **Spec Repo + submodule** (PDF LFS + 자동 MD extract) | 모든 PDF 첨부 (토큰 폭증), MCP 서버 (latency·인프라) |
| 문서 포맷 | **Markdown + Mermaid + WaveDrom** | Word·DOCX (정합성 검증 불가), Confluence (lock-in) |
| SFR 포맷 | **SystemRDL `.rdl`** + IP-XACT 1685-2022 XML (peakrdl emit) | Excel (diff·CI 검증 불가), XML 직접 편집 (비친화적) |
| AI 컨텍스트 주입 | **submodule 직접 read** + 참조 위계 프롬프트 | RAG · MCP (재인덱싱·청크·환각) |
| 단일 진실 원천 | **RTL Repo** (Design·RDL CI 가 미러) | 별도 spec 문서 (RTL 과 정합성 깨짐) |
| 펌웨어 실행 위치 | **FPGA · Veloce · Zebu** | SV TB 만 |
| 검증 시나리오 실행 위치 | **SSD Host (Linux 서버) Python**, NVMe/PCIe | SoC 안 self-check |

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

## 다음 액션 — 3개월 일제 전환

전 IP 를 동시에 신 워크플로우로 옮기는 **war-room 체제**. 부분 채택 없음.
세부 step-by-step 은 §10 참조.

| 기간 | 단계 | 핵심 산출물 |
|---|---|---|
| **Week 1–2** | 8개 repo + 변환 도구 (`docx2md`, `xlsx2rdl`, `pdf2md`, `peakrdl`) 셋업 | 8개 저장소 · CI invariant warning 가동 |
| **Week 2–5** | 전 IP **Bulk 변환** + Design 수동 보정 (병렬) | 모든 HLD/DLD 가 Markdown, 모든 SFR 이 SystemRDL, 모든 Spec PDF 가 MD extract |
| **Week 4–7** | PG §6 worked example 작성 (전 IP 병렬, Claude 보조) | 모든 IP 의 SW-HW 계약 문서 |
| **Week 5–9** | HAL.c · FW · Test Repo 이관 + Claude Code 의 dev-verifier 가동 | 모든 코드 저장소 PR-able 상태 |
| **Week 9–10** | CI 게이트 **warning → blocking** + Release gate R1 활성화 | 8-tuple invariant 강제 |
| **Week 10–12** | 첫 9-tuple release + 컷오버 (Word/Excel/Confluence read-only) | `rtl × design × rdl × pg × hal × spec × fw × test` · KPI baseline |

세부 내용은 다음 11개 챕터에서 단계별로 정당화한다.

---

[^1]: Boris Cherny (Anthropic Claude Code 창설자) 증언: "Early versions did use RAG with a local vector database, but the team found agentic search consistently outperformed it." — [Why Claude Code Chose ripgrep Over Vector Search](https://rust-trends.com/posts/ripgrep-claude-code/)
[^2]: [Context Engine vs RAG — Unblocked](https://getunblocked.com/blog/context-engine-vs-rag/)
[^3]: [IEEE 1685-2022 Standard](https://ieeexplore.ieee.org/document/10054520), 2022-09 IEEE SA Board 승인.
[^4]: [Diátaxis](https://diataxis.fr/), [Docs-as-Code — BrainGu](https://www.braingu.com/news/docs-as-code).
