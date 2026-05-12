# irq_ctrl

PLIC-compatible interrupt controller

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/cpu-team`      |
| Subsystem  | `cpu_ss`  |
| Bus        | `apb`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `NUM_IRQ` | `128` | `int` |

## Files
- `rtl/irq_ctrl.sv` — top module (stub)
- `sim/tb_irq_ctrl.sv` — smoke testbench
- `cfg/irq_ctrl.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
