# 01-Monorepo — Admin Tutorial

> 형상관리 관리자(Configuration Manager)가 monorepo 전략을 채택했을 때
> **첫 구축부터 일상 운영, 사고 대응까지** 단계별로 수행해보는 튜토리얼.
> 모든 명령은 로컬에서 그대로 재현 가능. 소요 시간 약 **30분**.

대상: 형상관리 관리자, 빌드 엔지니어, 릴리스 매니저.

---

## STEP 0. 사전 점검

```bash
git --version    # >= 2.40 (sparse-checkout cone 모드)
gh --version     # >= 2.40
python3 --version
gh auth status
```

전체 SoC 가 단일 repo 라는 점이 monorepo 의 결정적 특성. 100명+ 운영에서는
다음 기능들이 활성화되어 있어야 합니다:

```bash
# 큰 repo 친화 설정 (관리자가 표준화)
git config --global feature.manyFiles true
git config --global fetch.writeCommitGraph true
git config --global core.fsmonitor true
git config --global pack.threads 4
```

---

## STEP 1. 신규 monorepo 부트스트랩 (로컬 시연)

```bash
ROOT=/tmp/monorepo-admin
rm -rf $ROOT && mkdir -p $ROOT
git init -q --bare $ROOT/ssd-soc.git

# 본 저장소의 ssd_soc/ + tools/ + ci/ 등을 mainline 으로 push
STAGE=$(mktemp -d)
cp -r /Users/euihyeokkwon/Works/soc-cfg-mngt/. $STAGE/
( cd $STAGE
  rm -rf .git
  git init -q -b main
  git -c user.email=admin@example.com -c user.name=admin add -A
  git -c user.email=admin@example.com -c user.name=admin commit -q -m "init monorepo"
  git remote add origin $ROOT/ssd-soc.git
  git push -q origin main
)
echo "[ok] monorepo seed: $ROOT/ssd-soc.git"
```

---

## STEP 2. CODEOWNERS 일괄 적용 + drift 점검

monorepo 의 핵심은 단일 CODEOWNERS 가 모든 권한을 관장한다는 것. 본 데모 디렉터리의 샘플을 적용:

```bash
WORK=$(mktemp -d)
git clone -q $ROOT/ssd-soc.git $WORK
cd $WORK

mkdir -p .github
cp /Users/euihyeokkwon/Works/soc-cfg-mngt/cm-strategies/01-monorepo/CODEOWNERS .github/CODEOWNERS
git -c user.email=admin@example.com -c user.name=admin add .github/CODEOWNERS
git -c user.email=admin@example.com -c user.name=admin commit -q -m "ci: install CODEOWNERS"
git push -q origin main
```

**Drift 점검** — 모든 IP 의 `ip.yaml` `owner` 필드와 CODEOWNERS 항목이 일치하는지:

```bash
cd $WORK
python3 - <<'PY'
import re, glob, sys, pathlib
sys.path.insert(0, '/Users/euihyeokkwon/Works/soc-cfg-mngt/tools')
from bom import parse_simple_yaml

co_text = open('.github/CODEOWNERS').read()
errors = 0
for f in sorted(glob.glob('ssd_soc/subsystems/*/ip/*/cfg/*.ip.yaml')):
    meta = parse_simple_yaml(open(f).read())
    ip_owner = meta.get('owner','?')
    # 본 IP 경로가 CODEOWNERS 중 어디에 매핑되는지
    ip_path = pathlib.Path(f).parents[2]   # ssd_soc/subsystems/<ss>/ip/<name>/
    found = None
    for line in co_text.splitlines():
        if line.strip().startswith('#') or not line.strip(): continue
        parts = line.split(None, 1)
        if not parts: continue
        pat = parts[0].rstrip('/')
        if str(ip_path).startswith(pat):
            found = parts[1] if len(parts) > 1 else ''
    if found is None:
        print(f"::warning::{ip_path} not matched"); errors += 1
        continue
    if ip_owner.split('/')[-1].split('-')[0] not in found:
        print(f"::warning::owner mismatch {ip_path}: ip.yaml={ip_owner} CODEOWNERS={found}")
        errors += 1
print(f"\nTotal mismatches: {errors}")
PY
```

운영 환경에서는 이 스크립트를 **weekly CI** 로 돌려 알림.

---

## STEP 3. Branch Protection (모든 보호 브랜치에 동일 적용)

GitHub Enterprise 가 있다고 가정한 명령. 로컬에서는 시뮬레이션만:

