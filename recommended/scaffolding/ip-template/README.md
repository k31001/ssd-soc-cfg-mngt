# ${IP_NAME}

${IP_DESCRIPTION}

| Field      | Value                |
|------------|----------------------|
| Owner      | `@acme-ssd/${TEAM}`  |
| Subsystem  | `${SUBSYSTEM}`       |
| Status     | `proto` (start state)|
| License    | Apache-2.0           |

## 빠른 시작

```bash
# 본 IP repo 만 단독 작업
git clone git@github.com:acme-ssd/ip-${IP_NAME}.git
cd ip-${IP_NAME}
make lint sim
```

```bash
# 전체 SoC 워크스페이스에서 함께 작업
cd <ssd-soc-workspace>/ip/${IP_NAME}
git checkout -b feature/my-change
```

## 디렉터리
- `rtl/`         — RTL 소스 (SystemVerilog)
- `sim/`         — 테스트벤치 (cocotb / SV)
- `cfg/`         — IP-local 설정 / waiver
- `doc/`         — IP 명세, 인터페이스, 레지스터 맵
- `ip.yaml`      — IP 메타데이터 (IPLM-lite)
- `CODEOWNERS`   — 자동 생성. ip.yaml 의 owner 와 동기화

## CI 게이트
모든 PR 에서 다음 체크가 통과해야 머지 가능:
- `lint`              — Verible/Verilator
- `yaml-schema`       — ip.yaml 스키마 검증
- `smoke-sim`         — Icarus + cocotb 단위 sim
- `semver-bump-check` — PR 마다 ip.yaml `version` 필드 bump 여부

## 릴리스
`main` 에 머지 후 `vMAJOR.MINOR.PATCH` 태그 push 시 manifest-bump 봇이
mainline manifest 의 본 IP revision 을 갱신하는 PR 을 자동 생성합니다.
