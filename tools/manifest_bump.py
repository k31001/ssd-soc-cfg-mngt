#!/usr/bin/env python3
"""
manifest_bump.py — manifest 자동 갱신 봇.

서브명령:
  add-ip      새 IP 를 default.xml 에 <project> 한 줄로 추가
  bump        IP 가 새 tag 를 push 했을 때 해당 project 의 revision 갱신
  list        manifest 의 모든 project 와 revision 출력

Phase D 의 GitHub Actions 봇이 IP tag push 이벤트 (`repository_dispatch:
ip-tag-published`) 를 받으면 본 도구로 PR 을 자동 생성합니다.
"""
from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


# ET 가 attribute 순서를 보존하므로 round-trip 안전.
def load(path: Path) -> ET.ElementTree:
    return ET.parse(path)


def save(tree: ET.ElementTree, path: Path) -> None:
    # human-friendly 한 indent
    ET.indent(tree, space="  ", level=0)
    out = ET.tostring(tree.getroot(), encoding="unicode")
    # XML declaration 보존
    Path(path).write_text('<?xml version="1.0" encoding="UTF-8"?>\n' + out + "\n")


def find_project(root: ET.Element, name: str) -> ET.Element | None:
    for p in root.iter("project"):
        if p.attrib.get("name") == name:
            return p
    return None


def cmd_add_ip(args: argparse.Namespace) -> int:
    tree = load(Path(args.manifest))
    root = tree.getroot()
    if find_project(root, args.name):
        print(f"[skip] {args.name} already in manifest")
        return 0
    elem = ET.Element("project", {
        "name":   args.name,
        "path":   args.path,
        "groups": f"default,ip,{args.subsystem.replace('_ss','')}",
    })
    root.append(elem)
    save(tree, Path(args.manifest))
    print(f"[ok  ] added <project name='{args.name}' path='{args.path}'/>")
    return 0


def cmd_bump(args: argparse.Namespace) -> int:
    tree = load(Path(args.manifest))
    root = tree.getroot()
    p = find_project(root, args.name)
    if p is None:
        print(f"::error::project {args.name} not in manifest")
        return 1
    old = p.attrib.get("revision", "main")
    new = args.revision if args.revision.startswith("refs/") else f"refs/tags/{args.revision}"
    p.attrib["revision"] = new
    if "upstream" not in p.attrib:
        p.attrib["upstream"] = "main"
    save(tree, Path(args.manifest))
    print(f"[ok  ] {args.name}: {old} → {new}")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    tree = load(Path(args.manifest))
    root = tree.getroot()
    for p in root.iter("project"):
        rev = p.attrib.get("revision", "(default)")
        print(f"{p.attrib['name']:30} {p.attrib.get('path','-'):28} {rev}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="manifest auto-bump bot")
    sp = ap.add_subparsers(dest="cmd", required=True)

    s = sp.add_parser("add-ip", help="register a new IP project")
    s.add_argument("--manifest",  required=True)
    s.add_argument("--name",      required=True)
    s.add_argument("--path",      required=True)
    s.add_argument("--subsystem", required=True)
    s.set_defaults(func=cmd_add_ip)

    s = sp.add_parser("bump", help="pin a project to a new tag/SHA")
    s.add_argument("--manifest", required=True)
    s.add_argument("--name",     required=True)
    s.add_argument("--revision", required=True, help="tag (e.g. v2.4.0) or refs/tags/X or SHA")
    s.set_defaults(func=cmd_bump)

    s = sp.add_parser("list", help="dump current manifest project list")
    s.add_argument("--manifest", required=True)
    s.set_defaults(func=cmd_list)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
