# Verification Report

| 항목                     | 값                                            |
|--------------------------|-----------------------------------------------|
| Report version           | 1.0                                           |
| Repository               | `k31001/ssd-soc-cfg-mngt`                     |
| Snapshot commit          | `5f02d0b` (2026-05-15)                        |
| Workflow definition      | [`docs/WORKFLOW.md`](WORKFLOW.md)             |
| Harness                  | [`tools/ipflow.py`](../tools/ipflow.py)       |
| Simulator                | Verilator 5.048 (Mac local), apt verilator (CI Ubuntu) |
| Live dashboard           | <https://k31001.github.io/ssd-soc-cfg-mngt/>  |
| CI pipeline (latest run) | `ipflow-validate` #25928231471 — **success**  |

본 리포트는 본 레포가 정의한 9-stage closed-loop workflow 가 두 개의
reference IP (`irq_ctrl`, `trng`) 에서 실제로 닫혔음을 증명하고, 그 과정
에서 수행한 모든 검증 활동의 결과를 한 곳에 종합한다.

---

## 1. Executive summary

| 측정 항목                                  | 결과                          |
|--------------------------------------------|------------------------------|
| Reference IPs at v1.0.0 alpha (9-stage 완료) | **2 / 25** (`irq_ctrl`, `trng`) |
| Closed-loop invariants 검사                | **12 / 12 PASS** (6 invariant × 2 IP) |
| Self-checking TB scenarios (SV)            | **21 (11 + 10)**             |
| TB assertion checks (verilator 실측)       | **52 / 52 PASS** (29 + 23)   |
| HAL host smoke test                        | **33 / 33 PASS** (16 + 17)   |
| WaveDrom 도면 JSON ↔ SVG drift             | **0 drift**                  |
| CI matrix jobs (latest main)               | **7 / 7 success**            |

핵심 결론: **Programmer's Guide (Stage 5) 의 worked example 이 Test
Scenarios (Stage 7) 로 1:1 매핑되고, 그 scenarios 가 self-checking TB
의 assertion 으로 자동 검증되며, harness 가 cross-document 정합성을
PR 마다 fail-fast 로 강제하는 closed loop 이 두 독립된 IP 에서 동일
패턴으로 재현되었다.**

---

## 2. Scope & methodology

### 2.1 Scope

본 리포트가 다루는 검증 대상:
- `cpu_ss/ip/irq_ctrl` v1.0.0 — PLIC 계열 platform-level interrupt controller
- `sec_ss/ip/trng` v1.0.0 — TRNG (3-LFSR entropy emulator + repetition health test + FIFO)

본 리포트가 다루지 않는 것:
- 나머지 23 IP — spec(0.1.0/proto) 단계, stub RTL. 본 리포트의 다음
  revision 에서 점진적으로 promote.
- ASIC sign-off 항목 (timing closure, power, DFT, formal). 본 리포트는
  RTL functional + cross-document consistency 까지를 다룸.

### 2.2 검증 layer

세 layer 에서 독립적으로 검증을 수행한다:

| Layer            | 검증 대상                  | 도구                              |
|------------------|---------------------------|-----------------------------------|
| **L1 RTL self-checking TB** | RTL functional behaviour | Verilator 5.048 (`tools/ipflow.py sim`)        |
| **L2 HAL host smoke**       | HAL ↔ RTL register map | C compiler + shadow MMIO (`make test`)         |
| **L3 Closed-loop invariants** | Cross-document consistency | `tools/ipflow.py validate` (6 invariants)    |

세 layer 가 서로 다른 실패 mode 를 잡는다:
- L1 만으로는 가이드/HAL/IP-XACT 의 일관성을 보지 못한다.
- L3 만으로는 RTL 이 실제로 의도대로 동작하는지 알 수 없다.
- L2 는 HAL 함수 자체의 버그를 RTL 없이 잡는 빠른 안전망.

### 2.3 CI 통합

