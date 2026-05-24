# 6. End-to-End 워크플로우 — Base SoC에서 신규 SoC까지

본 장은 본 제안이 **현장에서 어떻게 흘러가는가**를 신규 SoC 부트스트랩
시나리오로 보인다. 5개 부서(HW / SW / AI / FW / DV)가 4개 저장소
(RTL · Doc · FW · Test)와 검증 환경(FPGA·Veloce·Zebu + SSD Host)
사이에서 어떻게 산출물을 주고받는지 swim lane으로 정리한다.

---

## 6.1 부서·저장소 매트릭스 (swim lane)

```mermaid
flowchart LR
    subgraph RTLR["① RTL Repo"]
      HW1["HW: RTL 변경<br/>(rtl/*.sv)"]
      HW2["lint + smoke synth<br/>tag (rtl-v*)"]
    end

    subgraph DOCR["② Doc Repo"]
      HW3["HW: DLD §5 갱신"]
      AI1["AI: SystemRDL / IP-XACT<br/>+ HAL.h auto-gen"]
      SW1["SW: Guide §6 worked example"]
      DC1["Doc CI: D1–D5<br/>tag (doc-v*)"]
    end

    subgraph FWR["③ FW Repo"]
      FWS["doc/ submodule update"]
      AI2["AI: HAL.c 재생성"]
      FW1["FW: ISR / DMA / 락 보강"]
      FC1["FW CI: F1–F3 + smoke<br/>tag (fw-v*)"]
    end

    subgraph TR["④ Test Repo"]
      TS["doc/ submodule update"]
      AI3["AI: Python scenarios<br/>(§6 / §8 변환)"]
      DV1["DV: 측정·assertion 보강"]
      TC1["Test CI: T1–T4<br/>tag (test-v*)"]
    end

    subgraph ENV["검증 환경"]
      HOST["💻 SSD Host<br/>(NVMe / PCIe driver)"]
      PLAT["🔧 FPGA · Veloce · Zebu<br/>(SoC + FW)"]
    end

    HW1 --> HW2 --> HW3 --> AI1 --> SW1 --> DC1
    DC1 -. submodule pin .-> FWS
    DC1 -. submodule pin .-> TS
    FWS --> AI2 --> FW1 --> FC1
    TS  --> AI3 --> DV1 --> TC1
    HW2 -. bitstream / image .-> PLAT
    FC1 -. FW binary load .-> PLAT
    TC1 -. Python on SSD Host .-> HOST
    HOST ==>|"NVMe / PCIe<br/>명령"| PLAT
    PLAT -. coverage gap .-> HW1
```

핵심: **AI는 "정합성 잡일"을 흡수**하고, 사람은 "**의도 정의**" (HW의 RTL,
SW의 가이드, FW의 ISR/락, DV의 측정·assertion)에 집중한다. 검증의 마지막
페이지는 두 군데에서 동시에: **FPGA·Veloce·Zebu** 위에서 펌웨어가 실행되고,
**SSD Host**의 Python이 NVMe/PCIe로 그 펌웨어를 구동·관찰한다 — 실제
SSD 동작 환경과 동일하다.

---

## 6.2 8단계 워크플로우 (구체적 명령 포함)

### Step 1 — Base 선정 (RTL · Doc · FW · Test 네 갈래)
- HW lead가 가장 유사한 in-house Base SoC를 선정.
- 변경이 필요한 IP가 속한 **RTL Repo branch**를 cut.
- **Doc Repo**는 그대로 유지 (해당 IP의 doc 영역만 수정 예정).
- **FW Repo와 Test Repo는 각각 fork 또는 새 branch** — 둘 다 Doc Repo의 현재 tag를 submodule pin.
  ```bash
  # FW 측
  cd fw-repo && git checkout -b derivative/new-soc
  git submodule update --init --remote doc/
  git -C doc/ checkout doc-v2.4.0   # base doc tag

  # Test 측 (별도 저장소)
  cd test-repo && git checkout -b derivative/new-soc
  git submodule update --init --remote doc/
  git -C doc/ checkout doc-v2.4.0   # 같은 doc tag로 정렬
  ```

