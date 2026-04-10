/*
 * Raspberry Pi 4 AArch64 arm stub for Phoenix-RTOS.
 *
 * Derived from the Raspberry Pi / Circle armstub8-rpi4 lineage:
 * Copyright (c) 2016 Raspberry Pi (Trading) Ltd.
 * Copyright (c) 2016 Stephen Warren <swarren@wwwdotorg.org>
 * Modified for Phoenix-RTOS 2026 Phoenix Systems.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * * Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * * Neither the name of the copyright holder nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include "board_config.h"

#define BIT(x) (1 << (x))

#define LOCAL_CONTROL   0xff800000
#define LOCAL_PRESCALER 0xff800008
#define GIC_DISTB       0xff841000
#define GIC_CPUB        0xff842000
#define GPIO_GPFSEL4    0xfe200010
#define GPIO_GPSET1     0xfe200020
#define GPIO_GPCLR1     0xfe20002c
#define GPIO42_SHIFT    6
#define GPIO42_OUTPUT   (1 << GPIO42_SHIFT)
#define GPIO42_SET      (1 << 10)
#define GPIO42_CLR      (1 << 10)
#define GPIO42_CODE_BITS   5
#define GPIO42_SHORT_TICKS 0x00180000
#define GPIO42_LONG_TICKS  0x00300000
#define GPIO42_SYNC_TICKS  0x00480000
#define GPIO42_STAGE_GAP_TICKS 0x00480000
#define OSC_FREQ        54000000
#define PLO_LOAD_ADDR   0x40080000

#define SCR_RW       BIT(10)
#define SCR_HCE      BIT(8)
#define SCR_RES1_5   BIT(5)
#define SCR_RES1_4   BIT(4)
#define SCR_NS       BIT(0)
#define SCR_VAL (SCR_RW | SCR_HCE | SCR_RES1_5 | SCR_RES1_4 | SCR_NS)

#define CPUECTLR_EL1       S3_1_C15_C2_1
#define CPUECTLR_EL1_SMPEN BIT(6)

#define SPSR_EL3_D         BIT(9)
#define SPSR_EL3_A         BIT(8)
#define SPSR_EL3_I         BIT(7)
#define SPSR_EL3_F         BIT(6)
#define SPSR_EL3_MODE_EL2H 9
#define SPSR_EL3_VAL \
	(SPSR_EL3_D | SPSR_EL3_A | SPSR_EL3_I | SPSR_EL3_F | SPSR_EL3_MODE_EL2H)

#define GICC_CTRLR  0x0
#define GICC_PMR    0x4
#define GICD_CTRLR  0x0
#define GICD_IGROUPR 0x80
#define GIC_IT_NR   0x8

	.section .text
	.globl _start
_start:
	b	start_late

	.org 0xd4
	.ascii "FIQS"
	.org 0xd8
	.globl spin_cpu0
spin_cpu0:
	.quad 0
	.org 0xe0
	.globl spin_cpu1
spin_cpu1:
	.quad 0
	.org 0xe8
	.globl spin_cpu2
spin_cpu2:
	.quad 0
	.org 0xf0
	.globl spin_cpu3
spin_cpu3:
	/* Firmware clears these 8 bytes after reading the initial value. */
	.org 0xf0
	.globl stub_magic
stub_magic:
	.word 0x5afe570b
	.org 0xf4
	.globl stub_version
stub_version:
	.word 0
	.org 0xf8
	.globl dtb_ptr32
dtb_ptr32:
	.word 0x0
	.org 0xfc
	.globl kernel_entry32
kernel_entry32:
	.word 0x0

	.org 0x100

start_late:
	mrs	x7, mpidr_el1
	and	x7, x7, #0x3
	cbnz	x7, 0f
	bl	gpio42_stage1
