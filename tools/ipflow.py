#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
ipflow — IP development closed-loop workflow harness.

본 도구는 docs/WORKFLOW.md 에서 정의한 9-stage workflow의 invariant 들을
자동 검사하고, 각 IP의 stage 완료도를 매트릭스로 출력한다.

USAGE:
  ipflow status                  # 모든 IP 의 stage matrix
  ipflow status --json           # 웹 대시보드용 JSON
  ipflow validate <ip-path>      # closed-loop invariant 일괄 검사
  ipflow scenarios <ip-path>     # scenarios.yaml 파싱 + tb_task 매칭
  ipflow run <ip-path>           # 호스트에서 가능한 단계 일괄 실행

설계:
  - PyYAML 의존성을 피하고, 작은 YAML 서브셋만 파서 (key: value, list,
    nested dict). ip.yaml / scenarios.yaml 모두 이 서브셋 안에서 동작.
  - 외부 명령(make, render-diagrams)을 wrap. 시뮬레이터가 필요한
    단계는 환경에 없을 때 SKIP 로 표시.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field, asdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


# ─────────────────────────────────────────────────────────────────────────────
# Tiny YAML parser — handles the subset our project files use
# ─────────────────────────────────────────────────────────────────────────────

def _parse_yaml(text: str):
    """Parse YAML subset: scalars, sequences of scalars, sequences of mappings,
    nested mappings. Indentation-based. No anchors, no flow style, no quotes
    handling beyond simple strip.
    """
    lines = []
    for raw in text.splitlines():
        # drop comments outside quotes (naive — fine for our docs)
        s = re.sub(r"(?<!\\)#.*$", "", raw).rstrip()
        if s.strip():
            lines.append(s)

    pos = [0]

    def cur_indent():
        if pos[0] >= len(lines):
            return -1
        line = lines[pos[0]]
        return len(line) - len(line.lstrip())

    def scalar(v: str):
        v = v.strip()
        if v.startswith(("'", '"')) and v.endswith(("'", '"')):
            return v[1:-1]
        if v.lower() in ("true", "yes"):
            return True
        if v.lower() in ("false", "no"):
            return False
        if v.lower() in ("null", "~", ""):
            return None
        if re.fullmatch(r"-?\d+", v):
            return int(v)
        if re.fullmatch(r"-?\d+\.\d+", v):
            return float(v)
        return v

    def parse_block(indent: int):
        # decide if mapping or sequence by peeking
        if pos[0] >= len(lines):
            return None
        first = lines[pos[0]].strip()
        if first.startswith("- "):
            return parse_seq(indent)
        return parse_map(indent)

    def parse_map(indent: int):
        out = {}
        while pos[0] < len(lines):
            line = lines[pos[0]]
            ci = len(line) - len(line.lstrip())
            if ci < indent:
                break
            if ci != indent:
                break
            body = line.strip()
            m = re.match(r"^([\w.\-]+)\s*:\s*(.*)$", body)
            if not m:
                pos[0] += 1
                continue
            key, rest = m.group(1), m.group(2).strip()
            pos[0] += 1
            if not rest:
                # nested
                if pos[0] < len(lines):
                    nxt = lines[pos[0]]
                    nxt_indent = len(nxt) - len(nxt.lstrip())
                    if nxt_indent > indent:
                        out[key] = parse_block(nxt_indent)
                        continue
                out[key] = None
            elif rest == "|":
                # block scalar
                buf = []
                while pos[0] < len(lines):
                    nxt = lines[pos[0]]
                    ni = len(nxt) - len(nxt.lstrip())
                    if ni <= indent:
                        break
                    buf.append(nxt[indent + 2 :])
                    pos[0] += 1
                out[key] = "\n".join(buf)
            elif rest.startswith("[") and rest.endswith("]"):
                inner = rest[1:-1].strip()
                out[key] = [scalar(x) for x in inner.split(",")] if inner else []
            else:
                out[key] = scalar(rest)
        return out

    def parse_seq(indent: int):
        out = []
        while pos[0] < len(lines):
            line = lines[pos[0]]
            ci = len(line) - len(line.lstrip())
            if ci != indent:
                break
            body = line.strip()
            if not body.startswith("- "):
                break
            item_body = body[2:]
            pos[0] += 1
            # if "- key: val" -> mapping item; look-ahead for more keys at indent+2
            m = re.match(r"^([\w.\-]+)\s*:\s*(.*)$", item_body)
            if m:
                # build mapping starting with this key
                first_key, first_rest = m.group(1), m.group(2).strip()
                item = {}
                if first_rest:
                    if first_rest.startswith("[") and first_rest.endswith("]"):
                        inner = first_rest[1:-1].strip()
                        item[first_key] = (
                            [scalar(x) for x in inner.split(",")] if inner else []
                        )
                    else:
                        item[first_key] = scalar(first_rest)
                else:
                    if pos[0] < len(lines):
                        nxt = lines[pos[0]]
                        ni = len(nxt) - len(nxt.lstrip())
                        if ni > indent + 2:
                            item[first_key] = parse_block(ni)
                # absorb subsequent keys at indent+2
                while pos[0] < len(lines):
                    nxt = lines[pos[0]]
                    ni = len(nxt) - len(nxt.lstrip())
                    if ni != indent + 2:
                        break
                    nbody = nxt.strip()
                    if nbody.startswith("- "):
                        break
                    mm = re.match(r"^([\w.\-]+)\s*:\s*(.*)$", nbody)
                    if not mm:
                        pos[0] += 1
                        continue
                    k2, r2 = mm.group(1), mm.group(2).strip()
                    pos[0] += 1
                    if not r2:
                        if pos[0] < len(lines):
                            nx2 = lines[pos[0]]
                            ni2 = len(nx2) - len(nx2.lstrip())
                            if ni2 > indent + 2:
                                item[k2] = parse_block(ni2)
                                continue
                        item[k2] = None
                    elif r2.startswith("[") and r2.endswith("]"):
                        inner = r2[1:-1].strip()
                        item[k2] = (
                            [scalar(x) for x in inner.split(",")] if inner else []
                        )
                    else:
                        item[k2] = scalar(r2)
                out.append(item)
            else:
                out.append(scalar(item_body))
        return out

    return parse_block(0) or {}


