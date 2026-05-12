#!/usr/bin/env python3
"""
repo_lite.py — Google `repo` 도구의 핵심 5% 만 흉내내는 minimal 폴백.

목적:
  - GitHub Enterprise / 사내 mirror 도입 전, 로컬 데모 환경에서 manifest 기반
    동기화 흐름을 그대로 시연할 수 있게 한다.
  - 100명+ 운영에서는 실제 `repo` 또는 사내 자작 manifest 도구로 교체.

지원하는 것:
  - <manifest><remote/><default/><project/></manifest> 파싱
  - <include name="other.xml"/>  (단일 디렉터리 내)
  - <remove-project name="..."/> + 재정의
  - sync: 각 project 를 fetch URL 에서 clone, revision 으로 checkout
  - manifest -r : 현재 워크스페이스의 SHA를 박은 동결 manifest 출력 (interactive)
  - status: 워크스페이스 내 각 project 의 dirty 여부 / current SHA / 브랜치 출력

지원하지 않는 것 (실제 repo 대비):
  - topic upload, Gerrit 연동, hook, --reference mirror, projects.list 변경 추적
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Project:
    name: str
    path: str
    remote: str
    revision: str
    groups: str = ""


@dataclass
class Manifest:
    remotes: dict[str, str]
    default_remote: str
    default_revision: str
    projects: dict[str, Project]


def load_manifest(path: Path) -> Manifest:
    tree = ET.parse(path)
    root = tree.getroot()

    remotes: dict[str, str] = {}
    default_remote = ""
    default_revision = "main"
    projects: dict[str, Project] = {}
    removed: set[str] = set()

    def merge(elem: ET.Element) -> None:
        nonlocal default_remote, default_revision
        for child in elem:
            tag = child.tag
            if tag == "include":
                inc = path.parent / child.attrib["name"]
                sub = load_manifest(inc)
                remotes.update(sub.remotes)
                if sub.default_remote and not default_remote:
                    default_remote = sub.default_remote
                if sub.default_revision and default_revision == "main":
                    default_revision = sub.default_revision
                for n, p in sub.projects.items():
                    projects[n] = p
            elif tag == "remote":
                remotes[child.attrib["name"]] = child.attrib["fetch"]
            elif tag == "default":
                default_remote = child.attrib.get("remote", default_remote)
                default_revision = child.attrib.get("revision", default_revision)
            elif tag == "remove-project":
                removed.add(child.attrib["name"])
                projects.pop(child.attrib["name"], None)
            elif tag == "project":
                name = child.attrib["name"]
                if name in removed:
                    removed.discard(name)
                projects[name] = Project(
                    name=name,
                    path=child.attrib.get("path", name),
                    remote=child.attrib.get("remote", default_remote),
                    revision=child.attrib.get("revision", default_revision),
                    groups=child.attrib.get("groups", ""),
                )
    merge(root)
    return Manifest(remotes, default_remote, default_revision, projects)


def cmd_sync(args: argparse.Namespace) -> int:
    m = load_manifest(Path(args.manifest))
    workdir = Path(args.workdir).resolve()
    workdir.mkdir(parents=True, exist_ok=True)
    groups = set(args.groups.split(",")) if args.groups else None

    for proj in m.projects.values():
        if groups:
            proj_groups = set((proj.groups or "default").split(","))
            if not proj_groups & groups:
                print(f"[skip ] {proj.path} (groups={proj.groups})")
                continue

        target = workdir / proj.path
        url = m.remotes[proj.remote].rstrip("/") + "/" + proj.name + ".git"
        if target.exists():
            print(f"[pull ] {proj.path}")
            subprocess.run(["git", "-C", str(target), "fetch", "--quiet", "--tags", "origin"], check=False)
        else:
            print(f"[clone] {proj.path} ← {url}")
            target.parent.mkdir(parents=True, exist_ok=True)
            r = subprocess.run(["git", "clone", "--quiet", url, str(target)],
                               capture_output=True, text=True)
            if r.returncode != 0:
                print(f"  ! clone failed: {r.stderr.strip()}")
                continue

        # checkout revision (branch / tag / SHA)
        rev = proj.revision.replace("refs/tags/", "")
        subprocess.run(["git", "-C", str(target), "checkout", "--quiet", rev], check=False)

    print(f"[done ] synced {len(m.projects)} projects → {workdir}")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    m = load_manifest(Path(args.manifest))
    workdir = Path(args.workdir).resolve()
    print(f"{'PROJECT':40} {'REV':24} {'STATE':10}")
    for proj in m.projects.values():
        target = workdir / proj.path
        if not target.exists():
            state = "missing"
            sha   = "-"
        else:
            sha = subprocess.run(["git", "-C", str(target), "rev-parse", "--short", "HEAD"],
                                 capture_output=True, text=True).stdout.strip()
            dirty = subprocess.run(["git", "-C", str(target), "status", "--porcelain"],
                                   capture_output=True, text=True).stdout.strip()
            state = "dirty" if dirty else "clean"
        print(f"{proj.path:40} {sha:24} {state:10}")
    return 0


def cmd_freeze(args: argparse.Namespace) -> int:
    """Emit a release-snapshot manifest with current SHAs."""
    m = load_manifest(Path(args.manifest))
    workdir = Path(args.workdir).resolve()
    out = ['<?xml version="1.0" encoding="UTF-8"?>', "<manifest>"]
    for r, fetch in m.remotes.items():
        out.append(f'  <remote name="{r}" fetch="{fetch}" />')
    out.append(f'  <default remote="{m.default_remote}" revision="{m.default_revision}" />')
    for proj in m.projects.values():
        target = workdir / proj.path
        if target.exists():
            sha = subprocess.run(["git", "-C", str(target), "rev-parse", "HEAD"],
                                 capture_output=True, text=True).stdout.strip()
        else:
            sha = proj.revision
        out.append(f'  <project name="{proj.name}" path="{proj.path}" revision="{sha}" />')
    out.append("</manifest>")
    print("\n".join(out))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="repo-lite — minimal AOSP-style manifest tool")
    sp = p.add_subparsers(dest="cmd", required=True)

    s = sp.add_parser("sync", help="clone/update all projects in manifest")
    s.add_argument("--manifest", required=True)
    s.add_argument("--workdir",  required=True)
    s.add_argument("--groups",   default="", help="comma-separated group filter (e.g. default,ip,host)")
    s.set_defaults(func=cmd_sync)

    s = sp.add_parser("status", help="show clean/dirty state per project")
    s.add_argument("--manifest", required=True)
    s.add_argument("--workdir",  required=True)
    s.set_defaults(func=cmd_status)

    s = sp.add_parser("freeze", help="emit pinned manifest of current SHAs")
    s.add_argument("--manifest", required=True)
    s.add_argument("--workdir",  required=True)
    s.set_defaults(func=cmd_freeze)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
