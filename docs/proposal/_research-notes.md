# Research Notes — 외부 인용 자료 (작업용)

> 본 보고서 7장(LLM Wiki 벤치마크), 8장(정량 효과) 작성을 위해 수집한 1차 자료.
> 보고서 본문에서는 핵심 문장만 인용하고, 원문 URL은 각주로 처리.

---

## 1. DeepWiki / Devin (Cognition AI)

- **링크 / 출처**
  - [DeepWiki: AI docs for any repo — Cognition Blog](https://cognition.ai/blog/deepwiki)
  - [DeepWiki](https://deepwiki.com/)
  - [DeepWiki MCP Server — Cognition Blog](https://cognition.ai/blog/deepwiki-mcp-server)
  - [DeepWiki — Devin Docs](https://docs.devin.ai/work-with-devin/deepwiki)
- **핵심 문장**
  - "DeepWiki **treats the source code itself as the ground truth** and generates documentation directly from it, staying accurate as the code evolves."
  - "Answers are **grounded in the indexed code and documentation**, with linked references so that developers can verify explanations and jump directly to relevant files or even specific lines."
- **정량 (2026)**
  - 50,000+ 공개 GitHub 저장소 인덱싱, 4B+ LoC 처리 완료.
- **시사점 (보고서용)**
  - DeepWiki는 "코드가 ground truth"라는 우리 가설과 같은 방향. 단, **AI 생성 문서를 별도로 호스팅**해야 하고 검증을 위해 다시 코드로 점프해야 함. 우리 방식은 *문서 자체가 git 안에 있어* 그 점프 비용이 0.
  - DeepWiki의 자체 가이드도 "Treat DeepWiki as a fast first read, **not ground truth**" 라고 권고 → AI-generated wiki의 한계 자인.

---

## 2. RAG / 벡터DB 한계 (코드·기술문서 도메인)

- **링크 / 출처**
  - [Vector Search vs. Filesystem Tools: 2026 Benchmarks — LlamaIndex](https://www.llamaindex.ai/blog/did-filesystem-tools-kill-vector-search)
  - [PageIndex: Vectorless, Reasoning-based RAG](https://pageindex.ai/blog/pageindex-intro)
  - [From RAG to Context — RAGFlow 2025 review](https://ragflow.io/blog/rag-review-2025-from-rag-to-context)
  - [Context Engine vs RAG — Unblocked](https://getunblocked.com/blog/context-engine-vs-rag/)
  - [Reproducibility Limitations of RAG Systems (arXiv 2509.18869)](https://arxiv.org/pdf/2509.18869)
- **핵심 문장**
  - "Most enterprise RAG failures stem from **context quality**, not retrieval recall."
  - "RAG is bound to context loss **due to chunking** and sub-optimal retrieval, making the LLM more prone to hallucinations."
  - "An agent that hallucinates can ship a PR that references a function **removed months ago**." (재인덱싱 지연의 비용)
- **정량**
  - McKinsey 2025: AI 코딩 도구 생산성 향상 20–45% (well-defined task), 하지만 컨텍스트 부족 시 **급격히 하락**.
- **시사점**
  - 코드/SoC 문서는 "정확한 심볼"이 필요한 도메인 → 의미적 유사도 검색은 노이즈를 생성. 청크 단위 검색이 RTL ↔ 문서 ↔ 헤더 ↔ HAL의 cross-reference 정합성을 보장하지 못함.

---

## 3. Agentic Search / Grep-First (Claude Code, Cursor, Devin)

- **링크 / 출처**
  - [Why Cursor, Claude Code, and Devin Use grep, Not Vectors — MindStudio](https://www.mindstudio.ai/blog/is-rag-dead-what-ai-agents-use-instead)
  - [Claude Code Doesn't Index Your Codebase — Vadim's blog](https://vadim.blog/claude-code-no-indexing)
  - [Why Claude Code Chose ripgrep Over Vector Search — Rust Trends](https://rust-trends.com/posts/ripgrep-claude-code/)
  - [Settling the RAG Debate — SmartScope](https://smartscope.blog/en/ai-development/practices/rag-debate-agentic-search-code-exploration/)
- **핵심 문장 (Boris Cherny, Anthropic / Claude Code 창설자)**
  - "Early versions did use RAG with a local vector database, but the team found **agentic search consistently outperformed it**."
  - 4 가지 이유: **precision, simplicity, freshness, privacy**.
  - "A symbol either appears in a file or it does not. **There is no fuzzy positive.** Vector embeddings can surface 'conceptually adjacent' code that shares no tokens with the target symbol — and in a coding context, conceptual adjacency without textual match is usually **noise, not signal**."
  - "Grep returns exact matches, works on any codebase without preprocessing, doesn't require indexing, and **fails loudly** (no match returned) rather than **quietly** (wrong match returned)."
- **시사점 — 본 보고서의 핵심 무기**
  - Anthropic이 직접 RAG → grep으로 전환했다는 사실은, "submodule + 마크다운 + grep" 워크플로우가 단순한 우리만의 취향이 아니라 **AI 에이전트 시대의 표준 패턴**이라는 결정적 근거.
  - SoC 산출물은 코드보다도 더 "정확한 심볼"(SFR 이름, 비트 필드, 함수 시그너처) 의존도가 높으므로 이 논증이 **더 강하게** 적용됨.

---

## 4. Diátaxis & Docs-as-Code

- **링크 / 출처**
  - [Diátaxis (공식)](https://diataxis.fr/)
  - [Diátaxis — GitHub repo](https://github.com/evildmp/diataxis-documentation-framework)
  - [Docs-as-Code: Automating Documentation — BrainGu](https://www.braingu.com/news/docs-as-code)
  - [What is Diátaxis — I'd Rather Be Writing](https://idratherbewriting.com/blog/what-is-diataxis-documentation-framework)
- **핵심 개념**
  - **4분면**: Tutorials / How-to Guides / Reference / Explanation. 각 분면은 다른 사용자 요구를 충족 → 섞으면 안 됨.
  - **Docs-as-Code**: "Documentation lives in a Git repository, changes go through pull requests, and updates deploy automatically. **Diátaxis is the most widely adopted framework for this approach.**"
- **SoC 산출물 5종과의 매핑**
  | Diátaxis | 우리 산출물 |
  |---|---|
  | Reference | SFR (IP-XACT), HAL API |
  | Explanation | HLD |
  | How-to Guides | Programmer's Guide |
  | Tutorials + Reference | DLD (구현 가이드 + 상세 reference 혼합) |
  - 즉 우리 5종 분류는 Diátaxis의 SoC 특화 변형. 보고서 3장에서 이 매핑으로 정당성 강화.

---

## 5. IP-XACT (IEEE 1685-2022)

- **링크 / 출처**
  - [IEEE 1685-2022 Standard (IEEE Xplore)](https://ieeexplore.ieee.org/document/10054520)
  - [IEEE SA 표준 페이지](https://standards.ieee.org/ieee/1685/10583/)
  - [Accellera IP-XACT Working Group](https://www.accellera.org/activities/working-groups/ip-xact)
  - [What's New in the 2022 IEEE IP-XACT Standard — Semiconductor Digest](https://www.semiconductor-digest.com/whats-new-in-the-2022-ieee-ip-xact-standard-big-reveals-from-the-chair/)
  - [IPXACT-2022 User Guide (Accellera PDF)](https://accellera.org/images/downloads/standards/ip-xact/IPXACT-2022_user_guide.pdf)
  - [DVCON US 2024 — What's new in IP-XACT 1685-2022](https://archive.dvcon.org/accellera-workshop-what-is-new-in-ip-xact-ieee-std-1685-2022/)
- **핵심 문장**
  - "Components, systems, bus interfaces and connections, abstractions of those buses, and details of the components including **address maps, register and field descriptions, and file set descriptions** for use in automating design, verification, documentation, and use flows for electronic systems."
- **타임라인**
  - 2021 말: Accellera → IEEE P1685 WG로 이관.
  - **2022-09**: IEEE SA Board 승인 → IEEE 1685-2022 공표.
  - **2023-06**: Accellera 보충자료 승인.
- **시사점**
  - 우리 SFR을 IP-XACT 1685-2022로 표현한다 = **국제 표준**에 위에 올라탐 = 검증 도구·EDA 벤더와의 호환성·미래 안정성 보장.

---

## 6. RTL / EDA AI (ChipNeMo, VeriGen, VeriAssist)

- **링크 / 출처**
  - [ChipNeMo: Domain-Adapted LLMs for Chip Design (arXiv 2311.00176)](https://arxiv.org/html/2311.00176v4)
  - [ChipNeMo PDF — NVIDIA](https://d1qx31qr3h6wln.cloudfront.net/publications/ChipNeMo%20(2).pdf)
  - [Towards LLM-Powered Verilog RTL Assistant (arXiv 2406.00115)](https://arxiv.org/pdf/2406.00115)
  - [Comprehensive Verilog Design Problems Benchmark (arXiv 2506.14074)](https://arxiv.org/html/2506.14074v1)
  - [AI in Chip Design: from Basic Tools to LLMs and AI Agents — SIGARCH](https://www.sigarch.org/ai-in-chip-design-from-basic-tools-to-llms-and-ai-agents/)
- **핵심 문장**
  - ChipNeMo: "Design and verification data collection encompassed a variety of source files, including **Verilog and VHDL (RTL and netlists), C++, Spice, Tcl**, various scripting languages, and build-related configuration files."
  - 대표 과제: "Generate EDA scripts to gather the number of flip-flops in a certain region of the chip and identifying logic related to a particular circuit."
- **시사점**
  - NVIDIA조차도 ChipNeMo 학습 데이터로 **이미 git에 정돈된 RTL/문서**를 전제. AI가 SoC 산출물을 효과적으로 활용하려면 **결정론적·구조적·git-versioned**이어야 한다는 우리 명제와 일치.
  - EDA AI(JedAI, Synopsys.ai)는 벤더 락인이 있지만, 우리 방식은 **표준(IP-XACT) + 오픈 포맷(Markdown) + git**으로 같은 효과를 락인 없이 달성.

---

## 7. 우리 방식에 대한 정직한 반론 (대비용)

1. **Submodule 학습 곡선**: git submodule은 일반 개발자에게 unfamiliar. → 보고서 9장에서 harness CLI(`tools/ipflow.py`)와 onboarding doc으로 흡수했음을 명시.
2. **대용량 binary/waveform**: git LFS 또는 별도 artifact store 필요. → 9장 마이그레이션 섹션에서 다룸.
3. **Cross-IP 검색 시 grep이 느릴 수 있다**: ripgrep + git의 path filter로 보완 가능 (수만 파일까지 sub-second). 임베딩보다 여전히 빠름.

---

## 8. 보고서 본문에서 사용할 산업 평균 수치 (출처 명시)

| 지표 | 값 | 출처 |
|---|---|---|
| AI 코딩 생산성 향상 (well-defined task) | **20–45%** | McKinsey 2025, [RAGFlow review](https://ragflow.io/blog/rag-review-2025-from-rag-to-context) |
| DeepWiki 인덱싱 규모 | 50,000+ repo / 4B+ LoC | [Cognition Blog](https://cognition.ai/blog/deepwiki) |
| RAG 실패 원인 비율 | 대부분이 **context quality**, retrieval recall 아님 | [Unblocked](https://getunblocked.com/blog/context-engine-vs-rag/) |
| Claude Code의 grep 선택 이유 | precision / simplicity / freshness / privacy | [Rust Trends](https://rust-trends.com/posts/ripgrep-claude-code/) |
| IP-XACT 표준 채택 시점 | IEEE 1685-2022 (2022-09 승인) | [IEEE Xplore](https://ieeexplore.ieee.org/document/10054520) |