# ─────────────────────────────────────────────────────────────────────────────
# Domain types
# ─────────────────────────────────────────────────────────────────────────────

STAGES = [
    "spec",       # cfg/ip.yaml
    "rtl",        # rtl/*.sv
    "design",     # doc/DESIGN.md + diagrams
    "ipxact",     # doc/*.ipxact.xml
    "guide",      # doc/PROGRAMMERS_GUIDE.md
    "hal",        # sw/*.h + *.c + Makefile
    "scenarios",  # verif/scenarios.yaml
    "sim",        # sim/tb_*.sv
]


@dataclass
class IpStatus:
    name: str
    path: str
    subsystem: str
    version: str | None
    stages: dict[str, bool] = field(default_factory=dict)


@dataclass
class CheckResult:
    name: str
    passed: bool
    detail: str = ""


# ─────────────────────────────────────────────────────────────────────────────
# Discovery helpers
# ─────────────────────────────────────────────────────────────────────────────

def find_all_ips(root: Path = REPO_ROOT) -> list[Path]:
    # ssd_soc/subsystems/<ss>/ip/<ip>/cfg/<ip>.ip.yaml → IP dir is parent.parent
    return sorted({p.parent.parent for p in root.glob("ssd_soc/subsystems/*/ip/*/cfg/*.ip.yaml")})


def ip_meta(ip_dir: Path) -> dict:
    yaml_files = list((ip_dir / "cfg").glob("*.ip.yaml"))
    if not yaml_files:
        return {}
    return _parse_yaml(yaml_files[0].read_text(encoding="utf-8"))


