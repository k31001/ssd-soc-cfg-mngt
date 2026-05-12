# debug_module

RISC-V debug module (JTAG/DM)

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/cpu-team`      |
| Subsystem  | `cpu_ss`  |
| Bus        | `apb`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `HARTS` | `1` | `int` |

## Files
- `rtl/debug_module.sv` — top module (stub)
- `sim/tb_debug_module.sv` — smoke testbench
- `cfg/debug_module.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