```bash
# (원격 모드) 본 monorepo 의 main 브랜치 보호 적용
gh api "repos/k31001/ssd-soc-cfg-mngt/branches/main/protection" \
  --method PUT \
  --input /Users/euihyeokkwon/Works/soc-cfg-mngt/recommended/scaffolding/policy/branch-protection.json \
  -H "Accept: application/vnd.github+json" 2>&1 | head -5 || echo "(no remote — skipping)"
```

표준 정책 핵심 (단일 source: `branch-protection.json`):
- `required_pull_request_reviews.required_approving_review_count = 1`
- `require_code_owner_reviews = true`
- `required_linear_history = true`
- `required_status_checks` 로 `lint`, `yaml-schema`, `smoke-sim` 등 강제

---

## STEP 4. 신규 IP 추가 — monorepo 식

submodule/manifest 와 달리, monorepo 에서 새 IP는 단순히 **디렉터리 + PR**:

```bash
cd $WORK
NEW_IP=thermal_sensor
NEW_SS=host_ss
mkdir -p ssd_soc/subsystems/$NEW_SS/ip/$NEW_IP/{rtl,sim,cfg,doc}

cat > ssd_soc/subsystems/$NEW_SS/ip/$NEW_IP/cfg/$NEW_IP.ip.yaml <<EOF
name: $NEW_IP
version: 0.1.0
status: proto
owner: "@acme-ssd/host-team"
subsystem: $NEW_SS
bus: apb
license: Apache-2.0
language: SystemVerilog
description: |
  Thermal sensor digital readout
parameters: {}
dependencies: ["common-libs >= 1.0.0"]
qual: { lint: pending, cdc: pending, coverage: pending, formal: pending, qual_report: null }
files: { rtl: [rtl/$NEW_IP.sv], sim: [sim/tb_$NEW_IP.sv] }
EOF

cat > ssd_soc/subsystems/$NEW_SS/ip/$NEW_IP/rtl/$NEW_IP.sv <<EOF
module $NEW_IP (input logic clk, input logic rst_n);
  initial \$display("[STUB] %m");
endmodule
EOF

cat > ssd_soc/subsystems/$NEW_SS/ip/$NEW_IP/sim/tb_$NEW_IP.sv <<EOF
\`timescale 1ns/1ps
module tb_$NEW_IP; logic clk=0,rst_n=0; always #5 clk=~clk;
  initial begin #20 rst_n=1; #100 \$display("[tb] ok"); \$finish; end
endmodule
EOF

# filelist 갱신도 PR 의 일부
echo "ssd_soc/subsystems/$NEW_SS/ip/$NEW_IP/rtl/$NEW_IP.sv" >> ssd_soc/scripts/compile.f

# CODEOWNERS 갱신 (자동 도구로 대체 가능)
# (host_ss 패턴이 이미 매칭하므로 추가 항목 불필요 — 그게 monorepo 의 단순함)

git checkout -b add-ip/$NEW_IP
git -c user.email=admin@example.com -c user.name=admin add -A
git -c user.email=admin@example.com -c user.name=admin commit -q -m "ip/$NEW_IP: onboard new IP under $NEW_SS"
git push -q origin add-ip/$NEW_IP || echo "(local bare — PR step skipped)"
```

monorepo onboarding 의 강점: **외부 manifest/매니페스트 PR 등 부수 절차가 없음**. 단일 PR.

---

## STEP 5. SKU 동결 (Release Snapshot)

monorepo 에서는 SKU 동결 = **tag** 입니다 (multi-repo 의 manifest snapshot 과 등가).

```bash
cd $WORK
# 모든 변경을 머지한 후 mainline 에서 양산 후보 tag
git checkout main
git pull -q
git tag -a sku-gen4-1tb-rc1 -m "Gen4 1TB release candidate 1"
git push -q origin sku-gen4-1tb-rc1

# BOM 산출 (가능한 한 monorepo 안의 ip.yaml 들로 직접)
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/bom.py \
   --manifest /Users/euihyeokkwon/Works/soc-cfg-mngt/cm-strategies/03-repo-manifest/default.xml \
   --workdir  $WORK \
   --output   $WORK/BOM-sku-gen4-1tb-rc1.md
head -10 $WORK/BOM-sku-gen4-1tb-rc1.md
```

> manifest 기반 BOM 도구를 그대로 재활용. monorepo 라도 `path` 만 맞으면 동작.

---

## STEP 6. 사고 대응 — 비밀 키 누출

가장 위험한 시나리오. **destructive 명령 금지** 원칙은 monorepo 에서도 동일.

