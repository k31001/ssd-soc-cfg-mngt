# 05. 트러블슈팅 가이드 (Troubleshooting Guide)

> **TL;DR** — 본 시스템에서 100명+ 운영 중 실제로 만날 수 있는 ~80개 시나리오를
> **증상 → 원인 → 진단 명령 → 해결** 4단 표로 정리. 영역별(Git/Manifest/CI/EDA/
> 권한/사고)로 분류되어 있으니 Ctrl+F 로 증상을 검색해 사용하세요.

---

## 0. 진단 우선 명령 (가장 먼저 실행)

문제가 났을 때 무엇을 먼저 봐야 하는지:

```bash
# 1) 현재 워크스페이스 상태
python3 tools/repo_lite.py status --manifest <m.xml> --workdir .
# (각 project clean/dirty/missing)

# 2) Manifest 가 expected revision 으로 sync 되어 있는지
git -C <project> describe --tags --always

# 3) 최근 CI 상태
gh run list --workflow=ip-ci.yml --limit 5

# 4) Manifest drift 확인
gh issue list --repo acme-ssd/ssd-soc-manifest --label drift

# 5) 로컬 빌드 상태
make elab 2>&1 | tail -20
```

위 5개의 결과를 캡처해 두면 누구에게 ask 하든 진단이 빨라집니다.

---

## 1. Repo / Manifest Sync

### 1.1 `repo sync` 가 특정 project 에서 실패

| 항목 | 내용 |
|---|---|
| **증상** | `error: Cannot fetch <project> (PermissionError)` |
| **원인** | 보안 IP 또는 PDK repo 에 GitHub team access 없음 |
| **진단** | `gh api repos/acme-ssd/<repo>/collaborators` 로 본인 포함 여부 |
| **해결** | `@security-lead` 또는 PD 팀에 access 요청. 보안 IP는 별도 sign-off 필요 |

### 1.2 `repo sync` 가 매우 느림 (>10분)

| 항목 | 내용 |
|---|---|
| **증상** | 34 project 클론에 30분+ |
| **원인** | 단일 머신에서 병렬 fetch 부족, 사내 mirror 미사용 |
| **진단** | `repo sync -j 1` 과 `-j 16` 비교 |
| **해결** | `repo init --reference=<mirror-path>` 로 사내 mirror cache 사용, `-j 16` 으로 병렬화 |

### 1.3 Manifest 가 가리킨 tag 가 존재하지 않음

| 항목 | 내용 |
|---|---|
| **증상** | `fatal: '<tag>' not found in <project>` |
| **원인** | IP repo 에서 tag 가 force-delete 되었거나 manifest 가 잘못 박힘 |
| **진단** | `git -C <project> ls-remote --tags origin | grep <tag>` |
| **해결** | manifest_bump.py 로 가까운 안정 tag 로 재핀, 사라진 tag 는 IP-owner 에 복구 요청 |

### 1.4 `<include>` 가 순환 참조

| 항목 | 내용 |
|---|---|
| **증상** | repo_lite.py 가 무한 루프 또는 RecursionError |
| **원인** | sku-A.xml 이 sku-B.xml 을 include, 다시 A 를 include |
| **진단** | grep -rE '<include' manifest/ |
| **해결** | manifest include 깊이 ≤ 2 규칙. 변경 시 platform-team 리뷰 강제 |

### 1.5 워크스페이스가 detached HEAD 투성이

| 항목 | 내용 |
|---|---|
| **증상** | `git -C <project> branch` 가 비어있음, commit 위험 |
| **원인** | repo sync 가 SHA/tag 로 직접 checkout (정상 동작) |
| **진단** | `repo status` 또는 본 저장소의 `tools/repo_lite.py status` |
| **해결** | 작업 전 `git -C <project> checkout main` 또는 `git checkout -b feature/...` |

---

## 2. Git Submodule (Strategy 02 사용 시)

### 2.1 Submodule 디렉터리가 비어있음