### Step 2 — RTL Repo: 새 요구사항 반영
- 예: `nvme_ctrl`에 NVMe 1.4 admin queue 확장 추가.
- `rtl/nvme_ctrl.sv` 수정, lint pass, RTL Repo CI green → tag (e.g. `rtl-v3.2.0`).

### Step 3 — Doc Repo: DLD §5 + AI가 IP-XACT 갱신
- HW가 `doc/nvme_ctrl/DLD.md §5` register map을 직접 수정 (의도 정의).
- Doc Repo CI는 RTL Repo의 `rtl-v3.2.0`을 read-only fetch하여 D1 (RTL ↔ DLD) 검사.
- AI가 `doc/nvme_ctrl/nvme_ctrl.ipxact.xml`을 갱신 → D2, D3 통과.
- AI가 `include/nvme_ctrl_hal.h`를 IP-XACT에서 재생성 → D3 통과.
- SW lead가 `doc/nvme_ctrl/PROGRAMMERS_GUIDE.md §6`에 새 worked example 추가.
- Doc Repo CI green → tag (e.g. `doc-v2.5.0`).

### Step 4a — FW Repo: submodule 갱신 + HAL.c 재생성
```bash
cd fw-repo
git submodule update --remote doc/
git -C doc/ checkout doc-v2.5.0
ai update-hal nvme_ctrl                      # AI 시나리오 C
```
- `fw/hal/nvme_ctrl_hal.c` — HAL 함수 본문 (Guide §6 시퀀스를 1:1 변환)

### Step 4b — Test Repo: submodule 갱신 + Python scenarios 생성
```bash
cd test-repo
git submodule update --remote doc/
git -C doc/ checkout doc-v2.5.0              # FW와 동일 doc tag (release gate가 강제)
ai generate-scenarios nvme_ctrl              # AI 시나리오 D
```
- `tests/scenarios/nvme_ctrl/sc_admin_queue_enable.py` — SSD Host용 Python
- `tests/scenarios/nvme_ctrl/regress_*.py` — Guide §8 pitfall 회귀

### Step 5 — FW: ISR / DMA / 락 보강
- AI가 만든 HAL을 FW lead가 review.
- 환경별 ISR 등록·락·DMA 정책 등 사람 영역 보강.
- `make test` host smoke pass 확인 (F3).

### Step 6 — DV: Python scenario 보강 (corner case · 측정)
- AI가 만든 시나리오에 측정 metric (latency·error 카운트·전력)과 corner case 추가.
- pre/post assertion 강화.
- T1, T2 invariant 통과 확인.

### Step 7 — FW · Test 각자 CI 통과 → tag
- FW Repo CI: F1–F3 + host smoke → `fw-v1.7.0`
- Test Repo CI: T1–T4 + pytest collect → `test-v0.9.3`
- Release gate (별도 CI 또는 사인오프): **`FW.doc-SHA == Test.doc-SHA`** 확인 (R1)

### Step 8 — 검증 환경에서 HW/SW coverif 실행
- RTL Repo `rtl-v3.2.0`이 합성/에뮬레이션되어 **FPGA bitstream** 또는 **Veloce/Zebu image**가 준비됨 (별도 빌드 인프라).
- FW Repo `fw-v1.7.0`의 binary가 그 플랫폼에 **load되어 실행**.
- DV가 **SSD Host**에서 Test Repo `test-v0.9.3`의 `tests/scenarios/nvme_ctrl/*.py`를 nightly + regression suite로 실행.
- Python이 NVMe/PCIe로 SoC를 구동, 결과(metric·assertion·coverage)가 dashboard로 수집.
- coverage gap → Step 2로 되돌아감 (RTL 또는 scenario 추가).

---

## 6.3 부서간 산출물 인계 정의

