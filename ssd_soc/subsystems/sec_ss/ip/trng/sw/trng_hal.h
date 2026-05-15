/* SPDX-License-Identifier: Apache-2.0 */
/* trng HAL — public API.
 *
 * 대상: doc/DESIGN.md, doc/PROGRAMMERS_GUIDE.md, doc/trng.ipxact.xml 에
 * 정의된 v1.0.0 controller. register 배치/reset 값/access 는 IP-XACT
 * memoryMap 의 C-side mirror.
 */
#ifndef TRNG_HAL_H
#define TRNG_HAL_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* SoC integration 에서 정의. host-test 는 본 헤더 include 전에 override 가능. */
#ifndef TRNG_BASE
#define TRNG_BASE  ((uintptr_t)0x20000000UL)
#endif

/* Constants */
#define TRNG_FIFO_DEPTH      16u
#define TRNG_ID_EXPECTED     0x54524E47UL   /* "TRNG" */
#define TRNG_VER_EXPECTED    0x00010000UL   /* 1.0.0  */

/* Register offsets */
#define TRNG_REG_CTRL          0x000u
#define TRNG_REG_STATUS        0x004u
#define TRNG_REG_DATA          0x008u
#define TRNG_REG_FIFO_LEVEL    0x00Cu
#define TRNG_REG_HEALTH        0x010u
#define TRNG_REG_SEED0         0x014u
#define TRNG_REG_SEED1         0x018u
#define TRNG_REG_SEED2         0x01Cu
#define TRNG_REG_INTR_EN       0x020u
#define TRNG_REG_INTR_STATUS   0x024u
#define TRNG_REG_IP_ID         0x030u
#define TRNG_REG_IP_VERSION    0x034u

/* CTRL bits */
#define TRNG_CTRL_ENABLE       (1u << 0)
#define TRNG_CTRL_SOFT_RESET   (1u << 1)
#define TRNG_CTRL_SEED_LOAD    (1u << 2)

/* STATUS bits */
#define TRNG_STATUS_DATA_READY (1u << 0)
#define TRNG_STATUS_FIFO_FULL  (1u << 1)
#define TRNG_STATUS_FIFO_EMPTY (1u << 2)
#define TRNG_STATUS_HEALTH_FAIL (1u << 3)

/* HEALTH bits */
#define TRNG_HEALTH_FAIL       (1u << 0)
#define TRNG_HEALTH_REP_SHIFT  8
#define TRNG_HEALTH_REP_MASK   (0xFu << 8)

/* Interrupt bits */
#define TRNG_INTR_DATA_READY   (1u << 0)
#define TRNG_INTR_HEALTH_FAIL  (1u << 1)

/* Low-level accessors */
static inline void
trng_write32(uint32_t off, uint32_t val)
{
    *(volatile uint32_t *)(TRNG_BASE + off) = val;
}

static inline uint32_t
trng_read32(uint32_t off)
{
    return *(volatile uint32_t *)(TRNG_BASE + off);
}

/* Public API */
int      trng_probe(void);
void     trng_init(void);

uint32_t trng_read_status(void);
uint32_t trng_read_health(void);
uint32_t trng_fifo_level(void);

uint32_t trng_read_data(void);                              /* FIFO pop (raw) */
int      trng_get_random_safe(uint32_t *out, uint32_t timeout_iters);

void     trng_write_seed(uint32_t idx, uint32_t value);     /* idx = 0..2 */

void     trng_set_intr_en(uint32_t mask);
uint32_t trng_read_intr_status(void);
void     trng_clear_intr(uint32_t mask);                    /* W1C */

void     trng_pulse_ctrl(uint32_t bits);                    /* CTRL pulse helper */
void     trng_recover(void);                                /* re-seed + soft reset */

#ifdef __cplusplus
}
#endif
#endif /* TRNG_HAL_H */
