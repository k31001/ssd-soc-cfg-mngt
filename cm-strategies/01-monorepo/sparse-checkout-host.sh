#!/usr/bin/env bash
# host_ss 팀용 sparse-checkout 부트스트랩 데모.
# 실제로는 git remote 가 GitHub Enterprise 일 것을 가정 — 여기선 로컬 시연.
set -euo pipefail

REMOTE="${1:-../../}"        # 데모용: 본 저장소 자체를 origin 으로 사용
WORKDIR="${2:-/tmp/ssd-soc-host-checkout}"

echo "[sparse] cloning blobless from $REMOTE → $WORKDIR"
rm -rf "$WORKDIR"
git clone --filter=blob:none --no-checkout "$REMOTE" "$WORKDIR" || {
  echo "[sparse] (remote 없음 — 데모를 위해 디렉터리 복사로 대체)"
  mkdir -p "$WORKDIR"
  cp -r "$REMOTE"/* "$WORKDIR"/ 2>/dev/null || true
  exit 0
}

cd "$WORKDIR"
git sparse-checkout init --cone
git sparse-checkout set \
  ssd_soc/common \
  ssd_soc/subsystems/host_ss \
  ci tools docs
git checkout main || git checkout master || true

echo "[sparse] done. disk footprint:"
du -sh .
echo "[sparse] checked-out top-level:"
ls