| 인계 시점 | 인계자 → 수신자 | 산출물 / 매개 |
|---|---|---|
| Step 2 종료 | HW → Doc Repo CI | RTL Repo의 새 tag (`rtl-v*`) |
| Step 3 종료 | HW + SW + AI → Doc Repo CI | DLD §5 · SystemRDL/IP-XACT · HAL.h · Guide §6, §8 |
| Step 3 → Step 4 | Doc Repo → FW Repo · Test Repo (동시) | `doc-v*` tag (양쪽 모두 같은 SHA로 핀) |
| Step 4a 종료 | AI → FW lead | HAL.c 초안 |
| Step 4b 종료 | AI → DV | Python scenario 초안 (SSD Host용) |
| Step 5 종료 | FW → FW Repo CI | 검증된 HAL.c + host smoke |
| Step 6 종료 | DV → Test Repo CI | 보강된 Python scenarios |
| Step 7 종료 | FW + Test Repo CI → Release gate | `fw-v*` · `test-v*` tag, **R1 (doc-SHA 정합) 통과** |
| Step 8 결과 | 검증 환경 (FPGA·Veloce·Zebu + SSD Host) → 전체 | metric · assertion · coverage 대시보드 |

각 인계는 **모두 git tag / submodule SHA**로 일어난다. Slack DM·메일
첨부·Confluence 페이지 없음. "**어느 RTL × 어느 doc × 어느 FW × 어느
Test 조합으로 측정했나**"가 항상 한 줄로 확정된다 — `rtl-v3.2.0 ×
doc-v2.5.0 × fw-v1.7.0 × test-v0.9.3`.

---

## 6.4 신규 SoC 부트스트랩의 정량적 이점

| 항목 | Before (수동) | After (submodule + AI) |
|---|---|---|
| Base SoC 복제 시간 | 2–5일 (수동 export·정리) | 분 단위 (`git submodule add`) |
| 변경 IP의 산출물 재생성 | 5종 × 사람 = 1–2주 | AI 초안 + 사람 review = 1–2일 |
| 산출물 정합성 검증 | 수동 cross-check, 누락 다수 | CI 자동 PASS/FAIL |
| FW 팀 부트스트랩 | 별도 spec 패키지 전달 | super-repo clone 한 번 |
| 신규 SoC 1차 tape-out 준비 | 분기 단위 | 월 단위 (단축 추정) |

이 정량은 산업 평균과 일치한다. McKinsey 2025[^1]에 따르면 AI 코딩 도구는
well-defined task에서 20–45% 생산성 향상을 보이며, 본 워크플로우는
"context를 결정론적으로 주는" 전제를 만족하므로 **상한값에 가깝게**
나타날 수 있다.

---

## 6.5 회귀 / 사고 / drift에 대한 대처

| 시나리오 | 대처 |
|---|---|
| RTL 변경 후 가이드/SFR 미갱신 | Doc Repo D1·D2 fail → Doc PR 차단 (FW/Test까지 안 감) |
| AI가 만든 HAL.h에 환각 | Doc D3 fail (SFR ↔ HAL.h) → Doc PR 차단 |
| FW가 stale doc tag로 머묾 | F2 fail (FW Repo `doc/` SHA monotonic 위반) |
| FW와 Test가 다른 doc tag를 봄 | **Release gate R1 fail** — release 차단 |
| DV가 Python scenario를 Guide에서 빠뜨림 | Test Repo T1 fail → Test PR 차단 |
| Pitfall 회귀 누락 | T2 fail → Test PR 차단 |
| FPGA / Veloce / Zebu 에서만 보이는 결함 | coverage gap report → Step 2로 회귀 (RTL 또는 scenario 추가) |

이 모든 대처는 사람의 성실성이 아니라 **CI 또는 git의 native 기능**에
의존한다.

다음 장(7장)에서 본 워크플로우가 최신 LLM Wiki 트렌드와 어떻게
비교되는지, 그리고 왜 우리가 "한 발 앞섰는가"를 정리한다.

---

[^1]: McKinsey 2025, [Productivity gains from AI coding tools — RAGFlow 회고에서 인용](https://ragflow.io/blog/rag-review-2025-from-rag-to-context).
