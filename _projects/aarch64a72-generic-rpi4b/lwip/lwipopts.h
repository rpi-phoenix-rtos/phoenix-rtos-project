/*
 * Phoenix-RTOS --- lwIP options for Raspberry Pi 4-B (BCM2711)
 *
 * Derived from the armv7a7-imx6ull-evk lwipopts.h. WiFi / IPsec are
 * disabled here because the Pi 4 port stops at Ethernet bring-up
 * (the BCM43455 WiFi work is parked behind the GENET tiers).
 *
 * Copyright 2026 Phoenix Systems
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#define LWIP_TCPIP_CORE_LOCKING      1
/* Deliver RX inline under the core lock instead of posting each packet to the
 * tcpip mailbox. Profiling (GENET_RXSTATS_LOG RXPROF) showed the per-packet
 * netif->input() mbox post+wake cost ~94us/frame at gigabit — the dominant
 * RX-throughput ceiling (raw TCP capped at ~14.5 MB/s = 12% of line rate),
 * far above the driver drain (which keeps up with zero loss). Running
 * tcpip_input() directly in the driver's (thread-context) irqThread removes
 * that cross-thread handoff. Requires LWIP_TCPIP_CORE_LOCKING (above). */
#define LWIP_TCPIP_CORE_LOCKING_INPUT 1
/* LWIP_CHKSUM_ALGORITHM=3 (uncached-pbuf checksum win) now lives in the lwip
 * port's arch/cc.h as the guarded arch default — kept out of here to avoid a
 * redefinition clash with that header. */
#define LWIP_SUPPORT_CUSTOM_PBUF     1
#define LWIP_NETIF_LOOPBACK          1
#define LWIP_HAVE_SLIPIF             0
#define LWIP_NETIF_API               1
#define LWIP_SOCKET                  1
#define LWIP_COMPAT_SOCKETS          0
#define LWIP_ARP                     1
#define LWIP_ICMP                    1
#define LWIP_RAW                     1
#define LWIP_NETPACKET               1
#define LWIP_DHCP                    1
#define LWIP_DNS                     1
#define LWIP_AUTOIP                  1
#define LWIP_UDP                     1
#define LWIP_TCP                     1
#define LWIP_TCP_KEEPALIVE           1
#define MEM_LIBC_MALLOC              1
#define MEMP_MEM_MALLOC              1
#define LWIP_ERRNO_INCLUDE           "errno.h"
#define LWIP_DNS_API_DEFINE_ERRORS   0
#define LWIP_DNS_API_DEFINE_FLAGS    0
#define LWIP_DNS_API_DECLARE_STRUCTS 0
#define LWIP_DNS_API_DECLARE_H_ERRNO 0
#define MEMP_NUM_NETCONN             1024
#define PPP_SUPPORT                  0
#define PPPOS_SUPPORT                0
#define PAP_SUPPORT                  0
#define CHAP_SUPPORT                 0
#define MSCHAP_SUPPORT               0
#define LWIP_TIMEVAL_PRIVATE         0

#define TCP_MSS                       1460
/* Window sizing. HISTORY: a LARGE scaled window (256*MSS + LWIP_WND_SCALE) once
 * BACKFIRED (3.67 vs 8.5 MB/s) — the host burst outran the Pi's RX drain, causing
 * drops/retransmits. That was BEFORE cacheable-RX (256-buf pool) + recvmbox
 * coalescing; the RX drain now sustains gigabit bursts (drop=0/rbuf_ovfl=0 at
 * 24 MB/s). 2026-08-26: profiling showed the SOCKET-recv path is window-credit-
 * LATENCY-bound (throughput = TCP_WND / effective-credit-RTT; 32*MSS / 1.60 ms
 * ≈ 27.9 MB/s, matching the 27.86 measured), NOT RX-drain-bound. So raise the
 * window to 44*MSS = 64240 B — the max without window scaling (<65535) — to widen
 * the credit pipe; predicted socket-recv ≈ 38, NFS toward ~31-33. (The recvmbox
 * coalesce cap stays 32 KB < tot_len's u16_t range, so bigger windows just split
 * chains — safe.) Validated drop=0 + 128 MB NFS sha256 bit-exact before shipping. */
#define TCP_WND                       (44 * TCP_MSS)
#define TCP_SND_BUF                   TCP_WND
#define TCP_SND_QUEUELEN              192
#define ETH_PAD_SIZE                  2
#define ETHARP_TABLE_MATCH_NETIF      1
#define IP_REASSEMBLY                 1
#define IP_FRAG                       1
#define SO_REUSE                      1
#define DEFAULT_THREAD_STACKSIZE      (4 * 4096)
#define TCPIP_THREAD_STACKSIZE        (4 * 4096)
#define TCPIP_THREAD_PRIO             3
#define TCPIP_MBOX_SIZE               256
#define DEFAULT_RAW_RECVMBOX_SIZE     32
#define DEFAULT_UDP_RECVMBOX_SIZE     32
#define DEFAULT_TCP_RECVMBOX_SIZE     32
#define DEFAULT_ACCEPTMBOX_SIZE       32
#define LWIP_HOOK_FILENAME            "phoenix-hooks.h"
#define LWIP_EXT_PF                   1
#define LWIP_NETIF_STATUS_CALLBACK    1
#define LWIP_DHCP_AUTOIP_COOP         1
#define LWIP_DHCP_AUTOIP_COOP_TRIES   3
#define LWIP_SO_RCVTIMEO              1
#define LWIP_SO_SNDTIMEO              1
#define ifreq                         lwip_ifreq
#define LWIP_NETIF_LINK_CALLBACK      1
#define LWIP_LINKMONITOR_DEV          1
#define LWIP_IFSTATUS_DEV_BUFFER_SIZE 1024
#define LWIP_IFSTATUS_DEV             1

#define PBUF_LINK_HLEN             44
#define LWIP_NETIF_REMOVE_CALLBACK 1

#define LWIP_STATS         1
#define LWIP_STATS_DISPLAY 1
#define LINK_STATS         1
#define IP_STATS           1
#define ICMP_STATS         1
#define IGMP_STATS         1
#define IPFRAG_STATS       1
#define UDP_STATS          1
#define TCP_STATS          1
#define MEM_STATS          1
#define MEMP_STATS         1
#define PBUF_STATS         1
#define SYS_STATS          1
