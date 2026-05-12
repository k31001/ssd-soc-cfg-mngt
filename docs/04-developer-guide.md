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
