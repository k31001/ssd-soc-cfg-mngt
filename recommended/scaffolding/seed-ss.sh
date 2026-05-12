#!/usr/bin/env bash
# 새 subsystem repo 부트스트랩. IP 보다 단순 — wrapper RTL + ss.yaml 만.
set -euo pipefail

SS_NAME="${1:?usage: $0 <ss_name> <team> <description> [--local <workdir>]}"
TEAM="${2:?team required}"
SS_DESC="${3:?description required}"
MODE="${4:-remote}"
WORKDIR="${5:-/tmp/ssd-soc-seed-demo}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE"/{rtl,sim,cfg,doc,.github/workflows}

cat > "$STAGE/cfg/$SS_NAME.ss.yaml" <<EOF
# Subsystem metadata (IPLM-lite SS schema)
name:        $SS_NAME
owner:       "@acme-ssd/$TEAM"
description: |
  $SS_DESC
ips: []   # populated by manifest-bump.py as IPs join
integration:
  bus:    axi
  clocks: [clk]
  resets: [rst_n]
EOF

cat > "$STAGE/rtl/$SS_NAME.sv" <<EOF
// SPDX-License-Identifier: Apache-2.0
// Subsystem wrapper: $SS_NAME ($SS_DESC)
module $SS_NAME (input logic clk, input logic rst_n);
  initial \$display("[STUB] subsystem %m");
endmodule
EOF

cat > "$STAGE/README.md" <<EOF
# $SS_NAME

$SS_DESC

Owner: \`@acme-ssd/$TEAM\`

Member IPs 는 \`cfg/$SS_NAME.ss.yaml\` 의 \`ips:\` 리스트로 관리됩니다.
새 IP 추가는 \`seed-ip.sh\` 가 자동 갱신합니다.
EOF

cat > "$STAGE/CODEOWNERS" <<EOF
*    @acme-ssd/$TEAM @acme-ssd/integration-team
EOF

cat > "$STAGE/.github/workflows/ci.yml" <<'EOF'
name: subsystem-ci
on:
  pull_request: { branches: [main] }
  schedule:
    - cron: '0 18 * * *'   # nightly
jobs:
  integration:
    uses: acme-ssd/.github/.github/workflows/reusable-integration-sim.yml@main
  cdc-rdc:
    uses: acme-ssd/.github/.github/workflows/reusable-cdc.yml@main
EOF

( cd "$STAGE"
  git init -q && git checkout -q -b main
  git -c user.email=ci@acme-ssd -c user.name="ssd-soc-bot" add -A
  git -c user.email=ci@acme-ssd -c user.name="ssd-soc-bot" commit -q -m "init: $SS_NAME subsystem"
)

if [ "$MODE" = "--local" ]; then
  REMOTES="$WORKDIR/remotes"
  mkdir -p "$REMOTES"
  git init -q --bare "$REMOTES/$SS_NAME.git"
  ( cd "$STAGE" && git remote add origin "$REMOTES/$SS_NAME.git" && git push -q origin main )
  echo "[seed-ss] local bare: $REMOTES/$SS_NAME.git"
else
  REPO="acme-ssd/$SS_NAME"
  gh repo create "$REPO" --private --description "$SS_DESC" || true
  ( cd "$STAGE" && git remote add origin "git@github.com:$REPO.git" && git push -q -u origin main )
  "$ROOT/recommended/scaffolding/apply-branch-protection.sh" "$REPO"
fi

rm -rf "$STAGE"
echo "[seed-ss] done. $SS_NAME bootstrapped."
