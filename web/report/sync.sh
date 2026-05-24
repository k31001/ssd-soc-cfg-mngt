#!/usr/bin/env bash
# docs/proposal/*.md → web/report/content/*.md 동기화.
# 로컬 미리보기 (python3 -m http.server -d web 8000) 와 CI deploy-pages가 모두 호출.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../docs/proposal"
DST="$HERE/content"

mkdir -p "$DST"
# 기존 mirror 정리 후 새로 복사 (rename된 파일이 남지 않도록)
find "$DST" -maxdepth 1 -type f -name '*.md' -delete
cp "$SRC"/*.md "$DST/"
echo "synced $(ls -1 "$DST" | wc -l | tr -d ' ') markdown files into web/report/content/"
