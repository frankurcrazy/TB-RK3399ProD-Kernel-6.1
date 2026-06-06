# Toybrick RK3399ProD Linux Kernel

This repository contains a Rockchip vendor Linux 6.1 kernel tree adapted for
the Toybrick RK3399ProD production board.

The tree was forked from a Rockchip 6.1 vendor kernel and ported from the older
Toybrick 4.4 board support package. The port keeps compatibility with the
legacy Toybrick U-Boot 2017.09 boot flow while enabling the board to boot a
modern Linux userspace from eMMC.

## Board Support

The current board target is:

- SoC: Rockchip RK3399Pro
- Board: Toybrick RK3399ProD production board
- Architecture: arm64
- Defconfig: `rockchip_linux_defconfig`
- Device tree: `rockchip/rk3399pro-toybrick-prod-linux.dtb`

Major board-level work in this tree includes:

- eMMC boot and root filesystem support with the existing Toybrick partition
  layout
- Compatibility fixes for the legacy Toybrick U-Boot GPIO, MMC and bootarg
  expectations
- HDMI display bring-up with framebuffer console support
- RK809 PMIC, RTC, regulator and audio codec support
- Status LED, fan, USB host/OTG and Type-C support
- RTL8723DU Wi-Fi and RTL8723D Bluetooth support, including firmware loading
- RK3399Pro NPU-related board integration
- Cleanup of board-specific DTS and driver issues found during bring-up

## PREEMPT_RT

This branch adds PREEMPT_RT support for improved real-time latency.

The base kernel reports `6.1.118`. The closest applicable official RT patch in
the Linux RT 6.1 series is `patch-6.1.119-rt45`, which has been applied and
adapted to this Rockchip vendor tree.

Notable RT-related changes:

- `CONFIG_PREEMPT_RT=y` is enabled in `rockchip_linux_defconfig`
- `localversion-rt` adds the `-rt45` kernel release suffix
- RT core changes are applied across scheduler, locking, softirq, printk, RCU,
  networking and serial console paths
- 8250 serial conflicts were resolved while preserving Rockchip-specific
  `UART_IER_PTIME` behavior
- RTL8723DU/rtw88 paths were adjusted for PREEMPT_RT by avoiding sleeping USB
  register operations in atomic station iterators and by serializing H2C/RF
  accesses with mutexes where those operations may sleep
- Rockchip USB2 PHY charger detection no longer keeps a mutex held across
  delayed work instances, avoiding a DWC3 runtime-resume rtmutex self-deadlock
  seen during boot

The expected kernel release string is:

```text
6.1.118-rt45
```

## Built-In Firewall Support

The board image is intended to run nftables and UFW without loading netfilter
modules from the root filesystem. The following options are built into the
kernel image with `=y`.

Core BPF and cgroup support:

```text
CONFIG_BPF_SYSCALL
CONFIG_BPF_JIT
CONFIG_CGROUP_BPF
```

Netfilter, conntrack, NAT, logging and flow table support:

```text
CONFIG_NETFILTER
CONFIG_NETFILTER_NETLINK_QUEUE
CONFIG_NETFILTER_NETLINK_LOG
CONFIG_NF_CONNTRACK
CONFIG_NF_CONNTRACK_EVENTS
CONFIG_NF_CONNTRACK_TIMESTAMP
CONFIG_NF_CONNTRACK_BRIDGE
CONFIG_NF_NAT
CONFIG_NF_LOG_SYSLOG
CONFIG_NF_LOG_ARP
CONFIG_NF_LOG_IPV4
CONFIG_NF_LOG_IPV6
CONFIG_NF_FLOW_TABLE
CONFIG_NF_FLOW_TABLE_INET
```

nftables families and expressions:

