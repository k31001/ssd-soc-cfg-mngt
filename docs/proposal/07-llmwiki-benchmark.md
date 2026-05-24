# 7. 산업·학계 벤치마크 — 최신 LLM Wiki 트렌드와 본 제안의 위치

본 장은 본 제안이 **최신 트렌드와 부합하는가**, 그리고 **어느 지점에서
한 발 앞서있는가**를 1차 자료를 들어 정리한다.

---

## 7.1 비교 대상 6가지 트렌드

| # | 트렌드 | 대표 사례 | 코어 아이디어 |
|---|---|---|---|
| ① | **LLM Wiki / Code-grounded Wiki** | DeepWiki (Cognition AI / Devin) | AI가 git repo에서 문서를 자동 생성 |
| ② | **Agentic Search (grep-first)** | Claude Code, Cursor, Devin | RAG 폐기, 파일 직접 read + ripgrep |
| ③ | **Vectorless RAG** | PageIndex | 임베딩 없이 reasoning-based 검색 |
| ④ | **Docs-as-Code + Diátaxis** | MkDocs/Docusaurus 기반 OSS 다수 | 문서 = 코드, PR로 리뷰, CI로 배포 |
| ⑤ | **IP-XACT 1685-2022** | Accellera WG, EDA 벤더 다수 | SoC register 표준 |
| ⑥ | **RTL LLM** | NVIDIA ChipNeMo, VeriAssist | 도메인 특화 LLM이 RTL/EDA 보조 |

---

## 7.2 ① LLM Wiki — DeepWiki와의 비교

**DeepWiki**[^1]는 GitHub 저장소에서 AI가 자동으로 wiki를 생성하는
서비스이다. 2026년 기준 **50,000+ 공개 저장소, 4B+ LoC 인덱싱**.

| 측면 | DeepWiki | 본 제안 |
|---|---|---|
| Source of truth | 코드 | **코드 + 사람이 쓴 마크다운** |
| 문서 위치 | 별도 호스팅 (deepwiki.com) | git 안 (마크다운) |
| 문서 정합성 | AI 추론 (재인덱싱에 의존) | **CI invariant로 강제** |
| AI 환각 처리 | 사용자 cross-check 권고 | **PR 차단** |
| 접근 방식 | 웹 / MCP | **직접 file read** |
| 외부 의존 | DeepWiki 서비스 | 0 (git만) |
| 락인 | Cognition 인프라 | 없음 |

DeepWiki 자체의 공식 가이드도 **"Treat DeepWiki as a fast first read,
not ground truth"**[^1]라고 권고한다. 즉 AI 생성 wiki는 본질적으로
**"검증되지 않은 추론 문서"**임을 자인한다.

본 제안은 그 한계를 **사람의 문서 + AI 자동 생성 + CI invariant**의
3겹 구조로 메운다. 즉 **DeepWiki가 비공식적으로 추구하는 방향을, 우리는
공식적·검증 가능하게 달성**한다.

---

## 7.3 ② Agentic Search — Anthropic Claude Code의 결정

본 제안의 가장 강력한 외부 증거는 **Anthropic Claude Code 팀의 자체
결정**이다.

> *"Boris Cherny's team built RAG into early Claude Code. They tested it
> against agentic search. **Agentic search won — not narrowly.** Early
> versions did use RAG with a local vector database, but the team found
> agentic search consistently outperformed it, with the main reasons being
> **precision, simplicity, freshness, and privacy**."*[^2]

이 4가지 사유는 SoC 산출물 도메인에 다음과 같이 적용된다:

| 사유 | 코드 도메인의 의미 | SoC 산출물 도메인의 의미 |
|---|---|---|
| **Precision** | 심볼이 있거나 없거나 | SFR 이름·offset·width가 있거나 없거나. 의미 유사도는 잡음 |
| **Simplicity** | grep 1개 도구 | git + grep 2개 도구 |
| **Freshness** | RTL 변경 즉시 반영 | RTL 변경 즉시 IP-XACT/HAL/Guide에 반영 |
| **Privacy** | 외부 API 미경유 | IP·SFR·HAL 모두 사내 git에 머묾 |

**보고서의 결정적 결론**: AI 코딩 도구 1위 (Claude Code)가 RAG를 폐기한
순간, 그것은 단순한 취향이 아니라 **AI 에이전트 시대의 산업적 표준
패턴**이 되었다. 본 제안은 그 패턴을 **SoC 산출물 도메인에 가장 먼저
적용**하는 것이다.

---

## 7.4 ③ Vectorless RAG — 같은 방향의 다른 표현

PageIndex 같은 vectorless RAG 도구[^3]는 **임베딩 없이 reasoning으로
계층적 인덱스를 탐색**한다. 98.7% 정확도를 달성했다고 보고하며, 벡터
RAG의 정확도·비용 trade-off를 명시적으로 거부한다.

본 제안은 이를 한 단계 더 단순화한다: **인덱스 자체를 git의 디렉터리
구조에 위임**한다. IP별 폴더, 문서 5종, 표준 파일 이름. 사람이 만든
인덱스가 이미 있으니 LLM이 별도 인덱스를 만들 이유가 없다.

---

## 7.5 ④ Docs-as-Code + Diátaxis

Diátaxis는 **수백 개 프로젝트**에서 채택된 산업 표준이며,[^4] 문서를
4분면(Tutorials / How-to / Reference / Explanation)으로 분해한다.

본 제안의 5종 산출물은 §3에서 보였듯 이 4분면의 SoC 특화 매핑이다.
즉 "왜 5종이냐"에 대한 답은 "Diátaxis의 SoC 도메인 자연 매핑"이다.

