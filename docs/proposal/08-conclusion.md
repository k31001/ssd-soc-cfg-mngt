# 8. 결론

## 8.1 핵심 명제

> **Markdown + Git Submodule + SystemRDL + Claude Code + RTL-Grounded CI** 워크플로우는 SoC 산출물 관리의 **AI 시대 표준**이며, Word/Excel/Confluence/RAG/MCP 대비 모든 축에서 우월하다.

이 결론은 우리만의 주장이 아니다:
- Anthropic Claude Code 팀이 RAG → grep-first 로 같은 결정 ([source](https://rust-trends.com/posts/ripgrep-claude-code/))
- DeepWiki/Devin 이 "코드 옆에 사는 문서" 로 수렴 ([source](https://deepwiki.com/))
- IEEE 1685-2022 가 SFR 표준 확정, SystemRDL 이 author format 으로 정착
- Diátaxis 가 산업 표준 문서 프레임워크
- NVIDIA ChipNeMo 등 RTL LLM 이 잘 정돈된 git 산출물을 전제

우리가 추가한 것은 **6개 흐름을 SSD Controller 도메인 + FW/Test 분리 + HW/SW coverif + Phase 1/2 + Claude dev-verifier 로 묶은 한 워크플로우**.

## 8.2 Day 90 도달 상태

| 영역 | 상태 |
|---|---|
| 저장소 | 8-repo 운영 중 (RTL · Design · RDL · PG · HAL · Spec · FW · Test) |
| 문서 포맷 | 모두 Markdown + SystemRDL (Word/Excel 0건) |
| SW-HW 계약 | PG Repo 가 단일 출처, FW · Test 가 같은 doc-tag 로 정렬 |
| 검증 환경 | FW on FPGA · Veloce · Zebu + Python on SSD Host |
| 정합성 | 8 CI invariant + Release gate R1 모두 PR-blocking |
| AI | Claude Code 가 HAL.c · FW · Test 작성 + self-check, CI 가 마지막 관문 |
| 참조 위계 | PG/RDL primary · DLD fallback · **RTL 직접 참조 0** (CI 강제) |
| Release 단위 | 9-tuple (`rtl × design × rdl × pg × hal × spec × fw × test`) |
| 신규 SoC 부트스트랩 | FW · Test fork → submodule pin → 즉시 시작 |

## 8.3 미루면 잃는 것

| 시간이 흐를수록 | 변환 안 한 경우 |
|---|---|
| AI 코딩 도구 적용 | 컨텍스트 부족으로 효과 50% 이하 (RAG 한계) |
| 신규 SoC 파생 | 사람의 산출물 복제·수정 비용 누적 |
| EDA 벤더 AI | 락인된 솔루션만 선택지 |
| 외주 IP 흡수 | 포맷 비호환·정합성 격차 누적 |
| FW · Test 의 doc 정렬 drift | "어느 doc 으로 검증했나" 가 불분명 |

**가장 큰 기회비용은 인프라가 아니라, SoC 산출물이 AI 시대 입력으로 변환 가능한 상태로 정돈되지 못한다는 점.** 매년 변환 비용은 누적된다.

## 8.4 마무리

> *"문서가 코드 옆에 살고, AI 가 그 문서를 직접 읽고, CI 가 그 정합성을 검사한다.
> 펌웨어는 FPGA·Veloce·Zebu 에서 동작하고, SSD Host 의 Python 이 NVMe 명령으로 그것을 구동한다."*

이 두 문장이 본 보고서의 전부이다. 3개월 후 사내 실측 데이터로 본 제안을 다시 검증한다.
