# 04. Verilog 개발자 가이드 (Developer Guide)

> **TL;DR** — IP 1개를 담당하는 RTL 개발자의 **첫날부터 양산까지** 워크플로.
> 워크스페이스는 `repo sync` 한 번으로 셋업되며, 일상 작업은
> `branch → code → local lint → PR → CI green → IP-owner approve → merge → tag`
> 패턴 1개로 끝납니다. **하지 말아야 할 안티패턴(top 에서 IP 직접 수정 등)**
> 을 명확히 인지하면 시스템이 알아서 도와줍니다.

대상 독자: SSD SoC 의 IP-level Verilog/SystemVerilog 개발자.

---

## 0. 사전 준비 (15분)

```bash
# 1) 도구
sudo apt-get install -y verilator iverilog python3
pip install --user pre-commit cocotb

# 2) GitHub 인증
gh auth login
gh auth setup-git

# 3) repo 도구 (옵션, 사내 mirror 있으면 사용)
mkdir -p ~/bin && curl -sL https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod +x ~/bin/repo && export PATH=~/bin:$PATH
```

---

## 1. 첫날 셋업 (Initial Workspace)

### 1.1 전체 워크스페이스 (Mainline)
```bash
mkdir ssd-soc && cd ssd-soc
repo init -u git@github.com:acme-ssd/ssd-soc-manifest.git -b main -m default.xml
repo sync -j 16            # 약 5~10분
make sim                    # Verilator로 elaborate, smoke run
```

워크스페이스 모습:
```
ssd-soc/
├─ .repo/                    # manifest 도구 메타
├─ top/
├─ subsystems/{host,fcc,mem,cpu,sec}_ss/
├─ ip/<25 IPs>/
├─ common-libs/
└─ verif/
```

### 1.2 자기 IP 만 단독으로 (개발 집중)
```bash
git clone git@github.com:acme-ssd/ip-pcie_phy.git
cd ip-pcie_phy
make lint sim
```

### 1.3 host_ss 팀: 우리 영역만 sparse 동기화
```bash
repo init -u git@github.com:acme-ssd/ssd-soc-manifest.git -b main -m default.xml \
   --groups=default,common,host,top
repo sync -j 16
```
→ 다른 subsystem IP 는 받지 않음.

### 1.4 SKU 별 워크스페이스 분리
```bash
mkdir ../ssd-soc-gen5 && cd ../ssd-soc-gen5
repo init -u … -m sku-gen5-4tb.xml
repo sync
```

---

## 2. 일상 워크플로 (Daily Loop)

```
┌──────────────────────────────────────────────┐
│  cd ip/<my-ip>                                │
│  git checkout -b feature/<topic>              │
│  ... edit RTL / sim ...                       │
│  ipgen 으로 ip.yaml ↔ 시그니처 sync           │
│  make lint sim                                │
│  git commit -s                                │
│  git push                                     │
│  gh pr create  →  CI green  →  approve → merge│
│  (mainline 통합은 manifest-bot 자동)          │
└──────────────────────────────────────────────┘
```

### 2.1 브랜치 만들기
```bash
cd ip/pcie_phy
git checkout main && git pull
git checkout -b feature/improve-ltssm
```

### 2.2 ip.yaml 우선 갱신, RTL 시그니처 재생성
```bash
# ip.yaml 의 parameter LANES 를 4 → 8 로 늘리는 경우
${EDITOR} ip.yaml
python3 tools/ipgen.py --ip-yaml ip.yaml   # rtl/<name>.sv 의 AUTO-GENERATED block 만 갱신
```

> `// AUTO-GENERATED-BEGIN` ↔ `// AUTO-GENERATED-END` 사이는 손편집 금지.
> 그 외 본문(`// User logic here` 아래)은 자유롭게 편집.

### 2.3 로컬 검증
```bash
make lint                         # Verible + Verilator -Wall
make sim                          # Icarus + smoke testbench
python3 tools/sync_codeowners.py --repo . --check   # CODEOWNERS drift 사전 확인
```

### 2.4 ip.yaml 의 version 필드 bump (필수)
```yaml
# ip.yaml
version: 0.2.0   # 이전 0.1.0 → 0.2.0
```
CI 의 `semver-bump-check` 가 bump 안 된 PR 을 자동 거절합니다.

### 2.5 Commit + PR
```bash
git commit -sm "pcie_phy: extend LANES support to 8 (v0.2.0)"
git push -u origin feature/improve-ltssm
gh pr create --fill
```

PR 본문에 다음이 자동/수동으로 포함되어야 합니다:
- 변경 요약 (Why / What)
- 검증 결과 (어떤 sim 통과, coverage 변화)
- IP-XACT/레지스터 맵 영향 (있을 시)
- breaking change 여부

