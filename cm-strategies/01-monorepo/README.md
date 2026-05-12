# Strategy 01 — Pure Git Monorepo

## 컨셉
SoC 전체(top + subsystems + IPs + common + verif)를 **하나의 Git repo**에 둡니다.
대표 사례: OpenTitan (lowRISC), Linux kernel (참고 모델), Google internal piper.

## 디렉터리 매핑
```
ssd-soc-monorepo/                  ← 단일 저장소
├─ top/
├─ subsystems/{host,fcc,mem,cpu,sec}_ss/
│   └─ ip/<25 IPs>/
├─ common/
├─ verif/
├─ tools/
└─ CODEOWNERS                       ← 디렉터리별 owner
```

(본 데모는 [`../../ssd_soc/`](../../ssd_soc/) 트리가 그대로 monorepo 임을 가정)

## 워크플로

### A. 신규 개발자 셋업 (전체 클론)
```bash
git clone git@github.com:acme-ssd/ssd-soc.git
cd ssd-soc
make sim
```

### B. host_ss 팀: 자기 영역만 sparse-checkout
```bash
git clone --filter=blob:none --no-checkout git@github.com:acme-ssd/ssd-soc.git
cd ssd-soc
git sparse-checkout init --cone
git sparse-checkout set common ssd_soc/subsystems/host_ss ci tools docs
git checkout main
```
→ 디스크에는 `host_ss` 와 공통 자산만 존재.

`sparse-checkout-host.sh` 가 위 절차의 자동화 스크립트입니다.

### C. Atomic cross-IP change
PCIe 컨트롤러와 NVMe processor 의 인터페이스를 동시에 변경하는 경우 **단일 PR**로
처리됩니다. 이것이 monorepo의 가장 큰 장점입니다.

### D. CI 트리거 최적화
디렉터리 기반 path filter (`paths: ssd_soc/subsystems/host_ss/**`) 로 IP-level CI
를 흉내냅니다. 단, 공통 코드 변경 시 전체 트리 CI가 트리거되는 점은 비용 부담.

## 권한 분리 (`CODEOWNERS`)
GitHub 의 `CODEOWNERS` 파일이 단일 repo 안에서 디렉터리별 리뷰어를 강제합니다.

```
# CODEOWNERS (root)
ssd_soc/subsystems/host_ss/    @acme-ssd/host-team
ssd_soc/subsystems/fcc_ss/     @acme-ssd/flash-team
ssd_soc/subsystems/mem_ss/     @acme-ssd/mem-team
ssd_soc/subsystems/cpu_ss/     @acme-ssd/cpu-team
ssd_soc/subsystems/sec_ss/     @acme-ssd/security-team
ssd_soc/common/                @acme-ssd/platform-team
ssd_soc/top/                   @acme-ssd/integration-team
```

**한계**: CODEOWNERS 는 _리뷰_ 만 강제할 뿐 _Push 권한_ 은 repo 전체에 동일합니다.
보안 IP(secure_boot_rom 등)를 별도 ACL 로 막고 싶다면 monorepo 만으로는 어렵습니다.

## 파생 SKU 관리

| 방식 | 장단점 |
|---|---|
| **브랜치 (`sku/gen4-1tb`, `sku/gen5-4tb`)** | merge 전쟁 위험, 분기 수명 길어짐 |
| **빌드 시 conditional include + parameter** | 권장. `cfg/sku/*.yaml` 로 선언 후 top 인스턴스 generate |
| **별도 디렉터리** (`top/sku-gen4/`) | 코드 중복 |

본 SoC 데모는 `ssd_soc/top/cfg/top.yaml` 의 `derivatives:` 리스트로 표현 → `topgen.py`
가 SKU 별 top wrapper 생성.

## 적합한 경우 vs 부적합한 경우

| 적합 ✓ | 부적합 ✗ |
|---|---|
| 단일 팀/단일 제품 라인 | 외부 vendor IP가 자주 들어옴 |
| 모든 코드가 같은 라이선스 | 보안 IP에 강한 ACL 필요 |
| Atomic refactor 빈도 높음 | 클론 사이즈/CI 비용 민감 |
| Verification framework가 RTL과 강결합 | PD/PDK 데이터가 거대 (LFS 필요) |

## 본 데모 파일
- `sparse-checkout-host.sh` — host_ss 만 부분 체크아웃
- `CODEOWNERS` — 샘플 권한 파일
- `.gitattributes` — eol/lfs 힌트
