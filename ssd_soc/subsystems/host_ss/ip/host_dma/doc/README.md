# host_dma

Host-side DMA engine (PRP/SGL)

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/host-team`      |
| Subsystem  | `host_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `CHANNELS` | `8` | `int` |
| `OUTSTANDING` | `32` | `int` |

## Files
- `rtl/host_dma.sv` — top module (stub)
- `sim/tb_host_dma.sv` — smoke testbench
- `cfg/host_dma.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
