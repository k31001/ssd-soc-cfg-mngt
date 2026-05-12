# flash_dma

NAND-side DMA + buffer manager

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
| `BUF_KB` | `64` | `int` |

## Files
- `rtl/flash_dma.sv` — top module (stub)
- `sim/tb_flash_dma.sv` — smoke testbench
- `cfg/flash_dma.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