| 항목 | 내용 |
|---|---|
| **증상** | `ls ip/pcie_phy/` 빈 디렉터리 |
| **원인** | clone 시 `--recurse-submodules` 안 함 |
| **해결** | `git submodule update --init --recursive` |

### 2.2 Submodule 안에서 commit 했는데 사라짐

| 항목 | 내용 |
|---|---|
| **증상** | 다음 `git submodule update` 후 본인 commit 분실 |
| **원인** | detached HEAD 상태에서 commit |
| **진단** | `git -C <ip> reflog | head` |
| **해결** | reflog 의 lost commit SHA 로 `git checkout -b recover/<topic> <SHA>` 후 PR |

### 2.3 Top SHA push 누락

| 항목 | 내용 |
|---|---|
| **증상** | 동료가 clone 하면 옛 IP 버전 |
| **원인** | submodule SHA staged 만 하고 push 안 됨 |
| **진단** | `git status -s` 또는 `git log --oneline origin/main..HEAD` |
| **해결** | `git push origin HEAD:main` (보호 브랜치라면 PR) |

### 2.4 `.gitmodules` URL 가 사내 mirror 와 다름

| 항목 | 내용 |
|---|---|
| **증상** | 사내 미러 사용해야 하는데 GitHub URL 그대로 |
| **해결** | `git config --global url."git@gitlab.acme:".insteadOf "git@github.com:acme-ssd/"` 으로 transparent rewrite |

---

## 3. CI / GitHub Actions

### 3.1 `semver-bump-check` fail

| 항목 | 내용 |
|---|---|
| **증상** | `::error::ip.yaml version must bump on PR` |
| **원인** | PR 에 ip.yaml 변경 없거나 version 동일 |
| **해결** | ip.yaml 의 `version:` 한 단계 bump (patch/minor/major). breaking change 면 MAJOR |

### 3.2 `codeowners-drift` fail

| 항목 | 내용 |
|---|---|
| **증상** | CODEOWNERS 가 ip.yaml 의 owner 와 불일치 |
| **진단** | `python3 tools/sync_codeowners.py --repo . --check` |
| **해결** | `python3 tools/sync_codeowners.py --repo .` 후 변경분 commit |

### 3.3 `yaml-schema` fail

| 항목 | 내용 |
|---|---|
| **증상** | `jsonschema.ValidationError: 'qual' is a required property` |
| **원인** | ip.yaml 에 필수 필드 빠짐 |
| **진단** | `cat recommended/scaffolding/policy/ip-yaml-schema.json` 의 `required:` 확인 |
| **해결** | 누락 필드 추가. status≥qual 시 reviewers 필수 |

### 3.4 Manifest-bot PR 이 생성 안됨

| 항목 | 내용 |
|---|---|
| **증상** | IP tag push 했는데 mainline manifest 에 PR 없음 |
| **원인** | (a) tag 가 `v` prefix 없음 (b) MANIFEST_BUMP_TOKEN secret 미설정 (c) workflow path filter 누락 |
| **진단** | `gh run list --workflow=manifest-bot.yml --repo acme-ssd/ssd-soc-manifest` |
| **해결** | tag 재발급 `vX.Y.Z`, organization secret 확인, dispatch 이벤트 직접 호출로 재현 |

### 3.5 Lint fail — Verible / Verilator 의 false positive

| 항목 | 내용 |
|---|---|
| **증상** | 코드는 의도된 패턴인데 lint 가 위반 |
| **해결** | `cfg/waivers.yaml` 에 rule + scope + reason + expiry 추가. expiry 가 핵심 — 만료 시 자동 재검토 |

### 3.6 CI 가 매번 같은 step 에서 timeout

| 항목 | 내용 |
|---|---|
| **증상** | full-soc job 이 4시간 초과 |
| **원인** | (a) 회귀 셋 폭주 (b) Verilator 캐시 미스 |
| **해결** | reusable workflow 의 `actions/cache` 로 obj_dir 캐시, 회귀를 nightly 와 weekly 로 분리 |

