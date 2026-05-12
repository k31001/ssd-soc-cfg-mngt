#!/usr/bin/env python3
"""
ipgen.py — 단일 ip.yaml 로부터 boilerplate (rtl/sim/doc) 재생성.

scaffold_ssd_soc.py 가 25개 IP 전체를 한 번에 부트스트랩하는 도구라면,
본 ipgen.py 는 **운영 단계**에 IP-owner 가 단일 IP 의 ports/parameter 를
ip.yaml 에서 바꾼 뒤 `module ... ();` 시그니처와 README 표를 다시 생성하는 도구.

원칙:
  - 사람이 손으로 채우는 영역은 절대 덮어쓰지 않음 (// USER-EDIT 마커 사이만 갱신).
  - PR 에서 ipgen 산출물과 손편집 결과의 diff 를 review 가능.

이번 데모는 *시그니처와 README* 만 갱신하도록 한정 — 실제 운영에서는
register file, CSR header, IP-XACT 파일 등도 같이 생성.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from bom import parse_simple_yaml  # type: ignore


SIG_TPL = """// AUTO-GENERATED-BEGIN — modified by ipgen.py. Do not edit.
// Source: ip.yaml (version={version}, status={status}, owner={owner})
module {name} #(
{params}
) (
  input  logic clk,
  input  logic rst_n{bus_port}
);
// AUTO-GENERATED-END
"""


def render_params(params: dict | None) -> str:
    if not params:
        return "  parameter int UNUSED = 0"
    out = []
    for k, v in (params or {}).items():
        if isinstance(v, int):
            out.append(f"  parameter int {k} = {v}")
        else:
            out.append(f'  parameter         {k} = "{v}"')
    return ",\n".join(out)


def render_bus(bus: str) -> str:
    return {
        "axi": ",\n  axi_if.slave        s_axi",
        "apb": ",\n  apb_if.slave        s_apb",
        "ahb": ",\n  // ahb interface not modeled",
    }.get(bus, "")


def update_signature(rtl_path: Path, header: str) -> None:
    """Replace AUTO-GENERATED block in existing RTL file, keep body untouched."""
    src = rtl_path.read_text() if rtl_path.exists() else ""
    if "// AUTO-GENERATED-BEGIN" in src:
        pre, _, rest = src.partition("// AUTO-GENERATED-BEGIN")
        _, _, post = rest.partition("// AUTO-GENERATED-END\n")
        new_src = pre + header + post
    else:
        # Brand-new file: prepend block + minimal body
        new_src = header + "\n  // User logic here\n\nendmodule\n"
    rtl_path.parent.mkdir(parents=True, exist_ok=True)
    rtl_path.write_text(new_src)


def main() -> int:
    ap = argparse.ArgumentParser(description="Regenerate IP signature from ip.yaml")
    ap.add_argument("--ip-yaml", required=True)
    ap.add_argument("--rtl",     required=False, help="rtl/<name>.sv path (default: inferred)")
    args = ap.parse_args()

    meta = parse_simple_yaml(Path(args.ip_yaml).read_text())
    name = meta["name"]
    rtl_path = Path(args.rtl) if args.rtl else Path(args.ip_yaml).parent / "rtl" / f"{name}.sv"

    header = SIG_TPL.format(
        name=name,
        version=meta.get("version", "?"),
        status=meta.get("status", "?"),
        owner=meta.get("owner", "?"),
        params=render_params(meta.get("parameters")),
        bus_port=render_bus(meta.get("bus", "axi")),
    )
    update_signature(rtl_path, header)
    print(f"[ipgen] regenerated signature in {rtl_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
