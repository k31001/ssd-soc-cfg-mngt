# 02-Submodule — Admin Tutorial

> 형상관리 관리자가 Git Submodule 전략을 채택했을 때 부트스트랩부터
> 일상 운영, IP onboarding, SKU 분기, 사고 대응까지 단계별로 수행.
> 소요 시간 약 **35분**.

대상: 형상관리 관리자, 릴리스 매니저.

---

## STEP 0. 사전 점검 + Git 옵션

```bash
git --version              # >= 2.40
gh --version
```

**관리자가 표준으로 강제해야 할 git config** — 모든 개발자가 동일해야 합니다:

```bash
git config --global submodule.recurse true           # add/checkout 시 자동 재귀
git config --global submodule.fetchJobs 8            # 병렬 fetch
git config --global push.recurseSubmodules check     # 부모 push 전 자식 push 확인
git config --global diff.submodule log               # diff 출력에 commit 메시지 포함
```

위 4줄을 회사 dotfiles 또는 onboarding 스크립트에 박아둘 것.

---

## STEP 1. 부트스트랩 (Top + 25 IP + 5 SS + common-libs)

본 데모는 로컬 bare repo 로 부트스트랩:

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
./cm-strategies/02-submodule/bootstrap-bare-repos.sh /tmp/sub-admin

ls /tmp/sub-admin/remotes | wc -l
# 31 (1 common + 5 ss + 25 ip)
ls /tmp/sub-admin/work/ssd-soc-top
cd /tmp/sub-admin/work/ssd-soc-top
cat .gitmodules | head -20
git submodule status | head
```

원격 모드(GitHub Enterprise) 라면 다음 한 줄들로 동일 작업:

```bash
# (원격 모드 — 데모용으로 실행 X)
gh repo create acme-ssd/ssd-soc-top --internal
for ss in host_ss fcc_ss mem_ss cpu_ss sec_ss; do
  gh repo create acme-ssd/$ss --internal
done
gh repo create acme-ssd/common-libs --internal
for ip in $(cat ip-catalog.txt); do gh repo create acme-ssd/ip-$ip --internal; done
# Top 에서 git submodule add 일괄 실행 → push
```

---

## STEP 2. `.gitmodules` 관리 (관리자 단일 권한)

`.gitmodules` 는 100명+ 환경에서 **관리자만 수정** 합니다. 일반 개발자가 임의로
submodule 추가하면 라이선스/권한 우회 가능. 정책:

```bash
# CODEOWNERS 에 .gitmodules 를 platform-team 단독 권한으로
cat >> /tmp/sub-admin/work/ssd-soc-top/.github/CODEOWNERS <<EOF
.gitmodules    @acme-ssd/platform-team @acme-ssd/legal-team
EOF
```

CI 가 `git diff --name-only origin/main HEAD` 에 `.gitmodules` 포함되면 자동으로
platform-team 리뷰 요구.

---

## STEP 3. 신규 IP onboarding (submodule add)

```bash
NEW_IP=thermal_sensor
cd /tmp/sub-admin

# 1) IP repo (bare) 생성 + 초기 컨텐츠
mkdir -p remotes
git init -q --bare remotes/ip-$NEW_IP.git
STAGE=$(mktemp -d)
cp -r /Users/euihyeokkwon/Works/soc-cfg-mngt/recommended/scaffolding/ip-template/. $STAGE/
sed -i.bak \
  -e "s/\${IP_NAME}/$NEW_IP/g" \
  -e "s|\${IP_DESCRIPTION}|Thermal sensor digital readout|g" \
  -e "s/\${SUBSYSTEM}/host_ss/g" \
  -e "s/\${TEAM}/host-team/g" \
  $(find $STAGE -type f \( -name "*.yaml" -o -name "*.md" -o -name "*.yml" -o -name CODEOWNERS \))
find $STAGE -name "*.bak" -delete
( cd $STAGE
  git init -q -b main
  git -c user.email=a@e -c user.name=a add -A
  git -c user.email=a@e -c user.name=a commit -q -m "init $NEW_IP"
  git remote add origin /tmp/sub-admin/remotes/ip-$NEW_IP.git
  git push -q origin main
)

# 2) Top repo 에 submodule 로 추가
cd /tmp/sub-admin/work/ssd-soc-top
git submodule add -q /tmp/sub-admin/remotes/ip-$NEW_IP.git ip/$NEW_IP
git -c user.email=a@e -c user.name=a commit -aq -m "ip/$NEW_IP: register as submodule"
git submodule status | grep $NEW_IP
```

**자동화 — 같은 작업을 한 줄 스크립트로**:
```bash
# 가상 명령 (실제 운영용)
admin_seed_ip_submodule.sh thermal_sensor host_ss host-team "Thermal sensor digital readout"
```

내부에서:
1. `gh repo create acme-ssd/ip-thermal_sensor`
2. ip-template 변수 치환 후 push
3. branch protection 적용
4. Top repo 에서 `git submodule add` + commit + push (PR)

---

## STEP 4. 모든 submodule 을 최신 tag 로 일괄 갱신 (Weekly)

```bash
cd /tmp/sub-admin/work/ssd-soc-top
bash /Users/euihyeokkwon/Works/soc-cfg-mngt/cm-strategies/02-submodule/update-submodules-to-tag.sh
git status
# 변경된 submodule SHA 들이 staged
git diff --cached --submodule=log | head -20
# 각 submodule 의 새 commit 메시지가 보임
```

이 결과로 PR 1건 → Top repo 의 manifest equivalent 갱신.

> 운영에서는 **CI 의 nightly job 이 본 스크립트를 자동 실행해 PR 생성**.

---

## STEP 5. SKU 분기 — submodule 방식

submodule 전략에서 SKU 는 **Top repo 의 분기** 입니다. (manifest 방식보다 무거움)

```bash
cd /tmp/sub-admin/work/ssd-soc-top