0:
	mov x0, LOCAL_CONTROL
	str wzr, [x0]
	mov w1, 0x80000000
	str w1, [x0, #(LOCAL_PRESCALER - LOCAL_CONTROL)]

	ldr x0, =OSC_FREQ
	msr cntfrq_el0, x0

	msr	cntvoff_el2, xzr
	mov	x0, #0x3
	msr	cnthctl_el2, x0

	msr	cptr_el3, xzr
	mov	x0, #SCR_VAL
	msr	scr_el3, x0

	mov	x0, #CPUECTLR_EL1_SMPEN
	msr	CPUECTLR_EL1, x0

	bl setup_gic
	bl	gpio42_stage2

	ldr	x0, =0x30c50830
	msr	sctlr_el2, x0

	mov	x0, #SPSR_EL3_VAL
	msr	spsr_el3, x0
	adr	x0, in_el2
	msr	elr_el3, x0
	eret

in_el2:
	mrs	x6, mpidr_el1
	and	x6, x6, #0x3
	cbz	x6, primary_cpu

	adr	x5, spin_cpu0
secondary_spin:
	wfe
	ldr	x4, [x5, x6, lsl #3]
	cbz	x4, secondary_spin
	mov	x0, #0
	mov	x1, #0
	mov	x2, #0
	mov	x3, #0
	br	x4

primary_cpu:
	bl	gpio42_stage3
	b	primary_cpu_late

primary_cpu_late:
	/*
	 * The current Phoenix kernel8.img is a raw plo binary, not a Linux
	 * Image-format payload. On real Pi firmware, the armstub kernel entry
	 * slot is derived by parsing the 64-bit kernel header, so for this
	 * bounded experiment jump directly to the configured kernel_address.
	 */
	ldr	x4, =PLO_LOAD_ADDR
	ldr	w5, [x4, #PLO_RPI_FIXED_ENTRY_SIGNATURE_OFFSET]
	ldr	w6, [x4, #(PLO_RPI_FIXED_ENTRY_SIGNATURE_OFFSET + 4)]
	ldr	w7, =PLO_RPI_FIXED_ENTRY_SIGNATURE0
	cmp	w5, w7
	b.ne	fixed_target_bad
	ldr	w7, =PLO_RPI_FIXED_ENTRY_SIGNATURE1
	cmp	w6, w7
	b.ne	fixed_target_bad
	bl	gpio42_stage4
	dsb	sy
	ic	iallu
	dsb	sy
	isb
	br	x4

fixed_target_bad:
	bl	gpio42_stage31
1:
	wfe
	b	1b

gpio42_stage1:
	mov	w0, #1
	b	gpio42_stage_emit


gpio42_stage2:
	mov	w0, #2
	b	gpio42_stage_emit


gpio42_stage3:
	mov	w0, #3
	b	gpio42_stage_emit


gpio42_stage4:
	mov	w0, #4
	b	gpio42_stage_emit


gpio42_stage31:
	mov	w0, #31
	b	gpio42_stage_emit

setup_gic:
	mrs x0, mpidr_el1
	ldr x2, =GIC_DISTB
	tst x0, #0x3
	b.eq 1f

	mov w0, #3
	str w0, [x2, #GICD_CTRLR]
1:
	add x1, x2, #(GIC_CPUB - GIC_DISTB)
	mov w0, #0x1e7
	str w0, [x1, #GICC_CTRLR]
	mov w0, #0xff
	str w0, [x1, #GICC_PMR]

	add x2, x2, #GICD_IGROUPR
	mov x0, #(GIC_IT_NR * 4)
	mov w1, #~0
2:
	subs x0, x0, #4
	str w1, [x2, x0]
	b.ne 2b
	ret

	.ltorg


gpio42_led_on:
	ldr	x0, =GPIO_GPFSEL4
	ldr	w1, [x0]
	mov	w2, #(7 << GPIO42_SHIFT)
	bic	w1, w1, w2
	mov	w2, #GPIO42_OUTPUT
	orr	w1, w1, w2
	str	w1, [x0]

	ldr	x0, =GPIO_GPSET1
	mov	w1, #GPIO42_SET
	str	w1, [x0]
	ret


.macro gpio42_delay_ticks reg, ticks
	ldr	\reg, =\ticks
991:
	subs	\reg, \reg, #1
	b.ne	991b
.endm


gpio42_stage_emit:
	mov	x12, x30
	mov	w11, w0
	bl	gpio42_led_off

	/* Sync pulse before the fixed-width stage code. */
	bl	gpio42_led_on
	gpio42_delay_ticks x9, GPIO42_SYNC_TICKS
	bl	gpio42_led_off
	gpio42_delay_ticks x9, GPIO42_SYNC_TICKS

	mov	w10, #(1 << (GPIO42_CODE_BITS - 1))
1:
	bl	gpio42_led_on
	tst	w11, w10
	b.eq	2f
	gpio42_delay_ticks x9, GPIO42_LONG_TICKS
	b	3f
2:
	gpio42_delay_ticks x9, GPIO42_SHORT_TICKS
3:
	bl	gpio42_led_off
	gpio42_delay_ticks x9, GPIO42_SHORT_TICKS
	lsr	w10, w10, #1
	cbnz	w10, 1b

	gpio42_delay_ticks x9, GPIO42_STAGE_GAP_TICKS
	mov	x30, x12
	ret


gpio42_led_off:
	ldr	x0, =GPIO_GPFSEL4
	ldr	w1, [x0]
	mov	w2, #(7 << GPIO42_SHIFT)
	bic	w1, w1, w2
	mov	w2, #GPIO42_OUTPUT
	orr	w1, w1, w2
	str	w1, [x0]

	ldr	x0, =GPIO_GPCLR1
	mov	w1, #GPIO42_CLR
	str	w1, [x0]
	ret
