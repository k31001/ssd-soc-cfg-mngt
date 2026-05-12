# SPDX-License-Identifier: Apache-2.0
# Host-side smoke build for the irq_ctrl HAL.
#
#   make           — build the HAL into a static archive + host smoke test
#   make test      — build and run the host smoke test
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
# test_hal_host.c #include's irq_ctrl_hal.c directly so the HAL picks up
# the test's shadow-buffer IRQ_CTRL_BASE override.
$(TEST): test_hal_host.c irq_ctrl_hal.c irq_ctrl_hal.h
	$(CC) $(CFLAGS) -I. test_hal_host.c -o $@

test: $(TEST)
	./$(TEST)

clean:
	rm -f $(OBJS) $(LIB) $(TEST)
