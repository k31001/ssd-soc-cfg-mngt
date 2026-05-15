/* SPDX-License-Identifier: Apache-2.0 */
/* trng_hal host-side smoke test (shadow MMIO). */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

static uint8_t g_mmio[4096];

#define TRNG_BASE  ((uintptr_t)g_mmio)
#include "trng_hal.h"
#include "trng_hal.c"

static int g_fail = 0;
#define CHECK(cond, tag) do { \
    if (!(cond)) { printf("[FAIL] %s\n", tag); g_fail++; } \
    else         { printf("[ pass ] %s\n", tag); } \
} while (0)

static void
seed_ro(void)
{
    *(uint32_t *)(g_mmio + TRNG_REG_IP_ID)      = TRNG_ID_EXPECTED;
    *(uint32_t *)(g_mmio + TRNG_REG_IP_VERSION) = TRNG_VER_EXPECTED;
}

int
main(void)
{
    memset(g_mmio, 0, sizeof g_mmio);
    CHECK(trng_probe() != 0, "T1 probe fails on zero IP_ID");
    seed_ro();
    CHECK(trng_probe() == 0, "T1 probe succeeds when constants match");

    trng_init();
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_CTRL) ==
              (TRNG_CTRL_ENABLE | TRNG_CTRL_SOFT_RESET | TRNG_CTRL_SEED_LOAD),
          "T2 init writes ENABLE|SOFT_RESET|SEED_LOAD pulse");
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_INTR_EN) == 0u,
          "T2 init zeros INTR_EN");

    trng_write_seed(0, 0xDEADBEEF);
    trng_write_seed(1, 0x98765432);
    trng_write_seed(2, 0xCAFEF00D);
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_SEED0) == 0xDEADBEEFu, "T3 seed0 rw");
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_SEED1) == 0x98765432u, "T3 seed1 rw");
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_SEED2) == 0xCAFEF00Du, "T3 seed2 rw");
    trng_write_seed(99, 0);
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_SEED2) == 0xCAFEF00Du, "T3 invalid idx no-op");

    /* simulate DATA_READY and pop */
    *(uint32_t *)(g_mmio + TRNG_REG_STATUS) = TRNG_STATUS_DATA_READY;
    *(uint32_t *)(g_mmio + TRNG_REG_DATA)   = 0x12345678u;
    uint32_t r = 0;
    CHECK(trng_get_random_safe(&r, 10) == 0,         "T4 get_random returns ok");
    CHECK(r == 0x12345678u,                          "T4 returned word matches");

    /* simulate HEALTH_FAIL — safe-get must return -1 */
    *(uint32_t *)(g_mmio + TRNG_REG_STATUS) = TRNG_STATUS_HEALTH_FAIL;
    CHECK(trng_get_random_safe(&r, 5) == -1,         "T5 safe-get -> -1 on health_fail");

    /* timeout case */
    *(uint32_t *)(g_mmio + TRNG_REG_STATUS) = 0;
    CHECK(trng_get_random_safe(&r, 3) == -2,         "T5 safe-get timeout -> -2");
    CHECK(trng_get_random_safe(NULL, 3) == -3,       "T5 safe-get NULL -> -3");

    /* INTR_EN / INTR_STATUS */
    trng_set_intr_en(0xFF);
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_INTR_EN) == 0x3u,
          "T6 set_intr_en masks to 2 bits");
    *(uint32_t *)(g_mmio + TRNG_REG_INTR_STATUS) = 0x3u;
    CHECK(trng_read_intr_status() == 0x3u, "T6 read_intr_status");
    trng_clear_intr(TRNG_INTR_HEALTH_FAIL);
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_INTR_STATUS) == TRNG_INTR_HEALTH_FAIL,
          "T6 clear_intr writes the bit (W1C)");

    /* recover */
    trng_recover();
    CHECK(*(uint32_t *)(g_mmio + TRNG_REG_CTRL) ==
              (TRNG_CTRL_ENABLE | TRNG_CTRL_SOFT_RESET | TRNG_CTRL_SEED_LOAD),
          "T7 recover writes CTRL pulse");

    if (g_fail == 0) { printf("\n[test_hal_host] ALL PASS\n"); return 0; }
    printf("\n[test_hal_host] %d FAILURES\n", g_fail);
    return 1;
}
