# Strategy 04 — Hybrid Monorepo + Git Subtree (Vendor IP Import)

## 컨셉
프로젝트 본체는 **monorepo** 로 유지하되, 외부 vendor IP (예: LDPC IP, PCIe controller hard IP)
는 `git subtree` 로 들여와 **vendor의 원본 히스토리를 보존**하면서 monorepo 안에
그대로 코드가 존재하도록 합니다. submodule 의 _detached HEAD_ 함정을 피하면서도
외부 코드의 출처를 유지하는 절충안.

대표 사용처: Linux kernel 의 일부 firmware blob 흡수, BSD 트리, 다수의 SoC팀
에서 양산 디버깅 편의성을 위해 vendor 코드를 "내 트리 안" 으로 들여오는 패턴.

## Subtree vs Submodule 비교

| 항목 | Submodule | Subtree |
|---|---|---|
| 클론 시 자동 동기화 | 별도 `--recurse-submodules` 필요 | 본 트리에 그대로 존재 ✓ |
| 외부 히스토리 보존 | 링크만 | **트리에 묻혀 보존** ✓ |
| Vendor에 변경 push back | 어색 | `git subtree push` 로 가능 |
| 부모 repo 크기 | 작음 ✓ | 커짐 (vendor 코드만큼) |
| 학습 곡선 | 중 | 중-높음 (한 번 익히면 단순) |
| Detached HEAD 함정 | 있음 | 없음 ✓ |

## 워크플로

### A. 외부 vendor LDPC IP 흡수
```bash
# 처음 vendor 코드 들여오기
git remote add ldpc-vendor git@github.com:ldpc-vendor/ldpc-codec.git
git fetch ldpc-vendor v2.4.0
git subtree add --prefix=ip/ldpc_codec/vendor \
    ldpc-vendor v2.4.0 --squash
```
→ `ip/ldpc_codec/vendor/` 디렉터리에 v2.4.0 시점의 코드가 평탄화되어 들어감.

### B. Vendor 업데이트 가져오기 (양산 디버깅 후 핫픽스 받음)
```bash
git fetch ldpc-vendor v2.4.1
git subtree pull --prefix=ip/ldpc_codec/vendor \
    ldpc-vendor v2.4.1 --squash -m "vendor: bump LDPC to v2.4.1"
```

### C. 내부 패치를 vendor 에게 push back
```bash
git subtree push --prefix=ip/ldpc_codec/vendor \
    ldpc-vendor feature/perf-patch
```
→ vendor 의 `feature/perf-patch` 브랜치로 _우리 디렉터리만 추출해_ push.

### D. CI 에서 vendor 코드 변경 식별
`paths: ip/ldpc_codec/vendor/**` path filter 로 vendor 변경 PR 만 별도 리뷰 그룹
(법무/라이선스 팀 포함) 강제.

## 본 데모 구성

`vendor-ldpc-stub/` 디렉터리가 가상의 외부 vendor 저장소 역할을 합니다.
부트스트랩 스크립트가 이를 bare repo 로 만들고, monorepo (= `ssd_soc/` 본체)
안에 subtree 로 흡수하는 시연을 합니다.

```bash
./demo-subtree.sh /tmp/ssd-soc-subtree-demo
```

## Subtree 안티패턴

1. **Vendor 디렉터리 안에서 통상 PR 로 자유 수정**: vendor push-back 불가능해짐.
   → 별도 디렉터리(`ip/ldpc_codec/patches/`) 에 patch 파일로 두고, build 시 적용.
2. **Squash 없이 import**: vendor의 수천 개 커밋이 본 트리 로그에 섞임.
   → 항상 `--squash` 권장.
3. **여러 prefix 가 같은 vendor remote 공유**: subtree push 시 prefix 미스매치.
   → vendor remote 당 prefix 1개로 제한.
4. **subtree 한 디렉터리를 다시 submodule 로 시도**: Git이 거부.

## 적합한 경우

- 외부 vendor 가 깃 호스팅을 _제공하지만_, IP 빌드 시 trace/wave 디버깅을 위해
  본 트리에서 함께 보고 싶을 때.
- Vendor 코드에 대한 잦은 local patch 가 필요할 때.
- 라이선스가 monorepo 본체와 양립 가능할 때.

## 부적합한 경우

- 보안/암호 IP — 라이선스 격리가 강력히 필요 → 별도 repo + ACL.
- Vendor 코드 크기가 RTL 본체보다 클 때 → 별도 repo + submodule.

## 본 데모 파일
- `vendor-ldpc-stub/` — 가상 외부 LDPC IP 저장소 (READMEs 와 소형 SV stub)
- `demo-subtree.sh` — bare remote 생성 + subtree add/pull/push 시연
