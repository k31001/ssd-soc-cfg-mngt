# 04-Subtree — Developer Tutorial

> 외부 vendor IP 를 monorepo 본체에 흡수해 다루는 워크플로를 실제 명령으로
> 한 줄씩 체험. 소요 시간 약 **20분**.

대상: vendor IP (LDPC, PCIe hard IP, 외부 IP) 와 협업하는 IP 개발자.
전제: macOS/Linux + Git ≥ 2.40.

> Subtree 는 대부분 운영 환경에서 **vendor IP 흡수** 전용으로 쓰입니다.
> 일반 사내 IP 까지 subtree 로 다루면 history 가 폭증합니다.

---

## STEP 0. 데모 부트스트랩

```bash
cd /Users/euihyeokkwon/Works/soc-cfg-mngt
./cm-strategies/04-subtree/demo-subtree.sh /tmp/st-demo 2>&1 | tail
ls /tmp/st-demo
# proj/  vendor-src/  vendor.git/
```

이제 다음 상황:
- `/tmp/st-demo/vendor.git` — 외부 vendor LDPC 의 bare repo (가상)
- `/tmp/st-demo/proj` — 우리 회사의 monorepo. 이미 vendor v2.4.0 흡수 + v2.4.1 hotfix 까지 pull 했음

---

## STEP 1. 흡수된 vendor 코드 위치 확인

```bash
cd /tmp/st-demo/proj
ls ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/
# (vendor/ 디렉터리는 demo 실행 결과로 생성됨 — 없으면 STEP 4 수동 실행)
ls ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor 2>/dev/null || echo "(subtree 미흡수 — STEP 4 참조)"
```

vendor 코드가 본 트리에 **그대로 평탄화** 되어 있습니다. submodule 처럼 별도 디렉터리/SHA pin 없이.

---

## STEP 2. vendor 코드 변경 + 내부 패치

상황: vendor LDPC IP 의 throughput 을 일부 튜닝.

```bash
cd /tmp/st-demo/proj
git checkout -b feature/ldpc-tune
# vendor 디렉터리는 우리 트리에 있으므로 그대로 수정 가능
echo "// internal tuning: increase parallel decoder" \
  >> ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor/rtl/ldpc_codec_vendor.sv 2>/dev/null || true

git add -A
git -c user.email=d@e -c user.name=d \
    commit -m "ldpc: internal tuning patch on vendor v2.4.1"
```

> Submodule 이었다면: vendor repo fork → 패치 PR → 우리 manifest 갱신 = 3 단계.
> Subtree: **단일 commit**.

---

## STEP 3. 내부 패치를 vendor 에게 push back

vendor 가 이 변경을 upstream 으로 받아들이고 싶다면:

```bash
cd /tmp/st-demo/proj
git subtree push --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
    ldpc-vendor feature/perf-patch 2>&1 | tail || true
```

`feature/perf-patch` 라는 새 브랜치가 vendor repo 에 생성되며, vendor 디렉터리의
commit 들만 추출되어 push 됩니다.

검증:
```bash
git -C /tmp/st-demo/vendor.git branch
# feature/perf-patch  main
```

---

## STEP 4. (참고) Subtree 처음 흡수하기

vendor 코드를 처음 들여오는 시나리오 (이미 demo 스크립트가 한 작업):

```bash
# 가상 vendor remote 등록
cd /tmp/proj-new
git init -q
git remote add ldpc-vendor /tmp/st-demo/vendor.git
git fetch -q ldpc-vendor

# 평탄화 흡수 — --squash 필수
git subtree add --prefix=ssd_soc/.../vendor \
    ldpc-vendor v2.4.0 --squash \
    -m "vendor: import ldpc_codec v2.4.0"

git log --oneline | head
# Squash 된 단일 import commit
```

**`--squash` 가 핵심**: vendor 의 수천 개 commit 이 본 트리 log 에 섞이지 않게 합니다.

---

## STEP 5. Vendor 업데이트 받기 (Hotfix Pull)

vendor 가 v2.4.2 를 release 했다는 가정:

```bash
cd /tmp/st-demo/proj
git fetch -q ldpc-vendor
git subtree pull --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
    ldpc-vendor v2.4.2 --squash \
    -m "vendor: bump ldpc_codec to v2.4.2" 2>&1 | tail -5 || \
    echo "(v2.4.2 미생성 — vendor.git 에 새 tag 만들면 pull 가능)"
```

내부 패치 (`STEP 2` 의 변경) 와 vendor 의 새 코드 사이에 conflict 가 발생하면
표준 git conflict 해결 절차로 처리.

---

## STEP 6. CI 가 vendor 변경을 식별하는 방법

`.github/workflows/vendor-review.yml` (가상 정책):

```yaml
on:
  pull_request:
    paths:
      - 'ssd_soc/**/vendor/**'   # vendor 디렉터리 변경에만 반응
jobs:
  legal-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Require legal-team review
        run: |
          gh pr edit ${{ github.event.pull_request.number }} \
            --add-reviewer @acme-ssd/legal-team \
            --add-label vendor-change
```

vendor 디렉터리 변경은 라이선스 관점에서 **반드시 추가 리뷰** 가 필요합니다.

---

## STEP 7. 안티패턴

| 안티패턴 | 왜 나쁜가 | 대안 |
|---|---|---|
| Vendor 디렉터리 안에 자유로운 사내 모듈 추가 | subtree push back 시 vendor 가 우리 코드까지 받게 됨 | 사내 patch 는 `ip/.../patches/*.patch` 별도 디렉터리 |
| `--squash` 없이 subtree add | vendor 의 수천 commit 이 본 트리 log 에 섞임 | 항상 `--squash` |
| 동일 vendor 를 여러 prefix 로 subtree add | push back 시 prefix mismatch | vendor remote 당 prefix 1개 원칙 |
| Subtree 디렉터리를 submodule 로 재변환 시도 | Git 가 거절 | rm -rf + git rm 후 submodule add 로 마이그레이션 |
| 보안/암호 IP 를 subtree 로 흡수 | 라이선스 격리 약함, ACL 못 검 | 보안 IP 는 별도 repo |

---

## STEP 8. 함정 — Vendor 업데이트 conflict

vendor 가 같은 파일을 변경했고 우리도 패치를 가진 경우:

```bash
# subtree pull 시 conflict 발생
git subtree pull ... 2>&1
# CONFLICT (content): Merge conflict in ...vendor/rtl/ldpc_codec_vendor.sv
```

처리:
```bash
# 1) 표준 git merge conflict 해결
git status
${EDITOR} ssd_soc/.../vendor/rtl/ldpc_codec_vendor.sv
git add ssd_soc/.../vendor/rtl/ldpc_codec_vendor.sv
git commit -m "Resolve vendor v2.4.2 merge with internal patch"
```

---

## 정리

| 한 줄 요약 | "Subtree = vendor IP 흡수 전용. 라이선스 격리 약하므로 보안·암호 IP 엔 절대 사용 X." |
|---|---|

| Subtree 가 잘 맞는 경우 | Subtree 를 다시 고려해야 할 신호 |
|---|---|
| Vendor IP 를 본 트리에서 함께 디버깅 | Vendor 코드 크기가 본 트리보다 큼 |
| Vendor 에게 내부 patch 를 자주 보냄 | 보안 IP / 라이선스 격리 필요 |
| 외부 의존성 1~2개 한정 | 5개 이상 vendor — 별도 repo + manifest |

다음 단계: 4가지 전략 비교 다 봤으면 → 추천 하이브리드 구성 [`../../recommended/README.md`](../../recommended/README.md) 으로.
