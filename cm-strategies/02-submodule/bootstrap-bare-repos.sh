#!/usr/bin/env bash
# Submodule 전략을 로컬에서 실제 실행해보기 위한 데모.
# 각 IP/Subsystem 을 bare repo 로 만들어 로컬 "fake GitHub" 를 흉내냅니다.
#
# 사용:
#   ./bootstrap-bare-repos.sh /tmp/ssd-soc-submodule-demo
set -euo pipefail

ROOT="${1:?usage: $0 <workdir>}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p "$ROOT/remotes"
cd "$ROOT/remotes"

echo "[bootstrap] creating bare repos for 25 IPs + 5 subsystems + common ..."

create_bare() {
  local name="$1" src="$2"
  rm -rf "$name.git"
  git init -q --bare "$name.git"
  local tmp="$(mktemp -d)"
  git init -q "$tmp"
  cp -r "$src"/* "$tmp"/ 2>/dev/null || true
  ( cd "$tmp"
    git add -A 2>/dev/null
    git -c user.email=demo@example.com -c user.name=demo commit -q -m "init $name" 2>/dev/null || true
    git remote add origin "$ROOT/remotes/$name.git"
    git branch -M main
    git push -q origin main 2>/dev/null || true
  )
  rm -rf "$tmp"
}

create_bare common-libs "$SRC/ssd_soc/common"

for ss in host_ss fcc_ss mem_ss cpu_ss sec_ss; do
  create_bare "$ss" "$SRC/ssd_soc/subsystems/$ss"
  for ip in "$SRC/ssd_soc/subsystems/$ss"/ip/*/; do
    [ -d "$ip" ] || continue
    ipn=$(basename "$ip")
    create_bare "ip-$ipn" "$ip"
  done
done

echo "[bootstrap] composing top repo ..."
mkdir -p "$ROOT/work"
cd "$ROOT/work"
rm -rf ssd-soc-top
git init -q ssd-soc-top
cd ssd-soc-top
mkdir -p top common-libs subsystems ip

git -c user.email=demo@example.com -c user.name=demo commit -q --allow-empty -m "init top"

git submodule add -q "$ROOT/remotes/common-libs.git" common-libs
for ss in host_ss fcc_ss mem_ss cpu_ss sec_ss; do
  git submodule add -q "$ROOT/remotes/$ss.git" "subsystems/$ss"
done
for ip in "$SRC/ssd_soc/subsystems"/*/ip/*/; do
  ipn=$(basename "$ip")
  git submodule add -q "$ROOT/remotes/ip-$ipn.git" "ip/$ipn"
done

git -c user.email=demo@example.com -c user.name=demo commit -q -m "wire 25 IPs + 5 subsystems + common as submodules"
echo "[bootstrap] done. result at: $ROOT/work/ssd-soc-top"
ls -la "$ROOT/work/ssd-soc-top"
echo ""
echo "[bootstrap] try:"
echo "  cd $ROOT/work/ssd-soc-top && git submodule status | head"
