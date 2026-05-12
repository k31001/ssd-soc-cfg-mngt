# 04-Subtree — Admin Tutorial

> Vendor IP 흡수를 위한 subtree 운영의 관리자 관점 튜토리얼.
> 첫 도입, 라이선스 검수, vendor 업데이트, 사고 대응까지. 소요 시간 약 **25분**.

대상: 형상관리 관리자, 라이선스/법무 협력 담당, vendor IP integrator.

> **subtree 는 일반 IP 형상관리의 _주_ 전략이 되어선 안 됩니다.**
> 본 가이드는 vendor IP 흡수가 필요해진 시점의 운영을 다룹니다.

---

## STEP 0. 사전 점검

```bash
git --version           # >= 2.40 (git subtree 안정성)
python3 --version
```

**Subtree 도입 전 체크리스트** (관리자 의사결정):
- [ ] vendor 가 자체 git repo 를 제공하는가? (제공 안 하면 zip import 만 가능)
- [ ] vendor 코드 크기 < 본 monorepo 의 10%?
- [ ] 우리가 vendor 에게 patch 를 자주 push 할 계획?
- [ ] vendor 라이선스가 본 monorepo 와 양립 가능?
- [ ] 보안/암호 IP 가 아닌가?

5개 모두 ✓ 일 때만 subtree 채택. 아니면 별도 vendor namespace repo + manifest 등록 권장.

---

## STEP 1. Vendor 도입 절차 — Subtree 흡수

```bash
ROOT=/tmp/st-admin
rm -rf $ROOT && mkdir -p $ROOT

# 1) Vendor 가 제공한 repo (가상)
./Users/euihyeokkwon/Works/soc-cfg-mngt/cm-strategies/04-subtree/demo-subtree.sh $ROOT 2>&1 | tail -5
ls $ROOT
# proj/  vendor-src/  vendor.git/
```

위 데모 스크립트가 이미 vendor v2.4.0 흡수 + v2.4.1 hotfix 까지 수행했습니다.

수동 흡수 과정 (운영 시 참고):
```bash
cd $ROOT/proj
# vendor remote 등록
git remote add ldpc-vendor /path/to/vendor-repo.git
git fetch -q ldpc-vendor --tags

# 최초 흡수 — 라이선스 검수 PR 로 진행
git subtree add --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
    ldpc-vendor v2.4.0 --squash \
    -m "vendor: import ldpc_codec v2.4.0 (LICENSE: <vendor terms>)"
```

---

## STEP 2. 라이선스 검수 자동화

vendor 흡수 PR 은 **반드시** legal-team 리뷰가 강제되어야 합니다.

```bash
mkdir -p $ROOT/proj/.github/workflows
cat > $ROOT/proj/.github/workflows/vendor-license.yml <<'EOF'
name: vendor-license-gate
on:
  pull_request:
    paths: ['ssd_soc/**/vendor/**']
jobs:
  legal:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Detect new LICENSE files under vendor/
        run: |
          DIFF=$(git diff --name-only origin/${{ github.base_ref }}...HEAD | grep -E 'vendor/.*LICENSE' || true)
          if [ -n "$DIFF" ]; then
            echo "::warning::New vendor LICENSE files detected:"
            echo "$DIFF"
            gh pr edit ${{ github.event.pull_request.number }} \
                --add-reviewer @acme-ssd/legal-team \
                --add-label vendor-license-review
          fi
        env: { GH_TOKEN: ${{ secrets.GITHUB_TOKEN }} }

      - name: SPDX header check
        run: |
          ALL_OK=true
          for f in $(git diff --name-only origin/${{ github.base_ref }}...HEAD | grep '\.sv$'); do
            head -3 "$f" | grep -q SPDX-License-Identifier || { echo "::error file=$f::Missing SPDX header"; ALL_OK=false; }
          done
          $ALL_OK
EOF
```

> CI 가 자동으로 legal-team 을 reviewer 로 추가하고, SPDX 헤더 부재 시 fail.

---

## STEP 3. Vendor 업데이트 받기 (Quarterly)

```bash
cd $ROOT/proj
git fetch -q ldpc-vendor --tags

# 최신 vendor tag 확인
git -C $ROOT/vendor.git tag --sort=-version:refname | head -3

# v2.4.2 등 새 tag 가 있으면 PR 단위로 흡수
git checkout -b vendor-bump/ldpc-v2.4.2
git subtree pull --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
    ldpc-vendor v2.4.2 --squash \
    -m "vendor: bump ldpc_codec to v2.4.2" 2>&1 | tail || echo "(v2.4.2 미생성 — 데모)"
```

