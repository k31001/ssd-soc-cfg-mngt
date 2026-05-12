#!/usr/bin/env bash
# `repo` 도구와 GitHub 없이도 manifest 흐름을 데모하기 위한 로컬 부트스트랩.
# 1) ssd_soc/ 하위 각 IP/Subsystem/common 을 로컬 bare repo 로 만든다.
# 2) default.xml 을 fetch URL이 로컬 경로를 가리키도록 다시 쓴다.
# 3) repo (또는 repo-lite.py 폴백) 으로 sync 한다.
set -euo pipefail

ROOT="${1:?usage: $0 <workdir>}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"

REMOTES="$ROOT/remotes"
WORK="$ROOT/work"
MFST="$ROOT/manifest"

mkdir -p "$REMOTES" "$WORK"
echo "[bootstrap] creating bare repos under $REMOTES ..."

mk_bare() {
  local name="$1" src="$2"
  rm -rf "$REMOTES/$name.git"
  git init -q --bare "$REMOTES/$name.git"
  local tmp; tmp="$(mktemp -d)"
  git init -q "$tmp"
  cp -r "$src"/* "$tmp"/ 2>/dev/null || true
  ( cd "$tmp"
    git add -A 2>/dev/null
    git -c user.email=demo@example.com -c user.name=demo commit -q -m "init $name" 2>/dev/null || true
    git branch -M main 2>/dev/null || true
    git remote add origin "$REMOTES/$name.git"
    git push -q origin main 2>/dev/null || true
  )
  rm -rf "$tmp"
}

# Top, common, verif
mk_bare ssd-soc-top      "$SRC/ssd_soc/top"
mk_bare common-libs      "$SRC/ssd_soc/common"
mk_bare verif-framework  "$SRC/ssd_soc/verif"

# Subsystems
for ss in host_ss fcc_ss mem_ss cpu_ss sec_ss; do
  mk_bare "$ss" "$SRC/ssd_soc/subsystems/$ss"
  for ip in "$SRC/ssd_soc/subsystems/$ss"/ip/*/; do
    [ -d "$ip" ] || continue
    ipn=$(basename "$ip")
    mk_bare "ip-$ipn" "$ip"
  done
done

# 로컬 manifest 디렉터리: fetch URL을 로컬 경로로 치환한 사본
rm -rf "$MFST"; mkdir -p "$MFST"
git init -q "$MFST"
sed "s|git@github.com:acme-ssd/|$REMOTES/|g; s|fetch=\".*ldpc-vendor.*\"|fetch=\"$REMOTES/\"|" \
  "$SRC/cm-strategies/03-repo-manifest/default.xml" > "$MFST/default.xml"
( cd "$MFST"
  git add default.xml
  git -c user.email=demo@example.com -c user.name=demo commit -q -m "local manifest"
  git branch -M main
)

# repo init/sync (real `repo` 가 있으면 사용, 없으면 repo-lite 폴백)
cd "$WORK"
if command -v repo >/dev/null 2>&1; then
  echo "[bootstrap] using real 'repo'"
  repo init -u "$MFST" -b main -m default.xml --no-clone-bundle --quiet
  repo sync -j 8 --quiet
else
  echo "[bootstrap] 'repo' not found — using bundled repo-lite.py fallback"
  python3 "$SRC/tools/repo_lite.py" sync --manifest "$MFST/default.xml" --workdir "$WORK"
fi

echo "[bootstrap] done. workspace: $WORK"
ls "$WORK" | head
