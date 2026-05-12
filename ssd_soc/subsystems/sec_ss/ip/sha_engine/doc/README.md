# sha_engine

SHA-2/3 hash engine

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/security-team`      |
| Subsystem  | `sec_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `WIDTHS` | `256_384_512` | `str` |

## Files
- `rtl/sha_engine.sv` — top module (stub)
- `sim/tb_sha_engine.sv` — smoke testbench
- `cfg/sha_engine.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
