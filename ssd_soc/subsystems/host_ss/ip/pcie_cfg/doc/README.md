# pcie_cfg

PCIe configuration space + capability registers

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/host-team`      |
| Subsystem  | `host_ss`  |
| Bus        | `apb`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `PCIE_GEN` | `4` | `int` |

## Files
- `rtl/pcie_cfg.sv` — top module (stub)
- `sim/tb_pcie_cfg.sv` — smoke testbench
- `cfg/pcie_cfg.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
