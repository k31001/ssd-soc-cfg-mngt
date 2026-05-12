# sram_scratchpad

On-die SRAM scratchpad (cached buffers)

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
| `SIZE_KB` | `512` | `int` |
| `BANKS` | `4` | `int` |

## Files
- `rtl/sram_scratchpad.sv` — top module (stub)
- `sim/tb_sram_scratchpad.sv` — smoke testbench
- `cfg/sram_scratchpad.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
