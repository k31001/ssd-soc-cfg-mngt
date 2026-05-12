/* SPDX-License-Identifier: Apache-2.0 */
/* irq_ctrl HAL — v1.0.0 controller용 구현. */

#include "irq_ctrl_hal.h"

#define IC_NUM IRQ_CTRL_NUM_IRQ

static struct {
    irq_ctrl_handler_t fn;
    void              *arg;
} g_isr[IC_NUM];

int
irq_ctrl_probe(void)
{
    uint32_t id  = irq_ctrl_read32(IRQ_CTRL_REG_IP_ID);
    uint32_t ver = irq_ctrl_read32(IRQ_CTRL_REG_IP_VERSION);
    if (id  != IRQ_CTRL_ID_EXPECTED)  return -1;
    if (ver != IRQ_CTRL_VER_EXPECTED) return -2;
    return 0;
}

void
irq_ctrl_init(void)
{
    irq_ctrl_write32(IRQ_CTRL_REG_THRESHOLD, IRQ_CTRL_PRIO_MAX);   /* 모두 mask */
    irq_ctrl_write32(IRQ_CTRL_REG_ENABLE,    0u);

    for (uint32_t i = 1; i < IC_NUM; i++) {
        irq_ctrl_write32(IRQ_CTRL_REG_PRIORITY(i), 0u);
    }

    irq_ctrl_clear_pending_all();

    for (uint32_t i = 0; i < IC_NUM; i++) {
        g_isr[i].fn  = (irq_ctrl_handler_t)0;
        g_isr[i].arg = (void *)0;
    }
}

void
irq_ctrl_set_priority(uint32_t src, uint32_t prio)
{
    if (src == 0u || src >= IC_NUM) return;
    if (prio > IRQ_CTRL_PRIO_MAX)   prio = IRQ_CTRL_PRIO_MAX;
    irq_ctrl_write32(IRQ_CTRL_REG_PRIORITY(src), prio & 0xFu);
}

uint32_t
irq_ctrl_get_priority(uint32_t src)
{
    if (src >= IC_NUM) return 0u;
    return irq_ctrl_read32(IRQ_CTRL_REG_PRIORITY(src)) & 0xFu;
}

void
irq_ctrl_enable(uint32_t src)
{
    if (src == 0u || src >= IC_NUM) return;
    uint32_t en = irq_ctrl_read32(IRQ_CTRL_REG_ENABLE);
    en |= (1u << src);
    irq_ctrl_write32(IRQ_CTRL_REG_ENABLE, en);
}

void
irq_ctrl_disable(uint32_t src)
{
    if (src == 0u || src >= IC_NUM) return;
    uint32_t en = irq_ctrl_read32(IRQ_CTRL_REG_ENABLE);
    en &= ~(1u << src);
    irq_ctrl_write32(IRQ_CTRL_REG_ENABLE, en);
}

bool
irq_ctrl_is_enabled(uint32_t src)
{
    if (src >= IC_NUM) return false;
    return (irq_ctrl_read32(IRQ_CTRL_REG_ENABLE) >> src) & 1u;
}

void
irq_ctrl_set_threshold(uint32_t thr)
{
    if (thr > IRQ_CTRL_PRIO_MAX) thr = IRQ_CTRL_PRIO_MAX;
    irq_ctrl_write32(IRQ_CTRL_REG_THRESHOLD, thr & 0xFu);
}

uint32_t
irq_ctrl_get_threshold(void)
{
    return irq_ctrl_read32(IRQ_CTRL_REG_THRESHOLD) & 0xFu;
}

uint32_t
irq_ctrl_get_pending(void)
{
    return irq_ctrl_read32(IRQ_CTRL_REG_PENDING);
}

void
irq_ctrl_clear_pending(uint32_t src)
{
    if (src == 0u || src >= IC_NUM) return;
    irq_ctrl_write32(IRQ_CTRL_REG_PENDING_CLEAR, 1u << src);
}

void
irq_ctrl_clear_pending_all(void)
{
    irq_ctrl_write32(IRQ_CTRL_REG_PENDING_CLEAR, 0xFFFFFFFEu);
}

uint32_t
irq_ctrl_claim(void)
{
    return irq_ctrl_read32(IRQ_CTRL_REG_CLAIM_COMPLETE) & 0x1Fu;
}

void
irq_ctrl_complete(uint32_t id)
{
    irq_ctrl_write32(IRQ_CTRL_REG_CLAIM_COMPLETE, id & 0x1Fu);
}

void
irq_ctrl_register(uint32_t src, irq_ctrl_handler_t fn, void *arg)
{
    if (src == 0u || src >= IC_NUM) return;
    g_isr[src].fn  = fn;
    g_isr[src].arg = arg;
}

uint32_t
irq_ctrl_dispatch(void)
{
    uint32_t serviced = 0u;
    for (;;) {
        uint32_t id = irq_ctrl_claim();
        if (id == 0u) break;

        if (g_isr[id].fn) {
            g_isr[id].fn(id, g_isr[id].arg);
        }

        irq_ctrl_complete(id);
        serviced++;
    }
    return serviced;
}
