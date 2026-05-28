# Executive Summary

## 한 줄 명제

> **8개 git 저장소 + Markdown · SystemRDL + Claude Code 가 RTL 변경을 두 페이즈로 전파**.
> 문서 ↔ 코드 정합성은 CI invariant 가, 환각은 Claude 의 self-check + CI 가 차단.

## 무엇을 하는가

| 단계 | 산출 |
|---|---|
| **Phase 1** (자동 + 사람 검토) | RTL → Design (HLD+DLD) → RDL (SystemRDL) → PG (Programmer's Guide) |
| **Phase 2** (Claude Code + CI) | RDL → HAL.h auto-gen + HAL.c · FW · Test (Python coverif) |

8개 저장소 · 9-tuple release (`rtl × design × rdl × pg × hal × spec × fw × test`).

## 핵심 규칙 4개

1. **참조 위계**: FW/Test (와 Claude) 는 PG/RDL 만 본다. DLD 는 fallback. **RTL 직접 참조 금지** (CI 가 차단).
2. **Hybrid 정합성**: 문서마다 `authored zone` (사람 자유) + `shadow zone` (자동 sync, 수동 차단). 사람 지식 보존 + drift 차단.
3. **Claude = developer + self-verifier**: HAL.c · FW · Test 를 Claude 가 작성, PR 전에 자기 출력물을 invariant 와 비교. CI 가 마지막 관문.
4. **표준 spec PDF**: Spec Repo + submodule (LFS PDF + 자동 MD extract). MCP·전체 첨부 모두 배제.

## 왜 이게 옳은가 (산업 근거)

- **Anthropic Claude Code 가 같은 결정**. 초기 RAG/벡터DB 를 폐기하고 grep-first agentic search 로 전환. 사유: precision · simplicity · freshness · privacy. ([source](https://rust-trends.com/posts/ripgrep-claude-code/))
- **DeepWiki 의 한계 자인**. "Treat DeepWiki as a fast first read, **not ground truth**." — AI 생성 wiki 가 검증 못하는 영역을 우리는 CI invariant 로 메움. ([source](https://deepwiki.com/))
- **SystemRDL · IP-XACT 1685-2022** 는 SFR 의 국제 표준. peakrdl OSS 툴체인.

## 정량 효과 (산업 평균 추정, PoC 후 실측 갱신)

| 축 | Before | After |
|---|---|---|
| LLM 토큰 / PR (예: HAL enable) | ~13k | **~5k** (-60%) |
| 검색 인프라 (벡터DB) | $$/월 | **0** |
| 신규 IP 부트스트랩 | 1–2주 | **1–2일** |
| 문서 ↔ RTL drift 결함 누출 | 다수 | **0 목표** (CI 차단) |
| AI 코딩 생산성 (well-defined task, McKinsey 2025) | baseline | **+20–45%** |

## 컷오버 — 3개월 (12주) 일제 전환

| 기간 | 단계 |
|---|---|
| Week 1–2 | 8 repo 셋업 + 변환 도구 (`docx2md` · `xlsx2rdl` · `pdf2md` · `peakrdl`) |
| Week 2–5 | 전 IP **bulk 변환** + Design 수동 보정 |
| Week 4–7 | PG §6 worked example 작성 (Claude 보조) |
| Week 5–9 | HAL · FW · Test 이관, Claude dev-verifier 가동 |
| Week 9–10 | CI 게이트 warning→**blocking**, Release gate R1 활성 |
| Week 10–12 | 첫 9-tuple release + 컷오버 (Word/Excel/Confluence read-only) |

**부분 채택 없음** · **전 IP 동시** · **12주 데드라인**.

→ 세부 단계 [§7 로드맵](07-roadmap.md). 아키텍처 [§2](02-proposal.md).
