# 형상관리 방식 비교 데모 (Comparison Demos)

같은 SSD Controller SoC를 4가지 형상관리 전략으로 각각 구성해 본 데모입니다.
각 방식의 트레이드오프를 직접 손에 잡히는 형태로 비교하기 위함이며, 데모 규모를
줄이기 위해 `host_ss` 와 2개 IP(`pcie_phy`, `nvme_cmd_proc`)를 공통 대상 부분집합으로
사용합니다.

| # | 방식 | 디렉터리 | 핵심 도구 | 강점 | 약점 |
|---|---|---|---|---|---|
| 01 | **Pure Git Monorepo** | [`01-monorepo/`](01-monorepo/)        | `git sparse-checkout`, CODEOWNERS | Atomic change, 단순 onboarding | 클론 비대, ACL 세분화 어려움 |
| 02 | **Git Submodule**     | [`02-submodule/`](02-submodule/)      | `.gitmodules`, `git submodule update` | 표준, 명시적 의존성 | 두 단계 PR(IP→Top), 디태치 헤드 함정 |
| 03 | **Google `repo` + manifest** | [`03-repo-manifest/`](03-repo-manifest/) | `repo init/sync`, manifest.xml | SKU별 분기 우수, 100+ 멀티레포 표준 | 외부 도구 의존, macOS/Win 어색 |
| 04 | **Hybrid Monorepo + Subtree** | [`04-subtree/`](04-subtree/) | `git subtree pull/push`, vendor branch | 외부 IP 흡수 깔끔 | 양방향 동기화 복잡, 히스토리 비대 |

## 비교 매트릭스 (요약)

| 항목 | Monorepo | Submodule | repo+manifest | Subtree |
|---|---|---|---|---|
| 학습 곡선 | 낮음 | 중 | 중-높음 | 중 |
| 부분 체크아웃 | sparse-checkout | 자연스러움 | groups 옵션 | 어려움 |
| 권한 분리(ACL) | 디렉터리 단위 | repo 단위 ✓ | repo 단위 ✓ | 디렉터리 단위 |
| 파생 SKU 관리 | 브랜치/디렉터리 | top SHA pin | **manifest branch** ✓✓ | 어려움 |
| Atomic cross-IP change | ✓✓ | ✗ (다단계 PR) | △ (topic upload) | ✓ |
| CI 비용 | 전체 빌드 트리거 위험 | IP 단위 분리 ✓ | IP 단위 분리 ✓ | 전체 빌드 위험 |
| IPLM 메타데이터 수용 | 단일 YAML 트리 | 각 repo 루트 YAML | 각 repo 루트 YAML | 단일 트리 |
| Windows/EDA 친화 | 좋음 | 보통 | 보통(Python 필요) | 좋음 |
| 외부 vendor IP 흡수 | 어색 | 자연스러움 | 자연스러움 | **자연스러움** ✓ |
| 라이선스/IP 격리 | 약함 | 강함 ✓ | 강함 ✓ | 약함 |

## 결론 (선요약)

100명+ SSD SoC 팀에는 **단일 전략은 부적합**합니다. 추천 구성은 다음 하이브리드:

> **`repo` + manifest 를 외피로**, **IP는 개별 Git repo**, **vendor IP는 별도 repo(또는 subtree)**, **PDK/대용량 데이터는 LFS 분리**.

자세한 추천 구성과 그 이유는 [`../recommended/`](../recommended/) 와
[`../docs/01-design.md`](../docs/01-design.md) 를 참고하세요.
