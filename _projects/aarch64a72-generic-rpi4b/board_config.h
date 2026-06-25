/*
 * Phoenix-RTOS
 *
 * Board config for aarch64a72-generic-rpi4b
 *
 * Copyright 2026 Phoenix Systems
 *
 * This file is part of Phoenix-RTOS.
 *
 * %LICENSE%
 */

#ifndef _BOARD_CONFIG_H_
#define _BOARD_CONFIG_H_

#define PLO_GICD_BASE_ADDRESS  0xff841000u
#define PLO_GICC_BASE_ADDRESS  0xff842000u
#define PLO_UART0_BASE_ADDRESS 0xfe201000u
#define RAM_ADDR 0x08000000u
#define RAM_BANK_SIZE 0x08000000u
#define PLO_RPI_PLO_DEST 0x00200000u
#define PLO_RPI_FIXED_ENTRY_SIGNATURE_OFFSET 0x4u
#define PLO_RPI_FIXED_ENTRY_SIGNATURE0 0x504c4f34u
#define PLO_RPI_FIXED_ENTRY_SIGNATURE1 0x454e5452u
#define PLO_RPI_MAILBOX_BASE_ADDRESS 0xfe00b880u
#define PLO_RPI_MAILBOX_BUFFER_ADDRESS 0x02000000u
#define RPI_MAILBOX_BASE_ADDRESS 0xfe00b880u
#define PLO_RPI_FB_WIDTH            1920u
#define PLO_RPI_FB_HEIGHT           1080u
#define PLO_RPI_FB_BPP              32u
#define HAS_GRAPHICS                1

#define PL011_TTY_BASE  0xfe201000u
#define PL011_TTY_CLOCK 48000000u
#define PL011_TTY_EARLY_VADDR 0xffffffffffe00000ull
#define PL011_TTY_KBD_PATH "/dev/kbd0"
#define PCIE_BCM2711_HOST_BASE 0xfd500000u
#define PCIE_BCM2711_HOST_SIZE 0x00010000u
#define PCIE_BCM2711_OUTBOUND_CPU_BASE  0x600000000ull
#define PCIE_BCM2711_OUTBOUND_PCIE_BASE 0xf8000000ull
#define PCIE_BCM2711_OUTBOUND_SIZE      0x04000000ull
#define XHCI_BCM2711_PCIE_BUS          1u
#define XHCI_BCM2711_PCIE_SLOT         0u
#define XHCI_BCM2711_PCIE_FUNC         0u
#define XHCI_BCM2711_PCI_CLASS_CODE    0x0c0330u
#define XHCI_BCM2711_MMIO_BASE         PCIE_BCM2711_OUTBOUND_CPU_BASE

/* SMP Phase A: enable plo's two-stage secondary release from armstub
 * spin-table into the kernel. Cores 1-3 wake, park in plo's
 * secondary_handoff busy-poll, and proceed to the kernel's
 * _other_core_trap once plo writes kernel entry PA into spin_cpuN.
 *
 * The earlier Phase B re-entry pathology (secondaries re-running the
 * trap routine many times per boot) was observed via UART markers
 * that have since been stripped, so re-enabling the gate is silent
 * on UART. Boot stability with secondaries reaching the kernel is
 * the next thing to verify on real hardware. */
#define PLO_SMP_ENABLE 1

/* TD-14/observability: the kernel klog ring (default 2 KB) is drained to the
 * UART + HDMI fbcon only by userspace libklog/pl011-tty, which attaches LATE in
 * boot. With 2 KB the early-boot lib_printf output overflows the ring before the
 * drain starts, so a NON-DETERMINISTIC amount of early kernel log survives to be
 * replayed — the confirmed cause of "UART/HDMI show long logs on some boots,
 * short on others." Size the ring to hold the entire pre-drain boot log so every
 * boot replays the same complete log to both UART and HDMI. */
#define KERNEL_LOG_SIZE (64 * 1024)

/* Task #31 — logging build mode (single source of truth).
 *
 *   0 (default, "DEBUG") — kernel log (klog) is printed to the console exactly
 *     as today: the kernel mirrors every klog byte to the UART (log/log.c) and
 *     pl011-tty drains the klog ring to the HDMI fbcon. This is the safety
 *     contract: with the macro at 0 the console behavior is byte-for-byte the
 *     historical behavior, so a logging bug cannot regress console visibility.
 *
 *   1 ("USER") — the verbose klog console output is SUPPRESSED on BOTH console
 *     sinks (the UART mirror in log_write() and the pl011-tty fbcon drain).
 *     Panic / critical kernel output is still mirrored to the UART (log_write's
 *     panic path is never gated). The klog is instead captured to
 *     /var/log/messages by the rpi4-klogd daemon, viewable with `logread`.
 *     This keeps the interactive console quiet (psh's own output still shows)
 *     while preserving the full log in a file (Linux-like).
 *
 * Two kinds of consumer reach this one definition two ways:
 *   - Compile-time console sinks (log/log.c, pl011-tty.c — both include this
 *     header) read the macro directly via #if.
 *   - The rpi4-klogd plo launch gate: scripts/rebuild-rpi4b-fast.sh greps this
 *     macro and exports a matching RPI4_LOG_TO_FILE env var (same mechanism as
 *     --variant -> RPI4B_VARIANT), and user.plo.yaml gates the launch on it. So
 *     the macro and the launch are derived from one place and cannot desync.
 *
 * To enable USER mode: set this to 1 and rebuild core
 * (./scripts/rebuild-rpi4b-fast.sh --scope core). See
 * docs/inprogress/2026-06-25-logging-var-log.md.
 */
#ifndef RPI4_LOG_TO_FILE
#define RPI4_LOG_TO_FILE 0
#endif

#endif
