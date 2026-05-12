# trng

True Random Number Generator

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/security-team`      |
| Subsystem  | `sec_ss`  |
| Bus        | `apb`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `RATE_MBPS` | `100` | `int` |

## Files
- `rtl/trng.sv` — top module (stub)
- `sim/tb_trng.sv` — smoke testbench
- `cfg/trng.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
