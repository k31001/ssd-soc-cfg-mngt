# 1. 문제 — 지금의 산출물 관리가 AI 시대에 무너지는 3가지 이유

## 1.1 산출물이 6개 시스템에 흩어져 있다

```
SoC Spec.docx           ─ SharePoint
HLD / DLD.docx          ─ Confluence (export)
SFR.xlsx                ─ Confluence 별첨
Programmer's Guide.pdf  ─ Confluence wiki
HAL 헤더.h              ─ Bitbucket
RTL.sv                  ─ 별도 Git
Test scenarios.docx     ─ Jira 첨부
표준 spec (NVMe/PCIe)    ─ 메일·공유 드라이브
```

cross-reference ("이 scenario 가 어떤 가이드의 어떤 절을 만족시키나?") → **사람이 추적**.

## 1.2 임베딩 RAG 는 코드·SoC 도메인에서 무너진다

| 문제 | 의미 |
|---|---|
| **재인덱싱 오버헤드** | RTL 변경 후 임베딩 갱신 지연 → LLM 이 *삭제된 함수를 호출* |
| **청킹 정합성 손실** | IP-XACT XML · register map 표는 전체로서만 의미. 청크가 잘리면 환각 |
| **의미 유사도의 잡음** | `IRQ_EN` 과 `INT_ENABLE` 을 동일시 → **잠재 버그** |

> "Most enterprise RAG failures stem from **context quality**, not retrieval recall." — Unblocked

## 1.3 MCP 문서검색은 토큰·latency 폭증

| 단계 | 비용 |
|---|---|
| MCP search call | API round-trip + 인증 |
| 후보 N개 fetch | N × HTML→MD + 페이로드 토큰 |
| LLM 컨텍스트 주입 | 무관·중복 청크 다수 |

산업 평균: **5–20× 토큰** (직접 read 대비), 수백 ms ~ 수 초 latency, 같은 질의 → 다른 답.

## 1.4 문서 ↔ RTL 정합성이 사람에게 달려 있다

| 시나리오 | 현실 |
|---|---|
| RTL SFR width 변경 | 가이드·헤더·TB 따로 누락 |
| 새 IP 추가 | 5종 문서를 5번 작성 |
| Spec change | 영향 범위 단언 불가 |

> 일정 시점 후 **문서를 더 이상 믿지 못한다**. 팀은 다시 RTL 을 직접 읽음 → 산출물 존재 의의 상실.

## 1.5 풀어야 할 단 하나의 질문

> **"RTL 을 single source of truth 로 두고, 다른 모든 산출물은 RTL 의 그림자로 자동 동기화되며, AI 는 그 산출물을 결정론적으로 읽는" 시스템이 가능한가?**

답은 가능하며, 필요한 빌딩블록은 이미 모두 산업에 준비되어 있다 — Markdown, Git Submodule, SystemRDL/IP-XACT 1685-2022, Claude Code 의 grep-first agentic search.

→ §2 가 이를 8-repo 토폴로지로 구체화.
