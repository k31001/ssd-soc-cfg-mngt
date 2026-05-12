#!/usr/bin/env bash
# `repo sync` 래퍼. 실제 repo 도구가 있으면 그것을, 없으면 repo-lite.py 를 사용.
set -euo pipefail

MFST="${1:-default.xml}"
WORK="${2:-.}"
GROUPS="${3:-}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if command -v repo >/dev/null 2>&1 && [ -d "$WORK/.repo" ]; then
  cd "$WORK"
  exec repo sync -j 8 ${GROUPS:+-g "$GROUPS"}
fi

ARGS=(sync --manifest "$MFST" --workdir "$WORK")
[ -n "$GROUPS" ] && ARGS+=(--groups "$GROUPS")
exec python3 "$ROOT/tools/repo_lite.py" "${ARGS[@]}"
