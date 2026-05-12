# ddr4_ctrl

DDR4 controller (command scheduler)

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/mem-team`      |
| Subsystem  | `mem_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `DATA_W` | `64` | `int` |
| `RANKS` | `2` | `int` |

## Files
- `rtl/ddr4_ctrl.sv` — top module (stub)
- `sim/tb_ddr4_ctrl.sv` — smoke testbench
- `cfg/ddr4_ctrl.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
