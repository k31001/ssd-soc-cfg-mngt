# SSD Controller SoC 형상관리 시스템 (Reference Implementation)

본 저장소는 100명+ 규모 RTL 개발자가 협업하는 SSD Controller SoC 프로젝트의
**형상관리(Source Configuration Management) 레퍼런스 구현**입니다.

## 구성

| 디렉터리 | 내용 |
|---|---|
| `ssd_soc/`       | 가상 SoC 스켈레톤 (top + 5 subsystems + 25 IPs) |
| `cm-strategies/` | 4가지 형상관리 방식 비교 데모 (monorepo / submodule / repo-manifest / subtree) |
| `recommended/`   | 추천 하이브리드 구성 (`repo` manifest + IP 분리 + IPLM-lite) |
| `ci/`            | 계층별 GitHub Actions workflows (IP / Subsystem / Top) |
| `tools/`         | 자동화 스크립트 (ipgen / topgen / bom / manifest-bump / release) |
| `docs/`          | 4종 문서 (설계서 / 구축 가이드 / 관리자 / 개발자 가이드) |

## 빠른 시작
```bash
make sim TOP=ssd_soc_top      # Verilator smoke build (stub)
make lint                     # Verible lint
python3 tools/bom.py          # 현재 manifest 의 BOM 출력
```

## 문서
- [01. 시스템 설계서](docs/01-design.md)
- [02. 구축 가이드](docs/02-build-guide.md)
- [03. 관리자 가이드](docs/03-admin-guide.md)
- [04. 개발자 가이드](docs/04-developer-guide.md)
