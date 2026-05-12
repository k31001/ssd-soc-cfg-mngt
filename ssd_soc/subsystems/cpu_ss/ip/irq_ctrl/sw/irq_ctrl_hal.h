/* SPDX-License-Identifier: Apache-2.0 */
/* irq_ctrl HAL — public API.
 *
 * Targets the v1.0.0 PLIC-style controller documented in
 *   doc/DESIGN.md, doc/PROGRAMMERS_GUIDE.md, doc/irq_ctrl.ipxact.xml
 *
 * The register layout, reset values, and access types in this header are
 * the C-side mirror of the IP-XACT memoryMap. Keep in sync.
 */
#ifndef IRQ_CTRL_HAL_H
#define IRQ_CTRL_HAL_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ─────────────────────────── Base address ───────────────────────────
 * The SoC integration package defines IRQ_CTRL_BASE. For unit testing
 * and host-side mocks the user may override it before including this
 * header. */
#ifndef IRQ_CTRL_BASE
#define IRQ_CTRL_BASE  ((uintptr_t)0x10000000UL)
#endif

/* ─────────────────────────── Constants ─────────────────────────── */
#define IRQ_CTRL_NUM_IRQ          32u            /* incl. reserved 0 */
#define IRQ_CTRL_PRIO_MAX         15u            /* 4-bit priority   */
#define IRQ_CTRL_ID_EXPECTED      0x49524301UL   /* "IRC\1"          */
#define IRQ_CTRL_VER_EXPECTED     0x00010000UL   /* 1.0.0            */

/* ─────────────────────────── Register offsets ─────────────────────────── */
#define IRQ_CTRL_REG_PRIORITY(i)   (0x000u + 4u * (i))    /* i = 0..31 */
#define IRQ_CTRL_REG_PENDING        0x100u
#define IRQ_CTRL_REG_PENDING_CLEAR  0x104u
#define IRQ_CTRL_REG_ENABLE         0x200u
#define IRQ_CTRL_REG_THRESHOLD      0x300u
#define IRQ_CTRL_REG_CLAIM_COMPLETE 0x304u
#define IRQ_CTRL_REG_IP_ID          0x308u
#define IRQ_CTRL_REG_IP_VERSION     0x30Cu

/* ─────────────────────────── Low-level accessors ───────────────────────────
 * Plain volatile load/store. On the target the bus fabric provides the
 * required ordering; if you need stronger ordering across HAL calls,
 * insert a DMB/fence at the call site. */
static inline void
irq_ctrl_write32(uint32_t off, uint32_t val)
{
    *(volatile uint32_t *)(IRQ_CTRL_BASE + off) = val;
}

static inline uint32_t
irq_ctrl_read32(uint32_t off)
{
    return *(volatile uint32_t *)(IRQ_CTRL_BASE + off);
}

/* ─────────────────────────── Public API ─────────────────────────── */

/* Probe the block. Returns 0 on success (IP_ID and IP_VERSION match),
 * negative errno-like value otherwise. */
int irq_ctrl_probe(void);

/* Full reset of SW-visible state: mask all sources, threshold high,
 * zero priorities, flush edge pending. Safe to call before configuring
 * any source. */
void irq_ctrl_init(void);

/* Per-source priority (0..15). 0 disables the source by priority. */
void irq_ctrl_set_priority(uint32_t src, uint32_t prio);
uint32_t irq_ctrl_get_priority(uint32_t src);

/* Per-source mask. */
void irq_ctrl_enable(uint32_t src);
void irq_ctrl_disable(uint32_t src);
bool irq_ctrl_is_enabled(uint32_t src);

/* Global priority threshold (0..15). */
void irq_ctrl_set_threshold(uint32_t thr);
uint32_t irq_ctrl_get_threshold(void);

/* Read pending bitmap (32-bit; bit i = source i pending). */
uint32_t irq_ctrl_get_pending(void);

/* W1C clear of one source's pending bit. Effective only on edge sources;
 * level sources will re-set next cycle if line is still high. */
void irq_ctrl_clear_pending(uint32_t src);

/* W1C clear of all sources (mask = 0xFFFFFFFE; source 0 reserved). */
void irq_ctrl_clear_pending_all(void);

/* Claim: returns the winning source ID (1..31) and atomically clears
 * its pending state (edge sources only). Returns 0 if no eligible
 * source is currently pending. */
uint32_t irq_ctrl_claim(void);

/* Complete: acknowledge service of source `id`. Currently informational
 * (no gating in v1.0); SW should still call it for forward
 * compatibility with multi-context revisions. */
void irq_ctrl_complete(uint32_t id);

/* ─────────────────────────── ISR helpers ───────────────────────────
 * The user provides a per-source dispatch table; the HAL provides the
 * canonical claim/dispatch/complete loop. Returns the number of sources
 * serviced (0 means spurious). */
typedef void (*irq_ctrl_handler_t)(uint32_t src, void *arg);

void irq_ctrl_register(uint32_t src, irq_ctrl_handler_t fn, void *arg);
uint32_t irq_ctrl_dispatch(void);

#ifdef __cplusplus
}
#endif

#endif /* IRQ_CTRL_HAL_H */
