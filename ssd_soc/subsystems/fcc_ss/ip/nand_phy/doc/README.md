# nand_phy

ONFI/Toggle NAND PHY (DQS/DQ)

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
| `DATA_W` | `8` | `int` |

## Files
- `rtl/nand_phy.sv` — top module (stub)
- `sim/tb_nand_phy.sv` — smoke testbench
- `cfg/nand_phy.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