### 3.7 `repository_dispatch` 이벤트가 안 받음

| 항목 | 내용 |
|---|---|
| **증상** | `gh api repos/.../dispatches` 호출은 성공인데 workflow 미실행 |
| **원인** | 대상 workflow 의 `on: repository_dispatch.types:` 가 매칭 안함 |
| **해결** | 정확한 type 이름 사용 (`ip-tag-published`), workflow 가 default branch 에 있는지 확인 |

---

## 4. EDA / Simulation

### 4.1 Verilator `module not found`

| 항목 | 내용 |
|---|---|
| **증상** | `%Error: Cannot find file containing module: <name>` |
| **원인** | filelist (`compile.f`) 의 file 순서 또는 `+incdir+` 부재 |
| **해결** | `+incdir+ssd_soc/common/pkg` 와 `+incdir+ssd_soc/common/interfaces` 가 SV 파일들 위에 위치해야 함 |

### 4.2 `interface` 가 못 찾음

| 항목 | 내용 |
|---|---|
| **증상** | `axi_if.slave` 가 unknown type |
| **원인** | interface 파일을 module 보다 늦게 컴파일 |
| **해결** | filelist 에서 `common/interfaces/*.sv` 를 IP RTL 보다 먼저 나열 |

### 4.3 Smoke sim 이 `$finish` 없이 hang

| 항목 | 내용 |
|---|---|
| **증상** | tb 가 종료 안됨 |
| **원인** | testbench 의 timeout 설정 누락 |
| **해결** | `initial #1ms $fatal("timeout");` 안전망 추가 |

### 4.4 Coverage 결과가 매번 빈 파일

| 항목 | 내용 |
|---|---|
| **증상** | Verilator coverage 결과가 0 line |
| **원인** | `--coverage` 옵션 미사용 또는 `Vmain.exe --coverage` 실행 안 함 |
| **해결** | reusable-coverage workflow 의 `verilator_coverage` step 적용 |

### 4.5 Top elab 은 통과하는데 sim 이 깨짐

| 항목 | 내용 |
|---|---|
| **증상** | elab OK, runtime UVM_FATAL |
| **원인** | 통합 시점에야 드러나는 protocol mismatch |
| **해결** | verif-framework 의 회귀 셋에 시나리오 등록, 1주 안에 fix |

---

## 5. 권한 / 라이선스 / CODEOWNERS

### 5.1 GitHub UI 에서 "Required reviewers" 가 무한 대기

| 항목 | 내용 |
|---|---|
| **증상** | CODEOWNERS 에 적힌 team 에 사람 없음 또는 inactive |
| **진단** | `gh api orgs/acme-ssd/teams/<slug>/members` |
| **해결** | team 인원 확보, 또는 backup 권한자 명시 |

### 5.2 Push 거절 — 보호 브랜치 위반

| 항목 | 내용 |
|---|---|
| **증상** | `! [remote rejected] main -> main (protected branch hook declined)` |
| **원인** | branch protection 의 required PR 우회 시도 |
| **해결** | PR 통해서만 머지. 정책 자체에 문제가 있으면 platform-team PR |

### 5.3 SPDX header 미부재로 PR 차단

| 항목 | 내용 |
|---|---|
| **증상** | `::error file=...::Missing SPDX header` |
| **해결** | 파일 첫 줄에 `// SPDX-License-Identifier: Apache-2.0` 추가 |

### 5.4 Vendor 라이선스 자동 검사 fail

| 항목 | 내용 |
|---|---|
| **증상** | vendor/ 경로 변경 PR 이 legal-team 리뷰 자동 추가 |
| **해결** | 정상 동작. legal-team review 후 머지 |

---

## 6. IP / IPLM 운영

### 6.1 `ip.yaml` 의 status 를 qual 로 올렸는데 CI fail

| 항목 | 내용 |
|---|---|
| **증상** | `'reviewers' is required when status >= qual` |
| **해결** | `reviewers:` 필드에 `@acme-ssd/integration-team` 등 추가 |