또한 Diátaxis 권장 도구(MkDocs, Docusaurus, mdBook)는 모두 **마크다운
+ git** 기반이다. 본 제안과 100% 같은 빌딩블록 위에 있다.

---

## 7.6 ⑤ IP-XACT 1685-2022 — 표준에 올라타기

| 항목 | 내용 |
|---|---|
| 표준 ID | **IEEE 1685-2022**[^5] |
| 승인 | 2022-09 IEEE SA Board |
| 보충자료 | 2023-06 Accellera 승인 |
| 표현 범위 | Components, bus interfaces, address maps, register/field descriptions, file set descriptions |
| EDA 도구 호환 | Synopsys, Cadence, Siemens, 오픈 도구 다수 |
| 본 제안에서의 위치 | SFR (Stage 4 산출물)의 **공식 포맷** |

별도 사내 포맷을 발명하지 않고 국제 표준을 채택하는 것은 **EDA 도구
호환성 + 미래 안정성 + 외주 IP 흡수 용이성**의 세 가지 이익을 동시에
제공한다.

---

## 7.7 ⑥ RTL LLM — NVIDIA ChipNeMo의 시사점

NVIDIA ChipNeMo[^6]는 도메인 특화 LLM이며, 학습 데이터로 **Verilog/VHDL
RTL, netlist, C++, Spice, Tcl, 빌드 설정 파일**을 모두 사용했다. 즉
**이미 git에 정돈된 SoC 산출물이 학습/추론의 전제**이다.

본 제안은 두 가지 관점에서 이 흐름과 정렬된다:
1. **AI가 활용할 수 있는 형태**로 산출물을 정리 — 마크다운, 구조화된
   IP-XACT, 표준 디렉터리 레이아웃.
2. **벤더 락인 회피** — Synopsys.ai, Cadence JedAI 같은 EDA 벤더 AI는
   강력하지만 락인이 크다. 본 제안은 오픈 포맷 + git으로 **유사한 효과를
   락인 없이** 달성한다.

VeriAssist[^7] 같은 OSS RTL LLM 보조도 같은 트렌드. 본 제안의 산출물
구조는 이런 OSS 도구가 즉시 활용 가능한 형태이다.

---

## 7.8 종합 비교표

| 트렌드 | 본 제안과의 일치도 | 본 제안의 차별점 |
|---|---|---|
| DeepWiki / LLM Wiki | 방향 동일 | **CI invariant로 정합성 강제** |
| Agentic Search (grep-first) | 정확히 동일 | **SoC 산출물 도메인 최초 적용** |
| Vectorless RAG | 방향 동일 | **git 디렉터리가 인덱스** (더 단순) |
| Docs-as-Code / Diátaxis | 빌딩블록 동일 | **SoC 5종 산출물의 표준 매핑 제시** |
| IP-XACT 1685-2022 | 표준 채택 | **마크다운 + IP-XACT의 hybrid 정합성 검사** |
| RTL LLM / ChipNeMo | 활용 전제 동일 | **벤더 락인 0** |

---

## 7.9 결론 — "트렌드에 부합"을 넘어 "트렌드를 종합"

본 제안은 다음 6개의 산업·학계 흐름의 **교집합**이다:

```
                        본 제안
                            │
            ┌───────────────┼───────────────┐
        DeepWiki        Claude Code       IP-XACT
       (code-grounded)  (grep-first)     (표준 SFR)
            │               │                │
        ────┴───────────────┴────────────────┴────
                  Markdown · Git · Diátaxis
```

각 흐름이 개별적으로는 우리 SoC 산출물 도메인에서 **부분 해답**일 뿐이지만,
**6개 모두를 한 워크플로우에 묶으면 완전한 답**이 된다. 그것이 본 제안의
구조적 가치이다.

다음 장(8장)에서 이 가치를 **정량적 산업 평균 수치**로 환산한다.

---

[^1]: [DeepWiki — Cognition Blog](https://cognition.ai/blog/deepwiki), [DeepWiki](https://deepwiki.com/), [Devin Docs](https://docs.devin.ai/work-with-devin/deepwiki).
[^2]: [Why Claude Code Chose ripgrep — Rust Trends](https://rust-trends.com/posts/ripgrep-claude-code/), [Why Cursor, Claude Code, and Devin Use grep — MindStudio](https://www.mindstudio.ai/blog/is-rag-dead-what-ai-agents-use-instead), [Claude Code Doesn't Index Your Codebase](https://vadim.blog/claude-code-no-indexing).
[^3]: [PageIndex: Vectorless, Reasoning-based RAG](https://pageindex.ai/blog/pageindex-intro).
[^4]: [Diátaxis](https://diataxis.fr/), [Docs-as-Code — BrainGu](https://www.braingu.com/news/docs-as-code).
[^5]: [IEEE 1685-2022 (IEEE Xplore)](https://ieeexplore.ieee.org/document/10054520), [Accellera IP-XACT WG](https://www.accellera.org/activities/working-groups/ip-xact), [IPXACT-2022 User Guide](https://accellera.org/images/downloads/standards/ip-xact/IPXACT-2022_user_guide.pdf).
[^6]: [ChipNeMo: Domain-Adapted LLMs for Chip Design](https://arxiv.org/html/2311.00176v4).
[^7]: [Towards LLM-Powered Verilog RTL Assistant (arXiv 2406.00115)](https://arxiv.org/pdf/2406.00115), [Comprehensive Verilog Design Problems Benchmark (arXiv 2506.14074)](https://arxiv.org/html/2506.14074v1).
