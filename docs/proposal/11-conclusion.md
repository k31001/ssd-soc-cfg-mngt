# 11. 결론

본 보고서는 10개의 장을 통해 다음 명제를 정당화했다:

> **Markdown + Git + 4-repo Submodule + SystemRDL + RTL-Grounded CI** 워크플로우는
> SoC 산출물 관리의 **AI 시대 표준**이며, Word/Excel/Confluence/RAG/MCP 기반
> 검색 방식 대비 **정확성·비용·정합성·속도 모든 축에서 우월**하다.

이 결론은 우리만의 주장이 아니다:
- Anthropic Claude Code 팀이 자신들의 도구에서 같은 결정을 내렸다 (RAG → grep-first).[^1]
- DeepWiki/Devin이 "코드 옆에 사는 문서"를 향해 가고 있다 — 우리는 그 종착점에 서 있다.[^2]
- Diátaxis가 산업 표준 문서 프레임워크이며 docs-as-code와 결합된다.[^3]
- IEEE 1685-2022가 SFR 표준을 확정했고, SystemRDL이 그 author format으로 자리 잡았다.[^4]
- NVIDIA·OSS 진영이 RTL LLM 학습 데이터로 잘 정돈된 git 산출물을 전제한다.[^5]

우리가 추가한 것은 **"이 6개 흐름을 SSD Controller 도메인 + FW/Test 분리
+ HW/SW coverif 흐름으로 묶은 한 워크플로우"** 이다.

---

## 11.1 3개월 후 도달하는 모습

| 측면 | Day 90 상태 |
|---|---|
| 산출물 위치 | RTL · Doc · FW · Test 4-repo, 각자 명확한 경계 |
| 문서 포맷 | 모두 Markdown + SystemRDL (Word/Excel 0건) |
| SW-HW 계약 | Doc Repo에서 단일 출처. FW · Test가 같은 doc-tag로 정렬 |
| 검증 환경 | FPGA · Veloce · Zebu에서 FW 실행 + SSD Host에서 Python coverif |
| 정합성 | Doc D1–D5 · FW F1–F3 · Test T1–T4 · Release R1 모두 PR-blocking |
| AI 컨텍스트 | RAG/MCP 미사용. submodule 직접 read로 결정론적 |
| Release 단위 | 4-tuple (`rtl-v* × doc-v* × fw-v* × test-v*`) 한 줄로 식별 |
| 신규 SoC 부트스트랩 | FW Repo · Test Repo만 fork → submodule pin → 즉시 시작 |

---

## 11.2 만약 변환을 미루면 — 기회비용

| 시간이 흐름에 따라 | 변환 안 한 경우 |
|---|---|
| AI 코딩 도구 적용 시도 | 컨텍스트 부족으로 효과 50% 이하 머묾 (RAG 한계) |
| 신규 SoC 파생 | 사람의 산출물 복제·수정 비용 누적, 매번 처음부터 |
| EDA 벤더 AI 도입 압력 | 락인된 솔루션 외 선택지 없음 |
| 외주 IP 흡수 | 포맷 비호환·정합성 격차 누적 |
| LLM Wiki / DeepWiki 류 확산 | 우리는 그 입력(잘 정돈된 git)을 만들어두지 못함 |
| FW / Test의 doc 정렬 drift | "어느 doc 버전으로 검증한 것인가" 가 불분명한 채 release |

**가장 큰 기회비용은 인프라 비용이 아니라, 우리 SoC 산출물이 AI 시대의
입력으로 변환 가능한 상태로 정돈되지 못한다는 점**이다. 매년 변환 비용은
누적되고, 시점이 늦어질수록 비용이 커진다.

---

## 11.3 마무리

> *"문서가 코드 옆에 살고, AI가 그 문서를 직접 읽고, CI가 그 정합성을
> 검사한다. 펌웨어는 FPGA·Veloce·Zebu에서 동작하고, SSD Host의 Python이
> 그것을 실제 NVMe 명령으로 구동한다."*

이 두 문장이 본 보고서의 전부이다. 우리는 그 두 문장을 **4-repo 토폴로지 ·
SystemRDL · 12주 일제 전환 step-by-step · 산업 평균 근거**로 풀어냈다.

3개월 후의 회고에서는 산업 평균 수치 대신 **사내 실측 데이터**로 본 제안의
효과를 검증할 것이다.

---

[^1]: §1.3, §2.3, §7.3 참고. [Why Claude Code Chose ripgrep](https://rust-trends.com/posts/ripgrep-claude-code/).
[^2]: §7.2 참고. [DeepWiki](https://deepwiki.com/).
[^3]: §3.2, §7.5 참고. [Diátaxis](https://diataxis.fr/).
[^4]: §2.2, §7.6 참고. [IEEE 1685-2022](https://ieeexplore.ieee.org/document/10054520), Accellera SystemRDL 2.0.
[^5]: §7.7 참고. [ChipNeMo](https://arxiv.org/html/2311.00176v4).