### 6.2 ip.yaml owner 변경했더니 CODEOWNERS drift

| 항목 | 내용 |
|---|---|
| **증상** | `codeowners-drift` CI fail |
| **해결** | `python3 tools/sync_codeowners.py --repo .` 로 자동 생성 후 commit |

### 6.3 `seed-ip.sh` 가 manifest PR 단계에서 멈춤

| 항목 | 내용 |
|---|---|
| **증상** | manifest_bump.py 가 manifest repo clone 못함 |
| **원인** | gh CLI 권한 부족 |
| **해결** | PAT 에 `repo:admin` scope 추가 또는 `MANIFEST_BUMP_TOKEN` 갱신 |

### 6.4 IP 가 두 SKU 에서 다른 tag 필요한데 충돌

| 항목 | 내용 |
|---|---|
| **증상** | mainline 통합 시점에 SKU 별 차이 흡수 불가 |
| **원인** | `if (SKU == "gen5")` 같은 매크로 fork |
| **해결** | parameter 로 흡수 가능하면 ip.yaml parameters, 아니면 IP 분리 또는 manifest 의 sku.xml 에서 다른 tag pin |

---

## 7. Top SoC / 릴리스

### 7.1 Top weekly CI 의 회귀가 어느 PR 부터인지 모르겠음

| 항목 | 내용 |
|---|---|
| **진단** | manifest repo 의 git log 를 weekly job 의 head SHA 기준으로 비교 |
| **해결** | `git -C manifest log <last-green-SHA>..<failing-SHA> --oneline` 으로 의심 PR 좁히기 |

### 7.2 Release snapshot 산출에서 `missing` 발생

| 항목 | 내용 |
|---|---|
| **증상** | release.py 의 `[release] wrote ... (34 projects, 3 missing)` |
| **원인** | 워크스페이스가 sync 불완전 |
| **해결** | `repo_lite.py sync` 재실행 후 release.py 재실행 |

### 7.3 양산 SKU 동결 시점에 PD 팀이 PDK 다른 버전 요청

| 항목 | 내용 |
|---|---|
| **해결** | sku-X.xml 에 `<remove-project name="pdk-views">` + 원하는 PDK 태그로 `<project>` 재정의 |

---

## 8. 사고 / 보안

### 8.1 비밀 키 (secret) 가 IP repo 에 commit + mainline 까지 머지됨

**즉시 대응 순서**:
1. **노출된 자산을 source system 에서 회전 (rotate) — 가장 먼저**.
2. Repo lock: `gh api repos/.../branches/main/protection -X PATCH -f lock_branch=true`.
3. `@security-lead` 에 escalation.
4. Git history 청소는 secondary — 외부 clone 은 이미 노출된 것으로 간주.
5. 클린 history 의 새 IP repo 마이그레이션 + manifest URL 갱신 PR.
6. 원본 IP repo archive.

> **하지 말 것**: force push 로 mainline history 재작성. (외부 clone 은 이미 노출.)

### 8.2 잘못된 IP tag 가 mainline manifest 에 머지

**대응**:
```bash
python3 tools/manifest_bump.py bump --manifest default.xml \
   --name ip-<X> --revision <previous-stable-tag>
# rollback PR 생성 → 즉시 머지
```

### 8.3 외부 라이선스 위반 발견 (vendor IP 가 GPL)

**대응**:
1. CI 정책으로 vendor/ 디렉터리 변경 추가 차단.
2. 별도 GPL 라이선스 repo 로 vendor 코드 마이그레이션.
3. Manifest 의 해당 project 를 새 repo URL 로 변경 PR.
4. Subtree 였다면 subtree 제거 후 별도 repo 흡수.

### 8.4 `.gitmodules` / manifest 가 임의로 머지됨