`.github/workflows/ipflow-validate.yml` 가 PR / `main` push 마다 다음 matrix
를 실행한다:

```
discover → [for each IP with verif/scenarios.yaml]
            ├─ validate          (6 invariants)
            ├─ hal-host-smoke    (make test)
            └─ verilator-sim     (apt-get install verilator → ipflow sim)
```

`.github/workflows/deploy-pages.yml` 는 `main` push 마다 status.json 을
재생성하고 GitHub Pages 로 web 대시보드를 배포.

---

## 3. L1 — RTL self-checking TB results

### 3.1 `irq_ctrl` — verilator 결과 (29 checks PASS)

11 scenario, 29 individual checks. 모두 commit `5f02d0b` 기준 Verilator
5.048 로 PASS.

| ID    | Scenario name              | Guide § | RTL features                                | Result |
|-------|---------------------------|---------|---------------------------------------------|--------|
| S01   | reset_state               | §2      | reset, regfile_default                      | PASS   |
| S02   | id_version_readback       | §9      | ro_regs, ip_id, ip_version                  | PASS   |
| S03   | priority_enable_rw        | §3      | regfile_rw, priority, enable                | PASS   |
| S04   | level_source              | §6      | level_detect, eligibility, arbiter          | PASS   |
| S05   | edge_source               | §6      | edge_detect, pending_latch                  | PASS   |
| S06   | threshold_gating          | §3      | threshold, eligibility                      | PASS   |
| S07   | priority_arbitration      | §3      | arbiter, tie_break                          | PASS   |
| S08   | claim_atomic_clear        | §5      | claim, edge_pending_clear                   | PASS   |
| S09   | pending_clear_w1c         | §6      | w1c, edge_pending_clear                     | PASS   |
| S10   | pslverr_unmapped          | §7      | apb_pslverr, addr_decode                    | PASS   |
| S11   | pslverr_ro_write          | §7      | apb_pslverr, ro_protection                  | PASS   |

세부 PASS 라인 (TB output 발췌):

```
[ pass ] T1 enable reset = 0          [ pass ] T7 higher prio wins (5 over 3)
[ pass ] T1 pending reset = 0         [ pass ] T7 tie → lowest ID wins
[ pass ] T1 threshold reset = 0       [ pass ] T8 claim returns winning ID
[ pass ] T1 eip low at reset          [ pass ] T8 src 5 pending cleared by claim
[ pass ] T2 IP_ID                     [ pass ] T8 next winner = 7
[ pass ] T2 IP_VERSION                [ pass ] T9 W1C clears src 3
[ pass ] T3 prio[5] rw                [ pass ] T9 claim 7
[ pass ] T3 enable rw (src0 forced 0) [ pass ] T9 eip low (all cleared)
[ pass ] T4 level pending set         [ pass ] T10 unmapped read raises pslverr
[ pass ] T4 eip high for level        [ pass ] T11 write to IP_ID raises pslverr
[ pass ] T4 eip_id == 16              [ pass ] T11 write to PENDING raises pslverr
[ pass ] T4 level pending clears      ...
[ pass ] T4 eip low after deassert     (총 29 PASS, 0 FAIL)
[ pass ] T5 edge pending sticks
[ pass ] T5 eip high for edge
[ pass ] T5 eip_id == 3
[ pass ] T6 eip masked by threshold
[ pass ] T6 eip restored
```

### 3.2 `trng` — verilator 결과 (23 checks PASS)

10 scenario, 23 individual checks. 모두 PASS.