# Gen5 SKU 분기 생성
git checkout -b sku/gen5-4tb

# SKU 별 IP 핀(특정 tag) 으로 변경
for ip_tag in "pcie_phy:v3.0.1-gen5" "pcie_ctrl:v3.0.1-gen5" "nand_phy:v4.0.0-16ch" "ddr4_ctrl:v2.0.0-16gb"; do
  IFS=: read ip tag <<<"$ip_tag"
  ( cd ip/$ip && git fetch -q && git checkout $tag 2>/dev/null || echo "(tag $tag missing — would be created in real flow)")
done
git add ip/
git -c user.email=a@e -c user.name=a commit -q -m "sku/gen5-4tb: pin IPs to gen5 tags" || true

git branch -a | head
```

**약점 노출**: SKU 가 5개 늘면 brnach 5개 + 각각 maintenance. manifest 방식 대비 폭증.

---

## STEP 6. CI 게이트 — `.gitmodules` 변경 검출

`.gitmodules` 가 바뀐 PR 은 legal/platform-team 추가 리뷰가 강제되어야 합니다.

```yaml
# .github/workflows/gitmodules-policy.yml
on: pull_request
jobs:
  gitmodules-change:
    if: contains(github.event.pull_request.labels.*.name, '')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Detect .gitmodules diff
        run: |
          git diff --name-only origin/${{ github.base_ref }}...HEAD | grep -q .gitmodules || exit 0
          gh pr edit ${{ github.event.pull_request.number }} \
              --add-reviewer @acme-ssd/platform-team,@acme-ssd/legal-team \
              --add-label submodule-change
        env: { GH_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
```

---

## STEP 7. Detached HEAD 사고 대응

개발자가 detached HEAD 상태에서 commit 후 `git submodule update` 로 commit 을 잃었다는 신고가 들어옴.

```bash
# IP repo 의 reflog 에 commit 이 남아있을 가능성
cd /tmp/sub-admin/work/ssd-soc-top/ip/pcie_phy
git reflog | head
# 잃어버린 commit SHA 발견 시 cherry-pick or 새 브랜치 생성
git checkout -b recover/lost-work <SHA>
```

운영 표준 — IP repo onboarding 문서에 **"항상 `git checkout main` 후 작업"**, dev container 셋업에 `git config submodule.recurse true` 강제.

---

## STEP 8. 잘못 push 된 submodule SHA 회수

mainline Top SHA 가 외부 노출된 IP commit 을 가리키면, 모든 협업자에게 노출된 것으로 간주.

```bash
# 1) Top main 잠금
gh api "repos/acme-ssd/ssd-soc-top/branches/main/protection" \
    --method PATCH -f lock_branch=true || true

# 2) IP repo 에서 클린 history 마이그레이션 (별도 새 IP repo)
#    git filter-repo --invert-paths --path <leaked-file> --force

# 3) Top 의 .gitmodules URL 을 새 IP repo 로 변경, submodule sync
cd Top
sed -i.bak 's|ip-pcie_phy\.git|ip-pcie_phy-clean.git|' .gitmodules
git submodule sync ip/pcie_phy
git submodule update --init ip/pcie_phy
git -c user.email=a@e -c user.name=a commit -aq -m "ip/pcie_phy: migrate to clean repo"
```

원본 IP repo 는 `gh repo archive` 후 접근 명단 보존.

---

## STEP 9. 운영 KPI (Submodule 특화)

| 지표 | 목표 | 측정 방법 |
|---|---|---|
| IP tag → Top SHA bump 지연 | < 12h | manifest-bump 봇 로그 |
| Detached HEAD 사고 (월간) | 0 | IP repo reflog 모니터링 |
| `.gitmodules` 변경 PR 비율 | 정상 운영에선 매우 낮음 | weekly diff |
| Stale submodule (1개월 무업데이트) | 0 | `git submodule foreach git log --since=1.month` |

---

## 자주 만나는 함정 (Admin 관점)

| 증상 | 원인 | 해결 |
|---|---|---|
| 클론이 한참 걸림 | 25개 submodule 직렬 fetch | `submodule.fetchJobs=8` |
| 일부 개발자만 detached HEAD 사고 | git config 미배포 | onboarding 스크립트 표준화 |
| `.gitmodules` URL 변경으로 모든 클론 깨짐 | URL hardcode | `url.<base>.insteadOf` 정책 |
| Top 의 submodule SHA 가 origin 의 IP main 보다 오래됨 | 자동 bump 봇 없음 | weekly `update-submodules-to-tag.sh` cron |
| SKU 가 늘수록 Top branch 가 폭주 | submodule 단독 운영 한계 | repo+manifest 하이브리드 검토 |

---

## 정리

| Submodule 이 잘 맞는 환경 | 다시 고려해야 할 신호 |
|---|---|
| IP 별 라이선스/ACL 격리 필수 | SKU 5개 이상으로 늘어남 |
| IP 가 외부 vendor 와 빈번히 교류 | atomic cross-IP refactor 가 잦음 |
| 각 IP 의 릴리스 주기가 독립적 | 100명+ 운영에서 ceremony 비용 부담 |

다음 단계: [03-repo-manifest ADMIN-TUTORIAL](../03-repo-manifest/ADMIN-TUTORIAL.md) — manifest 가 submodule 의 약점을 어떻게 흡수하는지.
