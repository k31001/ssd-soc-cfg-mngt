# trng — Programmer's Guide

대상: `sec_ss` subsystem 에 통합되는 `trng` IP 펌웨어 / 보안 라이브러리
엔지니어. v1.0.0.

본 문서는 register 사용 시나리오, 초기화 sequence, ISR flow, edge-case 처리,
[`sw/`](../sw/) 의 HAL 과 매칭되는 실전 예제를 다룬다.

---

## 1. 주소 맵 요약

Base 주소는 SoC integration 에서 정의한다 (`TRNG_BASE`).

| Offset  | Register     | Access   | 비고                                              |
|---------|--------------|----------|--------------------------------------------------|
| `0x000` | `CTRL`       | RW + pulse | ENABLE / SOFT_RESET / SEED_LOAD                |
| `0x004` | `STATUS`     | RO       | DATA_READY / FIFO_FULL / FIFO_EMPTY / HEALTH_FAIL |
| `0x008` | `DATA`       | RO pop   | Read 마다 FIFO 한 word pop                       |
| `0x00C` | `FIFO_LEVEL` | RO       | 0..16                                            |
| `0x010` | `HEALTH`     | RO       | FAIL latch + rep_count                           |
| `0x014` | `SEED0..2`   | RW       | LFSR seed (3 registers @ 0x14/0x18/0x1C)         |
| `0x020` | `INTR_EN`    | RW       | bit0=DATA_READY, bit1=HEALTH_FAIL                |
| `0x024` | `INTR_STATUS`| RW1C     | latched interrupt sources                        |
| `0x030` | `IP_ID`      | RO       | `0x54524E47` ("TRNG")                            |
| `0x034` | `IP_VERSION` | RO       | `0x00010000` = 1.0.0                             |

---

## 2. 초기화 sequence

부팅 시 권장 bring-up 순서.

```
 1. (선택) IP_ID / IP_VERSION sanity check
 2. CTRL ← 0                          ; ENABLE off
 3. INTR_EN ← 0                       ; 모든 interrupt mask
 4. SEED0/SEED1/SEED2 ← non-trivial 값 ; 보안상 보드별 unique seed 권장
 5. CTRL ← 0x7  (ENABLE | SOFT_RESET | SEED_LOAD)
                                      ; FIFO 비움 + LFSR 을 새 seed 로 리로드
 6. 폴링 또는 interrupt 로 STATUS.DATA_READY 대기
 7. INTR_EN ← 적절히 (e.g. 0x2: HEALTH_FAIL 만 alarm)
```

> Step 5 의 단일 펄스가 핵심: SOFT_RESET + SEED_LOAD 를 함께 펄스하면
> 이전 상태와 분리된 재현 가능한 시작점을 얻는다 (KAT 검증, debug log 비교
> 시 유용).

참조 HAL 루틴: [`sw/trng_hal.c`](../sw/trng_hal.c) 의 `trng_init()`.

---

## 3. Random word 획득 — 폴링 방식

```c
/* application 측 wrapper 예시 (HAL 제공 아님) */
uint32_t app_get_random_polled(void)
{
    while ((trng_read_status() & TRNG_STATUS_DATA_READY) == 0)
        ;                                  // wait until FIFO has data
    return trng_read_data();                // read pop
}
```

`STATUS.DATA_READY` 가 1 일 때만 read. health_fail 상태에서는 FIFO 가
잠기므로, fail 후에는 일정 시간 0 만 반환될 수 있다. 따라서:

```c
int trng_get_random_safe(uint32_t *out, uint32_t timeout_iters)
{
    while (timeout_iters--) {
        uint32_t st = trng_read_status();
        if (st & TRNG_STATUS_HEALTH_FAIL) return -1;
        if (st & TRNG_STATUS_DATA_READY)  { *out = trng_read_data(); return 0; }
    }
    return -2;                             // timeout
}
```

---

## 4. Random word 획득 — interrupt 방식

긴 cryptographic 연산 중 main loop 이 random 풀에서 미리 pre-fetch 하는
경우 interrupt-driven 방식이 적합.

```c
// 초기화 단계
trng_init();
trng_set_intr_en(TRNG_INTR_DATA_READY | TRNG_INTR_HEALTH_FAIL);
// CPU 측 PLIC: trng IRQ 활성화

// ISR (application 측 — HAL 제공 아님)
void app_trng_isr(void)
{
    uint32_t st = trng_read_intr_status();
    if (st & TRNG_INTR_HEALTH_FAIL) {
        sec_log_health_alarm();
        trng_recover();                    // soft_reset + 새 seed
    }
    if (st & TRNG_INTR_DATA_READY) {
        while (trng_read_status() & TRNG_STATUS_DATA_READY)
            ring_buffer_push(trng_read_data());
    }
    trng_clear_intr(st);                   // W1C
}
```

