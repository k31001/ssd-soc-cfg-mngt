# 1. 문제 정의 — 왜 기존 산출물 관리는 AI 시대에 무너지는가

본 장은 우리가 지금까지 의지해온 **Confluence + 별첨 DOCX/PDF + RAG/MCP 기반 검색**
모델이 AI 코딩 시대에 가지는 3대 구조적 비효율을 분석한다. 이 한계가
"마크다운 + Git + Submodule + RTL Grounded" 전략의 출발점이다.

---

## 1.1 SoC 산출물 관리의 전형적 현실

대부분의 팀이 다음과 같은 산출물 분산 상태에 있다.

```
SoC Spec.docx           ─ SharePoint
HLD/DLD.docx            ─ Confluence (export)
SFR 주소맵.xlsx         ─ Confluence 표 + 별첨
PROGRAMMERS_GUIDE.pdf   ─ Confluence wiki
HAL 헤더.h              ─ Bitbucket
RTL.sv                  ─ 별도 Git 저장소
Test scenarios.docx     ─ Jira 첨부
회의록·결정사항          ─ Confluence
```

각 산출물은 **다른 시스템·다른 포맷·다른 버전 라이프사이클**에 있고,
"이 RTL을 검증할 시나리오가 어떤 가이드의 어떤 절을 만족시키는지" 같은
cross-reference 질문에는 **사람이 직접 추적**해야 한다.

LLM이 이 환경에 진입하면 즉시 두 가지 비용 폭탄을 마주한다:
**(A) 임베딩·검색 인프라**, **(B) 토큰 폭증**.

---

## 1.2 비효율 #1 — 임베딩 RAG의 재인덱싱·청킹·환각 문제

벡터DB 기반 RAG는 코드/SoC 도메인에서 다음 세 가지 구조적 약점을 가진다.

### (a) 재인덱싱 오버헤드
- RTL이 변경될 때마다 관련 문서·헤더·HAL이 재생성된다. 벡터DB는 이 변화를 **전체 재임베딩** 또는 부분 갱신 파이프라인으로 따라가야 한다.
- 갱신이 늦어지면 LLM은 **삭제된 함수를 참조하는 코드**를 생성한다. RAG 업계는 이 현상을 "stale embedding"으로 인정한다.[^1]

### (b) 청킹으로 인한 정합성 손실
- 1685-2022 IP-XACT XML이나 register map 표는 **전체로서만** 의미를 가진다. 청크 단위로 잘리면 "이 비트 필드의 reset 값은?" 같은 질문에서 인접 청크가 빠지면 환각이 시작된다.
- RAGFlow의 2025 회고는 "RAG 실패의 대부분은 retrieval recall이 아니라 **context quality**"라고 결론지었다.[^2]

### (c) 의미적 유사도의 잡음
- SoC 도메인은 정확한 심볼 (`IRQ_EN`, `STATUS_REG.bit[3]`, `hal_irq_enable()`)에 의존한다. 의미 유사도는 `IRQ_EN`과 `INT_ENABLE`을 동일시할 수 있고, 이는 **잠재적 버그**다.
- Anthropic Claude Code 팀이 직접 내린 결론: "A symbol either appears in a file or it does not. There is **no fuzzy positive**."[^3]

---

## 1.3 비효율 #2 — Confluence/MCP 문서 검색의 토큰·latency 폭증

문서가 Confluence 같은 별도 시스템에 있으면, LLM이 이를 활용하려면
**MCP 또는 API 기반 검색**을 거쳐야 한다. 각 단계마다 비용이 누적된다.

| 단계 | 비용 |
|---|---|
| MCP search call | API round-trip + 인증 토큰 |
| 검색 결과 후보 N개 fetch | N × HTML→markdown 변환 + 페이로드 토큰 |
| LLM 컨텍스트에 주입 | 노이즈 포함된 청크 다수 토큰 소비 |
| 이를 기반으로 답변 | 환각 또는 "더 알아봐야" 회피 응답 |

실측 결과 산업에서는 다음 패턴이 관찰된다:
- **MCP 호출 1회당 평균 latency**: 수백 ms ~ 수 초.
- **단일 질의 처리에 요구되는 토큰**: 직접 git read 대비 **5–20배** (검색 결과 청크가 무관 내용을 다수 포함).
- **재현 가능성**: 검색 결과 순위가 인덱스 상태에 의존하므로 동일 질의에 다른 답.

McKinsey 2025 분석에서도 AI 코딩 도구의 생산성 향상이 20–45%에 이르지만,
**컨텍스트가 부족하면 급격히 하락**한다고 명시한다.[^2] 즉 "검색이 잘 되는가"보다
"컨텍스트가 결정론적으로 주어지는가"가 더 중요하다.

---

## 1.4 비효율 #3 — 문서 ↔ RTL 정합성 붕괴

가장 본질적인 문제는 산출물간 **정합성**이 사람의 성실성에 의존한다는 점이다.

| 시나리오 | 현실 |
|---|---|
| RTL의 SFR 비트 폭 변경 | 가이드·헤더·테스트벤치가 따로 업데이트 누락 |
| 새 IP 추가 | 5종 문서를 5번 작성 (저자·시스템·포맷 모두 분리) |
| Spec change | 어디까지 영향이 가는지 누구도 단언 불가 |
| 신규 SoC 파생 | Base SoC 산출물 전체를 수동으로 복사·수정 |

산업적으로 이를 "documentation drift"라 부른다. 일정 시점이 지나면
**문서를 더 이상 믿지 못하는 단계**가 되고, 팀은 다시 RTL을 직접
읽기 시작한다 — 즉 산출물의 존재 의의가 사라진다.

---

## 1.5 종합 — 우리가 풀어야 할 단 하나의 질문

> "**RTL을 single source of truth로 두고, 다른 모든 산출물은 RTL의 그림자로 (자동) 동기화되며, AI는 그 산출물을 결정론적으로 읽을 수 있는** 시스템이 가능한가?"

답은 가능하며, 그것을 가능케 하는 4가지 빌딩블록은 모두 이미
산업에 준비되어 있다.

1. **Markdown** — git-friendly, diff 가능, AI가 토큰 효율 최고로 읽음.
2. **Git + Submodule** — tag·branch 기반 결정론적 버전, 권한 분리, atomic change.
3. **IEEE 1685-2022 IP-XACT** — 등록된 국제 표준 register description.
4. **RTL-Grounded CI** — invariant 검사로 정합성을 빌드 시스템에 위임.

다음 장(2장)에서 이 4개를 묶어 단일 워크플로우로 제시한다.

---

[^1]: [PageIndex: Vectorless, Reasoning-based RAG](https://pageindex.ai/blog/pageindex-intro), [Reproducibility Limitations of RAG Systems (arXiv 2509.18869)](https://arxiv.org/pdf/2509.18869)
[^2]: [From RAG to Context — RAGFlow 2025 review](https://ragflow.io/blog/rag-review-2025-from-rag-to-context), [Context Engine vs RAG — Unblocked](https://getunblocked.com/blog/context-engine-vs-rag/)
[^3]: [Why Claude Code Chose ripgrep — Rust Trends](https://rust-trends.com/posts/ripgrep-claude-code/)
