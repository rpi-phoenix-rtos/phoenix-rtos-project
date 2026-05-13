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
#define OSC_FREQ        54000000
#define PI4_KERNEL_FALLBACK_ENTRY 0x00080000
#define UARTDR_OFFSET   0x0
#define UARTFR_OFFSET   0x18
#define UARTIBRD_OFFSET 0x24
#define UARTFBRD_OFFSET 0x28
#define UARTLCRH_OFFSET 0x2c
#define UARTCR_OFFSET   0x30
#define UARTFR_TXFF     BIT(5)

#define SCR_RW       BIT(10)
#define SCR_HCE      BIT(8)
#define SCR_RES1_5   BIT(5)
#define SCR_RES1_4   BIT(4)
#define SCR_NS       BIT(0)
#define SCR_VAL (SCR_RW | SCR_HCE | SCR_RES1_5 | SCR_RES1_4 | SCR_NS)

#define CPUECTLR_EL1       S3_1_C15_C2_1
#define CPUECTLR_EL1_SMPEN BIT(6)

/*
 * A72 erratum 859971 — disable instruction prefetch.
 * Mirrors ATF cortex_a72.h CORTEX_A72_CPUACTLR_EL1_DIS_INSTR_PREFETCH (bit 32).
 * Must be applied at EL3 because S3_1_C15_C2_0 (CPUACTLR_EL1) traps from
 * EL1 on A72 r0p3; Phoenix's earlier kernel-side attempt at this write
 * hung silently at the MRS. ATF's cortex_a72_reset_func applies the same
 * RMW unconditionally for r0p3.
 */
#define CPUACTLR_EL1                    S3_1_C15_C2_0
#define CPUACTLR_EL1_DIS_INSTR_PREFETCH (1UL << 32)

/*
 * A72 erratum 1319367 — Speculative AT instruction using out-of-context
 * translation regime could cause subsequent request to generate an
 * incorrect translation. Affects ALL r0p0..r0p3 (Pi 4 is r0p3).
 *
 * Reference: ARM-EPM-012079 Cortex-A72 SDEN, erratum 1319367.
 * Workaround: set CPUACTLR2_EL1.bit[0] = 1.
 * TF-A applies this UNCONDITIONALLY for r0p3 in
 * `lib/cpus/aarch64/cortex_a72.S` (`errata_a72_1319367_wa`).
 *
 * Symptom when missing: after the OS enables MMU and caches, an
 * unrelated translation request can return a stale or wrong TLB
 * result. The OS then reads garbage from what it believes is a
 * valid mapped address — wild pointers, bit-flipped descriptors,
 * etc. EXACTLY the failure mode plo has been hitting on this port.
 *
 * Phoenix-RTOS's previous cache-enable attempts (M+C, M+C+I) failed
 * with exactly this signature; standard rpi-tools armstub also does
 * not apply 1319367, so any port that exercises EL1/EL2 stage-1
 * translation under load on Pi 4 will likely hit this.
 */
