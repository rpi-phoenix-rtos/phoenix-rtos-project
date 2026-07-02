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
# mid-session). Must resolve to the coordination-repo tools/.gpu-libs so it survives
# prepare-buildroot.sh's --copy-components copy into buildroots/ (a source-relative
# path would resolve inside the throwaway copy). Both real build locations —
# sources/phoenix-rtos-project/_user/rpi4-quake and buildroots/.../_user/rpi4-quake —
# are exactly four path segments below the repo root, so climbing ../../../.. from
# this Makefile's own directory lands on the repo root in either case. Overridable
# via the environment (GPU_LIBS=...) for out-of-tree archive locations.
GPU_LIBS ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../..)/tools/.gpu-libs

QS_LIB := $(GPU_LIBS)/libquakespasm.a
V3D_GL_LIB := $(GPU_LIBS)/libGL-phoenix.a
V3D_LIB := $(GPU_LIBS)/libv3d-phoenix.a

# The GL/GPU archives are produced by out-of-band manual builds (tools/*-port/*.py),
# not by the automated core build. When they are absent (e.g. a fresh clone that only
# builds the base image), skip this component gracefully rather than aborting the whole
# `make -C _user all`: not including binary.mk means NAME is never added to
# ALL_COMPONENTS, so all/install/clean simply never reference rpi4-quake. When the
# archives ARE present the component links exactly as before.
ifeq ($(and $(wildcard $(QS_LIB)),$(wildcard $(V3D_GL_LIB)),$(wildcard $(V3D_LIB))),)

$(info rpi4-quake: GPU libs not present in $(GPU_LIBS), skipping (run tools/quakespasm-port/build-quakespasm-phoenix.py + tools/v3d-driver-port/build-gl-phoenix.py + build-v3d-phoenix.py to enable))

else

# -z stack-size sets PT_GNU_STACK p_memsz -> the kernel (process.c) uses it as the
# MAIN-thread stack size. Quake runs Host on the main thread (for correct TLS-based
# GL dispatch) and needs a large stack (big frames + recursive renderers): 32 MB.
LOCAL_LDLIBS := -Wl,-z,stack-size=33554432 -Wl,--start-group $(QS_LIB) $(V3D_GL_LIB) $(V3D_LIB) -Wl,--end-group -lstdc++ -lm

include $(binary.mk)

endif

endif
