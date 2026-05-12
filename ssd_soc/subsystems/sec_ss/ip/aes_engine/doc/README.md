# aes_engine

AES-256 XTS engine (data path encryption)

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
| `KEY_W` | `256` | `int` |
| `MODE` | `XTS` | `str` |

## Files
- `rtl/aes_engine.sv` — top module (stub)
- `sim/tb_aes_engine.sv` — smoke testbench
- `cfg/aes_engine.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
