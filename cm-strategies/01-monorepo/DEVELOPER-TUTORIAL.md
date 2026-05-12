# 01-Monorepo — Developer Tutorial

> 처음부터 끝까지 따라 하는 **튜토리얼**. 한 줄씩 실행하면서 monorepo 전략에서
> RTL 개발자가 일상적으로 마주치는 모든 시나리오를 직접 체험합니다.
> 소요 시간 약 **20분**.

대상: SSD SoC 의 IP-level RTL 개발자.
전제: macOS/Linux + Git ≥ 2.40 + Python 3.10+.

---

## STEP 0. 데모 워크스페이스 준비

전체 SoC repo 가 한 덩어리(monorepo) 라고 가정합니다. 본 저장소가 그 자체로 monorepo 형태이므로 그대로 활용:

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
ls
# .gitignore  Makefile  README.md  ci  cm-strategies  docs  recommended  ssd_soc  tools
```

본 저장소 자체를 mini-monorepo 라고 생각하고, **`ssd_soc/`** 를 SoC RTL tree로 다룹니다.

**예상 출력 시 통과 기준**: `ssd_soc/`, `tools/`, `Makefile` 이 모두 보임.

---

## STEP 1. 전체 클론 vs 부분 클론

### 1a. 전체 클론 (Newcomer first day)
```bash
mkdir -p /tmp/mono-demo && cd /tmp/mono-demo
git clone /Users/euihyeokkwon/Works/soc-cfg-mngt ssd-soc
cd ssd-soc
du -sh .
# ~10MB 정도 (실제 SoC 면 100MB~수GB)
```

### 1b. host_ss 팀: sparse-checkout 으로 자기 영역만
```bash
cd /tmp
rm -rf host-only
git clone --filter=blob:none --no-checkout \
   /Users/euihyeokkwon/Works/soc-cfg-mngt host-only
cd host-only
git sparse-checkout init --cone
git sparse-checkout set \
    ssd_soc/common \
    ssd_soc/subsystems/host_ss \
    tools docs ci
git checkout main

ls ssd_soc/subsystems/
# host_ss 만 보임
du -sh .
# 전체 대비 훨씬 작음
```

**중요 포인트**: cone-mode sparse-checkout 은 디렉터리 단위라서 EDA 도구가 path 못 찾는 문제가 거의 없습니다.

---

## STEP 2. 첫 PR — 내 IP에 dummy 레지스터 추가

### 2a. 브랜치 만들고 IP 위치로 이동
```bash
cd /tmp/host-only
git checkout -b feature/add-status-reg
cd ssd_soc/subsystems/host_ss/ip/pcie_phy
ls
# cfg  doc  rtl  sim
```

### 2b. RTL 수정 — 더미 상태 레지스터 노출
`rtl/pcie_phy.sv` 를 열고 `endmodule` 직전에 다음을 추가:

```systemverilog
  // STATUS register (read-only, demo)
  logic [31:0] status_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) status_reg <= 32'h0;
    else        status_reg <= status_reg + 1'b1;  // dummy counter
  end
```

### 2c. ip.yaml 의 version bump (CI 가 필수로 요구)
`cfg/pcie_phy.ip.yaml` 의 `version: 0.1.0` → `version: 0.2.0` 으로 수정.

```bash
sed -i.bak 's/version:     0\.1\.0/version:     0.2.0/' cfg/pcie_phy.ip.yaml
rm cfg/pcie_phy.ip.yaml.bak
grep version cfg/pcie_phy.ip.yaml
# version:     0.2.0
```

### 2d. 로컬 검증 (도구 없으면 skip 가능)
```bash
cd /tmp/host-only
# Verilator 가 있으면 lint
which verilator && make lint || echo "(skip: verilator not installed)"
```

### 2e. Commit
```bash
git add -A
git -c user.email=demo@example.com -c user.name=demo \
    commit -m "pcie_phy: expose dummy status counter (v0.2.0)"
git log --oneline -1
```

**튜토리얼 핵심**: monorepo 에서는 **단일 commit** 이 모든 변경을 담음. 다른 IP 와의 atomic refactor 도 같은 commit 으로 가능.

---

## STEP 3. Atomic Cross-IP 변경 — monorepo 의 진짜 장점

PCIe controller 와 NVMe processor 의 인터페이스를 동시에 변경한다고 가정.

```bash
cd /tmp/mono-demo/ssd-soc   # 전체 클론으로 이동 (cross-IP 보려면 풀체크아웃 필요)
git checkout -b refactor/axi-new-handshake

# 두 IP 의 RTL 을 한 commit 으로 수정
for ip in pcie_ctrl nvme_cmd_proc; do
  echo "// refactor: new handshake API" \
    >> ssd_soc/subsystems/host_ss/ip/$ip/rtl/$ip.sv
done

