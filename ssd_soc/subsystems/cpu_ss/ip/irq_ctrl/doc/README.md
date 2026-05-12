# irq_ctrl

PLIC-style platform-level interrupt controller (synthesizable, v1.0.0).

| Field      | Value                  |
|------------|------------------------|
| Owner      | `@ssd-soc/cpu-team`    |
| Subsystem  | `cpu_ss`               |
| Bus        | `apb`                  |
| Status     | `alpha`                |
| Language   | SystemVerilog          |

## Parameters
| Name        | Default | Type             | Description                                  |
|-------------|---------|------------------|----------------------------------------------|
| `NUM_IRQ`   | `32`    | `int unsigned`   | Source count (incl. reserved source 0).      |
| `PRIO_W`    | `4`     | `int unsigned`   | Priority field width (4 → 16 levels).        |
| `EDGE_MASK` | `'0`    | `[NUM_IRQ-1:0]`  | Per-source edge(1)/level(0) detect mask.     |

## Deliverables
- `rtl/irq_ctrl.sv` — synthesizable RTL (core + `apb_if` wrapper).
- `sim/tb_irq_ctrl.sv` — self-checking testbench, 11 directed scenarios.
- `doc/DESIGN.md` — architecture, regmap, datapath, timing.
- `doc/PROGRAMMERS_GUIDE.md` — bring-up, ISR flow, worked examples.
- `doc/irq_ctrl.ipxact.xml` — IEEE 1685-2014 SFR description.
- `sw/irq_ctrl_hal.{h,c}` — C HAL matching the SFR map.
- `sw/test_hal_host.c` + `sw/Makefile` — host-side HAL smoke test
  (`cd sw && make test`).

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim / host HAL test.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
