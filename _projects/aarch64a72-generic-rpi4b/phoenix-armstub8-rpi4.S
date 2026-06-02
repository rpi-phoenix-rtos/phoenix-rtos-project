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

#define CPUECTLR_EL1                             S3_1_C15_C2_1
#define CPUECTLR_EL1_SMPEN                       BIT(6)
#define CPUECTLR_EL1_DIS_TWALK_DESC_PREFETCH     (1UL << 38)
#define CPUECTLR_EL1_L2_IFETCH_PREFETCH_DISTANCE (3UL << 35)
#define CPUECTLR_EL1_L2_LS_PREFETCH_DISTANCE     (3UL << 32)

/*
 * BCM2711 silicon requires non-default L2 cache RAM timing for the
 * 1 MB Cortex-A72 cluster L2 to be reliable at the Pi 4's 1.5 GHz
 * fmax. Cortex-A72 TRM defaults assume tighter RAM timing than
 * BCM2711 silicon can meet, so the first cacheable D-side fill after
 * `SCTLR.C=1` can return corrupt data.
 *
 * Bit [0]: Data RAM Latency = 3 cycles (default 0 = 2 cycles)
 * Bit [5]: Data RAM Setup   = 1 cycle  (default 0 = 0 cycles)
 *
 * Every other working bare-metal RPi 4 stack sets this:
 *   - Canonical raspberrypi/tools/armstubs/armstub8.S
 *   - Trusted Firmware-A plat/rpi/common/aarch64/plat_helpers.S
 *     (plat_reset_handler for rpi4)
 *   - Circle boot/armstub/armstub8.S
 *
 * Phoenix-RTOS did NOT have this until 2026-05-17. The post-MMU/cache
 * crash signature on Pi 4 (EX=4 / ESR=0x02000000 EC=Unknown / FAR=0
 * / ELR at the first cacheable LDR after the M|C|I write) is
 * consistent with corrupt L2 RAM reads at the inaugural D-cache
 * fill.
 */
#define L2CTLR_EL1                  S3_1_C11_C0_2
#define L2CTLR_EL1_DATA_RAM_LATENCY (1UL << 1)   /* 3 cycles */
#define L2CTLR_EL1_DATA_RAM_SETUP   (1UL << 5)   /* 1 cycle  */

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
#define CPUACTLR_EL1_DIS_LOAD_PASS_STORE (1UL << 55)
#define CPUACTLR_EL1_DIS_L1D_HW_PREFETCH (1UL << 56)

/*
 * A72 erratum 1319367 — Speculative AT instruction using out-of-context
 * translation regime could cause subsequent request to generate an
 * incorrect translation. Affects ALL r0p0..r0p3 (Pi 4 is r0p3).
 *
 * Reference: ARM-EPM-012079 Cortex-A72 SDEN, erratum 1319367.
 *
 * CORRECT WORKAROUND (2026-05-17 fix): `CPUACTLR_EL1[46] = 1`
 * (DIS_HW_PAGE_AGGREGATION). SAME register as 859971, different bit.
 * Confirmed in TF-A `lib/cpus/aarch64/cortex_a72.S errata_a72_1319367_wa`
 * and Phoenix's own deep-dive doc `docs/plans/a72-errata-sweep.md`
 * line 98.
 *
 * PRIOR BROKEN ENCODING (now removed): Phoenix earlier wrote
 * `CPUACTLR2_EL1[0]` with `CPUACTLR2_EL1` defined as `S3_1_C15_C2_2`.
 * That encoding is NOT a documented A72 system register — see ATF
 * `cortex_a72.h` for the real CPUACTLR2_EL1 encoding (S3_1_C15_C0_4
 * on A72, used only for CVE-2018-3639 SSBD). Writing to an undefined
 * impl-defined sysreg can either trap silently (no visible effect)
 * or hit whatever physical reg lives at that encoding, corrupting
 * adjacent state. The post-MMU/cache crash signature
 * (EC=0x00 Unknown reason, FAR=0, ELR=first cacheable load after
 * SCTLR M|C|I) is consistent with that corruption.
 */