### 2.6 CI green → Owner approve → Merge
- Owner approve 후 PR 작성자 본인이 머지 가능 (squash merge 권장).
- 머지 후 `main` 에서 자동으로 tag candidate? 아닙니다 — **tag 는 명시적으로 push**.

### 2.7 Release tag (작은 변경 → patch, 큰 변경 → minor)
```bash
git checkout main && git pull
git tag -a v0.2.0 -m "extend LANES support to 8"
git push origin v0.2.0
```
→ `notify-manifest` job 이 mainline manifest 의 본 IP revision PR 자동 생성.

---

## 3. 자주 하는 작업 — 레시피 모음

### 3.1 새 register 추가 (CSR)
1. `doc/regmap.md` 갱신.
2. `cfg/regmap.hjson` 갱신 (OpenTitan style).
3. `tools/reggen.py` 실행 (있는 경우) → `rtl/<name>_reg.sv` 자동 생성.
4. unit sim 에 read/write 테스트 추가.

### 3.2 새 IP 의존성 추가 (다른 IP 호출)
1. `ip.yaml` 의 `dependencies:` 에 추가 (`- ip-axi_interconnect >= 1.0.0`).
2. PR 머지 → mainline manifest 다음 update 시 자동 resolve.
3. **주의**: 순환 의존(circular dep) 은 yaml-schema CI 가 거절.

### 3.3 Lint waiver 추가
```yaml
# cfg/waivers.yaml
- rule:   ALWAYS_FF_NON_BLOCKING
  scope:  rtl/<my-ip>.sv:142-148
  reason: "Vendor IP integration boundary, blocking required for handshake"
  expiry: 2026-12-31
```
- 모든 waiver 는 `reason` + `expiry` 필수.
- 만료된 waiver 는 weekly CI 에서 알림.

### 3.4 큰 refactor — 여러 IP 동시 변경
**우선 manifest topic 사용** (가장 가까운 atomic):
```bash
cd ip/pcie_phy && git checkout -b refactor/new-axi-bus
cd ../pcie_ctrl && git checkout -b refactor/new-axi-bus
# ... 두 IP 모두 동일 topic 이름
repo upload --current-branch --topic refactor/new-axi-bus
```
관리자/리뷰어는 같은 topic 의 두 PR 을 함께 보게 됩니다.

(완전 atomic 이 필요하면 형상관리 관리자(integration-team) 과 상의 — drop-in branch 협업 가능)

### 3.5 양산 SKU 별 RTL 분기
- **하지 마세요**: `if (SKU == "gen5")` 같은 SV 매크로 fork.
- **이렇게 하세요**:
  - parameter 로 흡수 가능 → ip.yaml parameters 사용.
  - parameter 만으론 부족 → 별도 IP repo 또는 별도 모듈로 분리.
  - SKU 단위 차이 → manifest 가 다른 tag 를 pin.

### 3.6 Vendor IP 호출
- Vendor IP 는 별도 repo (`vendor/<name>`). 우리 IP 에선 인터페이스만 의존.
- `ip.yaml` 의 `dependencies:` 에 `vendor/<name> >= X` 명시.
- vendor 코드를 우리 repo 안으로 복사 금지 — 라이선스 위반.

---

## 3.7 Integration Tutorial — 내 IP를 SoC 에 합치는 일 (STEP-BY-STEP)

> **상황**: 본인의 IP 가 IP-CI 는 모두 통과. 이제 **Subsystem** 과 **Top SoC** 통합에서 깨지지 않게 만들고 검증하는 것이 다음 책임입니다.
> 본 튜토리얼을 따라 가면 "내 IP 가 회사 SoC 안에서 정상 동작" 까지의 전체 흐름을 직접 체험합니다. 소요 시간 약 **40분**.

### STEP A. Integration Contract 확인 — 다른 IP가 나를 어떻게 호출하는가

```bash
cd /tmp/ssd-soc-recommended/work/checkout/ip/pcie_phy   # 또는 사내 워크스페이스
cat cfg/pcie_phy.ip.yaml | head -25
# - parameters, bus, clocks, resets 가 "내 IP 의 외부 계약(contract)"
```

다른 IP/Subsystem 이 내 IP 를 부를 때 가정하는 것:
- 인터페이스 (`bus`) — AXI 라면 master/slave 모드, 비트폭
- 클록/리셋 도메인 — 다른 도메인이면 CDC 필요
- 파라미터의 default — SKU 별로 바뀌어도 모두에서 elaborate 가능해야 함

**Tip**: contract 가 바뀌면 (포트 추가/제거, 파라미터 의미 변경) `version` 의 MAJOR 를 올려야 합니다 (semver). PR 본문에 **breaking change** 라벨 명시.

