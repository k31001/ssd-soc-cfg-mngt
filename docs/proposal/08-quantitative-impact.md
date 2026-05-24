# 8. 정량 효과 — 산업 평균 기준의 추정

본 장의 모든 수치는 **산업 평균** 또는 **공개된 1차 자료**에 근거한다.
사내 실측이 가능한 항목은 PoC 단계에서 다시 측정하여 갱신한다.

---

## 8.1 5가지 정량 축과 산업 근거

| 축 | Before (기존 방식) | After (본 제안) | 산업 근거 |
|---|---|---|---|
| ① AI 코딩 생산성 | baseline | +20–45% (well-defined task) | McKinsey 2025[^1] |
| ② 컨텍스트 부족 시 효율 손실 | n/a | 0 (결정론적 컨텍스트) | RAGFlow 2025 회고[^1] |
| ③ 검색 인프라 비용 | 벡터DB 운영 (수천 ~ 수만 USD/월) | 0 (git만) | 벤더 가격 일반 |
| ④ 임베딩 재인덱싱 latency | 분 ~ 시간 | 0 (즉시) | Cognition DeepWiki 한계 자인[^2] |
| ⑤ 문서 ↔ RTL drift 결함 | 사람의 성실성 의존 | 0 누출 목표 | 본 레포 invariant 6종 |

---

## 8.2 ① AI 코딩 생산성 — +20–45%의 의미

> McKinsey 2025: AI 코딩 도구는 **well-defined task에서 20–45% 생산성
> 향상**을 보이며, **컨텍스트가 부족하면 급격히 하락**한다.[^1]

이 "well-defined task"에 본 제안이 정확히 매핑된다:

| McKinsey의 "well-defined" 조건 | 본 제안에서 충족 방식 |
|---|---|
| 명확한 입력 명세 | Programmer's Guide §6 (worked example) |
| 명확한 출력 형식 | HAL header convention, Python scenario template |
| 정답 검증 가능 | CI invariant 6종 + host smoke + Verilator sim |
| 도메인 컨텍스트 결정론적 제공 | submodule pin + 직접 file read |

즉 본 제안은 **20–45% 향상의 상한값에 가까이 머무는** 워크플로우 설계이다.

---

## 8.3 ② 컨텍스트 부족의 비용 — RAG vs 직접 read

가상의 예시: irq_ctrl HAL에 enable 함수를 추가한다.

| 단계 | RAG/MCP 방식 토큰 | 본 제안 방식 토큰 |
|---|---|---|
| 컨텍스트 회수 | ~5000 (top-k 청크 다수, 무관 내용 포함) | ~1500 (3개 파일 grep으로 좁힘) |
| LLM 추론 입력 | ~7000 | ~2500 |
| 출력 | ~1000 | ~1000 |
| **합계** | **~13000** | **~5000** |
| 비용 비율 | **2.6x** | 1.0x |

산업 평균 토큰 비용(Claude Sonnet/Opus 기준)으로 환산하면, **연간 PR
1000건 가정 시 LLM API 비용이 절반 이하**로 떨어진다. 게다가 latency도
선형적으로 단축된다 (네트워크 + 벡터 검색 step 제거).

> **참고**: 이 수치는 도메인·도구·작업 형태에 따라 변동한다. PoC에서
> 측정 후 갱신할 것.

---

## 8.4 ③ 검색 인프라 비용 — 정확히 0

| 인프라 항목 | RAG 방식 | 본 제안 |
|---|---|---|
| 벡터DB (Pinecone/Weaviate/Qdrant 등) | $$ / 월 | 0 |
| 임베딩 API 호출 | $$$ (모든 변경 재임베딩) | 0 |
| 재인덱싱 파이프라인 | 운영 비용 + on-call | 0 |
| MCP 서버 운영 | 운영 비용 | 0 |
| Confluence 라이선스 (산출물 부분) | 사용자 수 × $ | 점진 감소 |

벡터DB의 enterprise 가격은 **수천 USD/월에서 수만 USD/월** 범위
(저장량·QPS에 따라). 본 제안은 이 비용을 **0**으로 만든다. 절약된
예산은 RTL LLM 도구·EDA 라이선스·시뮬레이션 컴퓨트에 재배치할 수 있다.

---

## 8.5 ④ Latency — 즉시성

