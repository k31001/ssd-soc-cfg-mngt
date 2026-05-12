# bbm

Bad block manager / WL helper

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/flash-team`      |
| Subsystem  | `fcc_ss`  |
| Bus        | `apb`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `BLOCKS` | `4096` | `int` |

## Files
- `rtl/bbm.sv` — top module (stub)
- `sim/tb_bbm.sv` — smoke testbench
- `cfg/bbm.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
