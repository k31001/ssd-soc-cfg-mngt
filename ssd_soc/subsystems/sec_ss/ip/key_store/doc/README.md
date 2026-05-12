# key_store

Hardware key store (OTP backed)

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
| `NUM_KEYS` | `32` | `int` |
| `KEY_W` | `256` | `int` |

## Files
- `rtl/key_store.sv` — top module (stub)
- `sim/tb_key_store.sv` — smoke testbench
- `cfg/key_store.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
