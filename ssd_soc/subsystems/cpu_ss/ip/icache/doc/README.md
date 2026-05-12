# icache

Instruction cache 32KB 4-way

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
| `SIZE_KB` | `32` | `int` |
| `WAYS` | `4` | `int` |

## Files
- `rtl/icache.sv` — top module (stub)
- `sim/tb_icache.sv` — smoke testbench
- `cfg/icache.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
