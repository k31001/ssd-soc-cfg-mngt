#!/usr/bin/env bash
# Subtree workflow 데모.
# 1) vendor-ldpc-stub/ 을 가짜 외부 vendor bare repo 로 만든다.
# 2) ssd_soc/ monorepo 를 임시 repo 로 init 한다.
# 3) git subtree add 로 vendor 를 ip/ldpc_codec/vendor/ 로 흡수한다.
# 4) vendor 측에서 hotfix 추가 → subtree pull 시연.
set -euo pipefail

ROOT="${1:?usage: $0 <workdir>}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$ROOT"
echo "[demo] step 1: vendor bare repo"
rm -rf "$ROOT/vendor.git" "$ROOT/vendor-src"
git init -q "$ROOT/vendor-src"
cp -r "$SRC/cm-strategies/04-subtree/vendor-ldpc-stub/"* "$ROOT/vendor-src/"
( cd "$ROOT/vendor-src"
  git add -A
  git -c user.email=v@vendor.com -c user.name=vendor commit -q -m "release v2.4.0"
  git tag -a v2.4.0 -m "release v2.4.0"
  git branch -M main
)
git init -q --bare "$ROOT/vendor.git"
( cd "$ROOT/vendor-src" && git remote add origin "$ROOT/vendor.git" && git push -q origin main --tags )

echo "[demo] step 2: project monorepo (clone of ssd_soc/)"
rm -rf "$ROOT/proj"
git init -q "$ROOT/proj"
cp -r "$SRC/ssd_soc" "$ROOT/proj/"
cp "$SRC/README.md" "$ROOT/proj/" 2>/dev/null || true
( cd "$ROOT/proj"
  git add -A
  git -c user.email=demo@example.com -c user.name=demo commit -q -m "init monorepo from ssd_soc skeleton"
  git branch -M main

  echo "[demo] step 3: subtree add vendor"
  git remote add ldpc-vendor "$ROOT/vendor.git"
  git fetch -q ldpc-vendor
  git subtree add --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
                  ldpc-vendor v2.4.0 --squash \
                  -m "vendor: import ldpc_codec v2.4.0" || true

  echo "[demo] step 4: simulate vendor hotfix"
)
( cd "$ROOT/vendor-src"
  sed -i.bak 's|pass-through stub|pass-through stub (v2.4.1 perf fix)|' rtl/ldpc_codec_vendor.sv && rm -f rtl/ldpc_codec_vendor.sv.bak
  git -c user.email=v@vendor.com -c user.name=vendor commit -aq -m "perf: tune throughput"
  git tag -a v2.4.1 -m "hotfix v2.4.1"
  git push -q origin main --tags
)
( cd "$ROOT/proj"
  git fetch -q ldpc-vendor
  git subtree pull --prefix=ssd_soc/subsystems/fcc_ss/ip/ldpc_codec/vendor \
                   ldpc-vendor v2.4.1 --squash \
                   -m "vendor: bump ldpc_codec to v2.4.1" || true
  echo ""
  echo "[demo] vendor history within project log:"
  git log --oneline | head
)
echo "[demo] done. project at: $ROOT/proj"
