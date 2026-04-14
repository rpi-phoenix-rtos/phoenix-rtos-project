/*
 * Raspberry Pi 4 relocatable kernel8 trampoline for Phoenix-RTOS.
 *
 * Copyright 2026 Phoenix Systems
 *
 * This file is part of Phoenix-RTOS.
 *
 * %LICENSE%
 */

#include "board_config.h"

#define UARTDR_OFFSET 0x0
#define UARTFR_OFFSET 0x18
#define UARTFR_TXFF   (1 << 5)

#define PLO_DEST      PLO_RPI_PLO_DEST
#define CACHE_LINE    64

	.section .text
	.globl _start
	.type _start, %function

	.extern phoenix_plo_payload_start
	.extern phoenix_plo_payload_end


_start:
	mov x19, x0

	adrp x20, phoenix_plo_payload_start
	add x20, x20, :lo12:phoenix_plo_payload_start
	adrp x21, phoenix_plo_payload_end
	add x21, x21, :lo12:phoenix_plo_payload_end
	ldr x22, =PLO_DEST
	mov x23, x22
	sub x26, x21, x20
	add x27, x23, x26

copy_loop:
	cmp x20, x21
	b.hs copy_done

	sub x24, x21, x20
	cmp x24, #8
	b.lo copy_tail

	ldr x25, [x20], #8
	str x25, [x22], #8
	b copy_loop

copy_tail:
	ldrb w25, [x20], #1
	strb w25, [x22], #1
	b copy_loop

copy_done:
	mov x24, x23
	lsr x24, x24, #6
	lsl x24, x24, #6
	add x25, x27, #(CACHE_LINE - 1)
	lsr x25, x25, #6
	lsl x25, x25, #6

cache_loop:
	dc cvau, x24
	add x24, x24, #CACHE_LINE
	cmp x24, x25
	b.lo cache_loop

	dsb ish
	ic iallu
	dsb ish
	isb

	mov x0, x19
	ldr x22, =PLO_DEST
	br x22
