# irq_ctrl — Programmer's Guide

Target: firmware engineers integrating `irq_ctrl` (PLIC-style) on the
`cpu_ss` subsystem. v1.0.0.

This guide covers register usage scenarios, recommended initialization
sequence, ISR flow, edge vs level subtleties, and worked examples
matching the HAL in [`sw/`](../sw/).

---

## 1. Address map quick-reference

Base address is SoC-integration-defined. The HAL exposes it as
`IRQ_CTRL_BASE`. Offsets within the 4 KiB window:

| Offset      | Reg              | Access      | Notes                                          |
|-------------|------------------|-------------|------------------------------------------------|
| `0x000`     | `PRIORITY[0]`    | RO=0        | Reserved (source 0).                           |
| `0x004+4*i` | `PRIORITY[i]`    | RW (4 bits) | i=1..31. 0 disables source i by priority.      |
| `0x100`     | `PENDING`        | RO          | Bit i = source-i pending.                      |
| `0x104`     | `PENDING_CLEAR`  | W1C         | Edge sources only.                             |
| `0x200`     | `ENABLE`         | RW          | Bit i = source-i unmasked.                     |
| `0x300`     | `THRESHOLD`      | RW (4 bits) | Source fires iff `priority > threshold`.       |
| `0x304`     | `CLAIM_COMPLETE` | R: claim    | Read returns winning ID, clears pending(edge). |
|             |                  | W: complete | Write completion ack.                          |
| `0x308`     | `IP_ID`          | RO          | `0x49524301` ("IRC\\1").                       |
| `0x30C`     | `IP_VERSION`     | RO          | `0x00010000` for v1.0.0.                       |

---

## 2. Initialization sequence

The recommended bring-up order at boot. Each step is non-destructive of the
previous step's state.

```
 1. (optional) sanity-check IP_ID / IP_VERSION
 2. THRESHOLD ← 0xF             ; mask all interrupts during setup
 3. ENABLE    ← 0               ; per-source mask everything
 4. for each used source i:
       PRIORITY[i] ← desired_level (1..15)
 5. PENDING_CLEAR ← 0xFFFFFFFE  ; flush any stale edge pending bits
 6. ENABLE    ← bitmask of used sources
 7. THRESHOLD ← lowest priority you want to admit, minus 1
       (e.g. THRESHOLD=0 admits priorities 1..15)
 8. CPU side: clear local pending, enable global IRQs (mstatus.MIE / CPSR.I etc.)
```

Steps 2–3 ensure the CPU does not see a spurious `eip` rise during setup;
step 5 cleans stale edge pending that might be set if the source was
toggling while the block was held in reset.

Reference HAL routine: `irq_ctrl_init()` in
[`sw/irq_ctrl_hal.c`](../sw/irq_ctrl_hal.c).

---

## 3. Configuring a source

A source's "fires the CPU" predicate is:

```
   pending[i] AND enable[i] AND priority[i] > threshold
```

Therefore *all three* must be set. Two common mistakes:
- Setting `ENABLE` while leaving `PRIORITY[i]=0` → never fires.
- Raising `THRESHOLD` ≥ `PRIORITY[i]` to "temporarily disable" — works, but
  affects **all** sources at-or-below that priority, not just source i.
  Use the per-source `ENABLE` bit for per-source masking.

---

## 4. Edge vs level sources

The detection mode for each source is **compile-time**, set via the
`EDGE_MASK` parameter at instantiation. The HAL exposes it through
`irq_ctrl_is_edge(i)` so generic code can choose the right flow.

| Aspect                | Edge source                                        | Level source                                  |
|-----------------------|----------------------------------------------------|-----------------------------------------------|
| When pending sets     | Cycle after rising edge of `irq_src_i[i]`.         | Combinational track of `irq_src_i[i]`.        |
| How pending clears    | SW: read `CLAIM_COMPLETE` (atomic) **or** W1C.     | Source must deassert its line.                |
| ISR responsibility    | Service device; SW-clear is sufficient.            | Service device until it deasserts its IRQ.    |
| Lost-event risk       | Yes if two edges occur faster than ISR latency.    | None — line stays asserted.                   |

