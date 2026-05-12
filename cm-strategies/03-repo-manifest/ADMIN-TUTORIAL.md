# 03-Repo+Manifest — Admin Tutorial

> Repo+Manifest 전략의 첫 부트스트랩, 매주 운영, SKU 분기, manifest-bot 자동화,
> 릴리스 동결, 사고 대응까지 모든 시나리오를 명령으로 체험. 소요 시간 약 **45분**.

대상: 형상관리 관리자, 빌드 엔지니어, 릴리스 매니저.

---

## STEP 0. 사전 점검

```bash
git --version           # >= 2.40
python3 --version       # >= 3.10
gh --version            # >= 2.40
```

`repo` 도구 설치 (옵션 — 사내 mirror 가 있으면 사용):
```bash
mkdir -p ~/bin && curl -sL https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod +x ~/bin/repo && export PATH=~/bin:$PATH
repo --version
```

본 데모는 `tools/repo_lite.py` 폴백으로 모든 흐름을 동일하게 시연.

---

## STEP 1. 부트스트랩 — 34개 component repo + manifest repo

로컬 데모:

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
./recommended/scaffolding/local-bootstrap.sh /tmp/rm-admin
ls /tmp/rm-admin/remotes | wc -l
# 35 (34 component repos + ssd-soc-manifest.git)
ls /tmp/rm-admin/work
# checkout/  checkout-gen5/  manifest/  BOM.md
```

원격 모드 (GitHub Enterprise) 절차:

```bash
# (실행 X — 데모용 예시)
gh repo create acme-ssd/ssd-soc-manifest --internal
for c in ssd-soc-top common-libs verif-framework pdk-views \
         host_ss fcc_ss mem_ss cpu_ss sec_ss \
         ip-pcie_phy ip-pcie_ctrl ip-nvme_cmd_proc ...; do
  gh repo create acme-ssd/$c --internal
