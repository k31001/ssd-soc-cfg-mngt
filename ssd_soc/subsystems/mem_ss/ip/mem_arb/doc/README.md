# mem_arb

Memory arbiter / QoS

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/mem-team`      |
| Subsystem  | `mem_ss`  |
| Bus        | `apb`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `PORTS` | `8` | `int` |

## Files
- `rtl/mem_arb.sv` — top module (stub)
- `sim/tb_mem_arb.sv` — smoke testbench
- `cfg/mem_arb.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
