# nand_ctrl

NAND command sequencer + timing engine

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/flash-team`      |
| Subsystem  | `fcc_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `CHANNELS` | `8` | `int` |
| `CE_PER_CH` | `4` | `int` |

## Files
- `rtl/nand_ctrl.sv` — top module (stub)
- `sim/tb_nand_ctrl.sv` — smoke testbench
- `cfg/nand_ctrl.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
