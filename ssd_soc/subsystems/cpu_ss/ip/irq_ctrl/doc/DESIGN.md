# irq_ctrl — Design Document

| Field         | Value                                |
|---------------|--------------------------------------|
| IP            | `irq_ctrl` (PLIC-style)              |
| Version       | 1.0.0                                |
| Subsystem     | `cpu_ss`                             |
| Bus           | APB (32-bit data, 12-bit local addr) |
| Source files  | `rtl/irq_ctrl.sv`                    |
| Language      | SystemVerilog (synthesizable subset) |
| License       | Apache-2.0                           |

This document analyzes the RTL implementation in [`rtl/irq_ctrl.sv`](../rtl/irq_ctrl.sv).

---

## 1. Overview

`irq_ctrl` is a Platform-Level Interrupt Controller (PLIC) that aggregates up
to `NUM_IRQ-1` external interrupt sources into a single CPU-facing external
interrupt pending signal (`eip_o`). Source 0 is reserved (matches PLIC
convention — used as the "no interrupt" sentinel returned by claim).

Per source, software can configure:
- **priority** (4-bit, 0..15; 0 disables the source by priority)
- **enable** (single bit; per-source mask)
- **detection mode** (edge or level — compile-time `EDGE_MASK`)

Globally:
- **threshold** (4-bit; a source fires only when `priority > threshold`)
- **claim/complete** atomic handshake for ISR entry/exit

The block targets a single hart, single context. Multi-hart support is left
as a future extension (see §8).

---

## 2. Top-level interface

```
            ┌──────────────────────────────────────┐
            │              irq_ctrl                │
  APB ──────┤ paddr/psel/penable/pwrite/pwdata     │
            │ → prdata/pready/pslverr              │
            │                                      │
 irq_src ───┤ irq_src_i[NUM_IRQ-1:0]               │
            │                                      │
            │                       eip_o ───►     │ to CPU mip.MEIP
            │                    eip_id_o ───►     │ informational
            └──────────────────────────────────────┘
```

| Port            | Dir | Width        | Description                                           |
|-----------------|-----|--------------|-------------------------------------------------------|
| `clk`           | in  | 1            | Primary clock; all logic in this domain.              |
| `rst_n`         | in  | 1            | Async active-low reset; sync deassert recommended.    |
| `paddr`         | in  | 12           | APB byte address (word-aligned).                      |
| `psel`/`penable`| in  | 1/1          | Standard APB select / enable.                         |
| `pwrite`        | in  | 1            | 1 = write, 0 = read.                                  |
| `pwdata`        | in  | 32           | Write data.                                           |
| `prdata`        | out | 32           | Read data (0 outside read access).                    |
| `pready`        | out | 1            | High during ACCESS phase (no wait-state).             |
| `pslverr`       | out | 1            | High on unmapped addr or RO write during ACCESS.      |
| `irq_src_i`     | in  | `NUM_IRQ`    | External sources; `[0]` ignored.                      |
| `eip_o`         | out | 1            | External interrupt pending to CPU.                    |
| `eip_id_o`      | out | `clog2(N)`   | Current winning source (informational).               |

A thin wrapper `irq_ctrl_apbif` connects the project-wide `apb_if.slave`
interface to the flat-port core.

---

## 3. Parameters

| Parameter   | Default | Range/Type             | Effect                                       |
|-------------|---------|------------------------|----------------------------------------------|
| `NUM_IRQ`   | 32      | int (incl. reserved 0) | Number of sources (1 to 32 recommended).     |
| `PRIO_W`    | 4       | int                    | Priority width; 4 → 16 levels.               |
| `EDGE_MASK` | `'0`    | `[NUM_IRQ-1:0]`        | Per-source detection mode (1=edge, 0=level). |

The current sizing of pending/enable as single 32-bit APB words restricts
`NUM_IRQ ≤ 32`. Wider configurations would require a strided register array
(out of scope for v1.0).

---

## 4. Block diagram

```
                       ┌──────────────────────────────┐
  irq_src_i[31:1] ──►──┤ Detect (edge/level)          ├──► pending_q[31:1]
                       │   • EDGE_MASK[i]=1 → rising  │
                       │   • EDGE_MASK[i]=0 → level   │
                       └──────────────┬───────────────┘
                                      │
                ┌─────────────────────▼──────────────────────┐
                │              Eligibility AND               │
                │  eligible[i] = pending & enable &          │
                │                (priority[i] > threshold)   │
                └─────────────────────┬──────────────────────┘
                                      │
                ┌─────────────────────▼──────────────────────┐
                │         Priority winner (combinational)    │
                │  highest priority; tie → lowest ID         │
                └────────────┬──────────────────┬────────────┘
                             │                  │
                       best_id (eip_id_o)   best_prio
                             │
                       (best_id != 0) ──► eip_o

           APB regfile ──► priority[31:0], enable, threshold
           APB read mux ──► prdata
           Claim read    ──► clear pending_q[best_id] (edge only)
           Pending W1C   ──► clear pending_q bits (edge only)
```

---

## 5. Register map

All offsets are byte addresses; access is 32-bit word, word-aligned.

