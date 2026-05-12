# axi_interconnect

SoC-level AXI interconnect (NoC stub)

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
| `NUM_MASTERS` | `8` | `int` |
| `NUM_SLAVES` | `12` | `int` |

## Files
- `rtl/axi_interconnect.sv` — top module (stub)
- `sim/tb_axi_interconnect.sv` — smoke testbench
- `cfg/axi_interconnect.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
