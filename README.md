# SSD Controller SoC 형상관리 시스템 (Reference Implementation)

본 저장소는 100명+ 규모 RTL 개발자가 협업하는 SSD Controller SoC 프로젝트의
**형상관리(Source Configuration Management) 레퍼런스 구현**이다. 단순한
git 전략 비교를 넘어, 하나의 IP 가 spec 부터 verification 까지 가는
**closed-loop workflow** 와 그것을 자동 검증하는 harness 까지를 함께
제공한다.

> **Live URLs** (GitHub Pages — `web/` 배포):
> - 🏠 <https://k31001.github.io/ssd-soc-cfg-mngt/> — 9-stage workflow 대시보드 + 25개 IP × 8 stage status matrix
> - 📘 <https://k31001.github.io/ssd-soc-cfg-mngt/report/> — **AI 친화 SoC 산출물 관리** 제안 보고서 (12장)
> - ▶ <https://k31001.github.io/ssd-soc-cfg-mngt/present/> — 20장 발표 슬라이드 (`←/→` nav · `N` 노트 · `F` 풀스크린 · `P` 인쇄)
>
> 로컬 미리보기: `make report-serve` → http://localhost:8000/

---

## 구성

| 디렉터리           | 내용                                                                                       |
|--------------------|--------------------------------------------------------------------------------------------|
| `ssd_soc/`         | 가상 SoC 스켈레톤 (top + 5 subsystems + 25 IPs).                                          |
| `cm-strategies/`   | 4가지 형상관리 방식 비교 데모 + 각 방식별 개발자/관리자 튜토리얼.                          |
| `recommended/`     | 추천 하이브리드 구성 (`repo` manifest + IP 분리 + IPLM-lite).                              |
| `tools/`           | 자동화 스크립트 — `ipgen` · `bom` · `manifest_bump` · `release` · **`ipflow`** · **`render-diagrams`**. |
| `docs/`            | 6종 문서 + **[WORKFLOW.md](docs/WORKFLOW.md)** (IP closed-loop 9-stage workflow).         |
| `ci/`              | 계층별 GitHub Actions workflow **템플릿** (각 IP/Subsystem repo 로 복사용).                 |
| `.github/workflows/` | 본 monorepo 에서 실제로 동작하는 active workflows (Pages 배포 / ipflow validate).         |
| `web/`             | 워크플로우 인터랙티브 대시보드 — 정적 HTML + Mermaid, GitHub Pages 로 배포.                |

---

## IP Closed-Loop Workflow ⭐

본 레포의 핵심 산출물이다. [`docs/WORKFLOW.md`](docs/WORKFLOW.md) 가 정의하는
**9-stage closed loop**:

```
Spec → RTL → Design Doc → IP-XACT → Programmer's Guide → HAL
                                       │
                                       └─→ Test Scenarios → RTL Verification → (반복)
```

핵심 invariant: **Programmer's Guide(Stage 5) 가 SW-HW 계약**이며, Test
Scenarios(Stage 7) 가 그 계약을 RTL 검증으로 옮긴다. 가이드의 모든 worked
example 은 적어도 하나의 test scenario 로 1:1 매핑되어야 하고, harness 가
이 매핑을 자동 검사한다.

### Harness: `tools/ipflow.py`

PyYAML 무의존 generic CLI. 25개 IP 어느 것에도 적용 가능.

```bash
tools/ipflow.py status                                      # IP × stage 매트릭스
tools/ipflow.py status --json > web/data/status.json        # 웹 대시보드 데이터
tools/ipflow.py validate <ip-dir>      # 6개 closed-loop invariant 검사
tools/ipflow.py scenarios <ip-dir>     # scenarios.yaml ↔ TB task 매칭
tools/ipflow.py sim <ip-dir>           # Verilator 로 self-checking TB 빌드/실행
tools/ipflow.py run <ip-dir>           # 도면 렌더 → validate → HAL smoke → verilator sim 일괄
```

자동 검사 항목 6종:

