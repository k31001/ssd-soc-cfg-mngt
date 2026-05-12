# nvme_cmd_proc

NVMe command processor (SQ/CQ handler)

| Field      | Value          |
|------------|----------------|
| Owner      | `@ssd-soc/host-team`      |
| Subsystem  | `host_ss`  |
| Bus        | `axi`        |
| Status     | `proto`        |
| Language   | SystemVerilog  |

## Parameters
| Name | Default | Type |
|---|---|---|
| `NUM_QUEUES` | `64` | `int` |
| `QDEPTH` | `1024` | `int` |

## Files
- `rtl/nvme_cmd_proc.sv` — top module (stub)
- `sim/tb_nvme_cmd_proc.sv` — smoke testbench
- `cfg/nvme_cmd_proc.ip.yaml` — IP metadata (IPLM-lite)

## CI
- IP-level workflow runs on every PR — lint / yaml-schema / unit sim.
- Tag bumps trigger `tools/manifest-bump.py` to open a mainline manifest PR.
