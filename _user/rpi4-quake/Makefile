#
# Phoenix-RTOS
#
# Raspberry Pi 4 (BCM2711) Quakespasm port (GLQuake capstone).
#
# This is the GLQuake flagship *application* — it lives under _user/ (the Phoenix
# in-tree applications project), not phoenix-rtos-devices (those are drivers). It is
# bundled into loader.disk (boot-launched) since a ~19 MB binary cannot be NFS-exec'd
# by the read-based process loader. The launch line is in
# _projects/aarch64a72-generic-rpi4b/user.plo.yaml; it resolves `rpi4-quake` by
# basename out of PREFIX_PROG_STRIPPED, so it is unaffected by which repo builds it.
#
# The engine + Phoenix platform shims are pre-built into libquakespasm.a by
# tools/quakespasm-port/build-quakespasm-phoenix.py (two flag sets: Quake-side TUs
# and the Mesa-side GL-context shim). This program links that archive against the
# ported Mesa GL frontend (libGL-phoenix.a) + v3d gallium driver (libv3d-phoenix.a).
#
# Only aarch64a72 (the Pi 4) builds this: the archives are aarch64 cross-built and
# absolute-pathed into the coordination repo, so for any other _user target this
# component contributes nothing (the guard below leaves ALL_COMPONENTS untouched).
#
# Copyright 2026 Phoenix Systems
# Author: Witold Bołt
#

ifeq ($(TARGET_FAMILY),aarch64a72)

NAME := rpi4-quake
LOCAL_SRCS := rpi4-quake-stub.c

# Stable home for the prebuilt engine archives (was /tmp, which the host reaped
# mid-session). Absolute coord-repo path so it survives prepare-buildroot.sh's
# --copy-components copy into .buildroot (a relative path would resolve inside the
# throwaway copy). Same trick the dropped gl* demos used for headers (V3D_COORD).
GPU_LIBS := /home/houp/phoenix-rpi/tools/.gpu-libs

QS_LIB := $(GPU_LIBS)/libquakespasm.a
V3D_GL_LIB := $(GPU_LIBS)/libGL-phoenix.a
V3D_LIB := $(GPU_LIBS)/libv3d-phoenix.a

# Fail fast with a clear message if a lib is missing, instead of an obscure link error.
$(if $(wildcard $(QS_LIB)),,$(error rpi4-quake: $(QS_LIB) missing — run tools/quakespasm-port/build-quakespasm-phoenix.py))
$(if $(wildcard $(V3D_GL_LIB)),,$(error rpi4-quake: $(V3D_GL_LIB) missing — run tools/v3d-driver-port/build-gl-phoenix.py))
$(if $(wildcard $(V3D_LIB)),,$(error rpi4-quake: $(V3D_LIB) missing — run tools/v3d-driver-port/build-v3d-phoenix.py))

# -z stack-size sets PT_GNU_STACK p_memsz -> the kernel (process.c) uses it as the
# MAIN-thread stack size. Quake runs Host on the main thread (for correct TLS-based
# GL dispatch) and needs a large stack (big frames + recursive renderers): 32 MB.
LOCAL_LDLIBS := -Wl,-z,stack-size=33554432 -Wl,--start-group $(QS_LIB) $(V3D_GL_LIB) $(V3D_LIB) -Wl,--end-group -lstdc++ -lm

include $(binary.mk)

endif
