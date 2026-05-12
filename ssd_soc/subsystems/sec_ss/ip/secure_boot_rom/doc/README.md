# secure_boot_rom

Secure boot ROM + verifier

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
| `ROM_KB` | `64` | `int` |

## Files
- `rtl/secure_boot_rom.sv` — top module (stub)
- `sim/tb_secure_boot_rom.sv` — smoke testbench
- `cfg/secure_boot_rom.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
