# SPDX-License-Identifier: Apache-2.0
# trng HAL host-side smoke build.

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Werror -O2 -g

TEST    := test_hal_host

.PHONY: all test clean

all: $(TEST)

$(TEST): test_hal_host.c trng_hal.c trng_hal.h
	$(CC) $(CFLAGS) -I. test_hal_host.c -o $@

test: $(TEST)
	./$(TEST)

clean:
	rm -f $(TEST)
	rm -rf $(TEST).dSYM
