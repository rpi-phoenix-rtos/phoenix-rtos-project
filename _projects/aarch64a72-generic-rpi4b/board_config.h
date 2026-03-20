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

#define PLO_GICD_BASE_ADDRESS  0x40041000u
#define PLO_GICC_BASE_ADDRESS  0x40042000u
#define PLO_UART0_BASE_ADDRESS 0xfe201000u

#define PL011_TTY_BASE  0xfe201000u
#define PL011_TTY_CLOCK 48000000u

#endif
