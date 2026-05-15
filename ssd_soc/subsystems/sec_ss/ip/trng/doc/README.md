# trng

True Random Number Generator (합성 가능, v1.0.0). entropy source emulator
(3-LFSR XOR) + repetition health test + 16-entry FIFO + APB SFR +
edge-latched interrupt.

| 항목      | 값                          |
|----------|----------------------------|
| Owner    | `@ssd-soc/security-team`   |
| Subsystem| `sec_ss`                   |
| Bus      | `apb`                      |
| Status   | `alpha`                    |
| Language | SystemVerilog              |

## Parameters
| Name         | Default | Type | 설명                              |
|--------------|---------|------|----------------------------------|
| `FIFO_DEPTH` | `16`    | int  | Output FIFO 길이 (RTL localparam) |

## 산출물
- `rtl/trng.sv` — 합성 가능 RTL (core + `apb_if` wrapper).
- `sim/tb_trng.sv` — self-checking testbench, 10개 directed scenario 그룹.
  Verilator 5.048 로 23/23 PASS.
- `doc/DESIGN.md` — 아키텍처, register map, datapath, 타이밍.
- `doc/PROGRAMMERS_GUIDE.md` — bring-up, ISR flow, worked examples.
- `doc/trng.ipxact.xml` — IEEE 1685-2014 SFR 정의.
- `doc/diagrams/*.json` + `*.svg` — WaveDrom source 와 렌더 산출물.
- `sw/trng_hal.{h,c}` — IP-XACT 와 정합하는 C HAL.
- `sw/test_hal_host.c` + `sw/Makefile` — host-side smoke test (17/17 PASS).
- `verif/scenarios.yaml` — closed-loop verification manifest.

## CI
- IP-level workflow 가 PR 마다 실행 — lint / yaml-schema / unit sim / host HAL.
- Tag bump 시 `tools/manifest-bump.py` 가 메인라인 manifest PR 생성.
