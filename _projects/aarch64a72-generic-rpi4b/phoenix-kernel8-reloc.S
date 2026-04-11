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
#define UARTICR_OFFSET 0x44
#define UARTFR_TXFF   (1 << 5)
#define UARTCR_UARTEN (1 << 0)
#define UARTCR_TXE    (1 << 8)
#define UARTCR_RXE    (1 << 9)
#define UARTLCRH_FEN  (1 << 4)
#define UARTLCRH_WLEN_8BIT (3 << 5)

#define PLO_DEST      PLO_RPI_PLO_DEST
#define CACHE_LINE    64

	.section .text
	.globl _start
	.type _start, %function

	.extern phoenix_plo_payload_start
	.extern phoenix_plo_payload_end


.macro uart_putc imm
991:
	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTFR_OFFSET)
	ldr w10, [x9]
	tst w10, #UARTFR_TXFF
	b.ne 991b
	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTDR_OFFSET)
	mov w10, #\imm
	str w10, [x9]
.endm


.macro uart_reinit_115200
	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTCR_OFFSET)
	mov w10, #0
	str w10, [x9]

	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTICR_OFFSET)
	mov w10, #0x7ff
	str w10, [x9]

	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTIBRD_OFFSET)
	mov w10, #26
	str w10, [x9]

	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTFBRD_OFFSET)
	mov w10, #3
	str w10, [x9]

	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTLCRH_OFFSET)
	mov w10, #(UARTLCRH_FEN | UARTLCRH_WLEN_8BIT)
	str w10, [x9]

	ldr x9, =(PLO_UART0_BASE_ADDRESS + UARTCR_OFFSET)
	mov w10, #(UARTCR_UARTEN | UARTCR_TXE | UARTCR_RXE)
	str w10, [x9]

	dsb sy
	isb
.endm


.macro uart_tag a, b, c
	uart_putc \a
	uart_putc \b
	uart_putc \c
	uart_putc 0x0d
	uart_putc 0x0a
.endm


_start:
	mov x19, x0
	uart_reinit_115200
	uart_tag 0x54, 0x52, 0x30

	adrp x20, phoenix_plo_payload_start
	add x20, x20, :lo12:phoenix_plo_payload_start
	adrp x21, phoenix_plo_payload_end
	add x21, x21, :lo12:phoenix_plo_payload_end
	ldr x22, =PLO_DEST
	mov x23, x22
	sub x26, x21, x20
	add x27, x23, x26

	uart_tag 0x54, 0x52, 0x31

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

	uart_tag 0x54, 0x52, 0x32

	mov x0, x19
	uart_tag 0x54, 0x52, 0x33
	ldr x22, =PLO_DEST
	br x22
