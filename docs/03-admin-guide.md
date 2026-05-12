# 03. 형상관리 관리자 가이드 (Admin Guide)

> **TL;DR** — 형상관리 관리자(Configuration Manager)는 일상 운영의
> "트래픽 통제관"입니다. 매주 manifest 통합, IP onboarding, SKU 분기,
> 권한 감사, 사고 대응을 담당하며 도구는 `tools/` 와 `recommended/scaffolding/`
> 에 모두 준비되어 있습니다. **모든 액션은 PR 또는 audit log 가 남는 동작**으로
> 만 수행하고, **destructive 명령(force push, repo 삭제) 은 절대 직접 실행하지 않습니다**.

대상 독자: 형상관리 관리자, 빌드 엔지니어, 릴리스 매니저.

---

## 1. 일상 (Daily/Weekly Routines)

### 1.1 매일 — Health Check (5분)
| 작업 | 명령 |
|---|---|
| Manifest drift 점검 | manifest-bot 의 `drift-check` 야간 결과 확인 (issue 자동 생성됨) |
| CI 실패율 | GitHub Actions usage 페이지에서 빨간 repo 확인 |
| LFS 사용량 | `gh api repos/acme-ssd/pdk-views/git/lfs/usage` |

### 1.2 매주 (화/목) — Integration Window
1. `manifest-bot` 가 IP tag 들을 모은 PR 묶음을 mainline manifest 에 생성.
2. 관리자는 PR 묶음을 **batch review**:
   ```bash
   gh pr list --repo acme-ssd/ssd-soc-manifest --label auto,manifest-bump --state open
   ```
3. 의존성 충돌 / CI 실패 PR 은 IP-owner 에게 ping.
4. 통과한 PR 들 머지 → mainline manifest 갱신.

### 1.3 매주 (금) — Top SoC Tag Candidate
1. Top CI weekly job 산출 확인 (`gh run list --repo acme-ssd/ssd-soc-top`).
2. 전체 회귀 PASS 시 `top: rc<N>` 태그 푸시.
3. release-snapshot artifact (release-<id>.xml, BOM-<id>.md) 가 `releases/` 디렉터리에 자동 commit 되는지 확인.

### 1.4 분기 1회 — 양산 SKU 동결
1. 신규 SKU 매니페스트 작성 (예: `sku-gen5-4tb-2026q3.xml`).
2. Top CI weekly 1주일 안정성 확인.
3. `tools/release.py snapshot` 으로 동결 manifest 산출.
4. release tag (`sku-gen5-4tb-2026q3`) 푸시 → release-snapshot CI 트리거.
5. 결과 manifest 를 PD/Foundry 사인오프 채널에 전달.

---

## 2. 가장 빈번한 액션 — 레시피

### 2.1 신규 IP onboarding
**시간: ~30분, 도구: `seed-ip.sh`**

```bash
recommended/scaffolding/seed-ip.sh \
    <ip_name> <subsystem> <team> "<short description>"
```

자동 처리:
1. `gh repo create acme-ssd/ip-<name>` (private)
2. ip-template 변수 치환 후 push
3. Branch protection 적용
4. `manifest_bump.py add-ip` 로 manifest PR 자동 생성

관리자 후처리:
- ip.yaml 의 `owner` 가 GitHub team과 매핑되는지 확인 (`gh api orgs/acme-ssd/teams/<slug>`)
- manifest PR 리뷰 + 머지

### 2.2 IP owner 교체
```bash
# IP repo 의 ip.yaml owner 필드 변경 PR
gh pr create --repo acme-ssd/ip-pcie_ctrl \
   --title "owner: handover to @acme-ssd/new-team" \
   --body "Sign-off from prev owner."
```
- ip.yaml 변경 PR 머지되면 `sync_codeowners.py` 가 CODEOWNERS 갱신.
- Drift CI 가 다음 PR 부터 새 owner 강제.

### 2.3 SKU 분기 (Branching for a new derivative)
1. `recommended/manifest/sku-<new>.xml` 작성 (다른 SKU를 복사 후 수정).
2. 매니페스트 PR — 통과 시 머지.
3. 양산팀에 `repo init -m sku-<new>.xml` 안내.

