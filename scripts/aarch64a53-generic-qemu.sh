#!/usr/bin/env bash
#
# Shell script for running Phoenix-RTOS on QEMU (aarch64a53-generic-qemu)
#
# Copyright 2026 Phoenix Systems
#

IMG_PLO_GENERIC="$(dirname "${BASH_SOURCE[0]}")/../_boot/aarch64a53-generic-qemu/plo.elf"
IMG_LOADER_GENERIC="$(dirname "${BASH_SOURCE[0]}")/../_boot/aarch64a53-generic-qemu/loader.disk"

for FILE in "$IMG_PLO_GENERIC" "$IMG_LOADER_GENERIC"; do
	if [ ! -f "$FILE" ]; then
		echo "Missing required file: $FILE"
		exit 1
	fi
done

exec qemu-system-aarch64 \
	-machine virt,secure=on,gic-version=2 \
	-cpu cortex-a53 \
	-smp 1 \
	-m 1G \
	-serial null \
	-serial mon:stdio \
	-display none \
	-kernel "$IMG_PLO_GENERIC" \
	-device loader,file="$IMG_LOADER_GENERIC",addr=0x48000000,force-raw=on \
	"$@"
