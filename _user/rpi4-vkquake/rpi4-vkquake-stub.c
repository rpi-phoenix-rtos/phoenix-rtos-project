/*
 * rpi4-vkquake-stub.c — placeholder translation unit for the rpi4-vkquake program.
 *
 * The actual vkQuake engine (including main(), in pl_phoenix_main.o) lives in
 * tools/.gpu-libs/libvkquake.a, built by tools/vkquake-port/build-vkquake-phoenix.py --link
 * with the correct per-file flag sets (engine vs Vulkan vid-shim). binary.mk needs
 * a LOCAL_SRCS file to produce the program; the linker pulls main() (and transitively
 * the whole engine) from the archive via crt0's reference to main.
 */
int rpi4_vkquake_stub_marker;