#define CPUACTLR2_EL1                   S3_1_C15_C2_2
#define CPUACTLR2_EL1_ERRATA_1319367_WA BIT(0)

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

	.macro uart_reinit_115200
	ldr	x8, =PL011_TTY_BASE
	mov	w9, wzr
	str	w9, [x8, #UARTCR_OFFSET]
	mov	w9, #26
	str	w9, [x8, #UARTIBRD_OFFSET]
	mov	w9, #3
	str	w9, [x8, #UARTFBRD_OFFSET]
	mov	w9, #0x70
	str	w9, [x8, #UARTLCRH_OFFSET]
	mov	w9, #0x301
	str	w9, [x8, #UARTCR_OFFSET]
	dsb	sy
	isb
	.endm

	.macro uart_putc imm
991:
	ldr	x8, =PL011_TTY_BASE
	ldr	w9, [x8, #UARTFR_OFFSET]
	tst	w9, #UARTFR_TXFF
	b.ne	991b
	mov	w9, #\imm
	str	w9, [x8, #UARTDR_OFFSET]
	.endm

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
	mov	x28, x0
	mrs	x7, mpidr_el1
	and	x7, x7, #0x3
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

	/*
	 * A72 EL3-only prerequisites for kernel-side cache enable.
	 * CPUECTLR_EL1 (S3_1_C15_C2_1) and CPUACTLR_EL1 (S3_1_C15_C2_0)
	 * trap from EL1 on A72 r0p3, so the kernel cannot apply these
	 * itself — empirically observed in earlier Phase A attempts.
	 * ATF's cortex_a72_reset_func applies the same pair.
	 *
	 * ORDER MATTERS on A72: CPUACTLR_EL1 must be written BEFORE
	 * SMPEN. Writes to CPUACTLR_EL1 after the core has joined the
	 * coherency domain (SMPEN=1) may be silently dropped on r0..r0p3.
	 * Match TF-A `cpu_reset_func_start cortex_a72` ordering.
	 */
	/* (1) Erratum 859971: CPUACTLR_EL1[32] DIS_INSTR_PREFETCH.
	 *     Required for I-cache to be safe to enable on A72 r0..r0p3.
	 *     RMW to preserve impl-def reset bits.
	 *     'orr (immediate)' cannot encode (1<<32); materialise it via x1.
	 */
	mrs	x0, CPUACTLR_EL1
	mov	x1, #CPUACTLR_EL1_DIS_INSTR_PREFETCH
	orr	x0, x0, x1
	msr	CPUACTLR_EL1, x0
	uart_putc 49	/* '1' — 859971 done */

	/* (2) Erratum 1319367: CPUACTLR2_EL1[0] = 1. Speculative AT
	 *     across translation-regime boundary can produce stale TLB
	 *     results. Affects all r0p0..r0p3 (Pi 4 is r0p3). TF-A
	 *     applies this unconditionally. Phoenix's previous cache-
	 *     enable failures (wild-pointer reads after SCTLR.C=1)
	 *     match the erratum's documented failure mode. */
	mrs	x0, CPUACTLR2_EL1
	orr	x0, x0, #CPUACTLR2_EL1_ERRATA_1319367_WA
	msr	CPUACTLR2_EL1, x0
	uart_putc 51	/* '3' — 1319367 done */

	/* (3) SMPEN — coherency on; required for inner-shareable D-cache.
	 *     Must come AFTER the CPUACTLR writes above. */
	mrs	x0, CPUECTLR_EL1
	orr	x0, x0, #CPUECTLR_EL1_SMPEN
	msr	CPUECTLR_EL1, x0
	uart_putc 50	/* '2' — SMPEN done */

	dsb	sy
	isb

	bl setup_gic

	ldr	x0, =0x30c50830
	msr	sctlr_el2, x0

	mov	x0, #SPSR_EL3_VAL
	msr	spsr_el3, x0
	adr	x0, in_el2
	msr	elr_el3, x0
	eret

in_el2:
	adr	x0, vectors_el2
	msr	vbar_el2, x0
	isb

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
	b	primary_cpu_late

primary_cpu_late:
	/*
	 * Restore the standard Pi firmware handoff contract here:
	 * - x0 receives the firmware-provided DTB pointer
	 * - x4 receives the firmware-provided kernel entry address
	 *
	 * The earlier fixed-address target probing turned the late armstub seam
	 * into the failure site itself on real hardware. Keep the proof points,
	 * but stop dereferencing the target image before the branch.
	 */
	ldr	w5, dtb_ptr32
	cbnz	x5, 0f
	mov	x5, x28
0:
	ldr	w4, kernel_entry32
	cbnz	x4, 1f
	ldr	x4, =PI4_KERNEL_FALLBACK_ENTRY
1:
	uart_reinit_115200
	uart_putc 65
	uart_putc 83
	uart_putc 48
	uart_putc 13
	uart_putc 10
	mov	x0, x5
	dsb	sy
	isb
	br	x4

	.align 11
vectors_el2:
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80
	b	armstub_exception
	.balign 0x80

armstub_exception:
2:
	wfe
	b	2b

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
