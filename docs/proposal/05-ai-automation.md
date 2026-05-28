# 5. AI 자동화 — Claude Code 가 개발자 + 검증자

본 장은 AI 의 역할을 두 가지로 명확히 한다:

1. **Developer**: Claude Code 가 HAL.c · FW driver/app · Python coverif 를 작성.
2. **Self-Verifier**: 작성 직후 자기 출력물을 doc invariant 와 비교, PR 전에
   환각을 차단.

그리고 Claude 가 어디를 참조하는가 — **참조 위계** — 를 구조적으로 정의한다.

---

## 5.1 Claude Code 의 작업 범위 (5가지 시나리오)

| # | 실행 저장소 | 입력 (Claude 가 read) | 출력 (Claude 가 write) | 검증 게이트 |
|---|---|---|---|---|
| A | **Design Repo** | RTL Repo `*.sv` (fetch) | DLD §5 shadow zone update 보조 + §1-4 초안 | D1 / D2 / D3 (사람 검토) |
| B | **RDL Repo** | RTL Repo + DLD | `<ip>.rdl` shadow update 보조 + field `desc` 초안 | R1 / R2 (사람 검토) |
| C | **PG Repo** | Design + RDL (submodule) | §6 worked example 초안 · §8 pitfall 후보 (incident log 추출) | P1–P4 (SW lead 검토) |
| D | **HAL Repo** | RDL + PG (submodule) | `HAL.c` 본문 (`HAL.h` 는 peakrdl) | H1 / H2 / H3 |
| E | **FW Repo** | HAL + PG + RDL + Design + Spec (submodule) | driver / app firmware 패치 | F1–F5 + host smoke |
| F | **Test Repo** | PG + RDL + Design + Spec (submodule) | Python coverif scenario | T1–T5 |

각 시나리오의 공통 특징:
- **Claude 는 git 안의 마크다운 / RDL / XML / PDF-extracted MD / C / Python 을 직접 read** 한다 (RAG·MCP 없음).
- **PR 전에 Claude 가 자기 출력물을 자체 검증** (§5.3).
- **CI invariant** 가 최종 신뢰의 관문 — Claude 의 자체 검증이 통과해도 CI 가 다시 본다.

---

## 5.2 참조 위계 — RTL 직접 참조 금지

FW · Test (그리고 Claude) 가 무엇을 어떤 순서로 보는지 명확한 규칙:

```
┌───────────────────────────────────────────────────┐
│ Primary (기본)                                     │
│   • PG (Programmer's Guide)  — SW-HW 계약        │
│   • RDL (SystemRDL)          — 레지스터 사양     │
├───────────────────────────────────────────────────┤
│ Secondary (Primary 가 부족할 때만)                  │
│   • DLD §1-4 (Design Repo)   — RTL 구현 디테일   │
├───────────────────────────────────────────────────┤
│ Background (한 번 읽고 끝)                          │
│   • HLD                       — IP 개념·블록도    │
├───────────────────────────────────────────────────┤
│ Reference (필요 시 grep)                            │
│   • Spec Repo MD extracts     — NVMe/PCIe/ONFI    │
├───────────────────────────────────────────────────┤
│ 🚫 금지                                            │
│   • RTL Repo (*.sv)           — 절대 직접 참조 X │
└───────────────────────────────────────────────────┘
```

### 왜 RTL 직접 참조 금지인가
- **추상화 경계 보존**. RTL 은 구현의 진실이지만, FW/Test 가 그것을 직접 보면 PG/RDL/DLD 가 부실해도 어떻게든 동작 — 결국 문서가 무용지물이 됨.
- **문서 부실 신호**. FW/Test 개발자가 "RTL 봐야겠다" 고 느끼는 순간이 곧 **PG/DLD 가 부족하다는 버그 리포트**. RTL 참조 금지가 그 피드백 루프를 강제.
- **권한 분리 보강**. RTL 은 SW 팀에 노출될 필요가 없는 산출물.
- **AI 컨텍스트 절약**. Claude 가 `*.sv` 를 일일이 안 봐도 된다.

