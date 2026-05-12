#!/usr/bin/env python3
"""
scaffold_ssd_soc.py — 가상 SSD Controller SoC 프로젝트 스켈레톤 생성기.

Phase A 부트스트랩 도구. SoC 카탈로그(아래 SOC_CATALOG)를 입력으로 받아
- 각 IP의 rtl/sim/doc/cfg 디렉터리 및 stub Verilog
- 각 Subsystem의 통합 wrapper
- Top-level SoC 인스턴스 wrapper
- 공통 interface, BFM, package
- Filelist, Makefile, README
를 생성한다.

본 스크립트는 Phase D의 `tools/ipgen.py`/`topgen.py` 의 prototype 이기도 하다.
실제 운영 도구에서는 SOC_CATALOG 가 외부 manifest.yaml 로 분리된다.
"""
from __future__ import annotations

import os
import textwrap
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SSD_SOC = ROOT / "ssd_soc"


# ─────────────────────────────────────────────────────────────────────────────
# SoC Catalog — 25 IPs across 5 subsystems
# ─────────────────────────────────────────────────────────────────────────────
SOC_CATALOG: dict[str, Any] = {
    "top": "ssd_soc_top",
    "subsystems": {
        "host_ss": {
            "desc": "PCIe Gen4/NVMe host interface subsystem",
            "owner": "@ssd-soc/host-team",
            "ips": [
                {"name": "pcie_phy",      "desc": "PCIe Gen4 PHY (analog/digital stub)",
                 "params": {"LANES": 4, "GEN": 4}, "bus": "axi"},
                {"name": "pcie_ctrl",     "desc": "PCIe controller MAC + DLL + TLP",
                 "params": {"LANES": 4, "MAX_PAYLOAD": 256}, "bus": "axi"},
                {"name": "nvme_cmd_proc", "desc": "NVMe command processor (SQ/CQ handler)",
                 "params": {"NUM_QUEUES": 64, "QDEPTH": 1024}, "bus": "axi"},
                {"name": "host_dma",      "desc": "Host-side DMA engine (PRP/SGL)",
                 "params": {"CHANNELS": 8, "OUTSTANDING": 32}, "bus": "axi"},
                {"name": "pcie_cfg",      "desc": "PCIe configuration space + capability registers",
                 "params": {"PCIE_GEN": 4}, "bus": "apb"},
            ],
        },
        "fcc_ss": {
            "desc": "Flash Channel Controller subsystem (NAND interface)",
            "owner": "@ssd-soc/flash-team",
            "ips": [
                {"name": "nand_phy",      "desc": "ONFI/Toggle NAND PHY (DQS/DQ)",
                 "params": {"CHANNELS": 8, "DATA_W": 8}, "bus": "axi"},
                {"name": "nand_ctrl",     "desc": "NAND command sequencer + timing engine",
                 "params": {"CHANNELS": 8, "CE_PER_CH": 4}, "bus": "axi"},
                {"name": "ldpc_codec",    "desc": "LDPC encoder/decoder (ECC)",
                 "params": {"CODEWORD": 4096, "ITERATIONS": 16}, "bus": "axi"},
                {"name": "flash_dma",     "desc": "NAND-side DMA + buffer manager",
                 "params": {"CHANNELS": 8, "BUF_KB": 64}, "bus": "axi"},
                {"name": "bbm",           "desc": "Bad block manager / WL helper",
                 "params": {"BLOCKS": 4096}, "bus": "apb"},
            ],
        },
        "mem_ss": {
            "desc": "On-die memory and interconnect subsystem",
            "owner": "@ssd-soc/mem-team",
            "ips": [
                {"name": "ddr4_ctrl",       "desc": "DDR4 controller (command scheduler)",
                 "params": {"DATA_W": 64, "RANKS": 2}, "bus": "axi"},
                {"name": "ddr4_phy",        "desc": "DDR4 PHY (write/read leveling stub)",
                 "params": {"DATA_W": 64}, "bus": "axi"},
                {"name": "sram_scratchpad", "desc": "On-die SRAM scratchpad (cached buffers)",
                 "params": {"SIZE_KB": 512, "BANKS": 4}, "bus": "axi"},
                {"name": "axi_interconnect","desc": "SoC-level AXI interconnect (NoC stub)",
                 "params": {"NUM_MASTERS": 8, "NUM_SLAVES": 12}, "bus": "axi"},
                {"name": "mem_arb",         "desc": "Memory arbiter / QoS",
                 "params": {"PORTS": 8}, "bus": "apb"},
            ],
        },
        "cpu_ss": {
            "desc": "Embedded RISC-V CPU subsystem (FW execution)",
            "owner": "@ssd-soc/cpu-team",
            "ips": [
                {"name": "riscv_core",    "desc": "RISC-V RV32IMC core (stub)",
                 "params": {"XLEN": 32, "MHARTID": 0}, "bus": "axi"},
                {"name": "icache",        "desc": "Instruction cache 32KB 4-way",
                 "params": {"SIZE_KB": 32, "WAYS": 4}, "bus": "axi"},
                {"name": "dcache",        "desc": "Data cache 64KB 8-way write-back",
                 "params": {"SIZE_KB": 64, "WAYS": 8}, "bus": "axi"},
                {"name": "debug_module",  "desc": "RISC-V debug module (JTAG/DM)",
                 "params": {"HARTS": 1}, "bus": "apb"},
                {"name": "irq_ctrl",      "desc": "PLIC-compatible interrupt controller",
                 "params": {"NUM_IRQ": 128}, "bus": "apb"},
            ],
        },
        "sec_ss": {
            "desc": "Security subsystem (crypto + secure boot)",
            "owner": "@ssd-soc/security-team",
            "ips": [
                {"name": "aes_engine",      "desc": "AES-256 XTS engine (data path encryption)",
                 "params": {"KEY_W": 256, "MODE": "XTS"}, "bus": "axi"},
                {"name": "sha_engine",      "desc": "SHA-2/3 hash engine",
                 "params": {"WIDTHS": "256_384_512"}, "bus": "axi"},
                {"name": "trng",            "desc": "True Random Number Generator",
                 "params": {"RATE_MBPS": 100}, "bus": "apb"},
                {"name": "secure_boot_rom", "desc": "Secure boot ROM + verifier",
                 "params": {"ROM_KB": 64}, "bus": "axi"},
                {"name": "key_store",       "desc": "Hardware key store (OTP backed)",
                 "params": {"NUM_KEYS": 32, "KEY_W": 256}, "bus": "apb"},
            ],
        },
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# Templates
# ─────────────────────────────────────────────────────────────────────────────
IP_RTL_TPL = """// SPDX-License-Identifier: Apache-2.0
// IP: {name}
// {desc}
//
// NOTE: 본 파일은 형상관리 시스템 데모를 위한 STUB RTL입니다.
//       실제 합성 가능한 구현은 IP-owner 팀이 채워야 합니다.

`ifndef {guard}
`define {guard}

module {name} #(
{param_block}
) (
  input  logic        clk,
  input  logic        rst_n,
{bus_ports}{extra_ports}
);

  // ─────────── STUB BODY ───────────
  // synthesis translate_off
  initial begin
    $display("[STUB] %m instantiated{param_display}", {param_args});
  end
  // synthesis translate_on

{stub_assigns}
endmodule

`endif // {guard}
"""

IP_TB_TPL = """// SPDX-License-Identifier: Apache-2.0
// Testbench: tb_{name}
// Smoke test for {name} IP (instantiation + clock/reset only).

`timescale 1ns/1ps

module tb_{name};
  logic clk = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  initial begin
    #20 rst_n = 1;
    #100;
    $display("[tb_{name}] smoke OK");
    $finish;
  end

  // DUT instantiation goes here (interfaces stubbed).
endmodule
"""

IP_YAML_TPL = """# IP metadata — IPLM-lite schema v1
# 본 파일이 IP의 single source of truth. CODEOWNERS, manifest, CI가 모두 참조.
name: {name}
version: 0.1.0           # semver. CI가 PR마다 bump 여부 확인
status: proto            # proto | alpha | qual | gold
owner: {owner}
subsystem: {subsystem}
description: |
  {desc}
bus: {bus}               # axi | apb | ahb
parameters:
{params_yaml}
dependencies:
  - common-libs >= 1.0.0
license: Apache-2.0
language: SystemVerilog
qual:
  lint: pending
  cdc: pending
  coverage: pending
  qual_report: null
files:
  rtl:
    - rtl/{name}.sv
  sim:
    - sim/tb_{name}.sv
"""

IP_README_TPL = """# {name}

{desc}

| Field      | Value          |
|------------|----------------|
| Owner      | `{owner}`      |
| Subsystem  | `{subsystem}`  |
| Bus        | `{bus}`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
{params_md}

## Files
- `rtl/{name}.sv` — top module (stub)
- `sim/tb_{name}.sv` — smoke testbench
- `cfg/{name}.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
"""

SS_RTL_TPL = """// SPDX-License-Identifier: Apache-2.0
// Subsystem: {ss_name}
// {desc}
//
// 본 wrapper는 소속 IP들을 단순 인스턴스화한 STUB 입니다.

`include "ssd_soc_pkg.svh"

module {ss_name} (
  input  logic clk,
  input  logic rst_n,
  axi_if.slave s_axi,
  apb_if.slave s_apb
);
  // synthesis translate_off
  initial $display("[STUB] subsystem %m instantiated");
  // synthesis translate_on

{ip_instances}
endmodule
"""

SS_YAML_TPL = """# Subsystem metadata
name: {ss_name}
owner: {owner}
description: |
  {desc}
ips:
{ip_list_yaml}
integration:
  bus: axi
  clocks: [clk]
  resets:  [rst_n]
"""

TOP_RTL_TPL = """// SPDX-License-Identifier: Apache-2.0
// Top: ssd_soc_top
// Virtual SSD Controller SoC — Top-level integration (STUB).

`include "ssd_soc_pkg.svh"

module ssd_soc_top (
  input  logic        clk,
  input  logic        rst_n,
  // External pads (stubbed)
  output logic [3:0]  pcie_tx_p, pcie_tx_n,
  input  logic [3:0]  pcie_rx_p, pcie_rx_n,
  inout  wire  [63:0] ddr_dq,
  output logic [7:0]  nand_ce_n,
  inout  wire  [7:0]  nand_dq
);

  // SoC interconnect (placeholder)
  axi_if #(.ADDR_W(40), .DATA_W(64)) sys_axi();
  apb_if #(.ADDR_W(32), .DATA_W(32)) sys_apb();

  // synthesis translate_off
  initial $display("[STUB] ssd_soc_top instantiated");
  // synthesis translate_on

{ss_instances}

  // Tie-offs for pads
  assign pcie_tx_p = '0;
  assign pcie_tx_n = '0;
  assign nand_ce_n = '1;

endmodule
"""

TOP_YAML_TPL = """# Top SoC metadata (declarative — OpenTitan 스타일 참고)
name: ssd_soc_top
version: 0.1.0
derivatives:
  - sku: gen4-1tb
    nand_channels: 8
    pcie_gen: 4
    dram: ddr4-4gb
  - sku: gen5-4tb
    nand_channels: 16
    pcie_gen: 5
    dram: ddr4-16gb
subsystems:
{ss_list_yaml}
"""

PKG_SV = """// SPDX-License-Identifier: Apache-2.0
// ssd_soc_pkg — SoC-wide type definitions.

`ifndef SSD_SOC_PKG_SVH
`define SSD_SOC_PKG_SVH

package ssd_soc_pkg;
  // Generic widths
  parameter int AXI_ADDR_W = 40;
  parameter int AXI_DATA_W = 64;
  parameter int APB_ADDR_W = 32;
  parameter int APB_DATA_W = 32;

  typedef enum logic [1:0] {
    LINK_DOWN = 2'b00,
    LINK_INIT = 2'b01,
    LINK_UP   = 2'b10,
    LINK_ERR  = 2'b11
  } link_state_e;
endpackage

// Bring interfaces into scope for `include consumers.
`include "axi_if.sv"
`include "apb_if.sv"

`endif // SSD_SOC_PKG_SVH
"""

AXI_IF_SV = """// SPDX-License-Identifier: Apache-2.0
// AXI4-lite-ish interface (stub for compile only).

interface axi_if #(
  parameter int ADDR_W = 40,
  parameter int DATA_W = 64
) (input logic clk = 0, input logic rst_n = 1);
  logic [ADDR_W-1:0] awaddr, araddr;
  logic [DATA_W-1:0] wdata,  rdata;
  logic              awvalid, awready;
  logic              wvalid,  wready;
  logic              arvalid, arready;
  logic              rvalid,  rready;
  logic              bvalid,  bready;

  modport master (input  awready, wready, arready, rdata, rvalid, bvalid,
                  output awaddr, araddr, wdata, awvalid, wvalid, arvalid, rready, bready);
  modport slave  (output awready, wready, arready, rdata, rvalid, bvalid,
                  input  awaddr, araddr, wdata, awvalid, wvalid, arvalid, rready, bready);
endinterface
"""

APB_IF_SV = """// SPDX-License-Identifier: Apache-2.0
// APB-ish interface (stub).

interface apb_if #(
  parameter int ADDR_W = 32,
  parameter int DATA_W = 32
) (input logic clk = 0, input logic rst_n = 1);
  logic [ADDR_W-1:0] paddr;
  logic              psel;
  logic              penable;
  logic              pwrite;
  logic [DATA_W-1:0] pwdata, prdata;
  logic              pready;
  logic              pslverr;

  modport master (input  prdata, pready, pslverr,
                  output paddr, psel, penable, pwrite, pwdata);
  modport slave  (output prdata, pready, pslverr,
                  input  paddr, psel, penable, pwrite, pwdata);
endinterface
"""

AXI_BFM_SV = """// SPDX-License-Identifier: Apache-2.0
// Minimal AXI BFM stub for smoke tests.
module axi_bfm_stub (axi_if.master m);
  initial begin
    m.awvalid = 0; m.wvalid = 0; m.arvalid = 0;
    m.rready  = 1; m.bready = 1;
  end
endmodule
"""

APB_BFM_SV = """// SPDX-License-Identifier: Apache-2.0
// Minimal APB BFM stub for smoke tests.
module apb_bfm_stub (apb_if.master m);
  initial begin
    m.psel    = 0; m.penable = 0; m.pwrite = 0;
    m.paddr   = '0; m.pwdata = '0;
  end
endmodule
"""

WAIVERS_YAML = """# Lint waivers (project-wide)
# 각 IP는 자기 cfg/ 하위에 별도 waivers/ 가 가능. 본 파일은 SoC-wide 공통 waiver.
waivers:
  - rule: VARIABLE_UNUSED
    scope: "**/stub*.sv"
    reason: "Stub RTL 의도적 미사용 신호 허용 (Phase A 데모)"
  - rule: UNDRIVEN_NET
    scope: "ssd_soc/top/**"
    reason: "Top-level pads 일부는 stub 상태에서 미구동"
"""

ROOT_README = """# SSD Controller SoC 형상관리 시스템 (Reference Implementation)

본 저장소는 100명+ 규모 RTL 개발자가 협업하는 SSD Controller SoC 프로젝트의
**형상관리(Source Configuration Management) 레퍼런스 구현**입니다.

## 구성

| 디렉터리 | 내용 |
|---|---|
| `ssd_soc/`       | 가상 SoC 스켈레톤 (top + 5 subsystems + 25 IPs) |
| `cm-strategies/` | 4가지 형상관리 방식 비교 데모 (monorepo / submodule / repo-manifest / subtree) |
| `recommended/`   | 추천 하이브리드 구성 (`repo` manifest + IP 분리 + IPLM-lite) |
| `ci/`            | 계층별 GitHub Actions workflows (IP / Subsystem / Top) |
| `tools/`         | 자동화 스크립트 (ipgen / topgen / bom / manifest-bump / release) |
| `docs/`          | 4종 문서 (설계서 / 구축 가이드 / 관리자 / 개발자 가이드) |

## 빠른 시작
```bash
make sim TOP=ssd_soc_top      # Verilator smoke build (stub)
make lint                     # Verible lint
python3 tools/bom.py          # 현재 manifest 의 BOM 출력
```

## 문서
- [01. 시스템 설계서](docs/01-design.md)
- [02. 구축 가이드](docs/02-build-guide.md)
- [03. 관리자 가이드](docs/03-admin-guide.md)
- [04. 개발자 가이드](docs/04-developer-guide.md)
"""

MAKEFILE = """# SSD SoC 데모 Makefile (Verilator/Icarus 기반)
TOP ?= ssd_soc_top
VERILATOR ?= verilator
ICARUS    ?= iverilog
VERIBLE   ?= verible-verilog-lint

FILELIST := ssd_soc/scripts/compile.f
BUILD    := build

.PHONY: sim lint clean elab

elab:
	$(VERILATOR) --lint-only -Wall -Wno-fatal -f $(FILELIST) --top-module $(TOP)

sim:
	mkdir -p $(BUILD)
	$(VERILATOR) --binary -Wno-fatal -f $(FILELIST) --top-module $(TOP) -Mdir $(BUILD)/obj_dir
	$(BUILD)/obj_dir/V$(TOP) || true

lint:
	@find ssd_soc -name '*.sv' -print0 | xargs -0 $(VERIBLE) --rules=-line-length || true

clean:
	rm -rf $(BUILD)
"""

GITIGNORE = """build/
*.vcd
*.fst
*.log
obj_dir/
__pycache__/
*.pyc
.DS_Store
"""

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
def w(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def render_params(params: dict) -> str:
    if not params:
        return "  parameter int UNUSED = 0"
    lines = []
    for k, v in params.items():
        if isinstance(v, int):
            lines.append(f"  parameter int {k} = {v}")
        else:
            lines.append(f'  parameter         {k} = "{v}"')
    return ",\n".join(lines)


def render_params_yaml(params: dict) -> str:
    if not params:
        return "  {}"
    return "\n".join(f"  {k}: {v!r}" for k, v in params.items())


def render_params_md(params: dict) -> str:
    if not params:
        return "_없음_"
    rows = ["| Name | Default | Type |", "|---|---|---|"]
    for k, v in params.items():
        rows.append(f"| `{k}` | `{v}` | `{type(v).__name__}` |")
    return "\n".join(rows)


def render_bus_ports(bus: str) -> str:
    # Note: no trailing comma — extra_ports (currently empty) sits after this,
    # and the closing `);` is on the next line in the template.
    return {
        "axi": "  axi_if.slave        s_axi",
        "apb": "  apb_if.slave        s_apb",
        "ahb": "  // ahb interface (not modeled)",
    }.get(bus, "")


# ─────────────────────────────────────────────────────────────────────────────
# Generators
# ─────────────────────────────────────────────────────────────────────────────
def gen_ip(ss_name: str, ss_meta: dict, ip: dict) -> None:
    name   = ip["name"]
    desc   = ip["desc"]
    bus    = ip["bus"]
    owner  = ss_meta["owner"]
    params = ip.get("params", {})

    ip_dir = SSD_SOC / "subsystems" / ss_name / "ip" / name
    param_block   = render_params(params)
    bus_ports     = render_bus_ports(bus)
    param_display = "".join(f", {k}=%0d" for k in params if isinstance(params[k], int))
    param_args    = ", ".join(k for k, v in params.items() if isinstance(v, int)) or "0"
    extra_ports   = ""
    # Tie-off any logic outputs to avoid undriven warnings (stub).
    stub_assigns  = "  // Stub tie-offs intentionally omitted (interfaces only).\n"

    guard = name.upper() + "_SV"

    rtl = IP_RTL_TPL.format(
        name=name, desc=desc, guard=guard,
        param_block=param_block, bus_ports=bus_ports, extra_ports=extra_ports,
        param_display=param_display, param_args=param_args,
        stub_assigns=stub_assigns,
    )
    tb = IP_TB_TPL.format(name=name)
    yml = IP_YAML_TPL.format(
        name=name, owner=owner, subsystem=ss_name, desc=desc, bus=bus,
        params_yaml=render_params_yaml(params),
    )
    rdme = IP_README_TPL.format(
        name=name, desc=desc, owner=owner, subsystem=ss_name, bus=bus,
        params_md=render_params_md(params),
    )

    w(ip_dir / "rtl" / f"{name}.sv", rtl)
    w(ip_dir / "sim" / f"tb_{name}.sv", tb)
    w(ip_dir / "cfg" / f"{name}.ip.yaml", yml)
    w(ip_dir / "doc" / "README.md", rdme)


def gen_subsystem(ss_name: str, ss_meta: dict) -> None:
    ss_dir = SSD_SOC / "subsystems" / ss_name
    # Instantiate all IPs as stubs.
    insts = []
    for ip in ss_meta["ips"]:
        insts.append(f"  // ── {ip['name']} ──")
        bus_conn = ".s_axi(s_axi)" if ip["bus"] == "axi" else ".s_apb(s_apb)"
        insts.append(f"  {ip['name']} u_{ip['name']} (.clk(clk), .rst_n(rst_n), {bus_conn});")
    ip_instances = "\n".join(insts)

    rtl = SS_RTL_TPL.format(ss_name=ss_name, desc=ss_meta["desc"], ip_instances=ip_instances)
    yml = SS_YAML_TPL.format(
        ss_name=ss_name, owner=ss_meta["owner"], desc=ss_meta["desc"],
        ip_list_yaml="\n".join(f"  - {ip['name']}" for ip in ss_meta["ips"]),
    )

    w(ss_dir / "rtl" / f"{ss_name}.sv", rtl)
    w(ss_dir / "cfg" / f"{ss_name}.ss.yaml", yml)
    w(ss_dir / "doc" / "README.md",
      f"# {ss_name}\n\n{ss_meta['desc']}\n\nOwner: `{ss_meta['owner']}`\n\n"
      f"## Member IPs\n" + "\n".join(f"- [{ip['name']}](../ip/{ip['name']}/doc/README.md)" for ip in ss_meta["ips"]))

    # SS-level testbench
    w(ss_dir / "sim" / f"tb_{ss_name}.sv",
      f"`timescale 1ns/1ps\nmodule tb_{ss_name};\n  logic clk=0, rst_n=0;\n  always #5 clk=~clk;\n"
      f"  initial begin #20 rst_n=1; #200 $display(\"[tb_{ss_name}] smoke OK\"); $finish; end\nendmodule\n")


def gen_top() -> None:
    top_dir = SSD_SOC / "top"
    ss_insts = []
    for ss_name in SOC_CATALOG["subsystems"]:
        ss_insts.append(f"  {ss_name} u_{ss_name} (.clk(clk), .rst_n(rst_n), .s_axi(sys_axi), .s_apb(sys_apb));")
    ss_instances = "\n".join(ss_insts)

    rtl = TOP_RTL_TPL.format(ss_instances=ss_instances)
    yml = TOP_YAML_TPL.format(
        ss_list_yaml="\n".join(f"  - {n}" for n in SOC_CATALOG["subsystems"]),
    )

    w(top_dir / "rtl" / "ssd_soc_top.sv", rtl)
    w(top_dir / "cfg" / "top.yaml", yml)
    w(top_dir / "doc" / "README.md",
      "# ssd_soc_top\n\n가상 SSD Controller SoC Top-level wrapper.\n\n"
      "## Subsystems\n" + "\n".join(f"- {n}: {m['desc']}" for n, m in SOC_CATALOG["subsystems"].items()))

    w(top_dir / "sim" / "tb_ssd_soc.sv",
      "`timescale 1ns/1ps\nmodule tb_ssd_soc;\n  logic clk=0, rst_n=0;\n  always #5 clk=~clk;\n"
      "  initial begin #20 rst_n=1; #500 $display(\"[tb_ssd_soc] SoC smoke OK\"); $finish; end\n"
      "  ssd_soc_top dut(.clk(clk), .rst_n(rst_n), .pcie_tx_p(), .pcie_tx_n(), .pcie_rx_p('0), .pcie_rx_n('0),\n"
      "                  .ddr_dq(), .nand_ce_n(), .nand_dq());\nendmodule\n")


def gen_common() -> None:
    c = SSD_SOC / "common"
    w(c / "pkg" / "ssd_soc_pkg.svh", PKG_SV)
    w(c / "interfaces" / "axi_if.sv", AXI_IF_SV)
    w(c / "interfaces" / "apb_if.sv", APB_IF_SV)
    w(c / "bfm" / "axi_bfm_stub.sv", AXI_BFM_SV)
    w(c / "bfm" / "apb_bfm_stub.sv", APB_BFM_SV)
    w(c / "waivers" / "lint_waivers.yaml", WAIVERS_YAML)
    w(c / "README.md",
      "# common\n\nSoC-wide 공통 자산.\n- `interfaces/` — AXI/APB SV interface\n- `bfm/` — 시뮬레이션 BFM stub\n- `pkg/` — 공통 package\n- `waivers/` — lint waiver\n")


def gen_scripts_and_filelist() -> None:
    # Compile filelist (Verilator)
    files = ["+incdir+ssd_soc/common/pkg", "+incdir+ssd_soc/common/interfaces",
             "ssd_soc/common/interfaces/axi_if.sv", "ssd_soc/common/interfaces/apb_if.sv",
             "ssd_soc/common/pkg/ssd_soc_pkg.svh"]
    for ss_name, ss_meta in SOC_CATALOG["subsystems"].items():
        for ip in ss_meta["ips"]:
            files.append(f"ssd_soc/subsystems/{ss_name}/ip/{ip['name']}/rtl/{ip['name']}.sv")
        files.append(f"ssd_soc/subsystems/{ss_name}/rtl/{ss_name}.sv")
    files.append("ssd_soc/top/rtl/ssd_soc_top.sv")

    w(SSD_SOC / "scripts" / "compile.f", "\n".join(files) + "\n")
    w(ROOT / "Makefile", MAKEFILE)
    w(ROOT / ".gitignore", GITIGNORE)
    w(ROOT / "README.md", ROOT_README)

    # Verif framework stubs
    w(SSD_SOC / "verif" / "env" / "ssd_env_pkg.sv",
      "// Stub UVM env scaffolding (실제 UVM 사용 시 채움)\npackage ssd_env_pkg;\nendpackage\n")
    w(SSD_SOC / "verif" / "tests" / "smoke_test.sv",
      "// Smoke test placeholder\nmodule smoke_test; initial $display(\"smoke\"); endmodule\n")
    w(SSD_SOC / "verif" / "scripts" / "run.sh",
      "#!/usr/bin/env bash\nset -e\nmake -C \"$(dirname \"$0\")/../../..\" elab\n")


# ─────────────────────────────────────────────────────────────────────────────
def main() -> None:
    print("[scaffold] generating ssd_soc skeleton...")
    gen_common()
    for ss_name, ss_meta in SOC_CATALOG["subsystems"].items():
        gen_subsystem(ss_name, ss_meta)
        for ip in ss_meta["ips"]:
            gen_ip(ss_name, ss_meta, ip)
    gen_top()
    gen_scripts_and_filelist()

    # Stats
    n_ips = sum(len(m["ips"]) for m in SOC_CATALOG["subsystems"].values())
    print(f"[scaffold] done. subsystems={len(SOC_CATALOG['subsystems'])}, ips={n_ips}")


if __name__ == "__main__":
    main()
