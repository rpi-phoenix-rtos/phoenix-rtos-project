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
#define UARTIBRD_OFFSET 0x24
#define UARTFBRD_OFFSET 0x28
#define UARTLCRH_OFFSET 0x2c
#define UARTCR_OFFSET 0x30
#define UARTFR_TXFF   (1 << 5)

#define PLO_DEST      PLO_RPI_PLO_DEST
#define CACHE_LINE    64

	.section .text
	.globl _start
	.type _start, %function

	.extern phoenix_plo_payload_start
	.extern phoenix_plo_payload_end

	.macro uart_reinit_115200
	ldr x3, =PL011_TTY_BASE
	mov w4, wzr
	str w4, [x3, #UARTCR_OFFSET]
	mov w4, #26
	str w4, [x3, #UARTIBRD_OFFSET]
	mov w4, #3
	str w4, [x3, #UARTFBRD_OFFSET]
	mov w4, #0x70
	str w4, [x3, #UARTLCRH_OFFSET]
	mov w4, #0x301
	str w4, [x3, #UARTCR_OFFSET]
	dsb sy
	isb
	.endm

	.macro uart_putc imm
991:
	ldr x3, =PL011_TTY_BASE
	ldr w4, [x3, #UARTFR_OFFSET]
	tst w4, #UARTFR_TXFF
	b.ne 991b
	mov w4, #\imm
	str w4, [x3, #UARTDR_OFFSET]
	.endm


_start:
	mov x19, x0
	uart_reinit_115200
	uart_putc 84
	uart_putc 82
	uart_putc 48
	uart_putc 13
	uart_putc 10

	adrp x20, phoenix_plo_payload_start
	add x20, x20, :lo12:phoenix_plo_payload_start
	adrp x21, phoenix_plo_payload_end
	add x21, x21, :lo12:phoenix_plo_payload_end
	ldr x22, =PLO_DEST
	mov x23, x22
	sub x26, x21, x20
	add x27, x23, x26
	uart_putc 84
	uart_putc 82
	uart_putc 49
	uart_putc 13
	uart_putc 10

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
	uart_putc 84
	uart_putc 82
	uart_putc 50
	uart_putc 13
	uart_putc 10

	mov x0, x19
	uart_putc 84
	uart_putc 82
	uart_putc 51
	uart_putc 13
	uart_putc 10
	ldr x22, =PLO_DEST
	br x22