def detect_stages(ip_dir: Path) -> dict[str, bool]:
    """Return which stages have artifacts present (cheap presence check;
    does NOT run invariant validation — that's `validate`)."""
    out = {}
    out["spec"] = bool(list((ip_dir / "cfg").glob("*.ip.yaml")))
    out["rtl"] = any((ip_dir / "rtl").glob("*.sv")) if (ip_dir / "rtl").is_dir() else False
    # rtl stage is "complete" only if RTL is not the stub
    if out["rtl"]:
        sv_files = list((ip_dir / "rtl").glob("*.sv"))
        has_stub = any(
            "STUB BODY" in p.read_text(encoding="utf-8", errors="ignore")
            for p in sv_files
        )
        out["rtl"] = not has_stub
    out["design"] = (ip_dir / "doc" / "DESIGN.md").exists()
    out["ipxact"] = bool(list((ip_dir / "doc").glob("*.ipxact.xml")))
    out["guide"] = (ip_dir / "doc" / "PROGRAMMERS_GUIDE.md").exists()
    out["hal"] = (ip_dir / "sw").is_dir() and bool(list((ip_dir / "sw").glob("*_hal.h")))
    out["scenarios"] = (ip_dir / "verif" / "scenarios.yaml").exists()
    # sim stage is "complete" only if TB is more than smoke stub
    out["sim"] = False
    sim_files = list((ip_dir / "sim").glob("tb_*.sv")) if (ip_dir / "sim").is_dir() else []
    if sim_files:
        body = sim_files[0].read_text(encoding="utf-8", errors="ignore")
        out["sim"] = ("ALL TESTS PASSED" in body) or ("$display" in body and "CHECK" in body)
    return out


def all_status() -> list[IpStatus]:
    rows = []
    for ip_dir in find_all_ips():
        meta = ip_meta(ip_dir)
        rows.append(
            IpStatus(
                name=meta.get("name", ip_dir.name),
                path=str(ip_dir.relative_to(REPO_ROOT)),
                # IP dir layout: subsystems/<ss>/ip/<ip>
                subsystem=meta.get("subsystem", ip_dir.parents[1].name),
                version=meta.get("version"),
                stages=detect_stages(ip_dir),
            )
        )
    return rows


# ─────────────────────────────────────────────────────────────────────────────
# Validators (closed-loop invariants)
# ─────────────────────────────────────────────────────────────────────────────

def _parse_design_regmap(design_md: Path) -> dict[int, dict]:
    """Extract offsets from DESIGN.md §5 register-map table.
    Returns {offset_int: {"name": str, "access": str}}.
    """
    if not design_md.exists():
        return {}
    text = design_md.read_text(encoding="utf-8")
    regs: dict[int, dict] = {}
    # Match table rows like: | `0x000` | `PRIORITY[0]` | RO ...
    pat = re.compile(
        r"^\|\s*`?(0x[0-9A-Fa-f]+)`?\s*\|\s*`?([^`|]+?)`?\s*\|\s*([^|]+?)\s*\|",
        re.MULTILINE,
    )
    for m in pat.finditer(text):
        try:
            off = int(m.group(1), 16)
        except ValueError:
            continue
        name = m.group(2).strip()
        access = m.group(3).strip()
        # filter out obvious header rows
        if name.lower() in ("name", "register", "이름", ""):
            continue
        regs[off] = {"name": name, "access": access}
    return regs


def _parse_ipxact_regmap(ipxact_xml: Path) -> dict[int, dict]:
    if not ipxact_xml.exists():
        return {}
    ns = {"ipx": "http://www.accellera.org/XMLSchema/IPXACT/1685-2014"}
    tree = ET.parse(ipxact_xml)
    out: dict[int, dict] = {}
    for reg in tree.iter("{http://www.accellera.org/XMLSchema/IPXACT/1685-2014}register"):
        name_el = reg.find("ipx:name", ns)
        off_el = reg.find("ipx:addressOffset", ns)
        acc_el = reg.find("ipx:access", ns)
        if off_el is None or name_el is None:
            continue
        try:
            off = int(off_el.text, 0)
        except (ValueError, TypeError):
            continue
        out[off] = {
            "name": name_el.text or "",
            "access": (acc_el.text if acc_el is not None else "") or "",
        }
    return out


def check_ipxact_vs_design(ip_dir: Path) -> CheckResult:
    design = _parse_design_regmap(ip_dir / "doc" / "DESIGN.md")
    ipxact_files = list((ip_dir / "doc").glob("*.ipxact.xml"))
    if not ipxact_files:
        return CheckResult("ipxact_vs_design", False, "no ipxact xml")
    ipxact = _parse_ipxact_regmap(ipxact_files[0])
    if not design or not ipxact:
        return CheckResult("ipxact_vs_design", False, f"empty: design={len(design)}, ipxact={len(ipxact)}")
    # Every IP-XACT offset must appear in DESIGN
    missing = [hex(off) for off in ipxact if off not in design]
    extras = []
    # PRIORITY_0 in ipxact is offset 0x000 and DESIGN also has it; PRIORITY array
    # in ipxact has offset 0x004 only (the rest is dim-based, not enumerated).
    # So we just check that every IP-XACT register appears at the right offset
    # in DESIGN.
    if missing:
        return CheckResult(
            "ipxact_vs_design", False, f"IP-XACT offsets not in DESIGN.md: {missing[:5]}"
        )
    return CheckResult(
        "ipxact_vs_design",
        True,
        f"{len(ipxact)} IP-XACT register(s) found at matching DESIGN.md offsets",
    )


