# 02. 구축 가이드 (Build Guide)

> **TL;DR** — 본 가이드는 백지 GitHub Enterprise 조직에서 시작해
> SSD Controller SoC 형상관리 시스템을 **단계별로 구축**합니다.
> 모든 명령은 재현 가능하며, GitHub Enterprise 가 없으면 로컬 모드
> (`--local`) 로 동일 절차를 시연할 수 있습니다.

전체 소요 시간(원격 모드): **2~3시간**. 로컬 데모 모드: **약 5분**.

---

## 0. 사전 준비 (Prerequisites)

### 0.1 도구
| 도구 | 버전 | 용도 |
|---|---|---|
| Git | ≥ 2.40 | 기본 |
| Python | ≥ 3.10 | tools/* 실행 |
| `gh` (GitHub CLI) | ≥ 2.40 | repo 생성/branch protection (원격 모드) |
| `repo` (옵션) | latest | AOSP manifest 도구 — 없으면 `repo_lite.py` 폴백 |
| Verilator (옵션) | ≥ 5.0 | local elab/sim |
| Verible (옵션) | latest | lint |

### 0.2 GitHub Enterprise 권한 (원격 모드 한정)
- Organization: `acme-ssd` (예시) Owner 권한.
- 다음 teams 사전 생성:
  - `@acme-ssd/integration-team`
  - `@acme-ssd/platform-team`
  - `@acme-ssd/host-team`, `flash-team`, `mem-team`, `cpu-team`, `security-team`
  - `@acme-ssd/legal-team`, `docs-team`, `pd-team`, `verif-team`
  - 각 team 의 `-backup` 별칭

### 0.3 인증
```bash
gh auth login                       # GitHub Enterprise SSO 로그인
gh auth status
```

---

## 1. 빠른 시작 (Local Mode — 5분 시연)

GitHub Enterprise 가 없는 환경에서 전체 시스템을 로컬에서 확인:

```bash
# 1) 본 저장소 클론
git clone <THIS_REPO> ssd-soc-cfg
cd ssd-soc-cfg

# 2) 가상 SoC 스켈레톤 부트스트랩 (이미 존재 시 skip)
python3 tools/scaffold_ssd_soc.py

# 3) 로컬 bare repo + manifest + sync + BOM end-to-end
./recommended/scaffolding/local-bootstrap.sh /tmp/ssd-soc-demo

# 4) 결과 확인
ls /tmp/ssd-soc-demo/work/           # checkout, checkout-gen5, BOM.md, manifest
head /tmp/ssd-soc-demo/work/BOM.md
python3 tools/repo_lite.py status \
    --manifest /tmp/ssd-soc-demo/work/manifest/default.xml \
    --workdir  /tmp/ssd-soc-demo/work/checkout
```

이 절차로 다음이 검증됩니다:
- 34개 component (1 top + 5 SS + 25 IP + common + verif + pdk) 동시 동기화
- mainline manifest 와 SKU manifest 의 분기 동작
- BOM 자동 생성
- repo_lite freeze 로 release snapshot 가능

---

## 2. 본 구축 절차 (Remote Mode — GitHub Enterprise)

### 2.1 [STEP 1] 조직/팀 셋업
```bash
# 조직과 팀들이 이미 존재한다고 가정. 누락분만 생성:
for t in integration-team platform-team host-team flash-team mem-team cpu-team \
         security-team legal-team docs-team pd-team verif-team; do
  gh api -X POST orgs/acme-ssd/teams -f name="$t" -f privacy=closed || true
done
```

### 2.2 [STEP 2] Manifest repo 생성
```bash
gh repo create acme-ssd/ssd-soc-manifest --internal \
   --description "SSD SoC manifest (mainline + SKU variants)"

# 본 저장소의 recommended/manifest/* 를 manifest repo 로 push
git clone git@github.com:acme-ssd/ssd-soc-manifest.git /tmp/mfst
cp recommended/manifest/*.xml /tmp/mfst/
cd /tmp/mfst
git add -A && git commit -m "init manifest" && git push
cd -
```

### 2.3 [STEP 3] 공통 repo 생성 (top, common-libs, verif-framework, pdk-views)
```bash
gh repo create acme-ssd/ssd-soc-top      --internal --description "Top SoC integration"
gh repo create acme-ssd/common-libs      --internal --description "Common SV interfaces/BFM/pkg"
gh repo create acme-ssd/verif-framework  --internal --description "UVM/verif env"
gh repo create acme-ssd/pdk-views        --private  --description "PDK views (LFS)"
```

본 데모 트리(`ssd_soc/`) 를 분리해서 각 repo로 푸시 — 스크립트 1줄:
```bash
recommended/scaffolding/seed-ss.sh host_ss host-team "PCIe/NVMe host subsystem"
# (5개 subsystem 모두 동일 명령으로)
```

### 2.4 [STEP 4] 25개 IP repo 생성
```bash
# host_ss 의 5개 IP 예시
for ip in pcie_phy:host-team:"PCIe PHY" pcie_ctrl:host-team:"PCIe controller" \
          nvme_cmd_proc:host-team:"NVMe cmd proc" host_dma:host-team:"Host DMA" \
          pcie_cfg:host-team:"PCIe config space"; do
  IFS=: read name team desc <<<"$ip"
  recommended/scaffolding/seed-ip.sh "$name" host_ss "$team" "$desc"
done
# 나머지 4 subsystem 동일 패턴. 1 IP onboarding ≈ 30초.
```

`seed-ip.sh` 가 내부적으로 수행:
1. `gh repo create acme-ssd/ip-<name>` (private)
2. `ip-template/` 변수 치환 + 초기 commit/push
3. `apply-branch-protection.sh` 로 정책 적용
4. `manifest_bump.py add-ip` 로 manifest PR 자동 생성

### 2.5 [STEP 5] Reusable workflow repo (`acme-ssd/.github`) 등록
```bash
gh repo create acme-ssd/.github --internal
git clone git@github.com:acme-ssd/.github.git /tmp/dot-github
mkdir -p /tmp/dot-github/.github/workflows /tmp/dot-github/schemas
cp ci/reusable/*.yml      /tmp/dot-github/.github/workflows/
cp recommended/scaffolding/policy/ip-yaml-schema.json /tmp/dot-github/schemas/

# CI에서 .ci/ 디렉터리로 호출되는 helper 스크립트
mkdir -p /tmp/dot-github/.ci
cp tools/repo_lite.py tools/bom.py tools/sync_codeowners.py \
   tools/manifest_bump.py tools/release.py /tmp/dot-github/.ci/

cd /tmp/dot-github
git add -A && git commit -m "init reusable workflows + helpers" && git push
cd -
```

이후 모든 IP repo 는 `acme-ssd/.github/.github/workflows/reusable-*.yml@main` 을 참조하므로,
정책 변경 시 본 repo 한 곳만 수정합니다.

### 2.6 [STEP 6] Manifest-bot 활성화
```bash
# secrets 등록 (organization secret — 모든 IP repo에서 dispatch 가능)
gh api -X PUT orgs/acme-ssd/actions/secrets/MANIFEST_BUMP_TOKEN \
   -f encrypted_value=<encrypted-PAT> -f visibility=all

# manifest-bot workflow 를 ssd-soc-manifest repo 에 설치
cp ci/manifest-bot.yml /tmp/mfst/.github/workflows/
cd /tmp/mfst && git add -A && git commit -m "install manifest-bot" && git push && cd -
```

### 2.7 [STEP 7] 첫 nightly 통과까지 확인
1. 임의 IP repo에서 PR 1건 생성 → IP-CI 4개 job 모두 녹색 확인.
2. IP tag (`v0.1.1`) push → manifest-bot 이 ssd-soc-manifest 에 PR 자동 생성.
3. PR 머지 → top repo의 manifest-resolve job 이 정상 resolve.
4. Top repo `weekly` workflow 한 번 trigger 후 release snapshot 산출 확인.

---

## 3. 검증 체크리스트

구축 완료 시 다음 모두 ✅ 여야 합니다.

- [ ] 34개 component repo 가 GitHub Enterprise 에 존재
- [ ] 각 IP repo 에 ip.yaml, CODEOWNERS, .github/workflows/ip-ci.yml 존재
- [ ] 모든 IP repo 의 main 브랜치에 protection 적용됨 (`gh api repos/.../branches/main/protection`)
- [ ] `ssd-soc-manifest/default.xml` 이 34개 project 모두 포함
- [ ] sku-gen4-1tb.xml, sku-gen5-4tb.xml 각각 정상 parse 됨 (`tools/repo_lite.py sync --groups default`)
- [ ] 임의 PR 에서 lint/yaml/smoke-sim 통과 또는 의도적 실패 확인됨
- [ ] manifest-bot 의 ip-tag-published dispatch가 PR 생성으로 이어짐
- [ ] `tools/bom.py` 가 BOM markdown 생성
- [ ] `tools/release.py snapshot` 이 동결 manifest 산출

---

## 4. 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| `repo sync` 가 hang | 인증 미캐시 | `gh auth setup-git` 후 재시도 |
| `seed-ip.sh` 가 manifest PR 단계에서 실패 | secrets.MANIFEST_BUMP_TOKEN 미설정 | STEP 6 secrets 확인 |
| CODEOWNERS drift CI 가 항상 fail | ip.yaml 의 owner 가 존재하지 않는 GitHub team | `gh api orgs/acme-ssd/teams/<slug>` 로 존재 확인 |
| Verilator elab 실패 (`module not found`) | filelist 의 incdir 순서 | `ssd_soc/scripts/compile.f` 의 `+incdir+` 가 모든 SV 위에 위치 |
| `repo init` 가 Windows 에서 실패 | repo 도구의 POSIX 의존 | dev container (Ubuntu 22.04) 사용 |
| Branch protection 적용 실패 (HTTP 403) | gh CLI 권한 부족 | `repo:admin` scope PAT 사용 |

---

## 5. 다음 단계
- 일상 운영 → [`03-admin-guide.md`](03-admin-guide.md)
- IP 개발자 워크플로 → [`04-developer-guide.md`](04-developer-guide.md)
