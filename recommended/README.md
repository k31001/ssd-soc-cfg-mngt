# Recommended Hybrid Configuration Management

본 디렉터리는 4가지 형상관리 방식의 비교(`../cm-strategies/`)와 산업 벤치마크
(NVIDIA·Samsung IPLM, AOSP repo, OpenTitan Hjson, BlackParrot RTL/SDK/HDK 분리,
Linux kernel lieutenant model)를 종합한 **공식 추천 구성**입니다.

## 결정 요약 (TL;DR)

| 레이어 | 선택 | 이유 |
|---|---|---|
| 외피 | **AOSP `repo` + manifest.xml** | SKU/파생 = manifest 분기, 100+ 검증된 패턴 |
| IP 단위 | **개별 Git repo** (semver tag) | ACL/CODEOWNERS/CI 권한 깔끔, 라이선스 격리 |
| 통합 단위 | **Subsystem repo + Top repo** | BlackParrot 식 lifecycle 분리 |
| 공통 자산 | **`common-libs` repo** (semver) | 모든 IP 가 의존, 안정성 우선 |
| Vendor IP | **별도 namespace repo** (필요시 subtree) | 외부 라이선스 격리 |
| PDK/PD 데이터 | **`pdk-views` repo + Git LFS** | 대용량, 별도 ACL, opt-in 동기화 (`groups="pdk"`) |
| IP 메타데이터 | **`ip.yaml`** (OpenTitan 스타일 YAML) | owner/status/qual/deps single source of truth |
| 자동화 | **GitHub Actions + `repo_lite.py`** | 계층별 CI, manifest 자동 bump |
| Verif | **`verif-framework` repo** | RTL 과 lifecycle 분리, 회귀 셋 독립 진화 |

## 디렉터리 구성 (본 데모 산출물)

```
recommended/
├─ README.md
├─ manifest/
│   ├─ default.xml              ← 메인 mainline (HEAD-tracking)
│   ├─ sku-gen4-1tb.xml         ← Gen4 1TB 양산 SKU
│   ├─ sku-gen5-4tb.xml         ← Gen5 4TB 양산 SKU
│   └─ release-template.xml     ← `repo manifest -r` 산출물 템플릿
├─ scaffolding/
│   ├─ ip-template/             ← 새 IP 부트스트랩 템플릿
│   │   ├─ ip.yaml
│   │   ├─ CODEOWNERS
│   │   ├─ .github/workflows/ci.yml
│   │   ├─ rtl/.gitkeep
│   │   ├─ sim/.gitkeep
│   │   └─ README.md
│   ├─ seed-ip.sh               ← 신규 IP repo 부트스트랩 (한 줄)
│   ├─ seed-ss.sh               ← 신규 subsystem repo 부트스트랩
│   ├─ apply-branch-protection.sh
│   ├─ local-bootstrap.sh       ← 로컬 전체 시연 (실제 GH Enterprise 없이 동작)
│   └─ policy/
│       ├─ branch-protection.json
│       ├─ codeowners-template
│       └─ ip-yaml-schema.json
└─ docs/                         ← 추천 구성에 관한 보충 문서는 ../docs/ 참조
```

## 운영 모델 (Operating Model)

### 1. IP-owner 모델 (Linux kernel lieutenant 차용)
- 각 IP 는 **1명의 Owner + 1명의 Backup** (CODEOWNERS).
- IP-owner 는 `ip.yaml`, RTL, sim, doc 의 1차 책임자.
- `ip.yaml` 의 `status` 가 `qual` 이상이면 **Integration team 추가 승인** 필수.

### 2. 통합 윈도우 (Integration Windows)
- IP → manifest 통합은 **매주 화/목 자동 PR** (manifest-bump 봇).
- Top tag (양산 후보) 는 **격주 금요일** 윈도우.
- 양산 SKU 동결은 **분기당 1회**, 별도 신청-승인 절차.

### 3. 브랜치 정책 (Trunk-Based)
- 모든 IP repo: `main` 만 보호 브랜치. feature branch 수명 < 5일.
- semver tag: `vMAJOR.MINOR.PATCH[-SKU]` (예: `v2.4.0-gen4`).
- Top SoC repo: `main` + `rel/<sku>` 브랜치 1쌍.

### 4. 권한/리뷰
- **CODEOWNERS** + **GitHub Branch Protection** + **`ip.yaml` owner drift CI**.
- Security IP (`sec_ss` 산하 5개) 는 추가 reviewer + sign-off label.
- PDK repo: 별도 GitHub team, push 권한 PD팀 한정.

### 5. 라이선스/외부 IP
- Vendor IP repo는 `vendor/` namespace 분리 (예: `vendor/ldpc-codec`).
- 라이선스 헤더 CI 게이트로 강제 (SPDX header).

## 무엇이 추가되었나 (Strategy 03 대비)

| 추가 | 이유 |
|---|---|
| `scaffolding/ip-template/` | 신규 IP 30분 onboarding |
| `seed-ip.sh` 한 줄 명령 | 100+ 개발자 운영에서 가장 빈번한 액션 자동화 |
| `branch-protection.json` | GitHub API 로 일괄 적용 (gh CLI) |
| `ip-yaml-schema.json` | CI 가 IPLM-lite 메타데이터 검증 |
| `local-bootstrap.sh` | 실제 GitHub 없이 전체 시연 가능 |

상세 동작/명령은 [`../docs/02-build-guide.md`](../docs/02-build-guide.md) 참고.