def check_hal_vs_ipxact(ip_dir: Path) -> CheckResult:
    ipxact_files = list((ip_dir / "doc").glob("*.ipxact.xml"))
    if not ipxact_files:
        return CheckResult("hal_vs_ipxact", False, "no ipxact xml")
    ipxact = _parse_ipxact_regmap(ipxact_files[0])
    hal_h = next((ip_dir / "sw").glob("*_hal.h"), None) if (ip_dir / "sw").is_dir() else None
    if not hal_h:
        return CheckResult("hal_vs_ipxact", False, "no HAL header")
    hal_text = hal_h.read_text(encoding="utf-8")
    # extract numeric offsets from `#define ..._REG_xxx 0x...`
    hal_offsets = set()
    for m in re.finditer(r"#define\s+\w+_REG_\w+\s+(0x[0-9A-Fa-f]+|\d+)u?", hal_text):
        try:
            hal_offsets.add(int(m.group(1), 0))
        except ValueError:
            continue
    # PRIORITY 배열은 HAL 매크로 IRQ_CTRL_REG_PRIORITY(i) 로 파생된다.
    # 이 매크로가 정의되어 있으면 0x000..0x07C 전체를 커버한 것으로 인정.
    if re.search(
        r"#define\s+\w+_REG_PRIORITY\s*\(\s*i\s*\)\s*\(\s*0x[0-9A-Fa-f]+u?\s*\+\s*4u?\s*\*\s*\(\s*i\s*\)\s*\)",
        hal_text,
    ):
        for off in range(0, 0x80, 4):
            hal_offsets.add(off)
    missing = []
    for off in ipxact:
        # PRIORITY (dim 31) only enumerates 0x004 in ipxact; allow it if covered
        if off in hal_offsets:
            continue
        missing.append(f"{ipxact[off]['name']} @ {hex(off)}")
    if missing:
        return CheckResult(
            "hal_vs_ipxact",
            False,
            f"IP-XACT registers not in HAL: {missing[:5]}",
        )
    return CheckResult(
        "hal_vs_ipxact",
        True,
        f"All {len(ipxact)} IP-XACT register offsets present in HAL header",
    )


def check_guide_funcs_in_hal(ip_dir: Path) -> CheckResult:
    guide = ip_dir / "doc" / "PROGRAMMERS_GUIDE.md"
    hal_h = next((ip_dir / "sw").glob("*_hal.h"), None) if (ip_dir / "sw").is_dir() else None
    if not guide.exists() or not hal_h:
        return CheckResult("guide_funcs_in_hal", False, "missing guide or HAL header")
    guide_text = guide.read_text(encoding="utf-8")
    hal_text = hal_h.read_text(encoding="utf-8")
    # find irq_ctrl_*-style calls in code fences
    calls = set(re.findall(r"\b([a-z_][a-z0-9_]*_[a-z]+)\s*\(", guide_text))
    # filter to identifiers that look like HAL APIs (have an underscore and contain ip prefix)
    ip_prefix = ip_dir.name + "_"
    calls = {c for c in calls if c.startswith(ip_prefix) or c == "mext_irq_handler"}
    # mext_irq_handler is a CPU-side function, exclude
    calls.discard("mext_irq_handler")
    missing = [c for c in sorted(calls) if c not in hal_text]
    if missing:
        return CheckResult("guide_funcs_in_hal", False, f"guide calls not in HAL: {missing}")
    return CheckResult(
        "guide_funcs_in_hal",
        True,
        f"All {len(calls)} guide-referenced HAL function(s) present",
    )