```text
CONFIG_NF_TABLES
CONFIG_NF_TABLES_INET
CONFIG_NF_TABLES_NETDEV
CONFIG_NF_TABLES_IPV4
CONFIG_NF_TABLES_IPV6
CONFIG_NF_TABLES_ARP
CONFIG_NF_TABLES_BRIDGE
CONFIG_NFT_NUMGEN
CONFIG_NFT_CT
CONFIG_NFT_FLOW_OFFLOAD
CONFIG_NFT_CONNLIMIT
CONFIG_NFT_LOG
CONFIG_NFT_LIMIT
CONFIG_NFT_MASQ
CONFIG_NFT_REDIR
CONFIG_NFT_NAT
CONFIG_NFT_TUNNEL
CONFIG_NFT_OBJREF
CONFIG_NFT_QUEUE
CONFIG_NFT_QUOTA
CONFIG_NFT_REJECT
CONFIG_NFT_REJECT_INET
CONFIG_NFT_COMPAT
CONFIG_NFT_HASH
CONFIG_NFT_FIB_INET
CONFIG_NFT_FIB_IPV4
CONFIG_NFT_FIB_IPV6
CONFIG_NFT_XFRM
CONFIG_NFT_SOCKET
CONFIG_NFT_TPROXY
CONFIG_NFT_SYNPROXY
CONFIG_NFT_DUP_IPV4
CONFIG_NFT_DUP_IPV6
CONFIG_NFT_DUP_NETDEV
CONFIG_NFT_FWD_NETDEV
CONFIG_NFT_FIB_NETDEV
CONFIG_NFT_REJECT_NETDEV
CONFIG_NFT_BRIDGE_META
CONFIG_NFT_BRIDGE_REJECT
```

iptables-nft and UFW compatibility:

```text
CONFIG_NETFILTER_XT_TARGET_LOG
CONFIG_NETFILTER_XT_TARGET_MARK
CONFIG_NETFILTER_XT_TARGET_NFLOG
CONFIG_NETFILTER_XT_TARGET_REJECT
CONFIG_NETFILTER_XT_TARGET_TCPMSS
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
CONFIG_NETFILTER_XT_MATCH_COMMENT
CONFIG_NETFILTER_XT_MATCH_CONNTRACK
CONFIG_NETFILTER_XT_MATCH_HL
CONFIG_NETFILTER_XT_MATCH_LENGTH
CONFIG_NETFILTER_XT_MATCH_LIMIT
CONFIG_NETFILTER_XT_MATCH_MARK
CONFIG_NETFILTER_XT_MATCH_MULTIPORT
CONFIG_NETFILTER_XT_MATCH_PKTTYPE
CONFIG_NETFILTER_XT_MATCH_RECENT
CONFIG_NETFILTER_XT_MATCH_STATE
CONFIG_NETFILTER_XT_MATCH_TCPMSS
CONFIG_IP_NF_IPTABLES
CONFIG_IP_NF_FILTER
CONFIG_IP_NF_TARGET_REJECT
CONFIG_IP_NF_NAT
CONFIG_IP_NF_TARGET_MASQUERADE
CONFIG_IP_NF_MANGLE
CONFIG_IP_NF_RAW
CONFIG_IP6_NF_IPTABLES
CONFIG_IP6_NF_MATCH_RT
CONFIG_IP6_NF_FILTER
CONFIG_IP6_NF_TARGET_REJECT
CONFIG_IP6_NF_MANGLE
CONFIG_IP6_NF_RAW
CONFIG_IP6_NF_NAT
CONFIG_IP6_NF_TARGET_MASQUERADE
```

Bridge and VLAN firewalling support:

```text
CONFIG_BRIDGE
CONFIG_VLAN_8021Q
CONFIG_BRIDGE_VLAN_FILTERING
```

## Build

Use the project build helper from the repository root:

```bash
./make_toybrick_boot_linux.sh
```

The script runs `rockchip_linux_defconfig`, builds the arm64 kernel image and
Toybrick DTB, then packages them into:

```text
boot_linux.img
```

Main outputs:

- `arch/arm64/boot/Image`
- `arch/arm64/boot/dts/rockchip/rk3399pro-toybrick-prod-linux.dtb`
- `boot_linux.img`
