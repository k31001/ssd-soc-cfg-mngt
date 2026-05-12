# riscv_core

RISC-V RV32IMC core (stub)

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
| `XLEN` | `32` | `int` |
| `MHARTID` | `0` | `int` |

## Files
- `rtl/riscv_core.sv` — top module (stub)
- `sim/tb_riscv_core.sv` — smoke testbench
- `cfg/riscv_core.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
