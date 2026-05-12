# ddr4_phy

DDR4 PHY (write/read leveling stub)

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

## Files
- `rtl/ddr4_phy.sv` — top module (stub)
- `sim/tb_ddr4_phy.sv` — smoke testbench
- `cfg/ddr4_phy.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