#define CPUACTLR_EL1_ERRATA_1319367_WA (1UL << 46)

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

	/* SMP-D-3 diagnostic: memory-based per-CPU markers. Each cpu
	 * writes 0x10000000 + cpu_id to PA 0x40 + cpu_id*4 (in armstub
	 * memory, no firmware data lives there). No UART contention,
	 * one MMIO write per cpu, full cache-coherency between cpu
	 * and the kernel-side reader. The kernel reads PA 0x40-0x4F
	 * at boot via a TTBR0 identity mapping and prints which cpus
	 * reached the armstub.
	 *
	 * Why memory not UART: the previous ";X<digit>" UART marker
	 * fired only on cpu3 in a single test, but UART contention
	 * (and possibly firmware leaving PL011 in an unusable state
	 * for some cores) could've masked cpu1/cpu2. Memory writes
	 * have no such ambiguity.
	 *
	 * x7 = cpu id (preserved across the block).
	 * Clobbers x8 (PA), x9 (value). */
	mov	x8, #0x40
	add	x8, x8, x7, lsl #2
	mov	w9, #0x10000000
	add	w9, w9, w7
	str	w9, [x8]
	dsb	sy
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
	 *
	 *     2026-05-17: bit 46 (DIS_HW_PAGE_AGGREGATION) added here too —
	 *     that is the CORRECT 1319367 workaround per TF-A
	 *     `cortex_a72.S errata_a72_1319367_wa` and Phoenix doc
	 *     `docs/plans/a72-errata-sweep.md` line 98. The prior code
	 *     wrote `CPUACTLR2_EL1[0]` with `CPUACTLR2_EL1` = S3_1_C15_C2_2
	 *     — an undefined A72 sysreg encoding. That write was a no-op
	 *     at best, silent state corruption at worst. */
	mrs	x0, CPUACTLR_EL1
	mov	x1, #CPUACTLR_EL1_DIS_INSTR_PREFETCH
	orr	x0, x0, x1
	mov	x1, #CPUACTLR_EL1_ERRATA_1319367_WA
	orr	x0, x0, x1
	movz	x1, #0x0180, lsl #48
	orr	x0, x0, x1	/* C-3v/w: disable L1D prefetch + load-pass-store. */
	msr	CPUACTLR_EL1, x0
	uart_putc 49	/* '1' — 859971 + 1319367 done */

	/* (3) C-3v/w: disable A72 L2/table-walk prefetch before SMPEN. */
	mrs	x0, CPUECTLR_EL1
	movz	x1, #0x001b, lsl #32
	bic	x0, x0, x1
	movz	x1, #0x0040, lsl #32
	orr	x0, x0, x1
	msr	CPUECTLR_EL1, x0
	uart_putc 52	/* '4' — L2 prefetch policy done */

	/* (4) SMPEN — coherency on; required for inner-shareable D-cache.
	 *     Must come AFTER the CPUACTLR writes above. */
	mrs	x0, CPUECTLR_EL1
	orr	x0, x0, #CPUECTLR_EL1_SMPEN
	msr	CPUECTLR_EL1, x0
	uart_putc 50	/* '2' — SMPEN done */

	/* (5) L2CTLR_EL1 RAM timing for BCM2711 silicon (2026-05-17).
	 *     Bit 1 = Data RAM Latency 3 cycles, Bit 5 = Data RAM Setup
	 *     1 cycle. Required for the cluster L2 to return correct data
	 *     at 1.5 GHz. Every other working RPi 4 bare-metal stack
	 *     (canonical RPi armstub8, TF-A, Circle) does this. Missing
	 *     this on Pi 4 is the strongest external signal we found for
	 *     "first cacheable load after SCTLR M|C|I returns garbage". */
	mrs	x0, L2CTLR_EL1
	orr	x0, x0, #L2CTLR_EL1_DATA_RAM_LATENCY
	orr	x0, x0, #L2CTLR_EL1_DATA_RAM_SETUP
	msr	L2CTLR_EL1, x0
	uart_putc 53	/* '5' — L2CTLR timing programmed */

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

	/* On cpu0 only: clear spin_cpu1/2/3 to 0. The Pi 4 SDRAM contents
	 * after a power-cycle are not deterministically zero, and the
	 * previous boot's plo may have left stale entry-point PAs in
	 * these slots. If secondaries wake from WFE seeing a stale
	 * non-zero value, they would branch to an obsolete address. */
	cbnz	x6, 9710f
	mov	x9, #0xe0
	str	xzr, [x9]
	mov	x9, #0xe8
	str	xzr, [x9]
	mov	x9, #0xf0
	str	xzr, [x9]
	dsb	sy
9710:

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