**운영 표준** — vendor bump 는 단독 PR (다른 변경과 섞지 않음). 라이선스 review 가 깔끔.

---

## STEP 4. 내부 패치 vendor 에 push back

```bash
cd $ROOT/proj
# 내부 feature 가 v2.4.1 위에 쌓여 있다고 가정
git subtree push --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
    ldpc-vendor feature/perf-patch
```

vendor 에 새 브랜치만 생성됨. vendor 측 PR 절차는 vendor 의 정책에 따름.

---

## STEP 5. 안티패턴 단속

| 안티패턴 | 감지 방법 | 대응 |
|---|---|---|
| Vendor 디렉터리 안에 사내 모듈 추가 | CI 가 PR 의 vendor/ 변경에 `Author != ldpc-vendor` 감지 | path 강제: `ip/.../patches/` 로 이동 |
| `--squash` 없이 subtree add | PR 의 commit 수 > 50 + path 가 vendor/ → 알림 | revert + 재흡수 |
| 같은 vendor 가 여러 prefix 로 흡수됨 | `git remote -v` 검토 | prefix 1개로 정규화 |
| 보안 IP 가 subtree 로 흡수 시도 | PR 의 `ssd_soc/sec_ss/.../vendor/` 매칭 시 자동 차단 | sec_ss 산하 vendor 는 별도 repo 강제 |

---

## STEP 6. Disengagement (Vendor 분리)

vendor IP 를 다음 세대에 안 쓰게 됐을 때:

```bash
cd $ROOT/proj
git rm -r ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor
git remote remove ldpc-vendor
git -c user.email=a@e -c user.name=a commit -aq -m "ldpc_codec: remove deprecated vendor v2.4.x"
```

history 의 vendor 코드는 그대로 보존 (legal compliance 목적). 새 vendor 도입 시 위 절차 반복.

---

## STEP 7. 운영 KPI

| 지표 | 목표 | 측정 |
|---|---|---|
| Vendor 업데이트 lead time (release → 흡수 PR) | < 2주 | vendor remote tag 추적 |
| SPDX header coverage | 100% | CI |
| vendor/ 디렉터리 내 사내 commit (안티패턴) | 0 | weekly diff |
| Vendor LICENSE 변경 감지 | 즉시 | path filter CI |

---

## STEP 8. 사고 대응 — 라이선스 위반 감지

상황: 외부 감사에서 vendor 의 GPL 코드가 본 monorepo 의 Apache 코드와 충돌.

```bash
# 1) 즉시 PR 차단 (CI 정책으로 vendor/ 디렉터리 변경 금지)
# 2) 해당 vendor 디렉터리를 별도 GPL 라이선스 repo 로 마이그레이션
# 3) Manifest 에 vendor 별도 repo 로 추가 후 subtree 제거
git rm -r ssd_soc/.../ldpc_codec/vendor
git commit -m "comply: move ldpc vendor to isolated GPL repo"
```

**원칙**: vendor IP 라이선스가 본 트리와 양립 안 되면 즉시 subtree 제거, **별도 repo 격리**.

---

## STEP 9. 자주 만나는 함정 (Admin)

| 증상 | 원인 | 해결 |
|---|---|---|
| `git subtree push` 가 너무 느림 | vendor 디렉터리 history 깊음 | `--rejoin` 옵션 사용 |
| Vendor pull 후 매번 conflict | 내부 patch 가 vendor 와 같은 라인 수정 | patch 디렉터리 분리 후 build 시 적용으로 변경 |
| Vendor 가 force push 함 | 우리 subtree 가 invalid history 가짐 | re-import: 새 brnach 에서 fresh `subtree add` |
| Subtree 디렉터리만 sparse-checkout 빠짐 | 권한 분리 불가 (monorepo 한계) | 보안 vendor 는 별도 repo |

---

## 정리

| Subtree 채택 의사결정 |
|---|
| **Yes** — vendor IP 1~2개, 본 트리와 라이선스 양립, 내부 patch 양방향 자주 |
| **No** — vendor IP 5개 이상, 보안/암호 IP, GPL/proprietary 혼합 |

> 100명+ SoC 운영에서 subtree 는 **하이브리드 구성의 작은 보조 패턴**으로
> 자리 잡는 것이 자연스럽습니다. 주 전략은 repo+manifest, vendor 일부만 subtree.

다음 단계: 4가지 전략 비교 완료. **추천 하이브리드 구성** → [`../../recommended/README.md`](../../recommended/README.md).