### 2.4 외부 vendor IP 도입
**선택 A — 별도 repo (권장)**
1. `gh repo create acme-ssd/vendor-<name> --private`
2. Vendor 코드 import (NDA 확인 후 `git push`).
3. ip.yaml + CODEOWNERS (`@legal-team` 추가).
4. Manifest 의 `<remote name="vendor">` 추가 + `<project>` 등록.

**선택 B — Subtree (소규모 vendor 코드, 잦은 patch 시)**
```bash
cd <top-repo>
git remote add vendor-x git@github.com:vendor-x/ip.git
git subtree add --prefix=ip/<name>/vendor vendor-x v1.0.0 --squash
```
(상세 패턴: [`../cm-strategies/04-subtree/README.md`](../cm-strategies/04-subtree/README.md))

### 2.5 권한 감사 (Quarterly)
```bash
# 1) 각 IP repo 의 push 권한자 추출
for r in $(gh repo list acme-ssd --limit 200 --json name --jq '.[].name' | grep '^ip-'); do
   gh api "repos/acme-ssd/$r/collaborators?affiliation=direct" --jq '.[].login' | sort -u | sed "s/^/$r,/"
done > /tmp/access.csv

# 2) ip.yaml 의 owner 와 비교 — drift 가 있으면 알림
python3 tools/audit_access.py --org acme-ssd --output /tmp/access-drift.md
```

### 2.6 잘못 push 된 IP 회수 (Incident Response)
**상황: 비밀 키/내부 문서가 IP repo 에 commit 되어 mainline 까지 갔다.**

> ⚠️ `git push --force` 는 관리자라도 직접 실행하지 않습니다. 다음 절차로:

1. **즉시**: 해당 IP repo 의 main 을 `lock_branch = true` 로 잠금 (gh API).
2. 보안 alert: `@security-lead` 에 ping, 노출 자산 (key/credential) 즉시 회전(rotate).
3. 클린 히스토리 PR — `git filter-repo` 로 비밀이 제거된 새 history 작성, **새 IP repo** 로 마이그레이션.
4. Manifest 의 `<project>` URL/SHA 갱신 PR.
5. 원본 IP repo 는 `archived = true` 로 만들고 접근 가능자 명단을 보존.

(절대 destructive 한 force push 로 mainline history 를 다시 쓰지 않습니다. 외부에 이미 clone 된 SHA는 노출이라고 가정.)

### 2.7 PDK / 대용량 자산 LFS 용량 관리
```bash
gh api repos/acme-ssd/pdk-views/git/lfs/usage
# 임계치(예: 80%) 초과 시:
#  - 오래된 PD 버전 archive
#  - LFS migrate to cold storage
```

---

## 3. 운영 규칙 (Operational Rules)

### 3.1 절대 하지 말 것 (Hard Don'ts)
- `--force` push to any protected branch.
- IP repo 의 `archive_after_30d` 정책 없이 임의 삭제.
- ip.yaml 의 owner 를 본인 계정으로 변경 (직접 권한 grab).
- secret/PAT 를 워크플로 변수에 평문 노출.
- CI 정책을 IP repo 안에서 우회 (정책은 `acme-ssd/.github` 에서만 변경).

### 3.2 항상 할 것 (Hard Dos)
- 모든 액션은 **PR + audit log** 흔적이 남도록.
- 정책 변경은 **reusable workflow** 한 곳만 (전 repo 영향).
- 매주 manifest drift 리포트 review.
- 분기마다 권한 감사 (2.5).

### 3.3 이름 규칙 (Naming)
| 종류 | 규칙 | 예 |
|---|---|---|
| IP repo | `ip-<snake_case>` | `ip-pcie_phy` |
| Subsystem repo | `<snake>_ss` | `host_ss` |
| Vendor repo | `vendor-<name>` | `vendor-ldpc-codec` |
| SKU manifest | `sku-<gen>-<cap>.xml` | `sku-gen5-4tb.xml` |
| IP semver tag | `vMAJOR.MINOR.PATCH[-SKU]` | `v2.4.0-gen4` |
| Top release tag | `sku-<name>-rc<N>` | `sku-gen5-4tb-rc1` |
| Release snapshot | `release-<id>-<sku>-<date>.xml` | `release-2026Q2-gen5-4tb-20260801.xml` |

