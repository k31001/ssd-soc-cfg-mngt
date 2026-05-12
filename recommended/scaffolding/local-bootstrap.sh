#!/usr/bin/env bash
# Recommended hybrid 구성을 로컬에서 end-to-end 시연.
#
# 동작:
#   1) ssd_soc/ 의 25 IP + 5 SS + top + common + verif 를 각각 bare repo 로 변환
#      (사실상 "GitHub Enterprise multi-repo" 의 로컬 모사)
#   2) 매니페스트 repo (default.xml + SKU manifests) 도 bare 로 push
#   3) `repo_lite.py sync` 로 워크스페이스 재구성
#   4) `tools/bom.py` 로 현재 BOM markdown 생성
#   5) status / freeze 명령 시연
#
# 사용:
#   ./local-bootstrap.sh /tmp/ssd-soc-recommended
set -euo pipefail

ROOT="${1:?usage: $0 <workdir>}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"

REMOTES="$ROOT/remotes"
WORK="$ROOT/work"
mkdir -p "$REMOTES" "$WORK"

mk_bare() {
  local name="$1" src="$2"
  rm -rf "$REMOTES/$name.git"
  git init -q --bare "$REMOTES/$name.git"
  local tmp; tmp="$(mktemp -d)"
  git init -q "$tmp"
  cp -r "$src"/. "$tmp"/ 2>/dev/null || true
  ( cd "$tmp"
    git add -A 2>/dev/null
    git -c user.email=demo@example.com -c user.name=demo commit -q -m "init $name" 2>/dev/null || true
    git branch -M main 2>/dev/null || true
    git remote add origin "$REMOTES/$name.git"
    # 데모용 가상 tag (manifest SKU pin 검증용)
    case "$name" in
      ip-pcie_phy|ip-pcie_ctrl|ip-pcie_cfg)
        git tag v2.4.0-gen4 2>/dev/null || true
        git tag v3.0.1-gen5 2>/dev/null || true
        ;;
      ip-nand_phy|ip-nand_ctrl)
        git tag v3.1.2-8ch 2>/dev/null || true
        git tag v4.0.0-16ch 2>/dev/null || true
        ;;
      ip-ddr4_ctrl)
        git tag v1.8.0-4gb 2>/dev/null || true
        git tag v2.0.0-16gb 2>/dev/null || true
        ;;
      ssd-soc-top)
        git tag sku-gen4-1tb-rc3 2>/dev/null || true
        git tag sku-gen5-4tb-rc1 2>/dev/null || true
        ;;
    esac
    git push -q origin main --tags 2>/dev/null || true
  )
  rm -rf "$tmp"
}

echo "==> [1/5] bare repos for all components"
mk_bare ssd-soc-top      "$SRC/ssd_soc/top"
mk_bare common-libs      "$SRC/ssd_soc/common"
mk_bare verif-framework  "$SRC/ssd_soc/verif"
for ss in host_ss fcc_ss mem_ss cpu_ss sec_ss; do
  mk_bare "$ss" "$SRC/ssd_soc/subsystems/$ss"
  for ip in "$SRC/ssd_soc/subsystems/$ss"/ip/*/; do
    [ -d "$ip" ] || continue
    mk_bare "ip-$(basename "$ip")" "$ip"
  done
done
# pdk-views: 빈 placeholder
mk_bare pdk-views "$(mktemp -d)"

echo "==> [2/5] manifest repo (default + SKU manifests, with localized fetch URLs)"
MFST_SRC="$(mktemp -d)"
for m in default.xml sku-gen4-1tb.xml sku-gen5-4tb.xml release-template.xml; do
  sed "s|git@github.com:acme-ssd/|$REMOTES/|g; s|fetch=\".*ldpc-vendor.*\"|fetch=\"$REMOTES/\"|" \
    "$SRC/recommended/manifest/$m" > "$MFST_SRC/$m"
done
( cd "$MFST_SRC"
  git init -q && git checkout -q -b main
  git -c user.email=demo@example.com -c user.name=demo add -A
  git -c user.email=demo@example.com -c user.name=demo commit -q -m "local manifest"
)
git init -q --bare "$REMOTES/ssd-soc-manifest.git"
( cd "$MFST_SRC" && git remote add origin "$REMOTES/ssd-soc-manifest.git" && git push -q origin main )
rm -rf "$MFST_SRC"

MFST_WORK="$WORK/manifest"
git clone -q "$REMOTES/ssd-soc-manifest.git" "$MFST_WORK"

echo "==> [3/5] sync workspace from default.xml"
mkdir -p "$WORK/checkout"
python3 "$SRC/tools/repo_lite.py" sync \
   --manifest "$MFST_WORK/default.xml" \
   --workdir  "$WORK/checkout" 2>&1 | tail -10

echo "==> [4/5] BOM (Bill-of-Materials) from current sync"
python3 "$SRC/tools/bom.py" --workdir "$WORK/checkout" --manifest "$MFST_WORK/default.xml" \
   --output "$WORK/BOM.md" || true
echo "BOM saved: $WORK/BOM.md"
head -20 "$WORK/BOM.md" 2>/dev/null || true

echo "==> [5/5] status + SKU manifest demo"
python3 "$SRC/tools/repo_lite.py" status \
   --manifest "$MFST_WORK/default.xml" \
   --workdir  "$WORK/checkout" | head -10
echo ""
echo "→ Switching to sku-gen5-4tb.xml ..."
mkdir -p "$WORK/checkout-gen5"
python3 "$SRC/tools/repo_lite.py" sync \
   --manifest "$MFST_WORK/sku-gen5-4tb.xml" \
   --workdir  "$WORK/checkout-gen5" 2>&1 | grep -E '(pcie|nand|ddr)' | head -5

echo ""
echo "[done] workspace: $WORK/checkout"
echo "[done] gen5 SKU: $WORK/checkout-gen5"
echo "[done] manifest: $MFST_WORK"
echo "[done] try: python3 $SRC/tools/repo_lite.py freeze --manifest $MFST_WORK/default.xml --workdir $WORK/checkout"
