# SSD Controller SoC 형상관리 시스템 (Reference Implementation)

본 저장소는 100명+ 규모 RTL 개발자가 협업하는 SSD Controller SoC 프로젝트의
**형상관리(Source Configuration Management) 레퍼런스 구현**입니다.

## 구성

| 디렉터리 | 내용 |
|---|---|
| `ssd_soc/`       | 가상 SoC 스켈레톤 (top + 5 subsystems + 25 IPs) |
| `cm-strategies/` | 4가지 형상관리 방식 비교 데모 + 각 방식별 **개발자/관리자 튜토리얼** |
| `recommended/`   | 추천 하이브리드 구성 (`repo` manifest + IP 분리 + IPLM-lite) |
| `ci/`            | 계층별 GitHub Actions workflows (IP / Subsystem / Top) |
| `tools/`         | 자동화 스크립트 (ipgen / topgen / bom / manifest-bump / release / **ipflow** / render-diagrams) |
| `docs/`          | 6종 문서 + [WORKFLOW.md](docs/WORKFLOW.md) (IP closed-loop 9-stage workflow) |
| `web/`           | 워크플로우 인터랙티브 대시보드 (Mermaid + status matrix, GitHub Pages 배포) |

## 빠른 시작
```bash
make sim TOP=ssd_soc_top                          # Verilator smoke build (stub)
make lint                                          # Verible lint
./recommended/scaffolding/local-bootstrap.sh /tmp/demo   # 전체 시스템 5분 시연
python3 tools/bom.py --manifest recommended/manifest/default.xml --workdir /tmp/demo/work/checkout
```

## 문서
- [01. 시스템 설계서](docs/01-design.md)
- [02. 구축 가이드](docs/02-build-guide.md)
- [03. 관리자 가이드](docs/03-admin-guide.md) (+ Integration Tutorial 섹션 포함)
- [04. 개발자 가이드](docs/04-developer-guide.md) (+ Integration Tutorial 섹션 포함)
- [05. 트러블슈팅 가이드](docs/05-troubleshooting.md)
- [06. 산업 벤치마크 기술 보고서](docs/06-industry-benchmark.md)
- [**IP Closed-Loop Workflow**](docs/WORKFLOW.md) — RTL ↔ 설계문서 ↔ IP-XACT ↔ Programmer's Guide ↔ HAL ↔ Test scenarios ↔ RTL verification 의 9-stage 폐쇄 루프 정의. 인터랙티브 시각 자료는 [`web/`](web/) (GitHub Pages 배포).

## 튜토리얼 (Step-by-Step)
각 형상관리 전략의 개발자/관리자 워크플로를 한 줄씩 따라하며 체험:
- [Strategy 01 — Monorepo](cm-strategies/01-monorepo/)  (DEVELOPER / ADMIN)
- [Strategy 02 — Submodule](cm-strategies/02-submodule/)  (DEVELOPER / ADMIN)
- [Strategy 03 — Repo+Manifest](cm-strategies/03-repo-manifest/)  (DEVELOPER / ADMIN)
- [Strategy 04 — Subtree](cm-strategies/04-subtree/)  (DEVELOPER / ADMIN)