### 구조적 강제 (§4.2 의 P4 · F3 · T4 invariant)
- PG Markdown 안에 `*.sv` 직접 링크 → **P4 fail**.
- FW source 에 RTL header `#include` → **F3 fail** (정적 분석).
- Test source 에 RTL path 언급 → **T4 fail** (regex/import 검사).

문화·convention 이 아니라 CI 가 강제하는 규칙.

### Claude Code 의 프롬프트 컨벤션

Claude 에게 작업을 시킬 때 시스템 프롬프트에 다음을 포함:

```
You are working in the FW Repo (or Test Repo) of an 8-repo SoC project.

Reference hierarchy (strict):
- Primary: doc/pg/<ip>/PROGRAMMERS_GUIDE.md, doc/rdl/<ip>/<ip>.rdl
- Secondary: doc/design/<ip>/DLD.md §1-4  (only if primary insufficient)
- Background: doc/design/<ip>/HLD.md  (read once)
- Reference: doc/spec/extracted/*.md  (grep on demand)
- FORBIDDEN: any *.sv from RTL Repo (will be blocked by CI; do not attempt)

Workflow:
1. Read primary refs to understand the SW-HW contract.
2. Write the patch.
3. Self-verify against invariants (§5.3) before opening PR.
```

---

## 5.3 Claude 의 자체 검증 (Pre-PR Self-Check)

Claude 가 코드 작성 직후 PR 을 만들기 전에 다음을 실행:

```
1. Re-read PG §6 worked example 의 모든 함수 시그너처
   ↓ 비교
2. Re-read HAL.h (submodule) 의 export
   ↓ 일치?
3. 작성한 HAL.c 의 함수 시그너처
   ↓ 일치?
   
4. (Test Repo 인 경우) PG §6 의 worked example 개수
   ↓ 일치?
5. 작성한 sc_*.py 의 scenario 개수
   
6. RTL 직접 참조 grep check
   ↓ 0 건?
   
7. Self-report:
   "12/12 PG §6 worked examples covered, 8/8 §8 pitfalls regression added,
    0 RTL direct references, HAL.h signature match: OK. Opening PR."
```

이 자체 검증의 가치:
- **PR 노이즈 감소** — CI 가 fail 할 PR 을 미리 차단.
- **Claude 의 환각 일찍 발견** — 잘못 작성하면 자기가 잡음.
- **사람 리뷰어의 부담 감소** — "기본적인 정합성은 통과한 PR"만 보면 됨.

CI 와의 차이:
- Claude 의 self-check 는 **신뢰의 1차 필터**. 빠르지만 권위는 없음.
- CI 는 **신뢰의 마지막 관문**. 느리지만 권위 있음. Claude 의 self-check 결과를 의심해도 됨.

---

## 5.4 컨텍스트 주입의 결정성 — RAG 와의 비교

### RAG/MCP 방식
```
[질의] "nvme_ctrl HAL admin queue enable 구현"
   ↓
[Vector search] top-k 청크 회수 (수십 개)
   ↓
[LLM context] 무관·중복 청크 다수
   ↓
[출력] 환각 위험
```

### 본 제안 (FW Repo 시점)
```
[질의] "nvme_ctrl HAL admin queue enable 구현"
   ↓
[Claude 도구]   Read("doc/pg/nvme_ctrl/PROGRAMMERS_GUIDE.md")   # submodule, primary
              Read("doc/hal/include/nvme_ctrl_hal.h")          # submodule, primary
              Read("fw/hal/nvme_ctrl_hal.c")                   # 현재 구현
   ↓
[LLM context] 정확히 3개 파일 — 모두 working copy
   ↓
[출력] HAL.c 패치 → 자체 검증 → FW CI (F1+host smoke) → PR
```

| 측면 | RAG/MCP | Submodule 직접 read |
|---|---|---|
| 같은 질의 → 같은 컨텍스트 | 인덱스 상태 의존 | git SHA pin 이면 항상 동일 |
| 컨텍스트 출처 | 인덱스 메타데이터 | `file_path:line` 직접 |
| 토큰 효율 | 청크 다수 = 폭증 | 필요한 파일만 |
| Privacy | 외부 인프라 가능 | git 안에서 끝 |
| **참조 위계 강제** | 어려움 (검색이 우선순위 안 봄) | **프롬프트 + grep 으로 강제** |