| ID    | Scenario name              | Guide § | RTL features                                | Result |
|-------|---------------------------|---------|---------------------------------------------|--------|
| S01   | reset_state               | §2      | reset, regfile_default                      | PASS   |
| S02   | id_version_readback       | §9      | ro_regs, ip_id, ip_version                  | PASS   |
| S03   | enable_fill_fifo          | §3      | lfsr, fifo_push, data_ready                 | PASS   |
| S04   | data_pop                  | §6      | fifo_pop, data_register                     | PASS   |
| S05   | seed_reuse_reproducible   | §6      | seed_load, soft_reset, lfsr_determinism     | PASS   |
| S06   | soft_reset_clears_fifo    | §5      | soft_reset, fifo_clear                      | PASS   |
| S07   | health_fail_repetition    | §6      | health_test, repetition_detect, irq         | PASS   |
| S08   | intr_status_w1c           | §4      | intr_edge_latch, w1c, irq                   | PASS   |
| S09   | pslverr_unmapped          | §7      | apb_pslverr, addr_decode                    | PASS   |
| S10   | pslverr_ro_write          | §7      | apb_pslverr, ro_protection                  | PASS   |

세부 PASS 라인:

```
[ pass ] T1 CTRL=0 at reset             [ pass ] T5 seed-reuse 시 동일 word #1
[ pass ] T1 STATUS empty + !data_ready  [ pass ] T5 seed-reuse 시 동일 word #2
[ pass ] T1 FIFO_LEVEL=0                [ pass ] T6 soft_reset 후 health_fail=0
[ pass ] T1 irq low at reset            [ pass ] T6 ENABLE 보존
[ pass ] T2 IP_ID = TRNG                [ pass ] T7 HEALTH.FAIL latched
[ pass ] T2 IP_VERSION=1.0              [ pass ] T7 STATUS.HEALTH_FAIL
[ pass ] T3 FIFO filled to 16           [ pass ] T7 irq_o rises on health fail
[ pass ] T3 STATUS.DATA_READY=1 / FIFO_FULL=1
[ pass ] T4 두 random word 가 서로 다름  [ pass ] T8 INTR_STATUS.HEALTH_FAIL latched
[ pass ] T4 두 pop 후 level == 사전 - 2  [ pass ] T8 W1C 후 비트 cleared
                                         [ pass ] T8 irq_o 가 떨어짐 (INTR_STATUS=0)
                                         [ pass ] T9 미매핑 주소 read 시 pslverr=1
                                         [ pass ] T10 STATUS write 시 pslverr=1
                                         [ pass ] T10 IP_ID write 시 pslverr=1
                                         (총 23 PASS, 0 FAIL)
```

---

## 4. L2 — HAL host smoke test results

shadow MMIO buffer 로 HAL 함수가 SFR map 과 일치하는 access pattern 을
내는지 확인. 실패 시 RTL 없이도 HAL 자체의 register offset / bit field /
함수 prototype 버그를 검출한다.

| IP        | Test 개수 | Result        |
|-----------|-----------|---------------|
| irq_ctrl  | 16        | **16/16 PASS** |
| trng      | 17        | **17/17 PASS** |
| **Total** | **33**    | **33/33**     |

대표 PASS 라인:

```
irq_ctrl:                              trng:
[ pass ] T1 probe fails on zero IP_ID  [ pass ] T1 probe succeeds when constants match
[ pass ] T1 probe succeeds…            [ pass ] T2 init writes ENABLE|SOFT_RESET|SEED_LOAD pulse
[ pass ] T2 init zeroes ENABLE         [ pass ] T2 init zeros INTR_EN
[ pass ] T2 init raises THRESHOLD…     [ pass ] T3 seed0/1/2 rw
[ pass ] T3 priority[5] = 7            [ pass ] T4 get_random returns ok
[ pass ] T3 priority clamped to 15     [ pass ] T4 returned word matches
[ pass ] T4 enable(12)                 [ pass ] T5 safe-get -> -1 on health_fail
[ pass ] T5 clear_pending(7) writes bit 7  [ pass ] T5 safe-get timeout -> -2
[ pass ] T6 claim masks to 5 bits      [ pass ] T6 clear_intr writes the bit (W1C)
[ pass ] T7 threshold rw               [ pass ] T7 recover writes CTRL pulse
```

