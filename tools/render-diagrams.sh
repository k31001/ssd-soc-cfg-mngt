#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# render-diagrams.sh — IP doc 폴더의 WaveDrom JSON source를 SVG로 렌더한다.
#
# 사용법:
#   tools/render-diagrams.sh                # 레포 전체 (ssd_soc/**/doc/diagrams)
#   tools/render-diagrams.sh <ip-dir>       # 특정 IP 폴더만
#   tools/render-diagrams.sh --check        # 렌더 후 git diff가 비어 있어야 PASS (CI용)
#
# Mermaid는 GitHub 마크다운에서 직접 렌더되므로 별도 단계 불필요.
# WaveDrom은 GitHub에서 inline 렌더가 안 되므로 .svg를 같이 커밋한다.

set -euo pipefail

WAVEDROM_CLI_VERSION="${WAVEDROM_CLI_VERSION:-3.2.0}"

CHECK_MODE=0
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_MODE=1 ;;
    -*)      echo "unknown flag: $arg" >&2; exit 2 ;;
    *)       TARGETS+=("$arg") ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  # 레포 루트 기준으로 모든 doc/diagrams 폴더 검색
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  cd "$REPO_ROOT"
  mapfile -t DIAGRAM_DIRS < <(find ssd_soc -type d -name diagrams | sort)
else
  DIAGRAM_DIRS=()
  for t in "${TARGETS[@]}"; do
    if [[ -d "$t/doc/diagrams" ]]; then
      DIAGRAM_DIRS+=("$t/doc/diagrams")
    elif [[ -d "$t" ]]; then
      DIAGRAM_DIRS+=("$t")
    else
      echo "no such directory: $t" >&2; exit 2
    fi
  done
fi

if [[ ${#DIAGRAM_DIRS[@]} -eq 0 ]]; then
  echo "[render-diagrams] no diagram directories found."
  exit 0
fi

# 호스트에 node가 있는지 확인
if ! command -v npx >/dev/null 2>&1; then
  echo "[render-diagrams] npx not found — node 18+ 가 필요합니다." >&2
  exit 1
fi

RENDERED=0
for dir in "${DIAGRAM_DIRS[@]}"; do
  shopt -s nullglob
  for src in "$dir"/*.json "$dir"/*.json5; do
    out="${src%.*}.svg"
    echo "[render-diagrams] $src → $out"
    npx --yes "wavedrom-cli@${WAVEDROM_CLI_VERSION}" -i "$src" -s "$out" >/dev/null
    RENDERED=$((RENDERED + 1))
  done
  shopt -u nullglob
done

echo "[render-diagrams] rendered $RENDERED file(s)."

if [[ $CHECK_MODE -eq 1 ]]; then
  # CI: 산출 SVG가 커밋된 것과 일치해야 PASS
  if ! git diff --quiet -- '*.svg'; then
    echo "[render-diagrams] FAIL — SVG가 source와 동기화되어 있지 않습니다."
    echo "                  로컬에서 'tools/render-diagrams.sh'를 다시 실행 후 커밋하세요."
    git --no-pager diff --stat -- '*.svg'
    exit 1
  fi
  echo "[render-diagrams] OK — drift 없음."
fi
