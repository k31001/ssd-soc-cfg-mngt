/* SPDX-License-Identifier: Apache-2.0 */
/* irq_ctrl HAL — public API.
 *
 * 대상: doc/DESIGN.md, doc/PROGRAMMERS_GUIDE.md, doc/irq_ctrl.ipxact.xml에
 * 문서화된 v1.0.0 PLIC 계열 controller.
 *
 * 본 헤더의 register 배치, reset 값, access type은 IP-XACT memoryMap의
 * C-side mirror이다. 양쪽을 항상 동기화 상태로 유지할 것.
 */
#ifndef IRQ_CTRL_HAL_H
#define IRQ_CTRL_HAL_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ─────────────────────────── Base address ───────────────────────────
 * IRQ_CTRL_BASE는 SoC integration package에서 정의한다. unit test 또는
 * host-side mock에서는 본 헤더 include 전에 override할 수 있다. */
#ifndef IRQ_CTRL_BASE
#define IRQ_CTRL_BASE  ((uintptr_t)0x10000000UL)
#endif

/* ─────────────────────────── Constants ─────────────────────────── */
#define IRQ_CTRL_NUM_IRQ          32u            /* 예약된 0 포함     */
#define IRQ_CTRL_PRIO_MAX         15u            /* 4-bit priority    */
#define IRQ_CTRL_ID_EXPECTED      0x49524301UL   /* "IRC\1"           */
#define IRQ_CTRL_VER_EXPECTED     0x00010000UL   /* 1.0.0             */

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
 * 단순 volatile load/store. 타깃에서는 bus fabric이 요구되는 ordering을
 * 제공한다. HAL 호출 사이에 더 강한 ordering이 필요하면 호출 지점에
 * DMB/fence를 삽입한다. */
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

/* 블록 probe. IP_ID, IP_VERSION이 일치하면 0 반환, 그 외에는 음수
 * (errno 스타일) 반환. */
int irq_ctrl_probe(void);

/* SW에서 보이는 상태를 전면 reset: 모든 source mask, threshold 최고로
 * 설정, priority 0으로 초기화, edge pending flush. source 구성 전에
 * 호출해도 안전. */
void irq_ctrl_init(void);

/* source별 priority (0..15). 0이면 priority로 인해 비활성화. */
void irq_ctrl_set_priority(uint32_t src, uint32_t prio);
uint32_t irq_ctrl_get_priority(uint32_t src);

/* source별 mask. */
void irq_ctrl_enable(uint32_t src);
void irq_ctrl_disable(uint32_t src);
bool irq_ctrl_is_enabled(uint32_t src);

/* source가 edge-triggered인지 query. EDGE_MASK는 RTL compile-time 상수이므로
 * SoC integration package가 IRQ_CTRL_EDGE_MASK 매크로로 주입한다.
 * 정의되지 않으면 전부 level (0)로 가정. */
#ifndef IRQ_CTRL_EDGE_MASK
#define IRQ_CTRL_EDGE_MASK 0u
#endif
static inline bool
irq_ctrl_is_edge(uint32_t src)
{
    return (src < IRQ_CTRL_NUM_IRQ) && ((IRQ_CTRL_EDGE_MASK >> src) & 1u);
}

/* 전역 priority threshold (0..15). */
void irq_ctrl_set_threshold(uint32_t thr);
uint32_t irq_ctrl_get_threshold(void);

/* Pending bitmap read (32-bit; 비트 i = source i pending). */
uint32_t irq_ctrl_get_pending(void);

/* 특정 source pending 비트를 W1C로 clear. edge source에만 유효하며,
 * level source는 line이 high인 동안 다음 cycle에 다시 set된다. */
void irq_ctrl_clear_pending(uint32_t src);

/* 모든 source W1C clear (mask = 0xFFFFFFFE; source 0은 예약). */
void irq_ctrl_clear_pending_all(void);

/* Claim: winning source ID (1..31) 반환 및 해당 pending 상태를 atomic
 * clear (edge source 전용). 현재 eligible pending source가 없으면 0. */
uint32_t irq_ctrl_claim(void);

/* Complete: source `id` 처리 완료 ack. 현재는 informational
 * (v1.0에 gating 없음). multi-context revision과의 forward
 * compatibility를 위해 SW에서 호출해 둘 것. */
void irq_ctrl_complete(uint32_t id);

/* ─────────────────────────── ISR helpers ───────────────────────────
 * 사용자가 source별 dispatch table을 제공하고, HAL은 canonical
 * claim/dispatch/complete 루프를 제공한다. 처리된 source 수를 반환
 * (0이면 spurious). */
typedef void (*irq_ctrl_handler_t)(uint32_t src, void *arg);

void irq_ctrl_register(uint32_t src, irq_ctrl_handler_t fn, void *arg);
uint32_t irq_ctrl_dispatch(void);

#ifdef __cplusplus
}
#endif

#endif /* IRQ_CTRL_HAL_H */
