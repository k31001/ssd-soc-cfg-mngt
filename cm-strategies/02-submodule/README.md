# Strategy 02 — Git Submodule

## 컨셉
Top SoC 저장소가 각 IP 저장소를 **`.gitmodules`** 로 핀(pin)합니다.
대표 사례: Chipyard (UC Berkeley), SiFive Freedom, BlackParrot.

## 구조
```
ssd-soc-top.git                ← Top integration repo
├─ .gitmodules                  ← IP repo URL + SHA pin
├─ top/
├─ subsystems/host_ss.git       (submodule)
│  └─ ip/
│     ├─ pcie_phy.git           (sub-submodule, 2단계 가능 - 권장 X)
│     ├─ ...
common-libs.git                 (submodule)
```

또는 평탄화(권장):
```
ssd-soc-top.git
├─ .gitmodules
├─ subsystems/host_ss/         (1단계 submodule)
├─ subsystems/fcc_ss/          (1단계 submodule)
│  ...
└─ ip/<25 IPs>/                (1단계 submodule — 한 단계로 평탄화 권장)
```

본 데모는 **평탄화 1단계 submodule** 을 가정합니다. 2단계 이상은 디태치 헤드와
업데이트 누락 위험이 폭증합니다.

## 워크플로

### A. 신규 클론
```bash
git clone --recurse-submodules git@github.com:acme-ssd/ssd-soc-top.git
cd ssd-soc-top
# .gitmodules 에 명시된 SHA로 IP 들이 체크아웃됨
```

### B. IP 버전 bump (PCIe 컨트롤러를 v1.3.0 으로)
```bash
# 1. IP repo 에서 작업
cd ip/pcie_ctrl
git checkout v1.3.0
cd ../..

# 2. Top 에서 pin 갱신
git add ip/pcie_ctrl
git commit -m "ip/pcie_ctrl: bump to v1.3.0"
git push
```
→ Top PR 1건이 IP의 새 SHA를 가리키도록 갱신.

### C. Atomic cross-IP change (단점)
PCIe IP 와 NVMe IP를 동시에 바꿔야 하면:
- IP A repo: PR 머지 → tag
- IP B repo: PR 머지 → tag
- Top repo: 두 IP SHA 갱신 PR 머지
→ **최소 3개의 PR**. monorepo 대비 가장 큰 약점.

대응: `git config submodule.recurse true`, 자동화 스크립트, **`tools/manifest-bump.py`**
스타일 봇으로 IP 태그를 감지해 Top PR을 자동 생성.

### D. 부분 클론
```bash
# host_ss 만 + common-libs 만
git clone --no-recurse-submodules git@github.com:acme-ssd/ssd-soc-top.git
cd ssd-soc-top
git submodule update --init common-libs ip/pcie_phy ip/pcie_ctrl ip/nvme_cmd_proc \
  ip/host_dma ip/pcie_cfg subsystems/host_ss
```
→ 자연스럽지만 **명령이 장황**. `manifest` 방식이 이를 단순화한 것.

## 데모 부트스트랩

본 디렉터리의 `bootstrap-bare-repos.sh` 는 로컬에 가짜 GitHub 흉내(bare repo)
를 만들어 submodule workflow를 실제로 실행해볼 수 있게 합니다.

```bash
./bootstrap-bare-repos.sh /tmp/ssd-soc-submodule-demo
cd /tmp/ssd-soc-submodule-demo/work/ssd-soc-top
git clone --recurse-submodules ...
```

## 함정 모음 (Pitfalls)

1. **Detached HEAD**: `git submodule update` 후 IP 디렉터리는 디태치 상태.
   → 작업 전 반드시 `git checkout main` 으로 브랜치 진입.
2. **부모 push 누락**: IP를 push 했지만 Top의 SHA pin 을 commit/push 안 하면
   다른 개발자는 옛 IP 버전을 받음. CI 게이트로 강제 검증 필요.
3. **`.gitmodules` URL hardcode**: 외부 미러/포크에서 동작 안 함.
   → 조직 단위 `insteadOf` 설정으로 해결.
4. **Submodule 안에서 외부 의존성 변경**: 검토 비가시성 ↑.
   → CI 가 `.gitmodules` 변경을 별도 plat-team 리뷰로 요구하게 강제.
5. **EDA 도구의 절대경로 hardcode**: 클론 위치 변경 시 깨짐.
   → Makefile / filelist 는 항상 repo 루트 기준 상대경로.

## 적합한 경우

- IP 별 라이선스/ACL 분리가 강력히 필요
- 외부 vendor IP를 git repo 형태로 받음
- 각 IP 가 자체 CI 와 릴리스 cadence 를 가짐 (semver tag)

## 본 데모 파일
- `.gitmodules.sample` — 25개 IP submodule 정의 샘플
- `bootstrap-bare-repos.sh` — 로컬 bare repo + Top demo 부트스트랩
- `update-submodules-to-tag.sh` — 모든 submodule을 최신 tag로 일괄 bump