| Offset  | Name              | Access      | Reset       | Description                                                    |
|---------|-------------------|-------------|-------------|----------------------------------------------------------------|
| `0x000` | `PRIORITY[0]`     | RO          | 0           | Reserved — pinned to 0.                                        |
| `0x004` | `PRIORITY[1]`     | RW          | 0           | Source-1 priority (`PRIO_W` LSBs).                             |
| …       | …                 | RW          | 0           | …                                                              |
| `0x07C` | `PRIORITY[31]`    | RW          | 0           | Source-31 priority.                                            |
| `0x100` | `PENDING`         | RO          | 0           | Bit i = source-i pending.                                      |
| `0x104` | `PENDING_CLEAR`   | W1C         | 0           | Write 1 to clear bit (edge sources only).                      |
| `0x200` | `ENABLE`          | RW          | 0           | Bit i = source-i unmasked; bit 0 always reads 0.               |
| `0x300` | `THRESHOLD`       | RW          | 0           | Global priority threshold.                                     |
| `0x304` | `CLAIM_COMPLETE`  | R: claim    | n/a         | Read → returns winning source ID & atomically clears pending.  |
|         |                   | W: complete | n/a         | Write → completion ack (informational in v1.0).                |
| `0x308` | `IP_ID`           | RO          | `0x49524301`| ASCII "IRC\\1".                                                |
| `0x30C` | `IP_VERSION`      | RO          | `0x00010000`| {major[15:8], minor[7:0], patch[7:0]} = 1.0.0.                 |

**Error behavior:**
- Read of unmapped offset → `pslverr=1`, `prdata=0`.
- Write to RO register (`PENDING`, `IP_ID`, `IP_VERSION`) → `pslverr=1`, no state change.

---

## 6. Datapath & functional behavior

### 6.1 Pending tracking
- Per cycle the input vector `irq_src_i` is registered into `irq_src_d`.
- For **edge sources** (`EDGE_MASK[i]=1`), `pending_q[i]` is set on the cycle
  after a rising edge (`irq_src_i[i] & ~irq_src_d[i]`). It is cleared by:
  - SW write 1 to bit i of `PENDING_CLEAR`, or
  - SW read of `CLAIM_COMPLETE` when source i is the current winner.
- For **level sources** (`EDGE_MASK[i]=0`), `pending_q[i]` directly tracks
  `irq_src_i[i]`. SW W1C / claim do **not** clear level pending — the source
  must deassert the line.
- Source 0 is unconditionally forced to 0 every cycle.

### 6.2 Arbitration
Combinational two-stage reduction in `always_comb`:
1. Compute `eligible[i] = pending_q[i] & enable_q[i] & (priority_q[i] > threshold_q)`.
2. Sequential scan from `i=1..NUM_IRQ-1` selects the source with strictly
   greatest `priority_q[i]`. Ties resolve to the lowest ID (the scan only
   updates on `>`, not `>=`).

`eip_o` is asserted iff `best_id ≠ 0`. Latency from source assertion to
`eip_o` rising:
- **Level source:** input flop → eligibility → mux → eip_o ≈ 1 cycle.
- **Edge source:** edge detect needs the previous-cycle sample, so 1 cycle to
  set `pending_q`, then combinational to `eip_o` ≈ 1 cycle.

### 6.3 Claim/complete
- Read of `CLAIM_COMPLETE` returns `{0…, best_id}`. In the same ACCESS
  cycle, if `best_id ≠ 0` **and** the winning source is edge-triggered, its
  `pending_q[best_id]` is cleared (synchronous, registered next cycle).
- Reading claim when no source is eligible returns 0 (PLIC convention).
- Write of `CLAIM_COMPLETE` is currently informational (no gating). It is
  exposed so the SW flow (`claim → ISR body → complete`) is identical to
  full PLIC and a future revision can add per-context "in-flight" tracking
  without an ABI break.

### 6.4 APB protocol
- 2-cycle SETUP/ACCESS access; `pready` is asserted only during ACCESS
  (`psel & penable`), so masters that observe `pready` will see one-wait
  semantics. Wait-states are not inserted in v1.0.
- `pslverr` is asserted during ACCESS for unmapped addresses or RO writes.

---

## 7. Timing

### 7.1 Level interrupt
```
 clk      __┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__┌──┐
 src[16]  ____________┌─────────────┐________
 pend[16] _______________┌──────────┐________   (1-cycle FF delay)
 eip      _______________┌──────────┐________
```

### 7.2 Edge interrupt with claim
```
 clk        __┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__┌──┐__┌──┐
 src[3]    ______┌──┐_______________________________     (1-cycle pulse)
 pend[3]   _________┌────────────────────┐__________     (sticks until claim)
 eip       _________┌────────────────────┐__________
 APB R     ___________________[CLAIM]_______________     (returns id=3)
 pend[3]   _________┌────────────────────┐__________
                                         └ cleared 1 cycle after access
```

---

## 8. Future extensions (out of scope v1.0)

- Multi-context support (per-hart THRESHOLD/ENABLE bank).
- `NUM_IRQ > 32` with strided pending/enable arrays.
- Claim-in-flight tracking (CLAIM_COMPLETE write becomes load-bearing).
- AXI4-Lite alternative front-end.
- ECC on configuration regs (security subsystem requirement).

---

## 9. Verification

[`sim/tb_irq_ctrl.sv`](../sim/tb_irq_ctrl.sv) covers 11 directed scenarios
including reset, RO/RW behavior, level/edge sources, threshold gating,
priority + tie-break arbitration, claim-atomic-clear, W1C, and `pslverr`
generation. The smoke-level CI sim job runs this TB on every PR.