### STEP B. Subsystem Integration Sim 로컬 실행

내 IP 단독 sim 통과는 시작에 불과. Subsystem 통합 환경에서 검증:

```bash
cd /tmp/ssd-soc-recommended/work/checkout/subsystems/host_ss
ls
# cfg  doc  rtl  sim
# - rtl/host_ss.sv : 5개 host IP 인스턴스화
# - cfg/host_ss.ss.yaml : member IPs

# Subsystem 통합 sim (Verilator 가 있으면)
make -C ../../ssd_soc sim TOP=host_ss 2>&1 | tail || echo "(skip: verilator missing)"
```

**기대 결과**: 내 IP 변경이 다른 host_ss IP 와 호환되어 elaborate + smoke 통과.
실패 시 — STEP C 로.

### STEP C. Integration 깨짐 디버깅 — 자주 보는 4가지

| 증상 | 진단 명령 | 해결 |
|---|---|---|
| `module not found` | `grep -n include subsystems/host_ss/rtl/host_ss.sv` | `ssd_soc/scripts/compile.f` 의 file 순서 |
| `port direction mismatch` | `git diff main...HEAD ip/<me>/cfg/*.ip.yaml` | parameter 의미 변경 시 SS rtl 도 갱신 PR |
| `multiple drivers on signal` | `verilator -Wall ... | grep MULTIDRIVEN` | tie-off 충돌 — Subsystem wrapper 가 자기 영역만 구동 |
| `CDC violation` | `cat ip/<me>/cfg/waivers.yaml` | 클록 도메인 횡단점에 sync 셀 추가 |

### STEP D. Top SoC Build 로컬 실행 (전체 elaborate)

```bash
cd /tmp/ssd-soc-recommended/work/checkout
make elab 2>&1 | tail || echo "(skip: verilator missing)"
```

Top elaborate 만 통과해도 SoC 통합 관점에서는 **99% 의 인터페이스 호환성** 검증됩니다. 본격 sim/coverage 는 weekly Top CI 가 담당.

### STEP E. Subsystem PR 흐름에 동반 변경 만들기

내 IP 변경이 Subsystem RTL 갱신을 요구하는 경우 (예: 포트 추가):

```bash
# 1) IP repo 의 PR — 새 포트 추가, ip.yaml version MAJOR bump
cd ip/pcie_phy
git checkout -b feature/add-debug-port
# ...edit rtl/, cfg/*.ip.yaml...
git commit -am "pcie_phy: expose debug port (v1.0.0 breaking)"
git push -u origin feature/add-debug-port

# 2) Subsystem repo 의 PR — host_ss.sv 가 새 포트를 연결
cd ../../subsystems/host_ss
git checkout -b feature/wire-pcie_phy-debug
${EDITOR} rtl/host_ss.sv     # 새 포트 wire 추가
git commit -am "host_ss: wire pcie_phy debug port"
git push -u origin feature/wire-pcie_phy-debug
```

**중요**: 두 PR 은 **같은 topic** (`repo upload --topic=...`) 으로 묶거나, IP PR 본문에 Subsystem PR 링크 명시. Subsystem PR 머지는 IP tag 가 push 된 *후* 가 자연스러운 순서.

### STEP F. Integration Window 참여

매주 화/목 manifest-bot 이 만드는 PR 묶음에 본인 IP 의 새 tag 가 포함됩니다.

```bash
# manifest PR 묶음 확인 (가상 — 실제는 GitHub UI)
gh pr list --repo acme-ssd/ssd-soc-manifest --label manifest-bump --state open | head

# 내 IP 의 PR 이 묶여있다면 → manifest CI 결과 확인 → 통과 시 머지 권한자 sign-off
```

**개발자가 할 일**: manifest PR 의 manifest-resolve / integration-sim 결과에 본인 IP 가 원인인 실패가 있으면 즉시 IP repo 에서 hotfix.

### STEP G. Cross-Subsystem Integration (CPU ↔ Host)

대형 SoC 에서는 한 IP 변경이 다른 subsystem 까지 영향:

```
host_ss/pcie_ctrl ──── 변경
                           │
                           ▼
   cpu_ss/irq_ctrl 의 IRQ 매핑 변경 필요  ← 다른 subsystem
```

이 경우 책임:
1. **IP-owner** = 변경 detect (자기 인터페이스가 cross-SS dependent 일 때).
2. PR 본문에 **"Affects: host_ss, cpu_ss"** 명시.
3. 두 subsystem owner 모두 reviewer.
4. Top SoC weekly CI 통과 확인 후에 본인 IP tag 푸시.

