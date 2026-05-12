# Strategy 03 — Google `repo` + Manifest

## 컨셉
**여러 개의 Git repo** 위에 XML manifest 한 장을 얹어 한 번에 동기화/체크아웃합니다.
대표 사례: AOSP (Android), Google Pixel/Tensor SoC, ChromeOS, Yocto Project.

```
ssd-soc-manifest.git              ← 매니페스트만 담은 별도 저장소
└─ default.xml                     ← <project name=... revision=...> 목록

(repo init/sync 후 워크스페이스 모습)
ssd-soc/
├─ .repo/                          ← repo tool 메타데이터
├─ top/                            ← 단독 git repo: ssd-soc-top.git
├─ common-libs/                    ← 단독 git repo
├─ subsystems/host_ss/             ← 단독 git repo
├─ ip/pcie_phy/                    ← 단독 git repo (1단계 평탄화)
├─ ip/pcie_ctrl/
└─ ...
```

## 워크플로

### A. 신규 개발자 셋업
```bash
mkdir ssd-soc && cd ssd-soc
repo init -u git@github.com:acme-ssd/ssd-soc-manifest.git -b main -m default.xml
repo sync -j 16            # 모든 IP 병렬 클론
```

### B. SKU 별 분기 = manifest 분기
```bash
# Gen4 1TB 제품용
repo init -m sku-gen4-1tb.xml
repo sync

# Gen5 4TB 제품용 (다른 디렉터리에)
mkdir ../ssd-soc-gen5 && cd ../ssd-soc-gen5
repo init -u … -m sku-gen5-4tb.xml
repo sync
```
**파생 SKU 가 늘어나도 매니페스트 파일 한 장 추가**. 이것이 submodule 대비 결정적 우위.

### C. 부분 동기화 (groups)
manifest 에 `groups="pdk"` 같은 태그를 달면 `repo sync -g default,-pdk` 로
PDK 데이터를 제외할 수 있습니다.

### D. Atomic cross-IP change (`topic upload`)
```bash
cd ip/pcie_ctrl && git checkout -b feature/new-api && ...edit... && git commit
cd ../nvme_cmd_proc && git checkout -b feature/new-api && ...edit... && git commit
repo upload --current-branch --re=reviewer1
```
→ 두 변경이 같은 topic 으로 묶여 Gerrit/리뷰 UI 에서 함께 보입니다.
   *완전한 atomicity 는 아니지만* 99% 의 운영 시나리오에서 충분.

### E. Snapshot 동결 (릴리스)
```bash
repo manifest -r -o release-2026Q2.xml
```
→ 모든 project 의 현재 SHA 가 박힌 동결 manifest 생성. 펌웨어 빌드, 사인오프
   타임스탬프, 양산 SKU 추적의 single source of truth.

## 본 데모에 포함된 매니페스트

| 파일 | 용도 |
|---|---|
| `default.xml`         | 메인 mainline manifest (HEAD pin) |
| `sku-gen4-1tb.xml`    | Gen4 1TB 제품 SKU (PCIe Gen4 + DDR4-4GB + 8ch NAND) |
| `sku-gen5-4tb.xml`    | Gen5 4TB 제품 SKU (PCIe Gen5 + DDR4-16GB + 16ch NAND) |
| `release-2026q2.xml`  | 분기 동결 스냅샷 (예시) |

## 로컬 부트스트랩

`repo` 바이너리를 깔거나 원격 GitHub 가 없어도 흐름을 시연할 수 있도록
`bootstrap-local.sh` 가 모든 IP/Subsystem 을 로컬 bare repo 로 만들어
매니페스트와 함께 `repo sync` 가능한 워크스페이스를 만듭니다.

```bash
./bootstrap-local.sh /tmp/ssd-soc-manifest-demo
cd /tmp/ssd-soc-manifest-demo/work
repo sync -j 4
```

## 함정 (Pitfalls)

1. **macOS/Windows 환경**: `repo` 는 Python 기반이지만 일부 동작은 POSIX 가정.
   → 회사 표준 dev container 에서만 동작 보장.
2. **매니페스트 PR 머지 직전**: 개별 IP repo 의 SHA 가 바뀌면 매니페스트도 갱신
   필요. **`tools/manifest-bump.py`** 가 IP tag push 시 자동 PR 생성.
3. **Manifest 와 CODEOWNERS 분리**: 각 IP repo 안에 자체 CODEOWNERS, 매니페스트
   repo 는 별도 owner 그룹.
4. **`repo` 자체에 대한 mirror/캐시**: 큰 조직은 `--reference` 로 mirror cache
   지정해 동시 sync 부담 분산.

## 적합한 경우

- IP 별 ACL/라이선스 분리 필요
- **파생 SKU(form factor, NAND 세대, PCIe 세대)가 빈번**
- 펌웨어/RTL/PD 데이터를 라이프사이클 별로 분리하고 싶음
- 100명 이상 다중 팀, AOSP 와 유사한 거버넌스

## 적합하지 않은 경우

- 단일 팀, 단일 라이선스, atomic refactor 중심 → monorepo 가 더 단순
- repo 바이너리 + Python 운영을 꺼리는 환경 → 매니페스트 핵심 가치만 가져와
  자체 manifest tool 자작도 가능 (Phase D 의 `tools/repo-lite.py` 참고)

## 본 데모 파일
- `default.xml`, `sku-gen4-1tb.xml`, `sku-gen5-4tb.xml`, `release-2026q2.xml`
- `bootstrap-local.sh` — 로컬 bare repo 생성 + 데모 워크스페이스
- `sync.sh` — `repo sync` 래퍼 (없으면 `repo-lite.py` 폴백)