---

## 5.5 표준 Spec PDF (NVMe / PCIe / ONFI) 의 참조 (item 7)

NVMe 2.0, PCIe 5.0, ONFI 5.0 같은 표준 spec 은 본 SoC 개발의 **외부 입력**.
PDF 가 원본 (수백 페이지).

**검토한 옵션 3가지**:

| 옵션 | 장점 | 단점 |
|---|---|---|
| (a) 모든 PDF 를 Claude 세션에 첨부 | 단순 | 매 세션마다 컨텍스트 폭증, 토큰 비용 |
| (b) **별도 Spec Repo + submodule** | git 결정론, MD extract 로 AI-friendly, 버전 pin | git LFS 필요 (PDF 큼) |
| (c) 별도 서버 + MCP 검색 | on-demand | 인프라 부담, latency, MCP 토큰 비용 (§1.3) |

**본 제안의 선택 — (b) Spec Repo + submodule**:

- Spec Repo 구조:
  ```
  spec-repo/
  ├─ pdfs/                          # git LFS (원본, 법적 참조)
  │   ├─ nvme-2.0.pdf
  │   ├─ pcie-5.0-base.pdf
  │   └─ onfi-5.0.pdf
  ├─ extracted/                     # 자동 추출 Markdown (AI-friendly)
  │   ├─ nvme-2.0/
  │   │   ├─ ch01-introduction.md
  │   │   ├─ ch04-admin-commands.md
  │   │   └─ ch07-namespace-management.md
  │   ├─ pcie-5.0/
  │   └─ onfi-5.0/
  └─ index.json                     # 섹션 인덱스 (grep 보조)
  ```
- 추출: `pdftotext` + 사내 후처리 (장/절 분리, 표 정리). PR 시 PDF 와 MD 가 짝.
- FW · Test Repo 가 `doc/spec/` 으로 submodule pin.
- Claude 는 `grep -rn 'admin queue' doc/spec/extracted/nvme-2.0/` 같은 식으로 **on-demand grep**, 필요한 챕터만 Read.
- 원본 PDF 가 필요할 때 (예: 법적 compliance review) 사람이 LFS 에서 fetch.
- 새 spec 버전 → Spec Repo 가 새 tag → FW/Test 가 `spec-v*` submodule update.

**왜 MCP 가 아닌가**:
- MCP 검색은 §1.3 의 토큰 폭증·latency 폭증 문제 그대로.
- spec 은 변경 빈도가 낮음 (수년) — on-demand 검색이 결정론적 pin 보다 약하다.
- 외부 인프라 의존이 늘어남 — submodule 한 줄로 끝나는 일을 서비스로 만들 이유 없음.

**왜 모든 PDF 첨부가 아닌가**:
- Claude 세션마다 수십 MB 의 spec 텍스트가 컨텍스트에 들어가는 비용 무한.
- 특정 질의 ("namespace identify 시퀀스") 에 필요한 건 NVMe 의 일부 챕터.

---

## 5.6 AI 자동화의 안전 boundary

> **원칙**: Claude 는 RTL 을 자동으로 수정하지 않는다. PG 와 HLD/DLD §1-4 도
> 사람 author. 사실 정합성은 자동화하고, **의도**는 사람이 정의한다.

| Claude 가 자동 생성하는 산출물 | Claude 가 자동 수정하지 않는 산출물 |
|---|---|
| Design 의 shadow zone 보조 · §1-4 초안 | RTL Repo 의 `*.sv` (의도 농축) |
| RDL 의 shadow update 보조 · field `desc` 초안 | HLD 전체 (Architect 영역) |
| IP-XACT XML, HAL.h (auto-gen, peakrdl) | DLD §1-4 (RTL designer 설계 의도) |
| PG §6 worked example 초안 (기존 사용 패턴 추출) | PG 의 SW-HW 계약 의사결정 |
| HAL.c 본문 (Claude + 검토) | FW 의 ISR / 락 / DMA 정책 |
| FW driver/app 패치 | Test 의 측정·assertion 의도 |
| Python coverif scenario | Spec PDF / 추출 MD 의 의미 해석 |
