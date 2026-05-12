#!/usr/bin/env python3
"""
bom.py — manifest 와 IP `ip.yaml` 을 종합해 Bill-of-Materials markdown 출력.

용도:
  - 양산 SKU 별로 어떤 IP가 어느 버전/상태/owner 로 들어갔는지 단일 페이지로 가시화.
  - 매주 자동 실행해 docs/bom-<date>.md 형태로 publish.
  - 보안 감사 시 "현재 mainline 의 모든 IP 책임자/라이선스/검증 상태" 한 번에 추출.

PyYAML 가 없는 환경도 지원하기 위해 minimal YAML 파서 내장 (ip.yaml 형식 한정).
"""
from __future__ import annotations

import argparse
import re
import sys
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


# ── minimal YAML for ip.yaml subset (key: value, key: [list], key: |multiline)
def parse_simple_yaml(text: str) -> dict:
    out: dict = {}
    stack: list = [out]
    indents: list[int] = [-1]
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        # strip comments at end of line (naive — won't handle '#' inside strings, fine for ip.yaml)
        stripped = re.sub(r"\s+#.*$", "", raw).rstrip()
        if not stripped.strip():
            i += 1; continue
        indent = len(stripped) - len(stripped.lstrip())
        while indents and indent <= indents[-1]:
            stack.pop(); indents.pop()
        line = stripped.strip()

        if line.startswith("- "):
            parent = stack[-1]
            # parent must be a list-holding key; lift previous key value to list
            # already a list (created previously)
            val = line[2:].strip()
            if isinstance(parent, list):
                parent.append(val)
            i += 1; continue

        m = re.match(r"^([\w.-]+):\s*(.*)$", line)
        if not m:
            i += 1; continue
        key, value = m.group(1), m.group(2)

        # block scalar
        if value == "|":
            i += 1
            block = []
            while i < len(lines):
                nxt = lines[i]
                if not nxt.strip(): block.append(""); i += 1; continue
                ni = len(nxt) - len(nxt.lstrip())
                if ni <= indent: break
                block.append(nxt[indent + 2 :])
                i += 1
            stack[-1][key] = "\n".join(block).rstrip()
            continue

        if value == "":
            # next line indented → nested dict OR list
            # peek
            j = i + 1
            while j < len(lines) and not lines[j].strip(): j += 1
            if j < len(lines):
                nxt = lines[j]
                ni = len(nxt) - len(nxt.lstrip())
                if ni > indent and nxt.lstrip().startswith("- "):
                    new: list = []
                else:
                    new = {}
            else:
                new = {}
            stack[-1][key] = new
            stack.append(new)
            indents.append(indent)
            i += 1; continue

        # inline list [a, b, c]
        if value.startswith("[") and value.endswith("]"):
            body = value[1:-1].strip()
            items = [x.strip().strip('"').strip("'") for x in body.split(",")] if body else []
            stack[-1][key] = items
            i += 1; continue

        # scalar
        v = value.strip().strip('"').strip("'")
        if v.lower() in ("true", "false"): v = (v.lower() == "true")
        elif re.match(r"^-?\d+$", v): v = int(v)
        elif v.lower() in ("null", "none", "~"): v = None
        stack[-1][key] = v
        i += 1
    return out


def parse_manifest(path: Path) -> list[tuple[str, str]]:
    """Return list of (name, path) for each project, expanding <include>."""
    tree = ET.parse(path)
    root = tree.getroot()
    out: list[tuple[str, str]] = []
    seen: set[str] = set()

    def walk(elem: ET.Element, base: Path) -> None:
        for child in elem:
            if child.tag == "include":
                inc = base / child.attrib["name"]
                walk(ET.parse(inc).getroot(), inc.parent)
            elif child.tag == "remove-project":
                seen.discard(child.attrib["name"])
                out[:] = [(n, p) for (n, p) in out if n != child.attrib["name"]]
            elif child.tag == "project":
                name = child.attrib["name"]
                path = child.attrib.get("path", name)
                if name not in seen:
                    seen.add(name)
                    out.append((name, path))
    walk(root, path.parent)
    return out


def read_ip_yaml(repo_root: Path) -> dict | None:
    """Find ip.yaml inside repo. Returns parsed dict or None."""
    # Direct
    p = repo_root / "ip.yaml"
    if p.is_file():
        return parse_simple_yaml(p.read_text())
    # Phase A style: cfg/<name>.ip.yaml
    cfg = repo_root / "cfg"
    if cfg.is_dir():
        for f in cfg.iterdir():
            if f.name.endswith(".ip.yaml"):
                return parse_simple_yaml(f.read_text())
    return None


def head_sha(repo_root: Path) -> str:
    if not (repo_root / ".git").exists():
        return "-"
    r = subprocess.run(["git", "-C", str(repo_root), "rev-parse", "--short", "HEAD"],
                       capture_output=True, text=True)
    return r.stdout.strip() or "-"


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate SoC Bill-of-Materials markdown.")
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--workdir",  required=True)
    ap.add_argument("--output",   default="-")
    args = ap.parse_args()

    projects = parse_manifest(Path(args.manifest))
    workdir  = Path(args.workdir)

    rows = []
    for name, path in projects:
        rpath = workdir / path
        sha = head_sha(rpath)
        meta = read_ip_yaml(rpath) or {}
        rows.append({
            "name":      name,
            "path":      path,
            "version":   meta.get("version", "-"),
            "status":    meta.get("status", "-"),
            "owner":     meta.get("owner", "-"),
            "license":   meta.get("license", "-"),
            "subsystem": meta.get("subsystem", "-"),
            "head":      sha,
        })

    lines = []
    lines.append("# Bill of Materials — SSD Controller SoC")
    lines.append("")
    lines.append(f"- Manifest: `{Path(args.manifest)}`")
    lines.append(f"- Workspace: `{Path(args.workdir)}`")
    lines.append(f"- Total components: {len(rows)}")
    lines.append("")
    lines.append("| # | Component | Path | Version | Status | Subsystem | Owner | HEAD |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for i, r in enumerate(rows, 1):
        lines.append(f"| {i} | `{r['name']}` | `{r['path']}` | {r['version']} | "
                     f"{r['status']} | {r['subsystem']} | {r['owner']} | `{r['head']}` |")

    # Quality summary
    by_status = {}
    for r in rows:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    lines.append("")
    lines.append("## Quality summary")
    for s in ("gold", "qual", "alpha", "proto", "-"):
        if s in by_status:
            lines.append(f"- `{s}` : {by_status[s]}")

    out = "\n".join(lines) + "\n"
    if args.output == "-":
        sys.stdout.write(out)
    else:
        Path(args.output).write_text(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
