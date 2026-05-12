# pcie_phy

PCIe Gen4 PHY (analog/digital stub)

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/host-team`      |
| Subsystem  | `host_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `LANES` | `4` | `int` |
| `GEN` | `4` | `int` |

## Files
- `rtl/pcie_phy.sv` — top module (stub)
- `sim/tb_pcie_phy.sv` — smoke testbench
- `cfg/pcie_phy.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
