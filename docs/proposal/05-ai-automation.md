# 5. AI 자동화 — Claude Code 가 개발자 + 자체 검증자

## 5.1 Claude 의 두 가지 역할

1. **Developer**: HAL.c · FW driver/app · Python coverif scenario 작성.
2. **Self-Verifier**: PR 전에 자기 출력물을 invariant 와 비교, 환각 1차 차단.

CI 는 신뢰의 마지막 관문. Claude self-check 는 noise 절감.

## 5.2 참조 위계 — RTL 직접 참조 금지

```
Primary   : PG (Programmer's Guide), RDL (SystemRDL)
Secondary : DLD §1-4 (Primary 부족할 때만)
Background: HLD (한 번 읽음)
Reference : Spec MD extracts (grep on-demand)
🚫 금지    : RTL Repo (*.sv)
```

**왜 RTL 금지인가**:
- **추상화 보존**. RTL 을 직접 보면 PG/RDL/DLD 가 부실해도 동작 → 결국 문서 무용지물.
- **문서 부실 신호**. "RTL 봐야겠다" 고 느끼는 순간이 PG/DLD 의 버그 리포트.
- **구조적 강제**. P4 (PG) · F3 (FW) · T4 (Test) invariant 가 PR 차단.

### Claude 프롬프트 컨벤션

```
Reference hierarchy (strict):
- Primary: doc/pg/<ip>/PROGRAMMERS_GUIDE.md, doc/rdl/<ip>.rdl
- Secondary: doc/design/<ip>/DLD.md §1-4
- Background: doc/design/<ip>/HLD.md
- Reference: doc/spec/extracted/*.md (grep)
- FORBIDDEN: any *.sv (CI will block; do not attempt)

Workflow: read primary → write patch → self-verify → PR.
```

## 5.3 Claude 의 6가지 작업 시나리오

| # | 저장소 | 입력 (Claude 가 read) | 출력 (Claude 가 write) | 검증 |
|---|---|---|---|---|
| A | Design | RTL fetch | DLD §5 shadow + §1-4 초안 | D1 / D2 |
| B | RDL | RTL + DLD | `.rdl` shadow + field `desc` 초안 | R1 / R2 |
| C | PG | Design + RDL (submodule) | §6 worked example 초안 + §8 후보 (incident log) | P1–P4 |
| D | HAL | RDL + PG (submodule) | `HAL.c` 본문 (HAL.h 는 peakrdl) | H1 / H2 / H3 |
| E | FW | HAL+PG+RDL+Design+Spec (submodule) | driver / app firmware 패치 | F1–F4 |
| F | Test | PG+RDL+Design+Spec (submodule) | Python coverif scenarios | T1–T5 |

## 5.4 Pre-PR Self-Check (Claude 의 자체 검증)

PR 만들기 전에 Claude 가 자체 수행:

```
1. PG §6 worked example 의 모든 함수 시그너처 re-read
2. HAL.h (submodule) export re-read
3. 작성한 HAL.c 의 시그너처 비교 → match?
4. Test 인 경우: PG §6 worked example 개수 vs sc_*.py 개수
5. RTL 직접 참조 grep check → 0?
6. Self-report: "12/12 worked examples covered, 0 RTL refs, signature match: OK"
```

가치:
- PR 노이즈 ↓ (CI fail 할 PR 미리 차단)
- 사람 리뷰어 부담 ↓ ("기본 정합성 통과" PR 만 본다)
- Claude 환각 일찍 발견

## 5.5 컨텍스트 주입 — RAG 와의 결정적 차이

| 측면 | RAG/MCP | submodule 직접 read |
|---|---|---|
| 같은 질의 → 같은 컨텍스트 | 인덱스 상태 의존 | git SHA pin = 항상 동일 |
| 출처 추적 | 메타데이터 | `file:line` 직접 |
| 토큰 효율 | 청크 다수 = 폭증 | 필요한 파일만 |
| 검색 인프라 | 벡터DB 운영 | 0 |
| Privacy | 외부 인프라 가능 | git 안 |
| 참조 위계 강제 | 어려움 | **프롬프트 + grep + CI** |

> "Boris Cherny's team tested RAG vs agentic search. **Agentic search won — not narrowly.**"
> — Anthropic Claude Code 팀, 사유: precision · simplicity · freshness · privacy ([source](https://rust-trends.com/posts/ripgrep-claude-code/))

본 제안은 그 결정을 **SoC 산출물 도메인에 가장 먼저 적용**한다.

## 5.6 표준 Spec PDF — Spec Repo + submodule

NVMe 2.0, PCIe 5.0, ONFI 5.0 같은 표준은 외부 입력. 3개 옵션 비교:

| 옵션 | 평가 |
|---|---|
| (a) 모든 PDF 를 Claude 세션에 첨부 | ❌ 매 세션 컨텍스트 폭증 |
| **(b) Spec Repo + submodule** | ✅ git 결정론, MD extract AI-friendly, 버전 pin |
| (c) MCP 서버 | ❌ latency · 인프라 · MCP 토큰 비용 |

**선택: (b)**.

```
spec-repo/
├─ pdfs/                  # git LFS (원본, 법적 참조)
│   ├─ nvme-2.0.pdf
│   └─ pcie-5.0-base.pdf
├─ extracted/             # 자동 MD (AI-friendly)
│   ├─ nvme-2.0/ch04-admin-commands.md
│   └─ pcie-5.0/...
└─ index.json
```

- 추출: `pdftotext` + 사내 후처리 (장/절 분리)
- FW · Test 가 `doc/spec/` 로 submodule pin
- Claude: `grep -rn 'admin queue' doc/spec/extracted/nvme-2.0/` on-demand
- 원본 PDF 는 법적 compliance 시 사람이 LFS fetch

## 5.7 AI 자동화의 boundary

> **원칙**: Claude 는 RTL 을 자동 수정하지 않는다. 사실 정합성은 자동, **의도**는 사람.

| Claude 자동 생성 | Claude 자동 수정 안 함 |
|---|---|
| shadow zone 보조 (Design · RDL · PG) | RTL 의 `*.sv` |
| HAL.h (peakrdl), HAL.c 본문 | HLD 전체, DLD §1-4 |
| PG §6 worked example 초안 | PG 의 SW-HW 계약 의사결정 |
| FW driver/app 패치 | FW 의 ISR/락/DMA 정책 |
| Python coverif scenario | Test 의 측정·assertion 의도 |
| Spec MD extract 갱신 | Spec PDF 의 의미 해석 |

→ §6 가 이 Claude 작업이 Phase 1/2 전체 흐름 안에서 어떻게 흘러가는지 보인다.