`DATA_READY` 는 FIFO 가 empty 에서 non-empty 로 전환되는 rising edge 에만
latch 되므로, ISR 내부에서는 STATUS 폴링으로 가능한 만큼 drain 한다.

---

## 5. Health-fail 복구

`HEALTH_FAIL` 이 latch 되면:
- FIFO push 정지 (잠김)
- `irq_o` 가 INTR_EN[1] 에 따라 rise
- `INTR_STATUS[1]` 한 번 set, W1C 후 다음 rising edge 까지 set 안 됨

복구 절차:
```c
void trng_recover(void)
{
    // 1) 새 seed 주입 (HW TRNG 라면 analog source restart 도 함께)
    trng_write_seed(0, get_fresh_entropy());
    trng_write_seed(1, get_fresh_entropy());
    trng_write_seed(2, get_fresh_entropy());

    // 2) SOFT_RESET + SEED_LOAD 펄스
    trng_pulse_ctrl(TRNG_CTRL_ENABLE | TRNG_CTRL_SOFT_RESET | TRNG_CTRL_SEED_LOAD);

    // 3) INTR_STATUS clear
    trng_clear_intr(TRNG_INTR_HEALTH_FAIL);
}
```

SOFT_RESET 은 HEALTH_FAIL latch 와 FIFO 를 모두 클리어. ENABLE 비트는
보존되므로 한 번의 write 로 즉시 재개 가능.

---

## 6. Worked examples

### 6.1 한 word random 받기 (간단)
```c
trng_init();
uint32_t r;
if (trng_get_random_safe(&r, 1000) == 0)
    printf("rand = 0x%08x\n", r);
```

### 6.2 32 byte key material 생성
```c
uint32_t buf[8];
for (int i = 0; i < 8; i++) {
    if (trng_get_random_safe(&buf[i], 5000) != 0) {
        sec_panic("TRNG starvation");
    }
}
```

### 6.3 Reproducible test vector (KAT mode)
```c
trng_write_seed(0, 0xDEADBEEF);
trng_write_seed(1, 0x98765432);
trng_write_seed(2, 0xCAFEF00D);
trng_pulse_ctrl(TRNG_CTRL_ENABLE | TRNG_CTRL_SOFT_RESET | TRNG_CTRL_SEED_LOAD);
delay_cycles(20);
uint32_t w0 = trng_read_data();
uint32_t w1 = trng_read_data();
// 동일 sequence 가 매번 나옴 → KAT
```

### 6.4 Health-fail injection (self-test)
```c
trng_write_seed(0, 0);
trng_write_seed(1, 0);
trng_write_seed(2, 0);
trng_pulse_ctrl(TRNG_CTRL_ENABLE | TRNG_CTRL_SEED_LOAD);
delay_cycles(10);
assert(trng_read_status() & TRNG_STATUS_HEALTH_FAIL);
trng_recover();  // 정상 seed 로 복구
```

---

## 7. 에러 응답

- 미매핑 offset read/write → `pslverr=1`
- RO register (STATUS / DATA / FIFO_LEVEL / HEALTH / IP_ID / IP_VERSION) write → `pslverr=1`

HAL 은 `pslverr` 를 polling 하지 않으며 bus fabric 이 load/store fault 로
노출하리라 가정한다.

---

## 8. 흔한 함정

| 증상                                    | 원인                                                     |
|----------------------------------------|----------------------------------------------------------|
| `DATA` read 가 계속 0                  | ENABLE off 또는 HEALTH_FAIL latch 후 미복구              |
| Random 이 매번 같음                    | KAT mode 의식하지 못한 채 hard-coded seed 사용           |
| `irq_o` 가 계속 fire                   | INTR_STATUS W1C 안 하거나 underlying source 가 아직 활성 |
| Boot 직후 spurious HEALTH_FAIL         | seed 가 0 인 채로 ENABLE — 초기화 sequence 위반          |
| `SEED_LOAD` 펄스만 했는데 stale data 옴 | SOFT_RESET 까지 함께 펄스해야 FIFO 비워짐                |

---

## 9. Versioning

| HAL macro              | v1.0.0 값     |
|------------------------|---------------|
| `TRNG_ID_EXPECTED`     | `0x54524E47`  |
| `TRNG_VER_EXPECTED`    | `0x00010000`  |

`trng_probe()` 가 두 값을 read 하여 일치 시 0 반환.