| Invariant              | 비교 대상                                                |
|------------------------|----------------------------------------------------------|
| `diagrams_drift`       | `doc/diagrams/*.json` ↔ `*.svg`                          |
| `ipxact_vs_design`     | `<ip>.ipxact.xml` ↔ `DESIGN.md §5` register table        |
| `hal_vs_ipxact`        | `<ip>_hal.h` SFR macro ↔ IP-XACT 모든 offset             |
| `guide_funcs_in_hal`   | `PROGRAMMERS_GUIDE.md` 코드 fence 호출 ↔ HAL 선언         |
| `scenarios_vs_guide`   | `scenarios.yaml` `guide_ref` ↔ 가이드 섹션 존재 여부      |
| `scenarios_vs_tb`      | `scenarios.yaml` `tb_task` ↔ TB SV task / inline tag      |

### Reference 구현 (v1.0.0 alpha)

두 IP 가 9-stage 를 모두 통과한 상태. 다른 IP 를 발전시킬 때의 모범 사례.

- **[`cpu_ss/ip/irq_ctrl`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/)** — PLIC 계열
  interrupt controller. 32 source / edge·level / threshold / claim-complete.
  TB 29 checks PASS (verilator), HAL host smoke 16/16 PASS.
- **[`sec_ss/ip/trng`](ssd_soc/subsystems/sec_ss/ip/trng/)** — True RNG (3-LFSR
  entropy emulator + repetition health test + 16-entry FIFO + edge-latched
  interrupt). TB 23 checks PASS (verilator), HAL host smoke 17/17 PASS.

irq_ctrl 의 stage 별 산출물:

| Stage | 산출물                                                                                            |
|-------|---------------------------------------------------------------------------------------------------|
| 1     | [`cfg/irq_ctrl.ip.yaml`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/cfg/irq_ctrl.ip.yaml)              |
| 2     | [`rtl/irq_ctrl.sv`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/rtl/irq_ctrl.sv) — PLIC 계열, 합성 가능 |
| 3     | [`doc/DESIGN.md`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/doc/DESIGN.md) + Mermaid + WaveDrom       |
| 4     | [`doc/irq_ctrl.ipxact.xml`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/doc/irq_ctrl.ipxact.xml) (1685-2014) |
| 5     | [`doc/PROGRAMMERS_GUIDE.md`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/doc/PROGRAMMERS_GUIDE.md)     |
| 6     | [`sw/irq_ctrl_hal.{h,c}`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/sw/) + host smoke test 16/16 PASS|
| 7     | [`verif/scenarios.yaml`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/verif/scenarios.yaml) — 11 시나리오 |
| 8     | [`sim/tb_irq_ctrl.sv`](ssd_soc/subsystems/cpu_ss/ip/irq_ctrl/sim/tb_irq_ctrl.sv) — self-checking  |
| 9     | `ipflow run` 전 단계 PASS                                                                          |

### 도면 인프라: WaveDrom + Mermaid

ASCII 텍스트 도면 대신 source-of-truth 가 있는 그래픽 도면 사용:

- **Mermaid** — 블록 다이어그램·플로우. GitHub markdown 이 inline 렌더.
- **WaveDrom** — 타이밍 파형·register bit-field 레이아웃. JSON source →
  `tools/render-diagrams.sh` → SVG (커밋되어 GitHub 에서 즉시 표시).

CI(`workflow-validate` job 의 `diagrams_drift`) 가 JSON ↔ SVG 동기화를
자동 검사하여 "source 만 고치고 SVG 재생성 잊은 PR" 을 fail 시킨다.

### 활성 CI workflows (`.github/workflows/`)

| Workflow              | 트리거               | 동작                                                                 |
|-----------------------|---------------------|----------------------------------------------------------------------|
| `deploy-pages.yml`    | `main` push         | `status.json` 재생성 → WaveDrom 재렌더 → `web/` 폴더 GitHub Pages 배포 |
| `ipflow-validate.yml` | PR / `main` push    | `scenarios.yaml` 이 있는 IP discover → 각 IP 의 6개 invariant 검사 + HAL host smoke + **verilator TB 실행** |

