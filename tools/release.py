#!/usr/bin/env python3
"""
release.py — Release snapshot manifest 생성기.

용도:
  - 양산/검증 단계마다 모든 IP/Subsystem 의 SHA 를 박은 동결 manifest 생성.
  - 추적 가능한 release_id, sku, snapshot_date, builder, source manifest 기록.
  - 추후 PD/Foundry 사인오프 단계에서 본 파일이 일치 검증의 single source.

사용:
  release.py snapshot --src-manifest manifest/default.xml \
      --workdir workspace --sku gen5-4tb --release-id 2026Q2-rc3 \
      --out releases/release-2026Q2-rc3.xml
"""
from __future__ import annotations

import argparse
import datetime as dt
import getpass
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from repo_lite import load_manifest  # type: ignore


def head_sha(repo_root: Path) -> str:
    r = subprocess.run(["git", "-C", str(repo_root), "rev-parse", "HEAD"],
                       capture_output=True, text=True)
    return r.stdout.strip()


def cmd_snapshot(args: argparse.Namespace) -> int:
    m = load_manifest(Path(args.src_manifest))
    workdir = Path(args.workdir)

    lines = ['<?xml version="1.0" encoding="UTF-8"?>', "<manifest>"]
    lines.append(f"  <notice>")
    lines.append(f"    Release: {args.release_id}")
    lines.append(f"    SKU:     {args.sku}")
    lines.append(f"    Date:    {dt.datetime.utcnow().isoformat()}Z")
    lines.append(f"    Source:  {args.src_manifest}")
    lines.append(f"    Builder: {os.environ.get('USER', getpass.getuser())}")
    lines.append(f"  </notice>")
    for r, fetch in m.remotes.items():
        lines.append(f'  <remote name="{r}" fetch="{fetch}" />')
    lines.append(f'  <default remote="{m.default_remote}" revision="{m.default_revision}" />')

    missing = 0
    for proj in m.projects.values():
        path = workdir / proj.path
        if path.is_dir():
            sha = head_sha(path)
        else:
            sha = ""
            missing += 1
        lines.append(f'  <project name="{proj.name}" path="{proj.path}" revision="{sha or "MISSING"}" />')

    lines.append("</manifest>")
    out = "\n".join(lines) + "\n"

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(out)
    print(f"[release] wrote {out_path} ({len(m.projects)} projects, {missing} missing)")
    if missing:
        print(f"::warning::{missing} project(s) not found in workdir — synced workspace recommended")
    return 0 if missing == 0 else 2


def main() -> int:
    ap = argparse.ArgumentParser(description="SSD SoC release snapshot tool")
    sp = ap.add_subparsers(dest="cmd", required=True)

    s = sp.add_parser("snapshot", help="freeze a release manifest")
    s.add_argument("--src-manifest", required=True)
    s.add_argument("--workdir",      required=True)
    s.add_argument("--sku",          required=True)
    s.add_argument("--release-id",   required=True)
    s.add_argument("--out",          required=True)
    s.set_defaults(func=cmd_snapshot)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