def check_diagrams_drift(ip_dir: Path) -> CheckResult:
    diagrams = ip_dir / "doc" / "diagrams"
    if not diagrams.is_dir() or not list(diagrams.glob("*.json")):
        return CheckResult("diagrams_drift", True, "no diagrams (skipped)")
    script = REPO_ROOT / "tools" / "render-diagrams.sh"
    if not script.exists():
        return CheckResult("diagrams_drift", False, "render-diagrams.sh missing")
    r = subprocess.run(
        ["bash", str(script), "--check", str(ip_dir)],
        capture_output=True,
        text=True,
    )
    return CheckResult(
        "diagrams_drift",
        r.returncode == 0,
        (r.stdout + r.stderr).strip().splitlines()[-1] if (r.stdout + r.stderr).strip() else "",
    )


def load_scenarios(ip_dir: Path) -> list[dict]:
    f = ip_dir / "verif" / "scenarios.yaml"
    if not f.exists():
        return []
    doc = _parse_yaml(f.read_text(encoding="utf-8"))
    return doc.get("scenarios", []) if isinstance(doc, dict) else []


def check_scenarios_vs_tb(ip_dir: Path) -> CheckResult:
    scenarios = load_scenarios(ip_dir)
    if not scenarios:
        return CheckResult("scenarios_vs_tb", False, "no scenarios.yaml or empty")
    tb = next((ip_dir / "sim").glob("tb_*.sv"), None)
    if not tb:
        return CheckResult("scenarios_vs_tb", False, "no tb_*.sv")
    tb_text = tb.read_text(encoding="utf-8")
    tb_tasks = set(re.findall(r"\btask\s+(?:automatic\s+)?(\w+)\b", tb_text))
    # CHECK("S01 ...") 또는 CHECK("T1 ...") 같이 scenario 태그가 박힌 문자열도
    # inline 매핑으로 인정.
    inline_ids = set(re.findall(r'"(S\d{2,3}|T\d{1,3})\b', tb_text))
    missing = []
    for sc in scenarios:
        ref = sc.get("tb_task")
        if ref:
            if ref in tb_tasks:
                continue
            # tolerate "inline:S01"
            if ref.startswith("inline:") and ref.split(":", 1)[1] in inline_ids:
                continue
            missing.append(f"{sc.get('id')}={ref}")
        else:
            # try id-based inline match
            if sc.get("id") not in inline_ids:
                missing.append(f"{sc.get('id')} (no tb_task and no inline id)")
    if missing:
        return CheckResult(
            "scenarios_vs_tb", False, f"missing TB tasks: {missing[:5]}"
        )
    return CheckResult(
        "scenarios_vs_tb",
        True,
        f"All {len(scenarios)} scenario(s) backed by TB task or inline id",
    )


def check_scenarios_vs_guide(ip_dir: Path) -> CheckResult:
    scenarios = load_scenarios(ip_dir)
    guide = ip_dir / "doc" / "PROGRAMMERS_GUIDE.md"
    if not scenarios:
        return CheckResult("scenarios_vs_guide", False, "no scenarios.yaml")
    if not guide.exists():
        return CheckResult("scenarios_vs_guide", False, "no PROGRAMMERS_GUIDE.md")
    text = guide.read_text(encoding="utf-8")
    sections = set(re.findall(r"^##\s*\d+\.", text, re.MULTILINE))
    # collect §N from scenarios and verify guide has at least one section per ref
    missing_refs = []
    for sc in scenarios:
        ref = (sc.get("guide_ref") or "").strip()
        if not ref:
            continue
        m = re.match(r"§(\d+)", ref)
        if not m:
            continue
        n = m.group(1)
        if not re.search(rf"^##\s*{n}\.", text, re.MULTILINE):
            missing_refs.append(ref)
    if missing_refs:
        return CheckResult(
            "scenarios_vs_guide",
            False,
            f"guide sections missing for refs: {sorted(set(missing_refs))[:5]}",
        )
    return CheckResult(
        "scenarios_vs_guide",
        True,
        f"All {len(scenarios)} scenarios reference existing guide sections",
    )


ALL_CHECKS = [
    check_diagrams_drift,
    check_ipxact_vs_design,
    check_hal_vs_ipxact,
    check_guide_funcs_in_hal,
    check_scenarios_vs_guide,
    check_scenarios_vs_tb,
]


# ─────────────────────────────────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────────────────────────────────