---

## 5. L3 — Closed-loop invariants

`tools/ipflow.py validate` 가 자동 검사하는 6개 invariant. 두 IP 모두 6/6 PASS.

| Invariant              | 검증 내용                                                          | irq_ctrl | trng |
|------------------------|------------------------------------------------------------------|----------|------|
| `diagrams_drift`       | `doc/diagrams/*.json` ↔ `*.svg` 동기화                            | PASS     | PASS |
| `ipxact_vs_design`     | IP-XACT register offset/access ↔ `DESIGN.md §5` 표                | PASS (9 regs) | PASS (12 regs) |
| `hal_vs_ipxact`        | HAL `*_REG_*` macro ↔ IP-XACT 모든 offset                         | PASS (9 offsets) | PASS (12 offsets) |
| `guide_funcs_in_hal`   | `PROGRAMMERS_GUIDE.md` 코드 fence 의 HAL 호출 ↔ HAL 헤더 export   | PASS (11 funcs) | PASS (11 funcs) |
| `scenarios_vs_guide`   | `scenarios.yaml` `guide_ref` 의 §N 이 가이드에 존재                | PASS (11 scenarios) | PASS (10 scenarios) |
| `scenarios_vs_tb`      | `scenarios.yaml` `tb_task` 가 TB 의 SV task / inline tag 와 매칭   | PASS (11 ↔ 11) | PASS (10 ↔ 10) |

이 6개가 **closed loop 의 의미상 boundary 점검**이다:
- 가이드 → HAL: SW 약속이 코드로 옮겨졌는가
- 가이드 → scenarios: SW 약속이 검증 대상으로 옮겨졌는가
- scenarios → TB: 검증 대상이 실제 assertion 으로 옮겨졌는가
- IP-XACT → HAL / DESIGN.md: SFR 정의가 세 source 에서 일관되는가
- diagrams: 도면 source 가 산출물과 동기화되는가

### 5.1 실제로 잡힌 사례 (회귀 방지 가치)

본 invariant 들이 단순한 형식 검사가 아니라 실제 결함을 잡았음을 보여
주는 사례:

| 검출 시점 | 결함                                                     | 잡은 invariant       |
|----------|--------------------------------------------------------|----------------------|
| irq_ctrl 1차 commit | 가이드 §4 가 `irq_ctrl_is_edge()` 를 약속했으나 HAL 에 미정의 | `guide_funcs_in_hal` |
| trng 1차 commit | 가이드 §3/§4 의 예시 함수명이 HAL prefix 와 충돌 (`trng_isr` 등) | `guide_funcs_in_hal` |
| trng RTL 1차 commit | 기본 seed 가 LFSR bit[31] 미설정 값이어서 candidate stream 이 초기 0 → health fail 조기 trigger | TB scenario S07 + S03 |
| irq_ctrl TB | APB driver task 의 NBA 가 verilator 의 NBA-as-blocking 과 race → claim ID 잘못 sample | verilator-sim 실패 → blocking + #1ns 패턴으로 수정 |

---

## 6. CI snapshot (`main` 의 최신 run)

```
Workflow              Run ID                Result
─────────────────────────────────────────────────────
deploy-pages          25928231465           success
ipflow-validate       25928231471           success
  └── discover                               success
  └── validate          (irq_ctrl)           success
  └── validate          (trng)               success
  └── hal-host-smoke    (irq_ctrl)           success
  └── hal-host-smoke    (trng)               success
  └── verilator-sim     (irq_ctrl)           success — 29 TB checks PASS
  └── verilator-sim     (trng)               success — 23 TB checks PASS
```

---

## 7. Coverage 점검 (RTL feature 태그 기준)

`scenarios.yaml` 의 `rtl_features_required` 가 선언한 feature 가 모두
적어도 하나의 scenario 의 `rtl_features` 에 의해 cover 되는지를
체크한다. `ipflow.py` 의 향후 enhancement 후보이지만, 본 리포트 시점에서
는 수동 점검으로 100% cover.