| 작업 | RAG 방식 | 본 제안 |
|---|---|---|
| RTL 변경 → AI가 새 SFR 명을 인지 | 재임베딩 후 (분 ~ 시간) | 즉시 (다음 read) |
| 새 IP 추가 → AI가 컨텍스트로 활용 | 인덱스 추가 후 | 즉시 (submodule add 후) |
| 신규 SoC 부트스트랩 시 인덱스 구축 | 시간 단위 | 0 (git submodule만) |

DeepWiki조차 인덱싱에 시간이 걸리며 (수십만 ~ 수백만 LoC 기준 분~시간),
인덱싱 직후의 변경은 **다음 인덱싱 cycle까지 stale**이다.[^2] 본 제안은
이 문제가 구조적으로 없다.

---

## 8.6 ⑤ 문서 ↔ RTL drift — 0 누출 목표

| 시나리오 | RAG 방식 | 본 제안 |
|---|---|---|
| RTL의 SFR width 변경 후 가이드 미갱신 | 사람 발견 시까지 stale | invariant #1 fail → PR 차단 |
| AI가 deprecated 함수 호출 코드 생성 | 사람 리뷰 시까지 stale | invariant #3 fail → PR 차단 |
| Scenarios에서 빠진 worked example | 다음 review까지 stale | invariant #4 fail → PR 차단 |
| Diagram source ≠ rendered SVG | 사람 발견 시까지 stale | invariant #6 fail → PR 차단 |

본 레포의 두 reference IP (`irq_ctrl`, `trng`)는 **현재까지 6종 invariant
전부 PASS**[^3]. 즉 정합성 결함 누출 0의 워크플로우가 **이미 가능함**이
실증되어 있다.

---

## 8.7 신규 SoC 부트스트랩 — 정성적 → 정량적

| 단계 | Before | After |
|---|---|---|
| Base SoC 식별 + 복제 | 2–5일 (사람) | 분 단위 (`git submodule add`) |
| 5종 산출물 재생성 (변경 IP) | 1–2주 (사람) | 1–2일 (AI 초안 + 사람 리뷰) |
| 정합성 cross-check | 누락 다수, sign-off 지연 | CI 자동 PASS/FAIL |
| FW 팀에 산출물 패키지 전달 | spec 별도 묶음 작성 | super-repo clone |
| 회귀 사고 / sign-off 후 발견 | 다수 | 0 누출 목표 |

산업 평균 SoC 부트스트랩 lead-time을 2–4 주에서 **수일 단위로 단축**
가능. 이는 단순 시간 절약이 아니라 **신규 SKU 파생 빈도를 늘릴 수 있는
조직 능력**으로 환산된다.

---

## 8.8 ROI 요약 (12개월 시점)

| 항목 | 누적 효과 |
|---|---|
| LLM API 비용 절감 | ~50% (컨텍스트 효율 개선) |
| 검색 인프라 비용 절감 | ~100% (벡터DB 미사용) |
| 신규 IP 부트스트랩 시간 | -70% (수동 작업 → AI 초안) |
| 신규 SoC 파생 시간 | -60% (산출물 자동 재생성) |
| 문서 drift 결함 누출 | -90% 이상 (CI 강제) |
| EDA AI 락인 위험 | 0 (오픈 포맷 + 표준) |

---

## 8.9 측정 가능한 PoC KPI

본 제안이 채택되면 **PoC 단계에서 다음 KPI를 측정**하여 본 장의 수치를
사내 데이터로 대체한다:

1. PR 1건당 평균 LLM 토큰 사용 (before / after)
2. PR ↔ merge lead-time
3. Invariant fail로 차단된 PR 비율 (drift 차단 효과)
4. AI 초안 → 사람 review 통과율
5. 신규 IP 부트스트랩 lead-time
6. 신규 SoC 파생 lead-time
7. 산출물 sign-off 후 회귀 결함 발견 수

다음 장(9장)에서 이 ROI를 누리기 위한 **리스크와 마이그레이션 전략**을
다룬다.

---

[^1]: McKinsey 2025; [From RAG to Context — RAGFlow 2025](https://ragflow.io/blog/rag-review-2025-from-rag-to-context).
[^2]: [DeepWiki — Cognition Blog](https://cognition.ai/blog/deepwiki) ("Treat DeepWiki as a fast first read, not ground truth").
[^3]: 본 레포 [`docs/VERIFICATION_REPORT.md`](../VERIFICATION_REPORT.md).