`ci/*.yml` 은 별개로 **각 IP/Subsystem repo 로 복사되는 템플릿** 이며 본
monorepo 에서 직접 실행되지 않는다.

---

## 빠른 시작

### 형상관리 시연

```bash
make sim TOP=ssd_soc_top                                       # Verilator smoke build (stub)
make lint                                                       # Verible lint
./recommended/scaffolding/local-bootstrap.sh /tmp/demo          # 전체 시스템 5분 시연
python3 tools/bom.py --manifest recommended/manifest/default.xml --workdir /tmp/demo/work/checkout
```

### IP closed-loop workflow 체험

```bash
# 1) 전체 25 IP 의 진행도 매트릭스
tools/ipflow.py status

# 2) irq_ctrl (유일하게 9-stage 완료된 IP) end-to-end 검증
tools/ipflow.py run ssd_soc/subsystems/cpu_ss/ip/irq_ctrl

# 3) 웹 대시보드 데이터 갱신 + 로컬 미리보기
tools/ipflow.py status --json > web/data/status.json
cd web && python3 -m http.server 8000   # http://localhost:8000
```

---

## 문서

- [01. 시스템 설계서](docs/01-design.md)
- [02. 구축 가이드](docs/02-build-guide.md)
- [03. 관리자 가이드](docs/03-admin-guide.md)
- [04. 개발자 가이드](docs/04-developer-guide.md)
- [05. 트러블슈팅 가이드](docs/05-troubleshooting.md)
- [06. 산업 벤치마크 기술 보고서](docs/06-industry-benchmark.md)
- ⭐ [**IP Closed-Loop Workflow**](docs/WORKFLOW.md) — 9-stage 폐쇄 루프
  정의, invariant 표, harness 명령. 인터랙티브 시각 자료는
  [k31001.github.io/ssd-soc-cfg-mngt](https://k31001.github.io/ssd-soc-cfg-mngt/).
- 📊 [**Verification Report**](docs/VERIFICATION_REPORT.md) — 두 reference
  IP (`irq_ctrl`, `trng`) 의 L1/L2/L3 검증 결과 종합. 52/52 TB checks +
  33/33 HAL smoke + 12/12 closed-loop invariants PASS.

---

## 튜토리얼 (Step-by-Step)

각 형상관리 전략의 개발자/관리자 워크플로를 한 줄씩 따라하며 체험:

- [Strategy 01 — Monorepo](cm-strategies/01-monorepo/)  (DEVELOPER / ADMIN)
- [Strategy 02 — Submodule](cm-strategies/02-submodule/)  (DEVELOPER / ADMIN)
- [Strategy 03 — Repo+Manifest](cm-strategies/03-repo-manifest/)  (DEVELOPER / ADMIN)
- [Strategy 04 — Subtree](cm-strategies/04-subtree/)  (DEVELOPER / ADMIN)

---

## 새 IP 를 발전시킬 때 (간단 체크리스트)

1. `tools/ipgen.py --name <ip> --subsystem <ss>` 로 스캐폴드 (Stage 1).
2. RTL 작성 (Stage 2) — `tools/ipflow.py status` 로 진행도 추적.
3. `doc/DESIGN.md` + `doc/diagrams/*.json` (Stage 3) → `tools/render-diagrams.sh`.
4. `doc/<ip>.ipxact.xml` (Stage 4) — DESIGN.md §5 와 일치하게.
5. **`doc/PROGRAMMERS_GUIDE.md` 의 §6 worked examples 를 먼저 적는다** (Stage 5).
6. `sw/<ip>_hal.{h,c}` + Makefile + host smoke test (Stage 6).
7. `verif/scenarios.yaml` — 가이드 §6 의 각 example 을 ID 한 줄로 옮긴다 (Stage 7).
8. `sim/tb_<ip>.sv` — 각 scenario 에 대응하는 SV task / inline check (Stage 8).
9. `tools/ipflow.py validate <ip>` 가 6개 invariant 모두 PASS 하면 sign-off (Stage 9).

상세는 [`docs/WORKFLOW.md`](docs/WORKFLOW.md), 모범 사례는 `cpu_ss/ip/irq_ctrl/`.
