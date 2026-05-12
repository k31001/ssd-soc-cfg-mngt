/* SPDX-License-Identifier: Apache-2.0 */
/* irq_ctrl_hal용 host-side smoke test.
 *
 * volatile MMIO 영역을 4 KiB shadow buffer로 대체하여 타깃 hardware
 * 없이 빌드 host에서 HAL을 검증할 수 있도록 한다.
 * 검증 항목: probe, init register sequence, set/get round-trip,
 * clear-pending bitmask, claim/complete read/write 인코딩.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

/* Shadow MMIO buffer (4 KiB) */
static uint8_t g_mmio[4096];

#define IRQ_CTRL_BASE  ((uintptr_t)g_mmio)
#include "irq_ctrl_hal.h"
/* HAL 구현을 in-place로 compile하여 override된 base 주소를 사용하도록 한다. */
#include "irq_ctrl_hal.c"

static int g_fail = 0;

#define CHECK(cond, tag) do {                                  \
    if (!(cond)) { printf("[FAIL] %s\n", tag); g_fail++; }     \
    else         { printf("[ pass ] %s\n", tag); }             \
} while (0)

static void
seed_probe_regs(void)
{
    *(uint32_t *)(g_mmio + IRQ_CTRL_REG_IP_ID)      = IRQ_CTRL_ID_EXPECTED;
    *(uint32_t *)(g_mmio + IRQ_CTRL_REG_IP_VERSION) = IRQ_CTRL_VER_EXPECTED;
}

int
main(void)
{
    /* T1: probe negative cases */
    memset(g_mmio, 0, sizeof g_mmio);
    CHECK(irq_ctrl_probe() != 0, "T1 probe fails on zero IP_ID");

    seed_probe_regs();
    CHECK(irq_ctrl_probe() == 0, "T1 probe succeeds when constants match");

    /* T2: init clears state */
    *(uint32_t *)(g_mmio + IRQ_CTRL_REG_ENABLE) = 0xDEADBEEFu;
    irq_ctrl_init();
    CHECK(*(uint32_t *)(g_mmio + IRQ_CTRL_REG_ENABLE) == 0u,
          "T2 init zeroes ENABLE");
    CHECK(*(uint32_t *)(g_mmio + IRQ_CTRL_REG_THRESHOLD) == IRQ_CTRL_PRIO_MAX,
          "T2 init raises THRESHOLD to max");
    CHECK(*(uint32_t *)(g_mmio + IRQ_CTRL_REG_PENDING_CLEAR) == 0xFFFFFFFEu,
          "T2 init pending-clear bitmask written");

    /* T3: priority RW */
    irq_ctrl_set_priority(5, 7);
    CHECK(irq_ctrl_get_priority(5) == 7, "T3 priority[5] = 7");
    irq_ctrl_set_priority(5, 99);
    CHECK(irq_ctrl_get_priority(5) == IRQ_CTRL_PRIO_MAX,
          "T3 priority clamped to 15");
    irq_ctrl_set_priority(0, 10);
    CHECK(irq_ctrl_get_priority(0) == 0,
          "T3 priority[0] write is no-op");

    /* T4: enable / disable */
    irq_ctrl_enable(12);
    CHECK(irq_ctrl_is_enabled(12), "T4 enable(12)");
    irq_ctrl_disable(12);
    CHECK(!irq_ctrl_is_enabled(12), "T4 disable(12)");
    irq_ctrl_enable(0);
    CHECK(!irq_ctrl_is_enabled(0), "T4 enable(0) is no-op");

    /* T5: clear_pending writes correct bitmask */
    *(uint32_t *)(g_mmio + IRQ_CTRL_REG_PENDING_CLEAR) = 0;
    irq_ctrl_clear_pending(7);
    CHECK(*(uint32_t *)(g_mmio + IRQ_CTRL_REG_PENDING_CLEAR) == (1u << 7),
          "T5 clear_pending(7) writes bit 7");

    /* T6: claim / complete encoding */
    *(uint32_t *)(g_mmio + IRQ_CTRL_REG_CLAIM_COMPLETE) = 0x1F | 0xFFFFFF00u;
    CHECK(irq_ctrl_claim() == 0x1F, "T6 claim masks to 5 bits");
    irq_ctrl_complete(9);
    CHECK(*(uint32_t *)(g_mmio + IRQ_CTRL_REG_CLAIM_COMPLETE) == 9u,
          "T6 complete writes ID");

    /* T7: threshold round-trip */
    irq_ctrl_set_threshold(11);
    CHECK(irq_ctrl_get_threshold() == 11, "T7 threshold rw");
    irq_ctrl_set_threshold(0xFF);
    CHECK(irq_ctrl_get_threshold() == IRQ_CTRL_PRIO_MAX,
          "T7 threshold clamps to 15");

    if (g_fail == 0) {
        printf("\n[test_hal_host] ALL PASS\n");
        return 0;
    }
    printf("\n[test_hal_host] %d FAILURES\n", g_fail);
    return 1;
}
