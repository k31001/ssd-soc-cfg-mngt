/* SPDX-License-Identifier: Apache-2.0 */
/* trng HAL — v1.0.0 controller 용 구현. */

#include "trng_hal.h"

int
trng_probe(void)
{
    if (trng_read32(TRNG_REG_IP_ID)      != TRNG_ID_EXPECTED)  return -1;
    if (trng_read32(TRNG_REG_IP_VERSION) != TRNG_VER_EXPECTED) return -2;
    return 0;
}

void
trng_init(void)
{
    trng_write32(TRNG_REG_CTRL, 0u);
    trng_write32(TRNG_REG_INTR_EN, 0u);
    /* SEED 는 default 값을 그대로 유지 (보드별 unique seed 가 필요하면
     * 호출자가 trng_write_seed 로 덮어쓰고 trng_pulse_ctrl(SEED_LOAD|...) 호출). */
    trng_write32(TRNG_REG_CTRL, TRNG_CTRL_ENABLE | TRNG_CTRL_SOFT_RESET | TRNG_CTRL_SEED_LOAD);
}

uint32_t
trng_read_status(void)
{
    return trng_read32(TRNG_REG_STATUS);
}

uint32_t
trng_read_health(void)
{
    return trng_read32(TRNG_REG_HEALTH);
}

uint32_t
trng_fifo_level(void)
{
    return trng_read32(TRNG_REG_FIFO_LEVEL) & 0x1Fu;
}

uint32_t
trng_read_data(void)
{
    return trng_read32(TRNG_REG_DATA);
}

int
trng_get_random_safe(uint32_t *out, uint32_t timeout_iters)
{
    if (!out) return -3;
    while (timeout_iters--) {
        uint32_t st = trng_read_status();
        if (st & TRNG_STATUS_HEALTH_FAIL) return -1;
        if (st & TRNG_STATUS_DATA_READY) {
            *out = trng_read_data();
            return 0;
        }
    }
    return -2;
}

void
trng_write_seed(uint32_t idx, uint32_t value)
{
    switch (idx) {
        case 0: trng_write32(TRNG_REG_SEED0, value); break;
        case 1: trng_write32(TRNG_REG_SEED1, value); break;
        case 2: trng_write32(TRNG_REG_SEED2, value); break;
        default: break;
    }
}

void
trng_set_intr_en(uint32_t mask)
{
    trng_write32(TRNG_REG_INTR_EN, mask & 0x3u);
}

uint32_t
trng_read_intr_status(void)
{
    return trng_read32(TRNG_REG_INTR_STATUS);
}

void
trng_clear_intr(uint32_t mask)
{
    trng_write32(TRNG_REG_INTR_STATUS, mask & 0x3u);
}

void
trng_pulse_ctrl(uint32_t bits)
{
    trng_write32(TRNG_REG_CTRL, bits);
}

void
trng_recover(void)
{
    /* 호출자가 미리 fresh seed 를 SEED0..2 에 write 했다고 가정.
     * (HW TRNG analog source 가 있다면 별도 restart 도 호출자 책임) */
    trng_write32(TRNG_REG_CTRL,
                 TRNG_CTRL_ENABLE | TRNG_CTRL_SOFT_RESET | TRNG_CTRL_SEED_LOAD);
    trng_clear_intr(TRNG_INTR_HEALTH_FAIL);
}
