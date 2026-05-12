# dcache

Data cache 64KB 8-way write-back

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/cpu-team`      |
| Subsystem  | `cpu_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `SIZE_KB` | `64` | `int` |
| `WAYS` | `8` | `int` |

## Files
- `rtl/dcache.sv` — top module (stub)
- `sim/tb_dcache.sv` — smoke testbench
- `cfg/dcache.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