| 항목 | 내용 |
|---|---|
| **증상** | platform-team 승인 없이 새 vendor 추가 |
| **해결** | CODEOWNERS 의 `.gitmodules` / `*.xml` 경로 강제, branch protection 의 `require_code_owner_reviews=true` 확인 |

---

## 9. 환경 / 도구 자체 문제

### 9.1 macOS 에서 `repo` 도구 동작 어색

| 항목 | 내용 |
|---|---|
| **해결** | Dev container (Ubuntu 22.04) 표준화. brew 의 `repo` 는 일부 manifest 옵션 미지원 |

### 9.2 Python `yaml` 모듈 없음

| 항목 | 내용 |
|---|---|
| **증상** | CI yaml-schema job 이 `ModuleNotFoundError: yaml` |
| **해결** | reusable workflow 가 `pip install PyYAML jsonschema` 를 보장 |

### 9.3 `gh` CLI 인증 만료

| 항목 | 내용 |
|---|---|
| **증상** | `gh auth status` 가 expired |
| **해결** | `gh auth refresh -s repo,workflow,admin:org` |

### 9.4 Git LFS 미설치 환경에서 PDK clone 실패

| 항목 | 내용 |
|---|---|
| **해결** | PDK 는 default sync 에서 제외 (`groups="pdk"`), PD 팀만 별도 sync |

---

## 10. 진단 도구 모음

```bash
# 1) 매니페스트 검증
python3 tools/repo_lite.py sync --manifest <m.xml> --workdir /tmp/test-sync
python3 tools/repo_lite.py status --manifest <m.xml> --workdir /tmp/test-sync
python3 tools/repo_lite.py freeze --manifest <m.xml> --workdir /tmp/test-sync

# 2) BOM / 의존성 점검
python3 tools/bom.py --manifest <m.xml> --workdir <ws> --output BOM.md

# 3) Manifest bump 시뮬레이션
python3 tools/manifest_bump.py list --manifest <m.xml>
python3 tools/manifest_bump.py bump --manifest <m.xml> --name <ip> --revision <tag>

# 4) CODEOWNERS drift
python3 tools/sync_codeowners.py --repo <ip-dir> --check

# 5) IP.yaml schema 검증 (jsonschema 설치 필요)
python3 -c "
import json, yaml, jsonschema
schema = json.load(open('recommended/scaffolding/policy/ip-yaml-schema.json'))
data = yaml.safe_load(open('<ip>/ip.yaml'))
jsonschema.validate(data, schema)
print('OK')"

# 6) Release snapshot dry-run
python3 tools/release.py snapshot --src-manifest <m.xml> --workdir <ws> \
       --sku test --release-id dry-run --out /tmp/release-dry.xml
```

---

## 11. 에스컬레이션 매트릭스

| 상황 | 1차 연락 | 2차 연락 | 비고 |
|---|---|---|---|
| IP CI 실패 | IP-owner | Subsystem-owner | 24h SLA |
| Manifest PR 충돌 | integration-team | platform-team | manifest PR labels 사용 |
| Top SoC 회귀 | integration-team | 해당 IP-owner | weekly 회의에서 triage |
| 보안 IP 사고 | security-lead | platform-team | 즉시 (15분) |
| 라이선스 위반 의심 | legal-team | platform-team + integration-team | vendor 디렉터리 변경 PR 즉시 hold |
| CI 인프라 장애 | platform-team | (GitHub Enterprise vendor) | downtime > 1h 시 양산 일정 영향 |
| 양산 release 사고 | integration-team + 양산 PM | C-level | 양산 사인오프 직전이면 사고 회고 필수 |

---

## 12. 관련 문서
- 시스템 설계 → [`01-design.md`](01-design.md)
- 초기 구축 → [`02-build-guide.md`](02-build-guide.md)
- 관리자 운영 → [`03-admin-guide.md`](03-admin-guide.md)
- 개발자 워크플로 → [`04-developer-guide.md`](04-developer-guide.md)
- 산업 벤치마크 → [`06-industry-benchmark.md`](06-industry-benchmark.md)