```bash
# 1) 즉시 main 잠금 (GitHub API)
gh api "repos/k31001/ssd-soc-cfg-mngt/branches/main/protection" \
  --method PATCH -f lock_branch=true 2>/dev/null || true

# 2) 회전 (rotate) — 노출된 secret 즉시 폐기/재발급. 이건 GitHub 가 아님.
echo "[manual] revoke leaked credentials in source system FIRST"

# 3) 클린 history 작성 (별도 작업 디렉터리, 절대 mainline 에서 force push 금지)
CLEAN=$(mktemp -d)
git clone -q --mirror $ROOT/ssd-soc.git $CLEAN/repo.git
cd $CLEAN/repo.git
# git-filter-repo (사전 설치 필요): 비밀이 든 path 를 모든 히스토리에서 제거
# 데모 — 실제로는 비밀 파일이 있어야 의미 있음
# pip install git-filter-repo
# git filter-repo --invert-paths --path some/leaked/file --force

# 4) 새 repo 로 이주, 원본은 archive
# gh repo archive k31001/ssd-soc-cfg-mngt -y
```

핵심 원칙:
1. **이미 외부에 clone 된 SHA는 노출됐다고 가정**. force push 로 history 다시 쓰는 것은 mainline 에 절대 적용 불가.
2. **노출 자산(키/토큰) 회전이 가장 먼저**. Git history 청소는 secondary.
3. **새 repo + archive 원본** 패턴이 모든 협력 환경에서 가장 안전.

---

## STEP 7. CI 비용 관리 (monorepo 특화)

monorepo 에서 PR 1건이 전체 CI 를 trigger 하면 비용 폭발. **path filter** 가 핵심:

```yaml
# .github/workflows/ip-ci.yml 예시
on:
  pull_request:
    paths:
      - 'ssd_soc/subsystems/host_ss/ip/**'   # host_ss IP 변경에만 반응
      - 'ssd_soc/common/**'                   # 공통 변경은 전체 trigger 의도
```

이를 통해 PR 별 평균 빌드 시간을 30% 이상 절감 가능 (실제 OpenTitan 운영 케이스 기준).

---

## STEP 8. 매주 KPI 리포트

monorepo 에서 관리자가 매주 점검할 4개 지표:

```bash
cd $WORK
# 1) 미머지 feature branch 중 5일 이상 된 것
git for-each-ref --format='%(refname:short) %(committerdate:relative)' refs/heads/ \
  | grep -E '(weeks? ago|months? ago)' | head

# 2) 큰 파일 / LFS 후보 (>5MB) — monorepo 비대화 방지
git rev-list --objects --all 2>/dev/null \
  | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' 2>/dev/null \
  | awk '$1=="blob" && $2>5000000 {print $2, $3}' | sort -rn | head

# 3) 최근 1주 lint 위반 건수 (CI artifact 에서 추출 — 가상)
echo "lint-violations-this-week: (gh api ...)"

# 4) Top SoC build 시간 추이
echo "top-soc-build-time: weekly trend chart"
```

---

## 자주 만나는 함정 (Admin 관점)

| 증상 | 원인 | 해결 |
|---|---|---|
| Repo 가 3년 후 50GB 가 됨 | LFS 미적용 + 큰 PD 산출물 직접 commit | `.gitattributes` LFS pattern + 매년 archive |
| 1개 IP 변경에도 전체 CI 가 돔 | path filter 미설정 | workflow `paths:` 명시 |
| CODEOWNERS 가 너무 길어짐 | IP 마다 owner 패턴 중복 | subsystem 단위로 묶고 IP override 는 예외만 |
| 보안 IP 의 누가 push 했는지 추적 어려움 | repo 단위 ACL 가 단일 | 보안 IP는 별도 repo 로 격리 (=하이브리드 전환) |
| 신규 개발자가 잘못된 IP 디렉터리에 commit | path 헷갈림 | pre-commit hook 으로 IP 경로 검증 |

---

## 정리

| Monorepo 가 잘 맞는 환경 | Monorepo 를 다시 고려해야 할 신호 |
|---|---|
| 단일 팀 / 단일 라이선스 | 외부 vendor IP 가 5개 넘게 늘어남 |
| Atomic cross-IP refactor 가 빈번 | 보안 IP 에 ACL 강제가 필요 |
| 모든 코드의 lifecycle 이 비슷 | PD/PDK 데이터 가 RTL 보다 커짐 |
| CI 인프라가 path filter 잘 지원 | SKU 파생이 5개 이상으로 늘어남 |

다음 단계: [02-submodule ADMIN-TUTORIAL](../02-submodule/ADMIN-TUTORIAL.md) — 같은 작업을 submodule 방식으로 수행.
