#!/usr/bin/env bash
# 모든 submodule 을 자기 origin 의 최신 tag로 일괄 갱신.
# 실제 운영에선 Phase D 의 tools/manifest-bump.py 가 동일 작업을 PR 자동 생성으로 수행.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
echo "[bump] updating submodules to latest tag..."

git submodule foreach --quiet '
  echo "- $name"
  git fetch --tags --quiet origin
  latest=$(git tag --sort=-version:refname | head -1)
  if [ -n "$latest" ]; then
    echo "    pin → $latest"
    git checkout --quiet "$latest"
  else
    echo "    (no tag, leaving at branch HEAD)"
  fi
'

# Stage submodule SHA changes in the superproject.
git add $(git submodule | awk '{print $2}')
echo "[bump] staged submodule pin changes:"
git diff --cached --name-only
echo "[bump] next: review & 'git commit -m \"bump all submodules to latest tag\"'"