### STEP H. Integration 회귀 추적

내 IP 가 어느 시점부터 SoC 통합 sim 을 깨뜨렸는지 추적:

```bash
# manifest 의 어느 bump 부터 fail 시작했는지
cd /tmp/ssd-soc-recommended/work/manifest
git log --oneline -20    # manifest PR 머지 히스토리

# IP 단독 sim 은 통과하지만 SoC sim 에서 fail → integration 회귀
# → verif-framework repo 의 회귀 셋에 본 시나리오 추가 요청
```

---

## 4. 안티패턴 (절대 하지 마세요)

| 안티패턴 | 왜 나쁜가 | 대안 |
|---|---|---|
| Top repo 에서 IP 코드를 직접 수정 | 변경이 IP repo 로 흘러가지 않음. 다음 manifest sync 에서 사라짐 | IP repo 에서 PR |
| `git submodule add` 로 vendor IP 임의 추가 | Manifest 와 일치하지 않음 → SKU 빌드 깨짐 | integration-team 통해 vendor repo + manifest 등록 |
| `// AUTO-GENERATED` 블록 손편집 | 다음 `ipgen` 실행 시 덮어쓰임 | ip.yaml 을 고치고 ipgen 재실행 |
| ip.yaml 의 `qual:` 필드 직접 수정 | CI 가 갱신할 값. drift CI 가 거절 | qual gate CI 통과로 자동 갱신 |
| `git push --force` | 보호 브랜치는 거절되지만, 본인 feature branch 도 다른 사람이 review 중이면 혼란 | 새 commit 으로 fixup |
| Top sim 결과를 IP repo 의 sim 로그로 commit | 거대한 vcd/log 가 IP repo 비대화 | LFS 또는 verif-framework repo |
| `gh repo create` 직접 (manifest 누락) | manifest 에 없는 IP 는 mainline 빌드에서 보이지 않음 | `seed-ip.sh` 사용 |
| ip.yaml 의 owner 를 임의 변경 | drift CI 가 거절, 거버넌스 위반 | 별도 handover PR (이전 owner sign-off) |

---

## 5. 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| `repo sync` 가 특정 IP 에서 실패 | 권한 부재 (보안 IP) | `@security-lead` 에 access 요청 |
| CI `semver-bump-check` fail | ip.yaml version 미bump | version 한 단계 올린 후 push |
| CI `codeowners-drift` fail | ip.yaml owner 변경했는데 CODEOWNERS 손편집 | `python3 tools/sync_codeowners.py --repo .` 실행 후 commit |
| Manifest-bot PR 안 생성됨 | tag 가 `v` prefix 없음 (`0.2.0` ✗ → `v0.2.0` ✓) | tag 재push |
| sim 이 detached HEAD 라고 경고 | 본인 IP 안에서 작업 시작 시 `git checkout main` 잊음 | `git checkout main && git pull` 후 feature branch |
| `Verilator` 가 `interface` 못 찾음 | filelist 의 `+incdir+` 가 늦게 옴 | scripts/compile.f 의 incdir 우선순위 조정 |

---

## 6. IP-owner 추가 책임

본인이 IP-owner 인 경우 더해지는 책임:

1. 다른 팀의 PR review (24시간 SLA).
2. ip.yaml 의 `status` 단계별 책임:
   - `proto`: 인터페이스 안정화 책임.
   - `alpha`: integration sim 깨뜨리지 않을 책임.
   - `qual`: CDC/coverage 모두 pass 유지.
   - `gold`: 양산 SKU 의 sign-off 까지 백업.
3. backup owner 와의 정기 sync (1on1).
4. waiver 만료 추적.

---

## 7. 빠른 참조

```bash
# 새 IP 워크스페이스
repo init -u <manifest> -b main -m default.xml && repo sync

# 자기 IP 만
git clone git@github.com:acme-ssd/ip-<name>.git

# 자기 IP 의 시그니처 재생성
python3 ../../tools/ipgen.py --ip-yaml ip.yaml

# CODEOWNERS 동기화 (PR 전)
python3 ../../tools/sync_codeowners.py --repo .

# 로컬 lint / sim
make lint && make sim

# 새 IP 추가 요청 (관리자 권한)
recommended/scaffolding/seed-ip.sh <name> <subsystem> <team> "<desc>"

# 현재 BOM
python3 ../../tools/bom.py --manifest manifest/default.xml --workdir . --output BOM.md
```

---

## 8. 관련 문서
- 시스템 설계 → [`01-design.md`](01-design.md)
- 초기 구축 (관리자) → [`02-build-guide.md`](02-build-guide.md)
- 일상 운영 (관리자) → [`03-admin-guide.md`](03-admin-guide.md)