### 3.4 변경 승인 절차

| 변경 종류 | 승인자 | 도구 |
|---|---|---|
| IP 코드 변경 | IP owner | PR (자동 CI 게이트) |
| ip.yaml owner/status 변경 | IP owner + integration-team | PR + drift CI |
| Manifest add-ip | integration-team | PR (자동 by manifest-bot) |
| Manifest SKU bump | integration-team + 양산 PM | PR + weekly CI green |
| CI policy 변경 | platform-team | PR on `acme-ssd/.github` |
| Branch protection 변경 | platform-team + security-lead | PR on `branch-protection.json` |
| Secret 변경 | platform-team | gh CLI + audit log review |

---

## 4. KPI / 운영 지표

| 지표 | 목표 | 측정 |
|---|---|---|
| IP PR 평균 머지 시간 | < 24h | GitHub Insights |
| Manifest auto-PR 머지율 | > 90% | manifest-bot 리포트 |
| CI 실패율 | < 5% | per-repo weekly digest |
| BOM 자동 publish 성공 | 100% | Top CI artifact 존재 여부 |
| 권한 드리프트 | 0 | quarterly audit |
| 평균 신규 IP onboarding | < 30분 | seed-ip.sh 시작 → 첫 PR 머지 |

---

## 5. 도구 빠른 참조

```bash
# Manifest
python3 tools/repo_lite.py sync   --manifest <m.xml> --workdir <dir>
python3 tools/repo_lite.py status --manifest <m.xml> --workdir <dir>
python3 tools/repo_lite.py freeze --manifest <m.xml> --workdir <dir> > release.xml

python3 tools/manifest_bump.py list  --manifest default.xml
python3 tools/manifest_bump.py add-ip --manifest default.xml --name ip-X --path ip/X --subsystem host_ss
python3 tools/manifest_bump.py bump   --manifest default.xml --name ip-X --revision v2.5.0

# BOM / Release
python3 tools/bom.py     --manifest default.xml --workdir <dir> --output BOM.md
python3 tools/release.py snapshot --src-manifest default.xml --workdir <dir> \
       --sku gen5-4tb --release-id 2026Q3 --out release-2026Q3.xml

# IP 부트스트랩
recommended/scaffolding/seed-ip.sh <name> <ss> <team> "<desc>"
recommended/scaffolding/seed-ss.sh <name> <team> "<desc>"
recommended/scaffolding/apply-branch-protection.sh <org/repo>

# CODEOWNERS drift
python3 tools/sync_codeowners.py --repo <ip-repo-dir> --check  # CI mode (exit non-zero on drift)
python3 tools/sync_codeowners.py --repo <ip-repo-dir>          # apply fix
```

---

## 6. FAQ

**Q. 새 IP 를 git submodule 로 추가하면 안 되나요?**
A. Submodule 은 단일 분기/단일 SKU 운영에는 충분하지만, SKU 분기와 100+ 멀티레포 에서
   manifest 보다 약합니다. 추천 구성은 manifest 기반. submodule 은 외부 vendor IP 일부에서만 사용.

**Q. 매주 manifest PR 묶음이 너무 많다.**
A. `manifest-bot` 의 `bump_window` 설정으로 같은 IP 의 여러 patch 를 하나의 PR 로 묶을 수 있음.
   배치 기간을 늘리거나 IP-owner 에게 minor PATCH 는 alpha 채널 (alpha/* 태그) 로 모아 push 권장.

**Q. 양산 후 발견된 버그로 IP 를 rollback 해야 한다.**
A. `tools/manifest_bump.py bump --name ip-X --revision <이전 tag>` 로 manifest 단일 PR
   (디렉터리 변경 없음). Top CI 통과 후 머지. 5분 내 가능.

**Q. PDK 가 너무 커서 sync 가 느리다.**
A. Default `repo init` 에서 `--groups=default,-pdk` 로 PDK 제외. PD 팀만 PDK 그룹 sync.

---

## 7. 관련 문서
- 시스템 설계 → [`01-design.md`](01-design.md)
- 초기 구축 → [`02-build-guide.md`](02-build-guide.md)
- 개발자 워크플로 → [`04-developer-guide.md`](04-developer-guide.md)
