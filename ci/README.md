# CI / Automation — 계층별 파이프라인

GitHub Actions 기반 3계층 CI. 각 IP/Subsystem/Top repo 는 본 디렉터리의
**reusable workflow** 를 호출합니다 (`acme-ssd/.github/.github/workflows/...`).
정책 변경은 본 한 곳만 수정하면 전 repo 에 즉시 반영됩니다.

## 구조

```
ci/
├─ ip-ci.yml              ← 신규 IP repo 에 복사되는 entry workflow
├─ subsystem-ci.yml       ← subsystem repo 용
├─ top-ci.yml             ← top SoC repo 용
├─ manifest-bot.yml       ← 매니페스트 자동 갱신 봇
└─ reusable/
    ├─ lint.yml            (lint — Verible/Verilator)
    ├─ yaml-schema.yml     (ip.yaml 스키마 검증)
    ├─ smoke-sim.yml       (단위 sim — Icarus + cocotb)
    ├─ integration-sim.yml (subsystem 통합 sim — Verilator)
    ├─ cdc.yml             (CDC/RDC — 오픈소스 도구 부재 시 dry-run)
    ├─ codeowners-drift.yml(ip.yaml ↔ CODEOWNERS 검증)
    └─ full-soc.yml        (top: 전체 SoC build + Yosys dry-synth)
```

## 트리거 매트릭스

| Repo 계층 | 이벤트 | 실행 job | 비용/소요 |
|---|---|---|---|
| IP        | `pull_request` | lint, yaml-schema, smoke-sim, semver-bump, codeowners-drift | 2–5분 |
| IP        | `push` + tag `v*` | + notify-manifest-bot | 1분 |
| Subsystem | `pull_request` | integration-sim, cdc, manifest-resolve | 10–20분 |
| Subsystem | nightly cron    | 전체 회귀 + coverage | 1–2시간 |
| Top SoC   | `pull_request`  | full-soc elab, lint | 30–60분 |
| Top SoC   | weekly + tag    | full-soc build, dry-synth, BOM publish, release manifest freeze | 4–8시간 |
| Manifest  | `repository_dispatch: ip-tag-published` | manifest_bump → auto PR | 1분 |

## 품질 게이트 (Required Status Checks)

| IP-level (모두 통과해야 머지) |
|---|
| `lint` |
| `yaml-schema` |
| `smoke-sim` |
| `semver-bump-check` |
| `codeowners-drift` (status≥qual 시) |

| Subsystem-level |
|---|
| `integration-sim` |
| `cdc` |
| `manifest-resolve` (IP 의존성 SHA가 mainline manifest와 일치하는지) |

| Top-level |
|---|
| `full-soc-elab` |
| `release-snapshot-build` (tag push 시) |

## 개발자 영향

- IP-owner 는 PR 마다 `ip.yaml` 의 `version` 을 bump 해야 함 (자동 체크).
- Subsystem-owner 는 IP tag 가 푸시될 때 별도 작업 불필요 — manifest-bot 이 PR 생성.
- 권한 분리: workflow 파일 자체는 `@acme-ssd/platform-team` 만 수정 가능.

## 모니터링

- 매주 월요일 `tools/ci_cost_report.py` 가 Actions 사용량을 시트로 발행.
- 실패율 > 5% IP 는 자동으로 weekly digest에 noted.
