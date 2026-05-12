# ldpc_codec

LDPC encoder/decoder (ECC)

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
| `CODEWORD` | `4096` | `int` |
| `ITERATIONS` | `16` | `int` |

## Files
- `rtl/ldpc_codec.sv` — top module (stub)
- `sim/tb_ldpc_codec.sv` — smoke testbench
- `cfg/ldpc_codec.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
