# pcie_ctrl

PCIe controller MAC + DLL + TLP

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
| `MAX_PAYLOAD` | `256` | `int` |

## Files
- `rtl/pcie_ctrl.sv` — top module (stub)
- `sim/tb_pcie_ctrl.sv` — smoke testbench
- `cfg/pcie_ctrl.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
