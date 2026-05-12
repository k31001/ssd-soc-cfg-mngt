# irq_ctrl

PLIC 계열 platform-level interrupt controller (합성 가능, v1.0.0).

| 항목       | 값                     |
|-----------|------------------------|
| Owner     | `@ssd-soc/cpu-team`    |
| Subsystem | `cpu_ss`               |
| Bus       | `apb`                  |
| Status    | `alpha`                |
| Language  | SystemVerilog          |

## Parameters
| 이름        | 기본값  | 타입             | 설명                                          |
|-------------|--------|------------------|----------------------------------------------|
| `NUM_IRQ`   | `32`   | `int unsigned`   | source 개수 (예약된 source 0 포함).          |
| `PRIO_W`    | `4`    | `int unsigned`   | priority 필드 폭 (4 → 16 단계).              |
| `EDGE_MASK` | `'0`   | `[NUM_IRQ-1:0]`  | source별 edge(1)/level(0) 감지 모드.         |

## 산출물
- `rtl/irq_ctrl.sv` — 합성 가능 RTL (core + `apb_if` wrapper).
- `sim/tb_irq_ctrl.sv` — self-checking testbench, 11개 directed 시나리오.
- `doc/DESIGN.md` — 아키텍처, register map, datapath, 타이밍.
- `doc/PROGRAMMERS_GUIDE.md` — bring-up, ISR 흐름, 사용 예제.
- `doc/irq_ctrl.ipxact.xml` — IEEE 1685-2014 SFR 정의.
- `sw/irq_ctrl_hal.{h,c}` — SFR map과 정합하는 C HAL.
- `sw/test_hal_host.c` + `sw/Makefile` — 호스트 측 HAL smoke test
  (`cd sw && make test`).

## CI
- IP 레벨 workflow가 PR마다 실행 — lint / yaml-schema / unit sim / host HAL test.
- Tag bump 시 `tools/manifest-bump.py`가 메인라인 manifest PR을 자동 생성.