# 두 ip.yaml version 동시 bump
for ip in pcie_ctrl nvme_cmd_proc; do
  sed -i.bak 's/version:     0\.1\.0/version:     0.2.0/' \
    ssd_soc/subsystems/host_ss/ip/$ip/cfg/$ip.ip.yaml
  rm ssd_soc/subsystems/host_ss/ip/$ip/cfg/$ip.ip.yaml.bak
done

git add -A
git -c user.email=demo@example.com -c user.name=demo \
    commit -m "axi: new handshake API across pcie_ctrl + nvme_cmd_proc"
git show --stat HEAD | tail -10
```

**이 commit 하나로** 두 IP 가 동시에 새 인터페이스로 이행. submodule 이었다면 PR 3개(IP×2 + top)가 필요했을 작업.

---

## STEP 4. Sparse 환경에서 cross-IP 변경이 필요해질 때

host_ss 만 sparse-checkout 한 개발자가 NVMe IP 도 봐야 하면:

```bash
cd /tmp/host-only
git sparse-checkout add ssd_soc/subsystems/host_ss/ip/nvme_cmd_proc
ls ssd_soc/subsystems/host_ss/ip/
# 이제 nvme_cmd_proc 가 보임
```

원래 모드(자기 영역만) 로 돌아가려면:
```bash
git sparse-checkout reapply
```

---

## STEP 5. CODEOWNERS 가 PR 흐름을 어떻게 강제하는가

`cm-strategies/01-monorepo/CODEOWNERS` 가 표준 위치 (`.github/CODEOWNERS`) 로 복사된다고 가정.
원격이 GitHub Enterprise 일 때 PR 생성 시:
- `ssd_soc/subsystems/host_ss/` 안의 변경 → `@acme-ssd/host-team` 자동 reviewer.
- `ssd_soc/common/` 변경 → `@acme-ssd/platform-team` 자동 reviewer.
- `ssd_soc/subsystems/sec_ss/ip/aes_engine/` 변경 → `@crypto-team` + `@security-lead` 두 명 요구.

로컬에서는 동작 시뮬레이션 불가. PR 생성 시 GitHub UI 가 강제합니다.

**Tip — 본인 PR이 어떤 reviewer 그룹을 trigger 하는지 미리 확인**:
```bash
# 변경된 파일 목록을 CODEOWNERS 와 매칭
git diff --name-only main...HEAD | while read f; do
  grep -E "^[^#]*${f%/*}" cm-strategies/01-monorepo/CODEOWNERS | head -1
done | sort -u
```

---

## STEP 6. SKU 별 빌드 — parameter 기반

monorepo 에서 파생 SKU 처리의 권장 방법은 **branch 분리 X**, **parameter 주입 ✓**.

```bash
cd /tmp/mono-demo/ssd-soc
ls ssd_soc/top/cfg/
cat ssd_soc/top/cfg/top.yaml
```

`top.yaml` 의 `derivatives:` 리스트가 SKU 명세. SKU 별 빌드는 makefile parameter 로:

```bash
# gen4 1TB SKU 빌드
make sim TOP=ssd_soc_top SKU=gen4-1tb || echo "(verilator 미설치 — 가상 실행)"

# gen5 4TB SKU 빌드
make sim TOP=ssd_soc_top SKU=gen5-4tb || echo "(verilator 미설치)"
```

이 방식의 의미: **분기/디렉터리/태그 분리 없이** SKU 차이를 parameter+conditional generate 로 흡수.

---

## STEP 7. PR 머지 후 정리

```bash
cd /tmp/mono-demo/ssd-soc
# 가상 리뷰/머지 후
git checkout main
git branch -d refactor/axi-new-handshake
git log --oneline -5
```

---

## 자주 만나는 함정 (Pitfalls — monorepo edition)

| 증상 | 원인 | 해결 |
|---|---|---|
| `git status` 가 무거움 | repo 전체 크기 | `git config feature.manyFiles true`, fsmonitor 활성화 |
| PR 1건이 모든 CI 작업을 trigger | path filter 미적용 | workflow `paths:` 에 디렉터리 명시 |
| sparse-checkout 모드에서 EDA 도구가 path 못찾음 | non-cone 모드 사용 | `git sparse-checkout init --cone` 만 사용 |
| 다른 팀의 변경으로 머지 충돌 빈발 | branch 너무 오래 유지 | feature branch < 5일 |
| 비밀 키 실수 commit | `git filter-repo` 필요 | mainline 으로 push 전이라면 `git reset --soft`, push 됐다면 ADMIN guide 의 사고대응 |

---

## 정리

| 한 줄 요약 | "Monorepo = single source of truth, atomic refactor 최강, 단 권한 격리는 CODEOWNERS 로만." |
|---|---|

| 다음 단계 | 같은 SoC를 [02-submodule](../02-submodule/DEVELOPER-TUTORIAL.md) / [03-repo-manifest](../03-repo-manifest/DEVELOPER-TUTORIAL.md) / [04-subtree](../04-subtree/DEVELOPER-TUTORIAL.md) 로 다뤘을 때의 비교 |