done
# manifest 파일 push
git clone git@github.com:acme-ssd/ssd-soc-manifest.git /tmp/mfst
cp recommended/manifest/*.xml /tmp/mfst/
( cd /tmp/mfst && git add -A && git commit -m "init manifest" && git push )
```

---

## STEP 2. Manifest repo 의 권한 모델

`ssd-soc-manifest` repo 는 형상관리의 **사실상 control plane**. 권한이 가장 엄격해야 합니다.

```bash
# CODEOWNERS
cat > /tmp/rm-admin/work/manifest/CODEOWNERS <<EOF
*.xml      @acme-ssd/integration-team
EOF

# Branch protection
gh api repos/acme-ssd/ssd-soc-manifest/branches/main/protection \
   --method PUT \
   --input /Users/euihyeokkwon/Works/soc-cfg-mngt/recommended/scaffolding/policy/branch-protection.json \
   2>/dev/null || echo "(local — would apply)"

# 추가: manifest 변경은 PR 1건당 IP 1개로 제한 (큰 일괄 변경 방지)
```

> Manifest PR 의 추가 권장: **PR template 으로 "어떤 IP, 어떤 tag, 어떤 검증 통과"** 를 강제.

---

## STEP 3. 매니페스트 구조 운영

본 데모의 manifest 들:

```bash
cd /tmp/rm-admin/work/manifest
ls
# default.xml  release-template.xml  sku-gen4-1tb.xml  sku-gen5-4tb.xml
```

| 파일 | 역할 | 변경 빈도 |
|---|---|---|
| `default.xml`        | mainline. IP `revision="main"` 추적 | 매일 (manifest-bot PR) |
| `sku-*.xml`          | 양산 SKU. `<include>` + tag pin | SKU 신규 도입 시 |
| `release-template.xml` | release.py 의 입력 템플릿 | 거의 없음 |

**검증**:
```bash
python3 - <<'PY'
import sys; sys.path.insert(0,'/Users/euihyeokkwon/Works/soc-cfg-mngt/tools')
from repo_lite import load_manifest
from pathlib import Path
for f in ['default.xml', 'sku-gen4-1tb.xml', 'sku-gen5-4tb.xml']:
    m = load_manifest(Path(f))
    print(f"{f:24} projects={len(m.projects)} default_remote={m.default_remote}")
PY
```

---

## STEP 4. 신규 IP onboarding

`seed-ip.sh` 한 줄로 모든 부수 작업 자동화 (로컬 모드 시연):

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
./recommended/scaffolding/seed-ip.sh thermal_sensor host_ss host-team \
   "Thermal sensor digital readout" --local /tmp/rm-admin
ls /tmp/rm-admin/remotes/ip-thermal_sensor.git
```

내부에서 수행:
1. IP repo (bare) 생성
2. ip-template 변수 치환 → 초기 commit/push
3. (원격 모드) branch protection 적용
4. (원격 모드) manifest_bump.py 로 default.xml 에 `<project>` 추가하는 PR 자동 생성

수동으로 manifest 갱신해보기:
```bash
cp /tmp/rm-admin/work/manifest/default.xml /tmp/test-add.xml
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/manifest_bump.py add-ip \
   --manifest /tmp/test-add.xml --name ip-thermal_sensor \
   --path ip/thermal_sensor --subsystem host_ss
grep thermal_sensor /tmp/test-add.xml
```

---

## STEP 5. SKU 분기 — manifest 추가만으로 끝

submodule 방식의 SKU branch 와 달리, manifest 추가만으로 SKU 생성:

```bash
# 1) sku-gen6-8tb.xml 신규 작성 (gen5 파일 복사 후 수정)
cd /tmp/rm-admin/work/manifest
cp sku-gen5-4tb.xml sku-gen6-8tb.xml
sed -i.bak 's/gen5/gen6/g; s/4tb/8tb/g; s/v3\.0\.1/v4.0.0/g; s/4-16gb/-32gb/g' sku-gen6-8tb.xml
rm sku-gen6-8tb.xml.bak

# 2) PR 1건으로 mainline manifest 에 등록 — Top branch 추가 불필요

# 3) 양산팀에 사용 안내
echo "repo init -m sku-gen6-8tb.xml && repo sync"
```

**SKU 1개 추가에 필요한 작업**: manifest 파일 1개 + PR 1건. Submodule 의 Top branch + 모든 submodule SHA 갱신 대비 압도적 우위.

---

## STEP 6. Manifest-bot 동작 점검 (가장 중요)

manifest-bot 은 IP tag 가 push 될 때마다 mainline manifest 의 revision 을 갱신하는 PR 을 자동 생성. 본 운영 모델의 **핵심 자동화**.

봇 동작 시뮬레이션:
```bash
# IP 가 v0.2.0 을 push 했다는 이벤트 시뮬레이션
cp /tmp/rm-admin/work/manifest/default.xml /tmp/bot-test.xml
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/manifest_bump.py bump \
   --manifest /tmp/bot-test.xml --name ip-pcie_phy --revision v0.2.0
grep pcie_phy /tmp/bot-test.xml | head -1

# 운영에서는 위 결과로 ssd-soc-manifest 에 PR 생성
```

봇이 매주 화/목 batch 로 묶어 PR 1건에 여러 IP bump 를 모으도록 설정 가능.

---

## STEP 7. Drift 점검 (매니페스트 ↔ 실제 IP tag)

매일 자정 manifest-bot 이 모든 IP repo 의 최신 tag 와 manifest 의 pin 을 비교:

```bash
# 가상 drift checker (실제 운영용)
python3 - <<'PY'
import sys, subprocess, xml.etree.ElementTree as ET
sys.path.insert(0, '/Users/euihyeokkwon/Works/soc-cfg-mngt/tools')
from repo_lite import load_manifest
from pathlib import Path

m = load_manifest(Path('/tmp/rm-admin/work/manifest/default.xml'))
drifts = []
for proj in m.projects.values():
    rev = proj.revision
    if rev == 'main':
        continue  # HEAD-tracking 은 drift 무관
    # 실제: ls-remote 로 최신 tag 확인
    drifts.append(f"{proj.name}: pinned {rev}")

print(f"Manifest drift report — pinned projects: {len(drifts)}")
for d in drifts[:5]:
    print(f"  {d}")
PY
```

운영에서는 drift report 가 Github Issue 로 자동 생성 (manifest-bot.yml 의 `drift-check` job).

---

## STEP 8. Release 동결 (양산 SKU)

분기 1회 양산 SKU 사인오프 manifest 생성:

```bash
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/release.py snapshot \
   --src-manifest /tmp/rm-admin/work/manifest/sku-gen5-4tb.xml \
   --workdir      /tmp/rm-admin/work/checkout-gen5 \
   --sku gen5-4tb --release-id 2026Q3-MP \
   --out /tmp/rm-admin/release-2026Q3-MP.xml

head -12 /tmp/rm-admin/release-2026Q3-MP.xml
# <notice> 블록에 release_id, sku, date, builder 모두 기록
# 모든 project 가 SHA-pinned
```

이 파일이 **PD/Foundry sign-off 의 single source**. tag (`sku-gen5-4tb-MP`) + 본 manifest 파일 + BOM markdown 세트를 양산팀/사인오프 채널에 전달.

```bash
python3 /Users/euihyeokkwon/Works/soc-cfg-mngt/tools/bom.py \
   --manifest /tmp/rm-admin/work/manifest/sku-gen5-4tb.xml \
   --workdir  /tmp/rm-admin/work/checkout-gen5 \
   --output   /tmp/rm-admin/BOM-2026Q3-MP.md
head -15 /tmp/rm-admin/BOM-2026Q3-MP.md
```

---

## STEP 9. 권한 감사 (Quarterly)

manifest 의 `<project>` 가 가리키는 모든 repo 에 대해 push 권한자 추출:

```bash
python3 - <<'PY'
import sys, subprocess
sys.path.insert(0, '/Users/euihyeokkwon/Works/soc-cfg-mngt/tools')
from repo_lite import load_manifest
from pathlib import Path

m = load_manifest(Path('/tmp/rm-admin/work/manifest/default.xml'))
print("Component, GitHub repo (would query collaborators in real env)")
for proj in list(m.projects.values())[:8]:
    print(f"  {proj.path:30}  acme-ssd/{proj.name}")
# 운영: 위 list 의 각 repo 에 대해 gh api repos/.../collaborators
PY
```

---

## STEP 10. 사고 대응 — manifest 가 잘못 머지된 경우

mainline `default.xml` 에 깨진 IP revision 이 머지되면 **모든 다음 sync 가 깨짐**.

```bash
# 1) manifest 이전 commit 으로 revert PR (force push 아님)
cd /tmp/rm-admin/work/manifest
git log --oneline -5
# git revert <broken-sha> --no-edit
# git push -u origin revert/broken-manifest
# gh pr create --title "Revert broken manifest" ...

# 2) 머지 후 manifest-bot 이 다음 IP tag 검증 사이클부터 다시 정상

# 절대 force push 로 mainline manifest history 재작성 금지
# (모든 개발자가 이미 그 commit 을 clone 했다고 가정)
```

manifest 는 텍스트라 revert 가 깨끗합니다. submodule 의 SHA-pin 회복 대비 운영 부담 훨씬 낮음.

---

## STEP 11. 운영 KPI

| 지표 | 목표 | 측정 |
|---|---|---|
| Manifest bump PR 자동 생성 시간 | < 5분 | manifest-bot 로그 |
| Mainline manifest 의 stale 비율 (1개월 무업데이트 IP) | 0 | drift report |
| `repo sync` 평균 시간 (34 project) | < 3분 | dev container telemetry |
| SKU 추가 → 양산 후보 빌드까지 | < 1주 | release.py snapshot 시점 |
| Release manifest 의 missing 0 | 100% | release.py 종료 코드 |

---

## 자주 만나는 함정 (Admin)

| 증상 | 원인 | 해결 |
|---|---|---|
| `repo sync` 가 일부 IP 에서 인증 실패 | 보안 IP 의 ACL 미부여 | `@security-lead` 에 access 요청 |
| Mainline default.xml 머지 폭주 | manifest-bot 의 batch 미사용 | 봇의 PR window 를 화/목으로 축소 |
| 같은 IP 가 두 SKU 에서 다른 tag 필요한데 충돌 | manifest 분기로 해결 가능한 문제를 monorepo 식 ifdef 로 시도 | sku-*.xml 의 `<remove-project>` + 재정의 |
| `repo init` 가 macOS/Windows 에서 안 됨 | repo 도구 POSIX 의존 | dev container 표준화 |
| Release snapshot 산출 시 `missing` 발생 | 워크스페이스가 sync 불완전 | `repo sync` 재실행 후 `release.py snapshot` |

---

## 정리

| Repo+Manifest 가 잘 맞는 환경 | 다시 고려해야 할 신호 |
|---|---|
| IP 수 > 20, 팀 수 > 5 | IP 수가 적고 한 팀 운영 |
| SKU 파생이 잦음 (3개 이상) | 운영팀에 `repo` 도구 학습 여력 부족 |
| 양산/사인오프 재현성 필수 | atomic refactor 매주 발생 → 보조 도구 추가 필요 |
| 외부 vendor / PDK 격리 필요 | manifest tooling 운영 인력 부재 |

다음 단계: [04-subtree ADMIN-TUTORIAL](../04-subtree/ADMIN-TUTORIAL.md) — vendor IP 흡수 시점에 추가되는 subtree 운영.