def cmd_status(args) -> int:
    rows = all_status()
    if args.json:
        out = [
            {
                "name": r.name,
                "path": r.path,
                "subsystem": r.subsystem,
                "version": r.version,
                "stages": r.stages,
                "percent": int(100 * sum(r.stages.values()) / max(1, len(r.stages))),
            }
            for r in rows
        ]
        print(json.dumps({"ips": out, "stages": STAGES}, indent=2))
        return 0

    print(f"\n{'IP':<24}{'SS':<10}{'Ver':<10}" + "".join(s[:5].ljust(7) for s in STAGES))
    print("-" * (24 + 10 + 10 + 7 * len(STAGES)))
    for r in rows:
        mark = lambda b: "  ✓   " if b else "  ·   "  # noqa: E731
        print(
            f"{r.name:<24}{r.subsystem:<10}{(r.version or '-'):<10}"
            + "".join(mark(r.stages.get(s, False)) for s in STAGES)
        )
    print()
    return 0


def cmd_validate(args) -> int:
    ip_dir = Path(args.ip).resolve()
    if not ip_dir.is_dir():
        print(f"no such directory: {ip_dir}", file=sys.stderr)
        return 2
    print(f"\n[ipflow validate] {ip_dir.relative_to(REPO_ROOT)}\n")
    n_fail = 0
    for fn in ALL_CHECKS:
        res: CheckResult = fn(ip_dir)
        tag = "PASS" if res.passed else "FAIL"
        print(f"  [{tag}] {res.name:<24} — {res.detail}")
        if not res.passed:
            n_fail += 1
    print()
    if n_fail:
        print(f"[ipflow validate] {n_fail} check(s) failed.\n")
        return 1
    print("[ipflow validate] all checks passed.\n")
    return 0


def cmd_scenarios(args) -> int:
    ip_dir = Path(args.ip).resolve()
    scenarios = load_scenarios(ip_dir)
    if not scenarios:
        print("(no scenarios)")
        return 0
    print(f"\n{ip_dir.name} scenarios — {len(scenarios)} entries\n")
    print(f"  {'ID':<6}{'Name':<32}{'Guide':<10}{'TB Task':<30}")
    print("  " + "-" * 78)
    for sc in scenarios:
        print(
            f"  {sc.get('id',''):<6}{sc.get('name',''):<32}"
            f"{sc.get('guide_ref',''):<10}{sc.get('tb_task',''):<30}"
        )
    print()
    return 0


def _detect_top_module(tb_file: Path) -> str:
    """tb_<name>.sv 의 첫 'module <name>;' 을 추출. 없으면 파일 이름 기반 fallback."""
    text = tb_file.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r"^\s*module\s+(\w+)\s*[;(]", text, re.MULTILINE)
    return m.group(1) if m else tb_file.stem