**ISR rule of thumb:** for edge sources, claim + service. For level
sources, claim + service the device's own status registers until the line
drops, *then* re-read PENDING to confirm.

---

## 5. ISR control flow

The standard PLIC handler in the CPU's machine-mode trap vector:

```c
void mext_irq_handler(void)
{
    uint32_t id = irq_ctrl_claim();          // read CLAIM_COMPLETE
    if (id == 0) return;                     // spurious

    g_isr_table[id]();                       // dispatch to per-source ISR

    irq_ctrl_complete(id);                   // write CLAIM_COMPLETE
}
```

Notes:
- The block re-evaluates eligibility every cycle, so as long as another
  source is pending, `eip_o` will stay high and the CPU will re-enter
  `mext_irq_handler` after `mret`. You do **not** need to loop inside the
  handler.
- For nested/priority-preemptive handling, raise `THRESHOLD` to the
  current source's priority before re-enabling global IRQs inside the
  ISR; restore at completion.

---

## 6. Worked examples

### 6.1 Enable a level-triggered UART RX interrupt (source 12, priority 5)

```c
irq_ctrl_set_priority(12, 5);
irq_ctrl_enable(12);
irq_ctrl_set_threshold(0);   // admit priorities ≥ 1
```

In the UART ISR, drain RX FIFO until empty — the line will deassert.
No SW pending-clear needed (level mode).

### 6.2 Enable an edge-triggered DMA done interrupt (source 4, priority 10)

```c
irq_ctrl_set_priority(4, 10);
irq_ctrl_clear_pending(4);   // flush any stale edge bit
irq_ctrl_enable(4);
```

In the DMA ISR, service the device. The `irq_ctrl_claim()` call already
cleared `PENDING[4]` atomically; no W1C needed.

### 6.3 Software-trigger a soft IRQ (debug)

This block has no dedicated software-trigger register, but you can W1C a
bit to nothing (a no-op) — to truly inject, hold a GPIO source high
through the `irq_src_i` aggregation harness for one cycle.

### 6.4 Disable all interrupts during a critical section

```c
uint32_t prev = irq_ctrl_get_threshold();
irq_ctrl_set_threshold(0xF);     // mask all 1..15 priorities
/* critical section */
irq_ctrl_set_threshold(prev);
```

Faster than touching `ENABLE`, and atomically restored.

---

## 7. Error responses

The block raises `pslverr` for:
- Read or write of an unmapped offset within the 4 KiB window.
- Write to any read-only register (`PENDING`, `IP_ID`, `IP_VERSION`).

Firmware should treat `pslverr` as a fatal misconfiguration — there is no
"retry" semantics defined. The HAL does not poll `pslverr`; the bus
fabric is expected to surface it as a load/store fault.

---

## 8. Common pitfalls

| Symptom                                  | Cause                                                              |
|------------------------------------------|--------------------------------------------------------------------|
| `eip` never rises.                       | `PRIORITY[i]=0`, or `THRESHOLD ≥ PRIORITY[i]`, or `ENABLE[i]=0`.   |
| `eip` keeps re-firing after ISR returns. | Level source: device line still asserted (ISR didn't service).    |
| `eip` re-fires occasionally on edge src. | Two close edges; second was captured during ISR.                  |
| `claim` returns 0 inside the ISR.        | Race between hardware re-arbitration and ISR entry; treat as OK.  |
| Spurious IRQ at boot.                    | Stale edge pending — call `irq_ctrl_clear_pending_all()` in init. |

---

## 9. Versioning

| HAL macro              | v1.0.0 value |
|------------------------|--------------|
| `IRQ_CTRL_ID_EXPECTED` | `0x49524301` |
| `IRQ_CTRL_VER_EXPECTED`| `0x00010000` |

`irq_ctrl_probe()` reads both and returns 0 on a match.
