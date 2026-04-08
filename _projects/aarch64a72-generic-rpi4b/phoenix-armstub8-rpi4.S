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

#define BIT(x) (1 << (x))

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

	.section .text
	.globl _start
_start:
	msr	cntvoff_el2, xzr
	mov	x0, #0x3
	msr	cnthctl_el2, x0

	msr	cptr_el3, xzr
	mov	x0, #SCR_VAL
	msr	scr_el3, x0

	mov	x0, #CPUECTLR_EL1_SMPEN
	msr	CPUECTLR_EL1, x0

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
	ldr	w4, kernel_entry32
	ldr	w0, dtb_ptr32
	mov	x1, #0
	mov	x2, #0
	mov	x3, #0
	br	x4

	.ltorg

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