def run_verilator_sim(ip_dir: Path) -> CheckResult:
    """verilator 가 PATH 에 있으면 본 IP 의 TB 를 빌드/실행하고 결과 판정."""
    sim_dir = ip_dir / "sim"
    rtl_dir = ip_dir / "rtl"
    tb_files = list(sim_dir.glob("tb_*.sv"))
    rtl_files = list(rtl_dir.glob("*.sv"))
    if not tb_files or not rtl_files:
        return CheckResult("verilator_sim", True, "no TB or RTL — skipped")

    try:
        subprocess.run(["verilator", "--version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        return CheckResult("verilator_sim", True, "verilator not installed — skipped")

    top = _detect_top_module(tb_files[0])
    work = Path("/tmp") / f"ipflow_verilator_{ip_dir.name}"
    if work.exists():
        subprocess.run(["rm", "-rf", str(work)])
    work.mkdir(parents=True)

    cmd = [
        "verilator", "--binary", "-sv",
        "-Wno-DECLFILENAME", "-Wno-UNUSEDSIGNAL", "-Wno-INITIALDLY",
        "-Wno-MULTIDRIVEN", "-Wno-TIMESCALEMOD", "-Wno-UNUSEDPARAM",
        "--top-module", top, "--Mdir", str(work / "obj_dir"),
        "-o", "Vsim",
        "-j", "0",
    ] + [str(p) for p in rtl_files] + [str(p) for p in tb_files]

    build = subprocess.run(cmd, capture_output=True, text=True)
    if build.returncode != 0:
        return CheckResult("verilator_sim", False, f"build failed:\n{build.stderr[-500:]}")

    run = subprocess.run([str(work / "obj_dir" / "Vsim")], capture_output=True, text=True)
    out = run.stdout + run.stderr
    # PASS criteria: "ALL TESTS PASSED" present AND no "FAIL" lines
    passed = "ALL TESTS PASSED" in out and "[FAIL]" not in out
    if passed:
        n_pass = out.count("[ pass ]")
        return CheckResult("verilator_sim", True, f"{n_pass} TB checks PASS")
    n_fail = out.count("[FAIL]")
    return CheckResult(
        "verilator_sim", False,
        f"{n_fail} TB check(s) FAILED — see {work}/obj_dir/Vsim output",
    )


def cmd_sim(args) -> int:
    ip_dir = Path(args.ip).resolve()
    if not ip_dir.is_dir():
        print(f"no such directory: {ip_dir}", file=sys.stderr)
        return 2
    print(f"\n[ipflow sim] {ip_dir.relative_to(REPO_ROOT)}")
    res = run_verilator_sim(ip_dir)
    tag = "PASS" if res.passed else "FAIL"
    print(f"  [{tag}] {res.name:<24} — {res.detail}\n")
    return 0 if res.passed else 1


def cmd_run(args) -> int:
    ip_dir = Path(args.ip).resolve()
    if not ip_dir.is_dir():
        print(f"no such directory: {ip_dir}", file=sys.stderr)
        return 2
    print(f"\n[ipflow run] {ip_dir.relative_to(REPO_ROOT)}\n")

    # 1. render diagrams
    diagrams = ip_dir / "doc" / "diagrams"
    if diagrams.is_dir() and list(diagrams.glob("*.json")):
        print("• stage: diagrams")
        r = subprocess.run(
            ["bash", str(REPO_ROOT / "tools" / "render-diagrams.sh"), str(ip_dir)]
        )
        if r.returncode != 0:
            return r.returncode

    # 2. validate
    print("• stage: validate")
    rc = cmd_validate(argparse.Namespace(ip=str(ip_dir)))
    if rc != 0:
        return rc

    # 3. host HAL test
    sw_dir = ip_dir / "sw"
    if (sw_dir / "Makefile").exists():
        print("• stage: hal-host")
        r = subprocess.run(["make", "-C", str(sw_dir), "test"])
        if r.returncode != 0:
            return r.returncode
        subprocess.run(["make", "-C", str(sw_dir), "clean"], stdout=subprocess.DEVNULL)

    # 4. RTL simulation (verilator) — 환경에 없으면 skip
    if not getattr(args, "no_sim", False):
        print("• stage: verilator-sim")
        res = run_verilator_sim(ip_dir)
        tag = "PASS" if res.passed else "FAIL"
        print(f"  [{tag}] {res.name:<24} — {res.detail}")
        if not res.passed:
            return 1

    print("\n[ipflow run] all stages OK.\n")
    return 0


# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────

def main(argv=None):
    p = argparse.ArgumentParser(prog="ipflow", description="IP closed-loop workflow harness")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_status = sub.add_parser("status", help="show stage matrix for all IPs")
    p_status.add_argument("--json", action="store_true", help="emit JSON for web dashboard")
    p_status.set_defaults(func=cmd_status)

    p_val = sub.add_parser("validate", help="run closed-loop invariants on one IP")
    p_val.add_argument("ip", help="path to IP directory")
    p_val.set_defaults(func=cmd_validate)

    p_sc = sub.add_parser("scenarios", help="list scenarios for an IP")
    p_sc.add_argument("ip", help="path to IP directory")
    p_sc.set_defaults(func=cmd_scenarios)

    p_run = sub.add_parser("run", help="render diagrams + validate + host HAL test + RTL sim")
    p_run.add_argument("ip", help="path to IP directory")
    p_run.add_argument("--no-sim", action="store_true", help="verilator 단계 건너뛰기")
    p_run.set_defaults(func=cmd_run)

    p_sim = sub.add_parser("sim", help="run Verilator simulation on one IP's TB")
    p_sim.add_argument("ip", help="path to IP directory")
    p_sim.set_defaults(func=cmd_sim)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