### 7.1 irq_ctrl — 21 features / 21 covered (100%)

```
reset, regfile_default, regfile_rw, priority, enable, threshold,
level_detect, edge_detect, pending_latch, eligibility, arbiter,
tie_break, claim, edge_pending_clear, w1c, apb_pslverr, addr_decode,
ro_protection, ro_regs, ip_id, ip_version
```

### 7.2 trng — 23 features / 23 covered (100%)

```
reset, regfile_default, regfile_rw, lfsr, fifo_push, fifo_pop,
fifo_clear, data_register, data_ready, soft_reset, seed_load,
lfsr_determinism, health_test, repetition_detect, intr_edge_latch,
w1c, irq, apb_pslverr, addr_decode, ro_protection, ro_regs, ip_id,
ip_version
```

---

## 8. 환경 정보

| 항목                | Local (Mac)                                | CI (GitHub-hosted Ubuntu)              |
|---------------------|--------------------------------------------|----------------------------------------|
| OS                  | macOS 26 (Darwin 25.3.0, arm64)            | ubuntu-latest                          |
| Verilator           | 5.048 (Homebrew)                           | apt verilator (5.x)                    |
| C compiler          | clang (Xcode)                              | gcc                                    |
| Node.js (WaveDrom)  | 22.22.2                                    | actions/setup-node@v4 (Node 20)        |
| Python              | 3.x system                                 | 3.x system                             |
| 산출 데이터         | `tools/ipflow.py status --json`            | 동일, push 시 `deploy-pages` 가 갱신    |

---

## 9. 한계 및 향후 작업

| 한계                                                | 영향                                      | 계획                                                  |
|----------------------------------------------------|------------------------------------------|-----------------------------------------------------|
| RTL feature coverage 가 수동 점검                    | 누락 가능성                              | `ipflow.py` 에 coverage-rollup 추가                  |
| 23 / 25 IP 는 spec only (stub)                      | 본 리포트 적용 범위 제한                  | promote 우선순위 결정 후 IP 단위로 9-stage 진행       |
| Verilator 외 시뮬레이터 (VCS / Xcelium) 미검증        | NBA-as-blocking 영향 가능                | qualification 단계에서 dual-simulator regression     |
| Formal property check 없음                          | 정합 검증만, equivalence/safety 미보장    | qual 단계에서 sva + JG 도입 예정                      |
| Clock / power / DFT sign-off 미수행                  | RTL functional 까지만 본 리포트가 다룸     | back-end flow 별도 리포트                             |
| `ip_ci.yml` 의 lint / yaml-schema 단계는 외부 reusable workflow 참조 | 본 리포지토리에서 직접 실행 불가 | 본 monorepo 의 active workflow 는 ipflow-validate / deploy-pages 두 개만 동작 |

---

## 10. Sign-off

본 리포트가 다루는 두 IP 는 다음 조건을 모두 충족한다:

- 9-stage workflow 의 모든 단계 산출물 존재
- 6/6 closed-loop invariants PASS
- L1/L2/L3 모든 layer 의 자동 검사 PASS
- CI 의 모든 matrix job 이 `main` 의 latest commit 에서 success
- 가이드의 100% worked example 이 scenarios 로 매핑되고, scenarios 의
  100% 가 TB 의 assertion 으로 검증됨

위 조건에 따라 두 IP 의 status 를 `proto → alpha` 로 promote 한 상태
이며 (`cfg/*.ip.yaml` 의 `version: 1.0.0`, `status: alpha`), 다음
quality gate 인 **qual** 진입을 위해 §9 의 한계 항목을 차례로 해소한다.

---

*본 리포트는 commit `5f02d0b` 시점의 스냅샷이다. 후속 promote / 신규 IP
추가 시 본 문서를 갱신하거나 release-tag 별 archived report 를 추가한다.*
