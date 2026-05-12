# SPDX-License-Identifier: Apache-2.0
# irq_ctrl HAL용 host-side smoke build.
#
#   make           — HAL을 static archive로 빌드 + host smoke test 생성
#   make test      — host smoke test 빌드 및 실행
#   make clean

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Werror -O2 -g

LIB     := libirq_ctrl_hal.a
TEST    := test_hal_host
OBJS    := irq_ctrl_hal.o

.PHONY: all test clean

all: $(LIB) $(TEST)

$(LIB): $(OBJS)
	$(AR) rcs $@ $^

irq_ctrl_hal.o: irq_ctrl_hal.c irq_ctrl_hal.h
	$(CC) $(CFLAGS) -c $< -o $@

# The host test overrides IRQ_CTRL_BASE before including the header, so it
# does NOT link the .o (which compiled with the default base). It compiles
# the .c directly with the shadow buffer as the base.
# test_hal_host.c가 irq_ctrl_hal.c를 직접 #include하여 test의
# shadow-buffer IRQ_CTRL_BASE override가 HAL에 적용되도록 한다.
$(TEST): test_hal_host.c irq_ctrl_hal.c irq_ctrl_hal.h
	$(CC) $(CFLAGS) -I. test_hal_host.c -o $@

test: $(TEST)
	./$(TEST)

clean:
	rm -f $(OBJS) $(LIB) $(TEST)
