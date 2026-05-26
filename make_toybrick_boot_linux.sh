#!/bin/bash

set -euo pipefail

VERSION="2.0"
BOARD="${1:-prod}"
JOBS="$(nproc)"
TOP_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGE_DIR="${TOP_DIR}/boot_linux"
IMAGE_PATH="${TOP_DIR}/arch/arm64/boot/Image"
DTB_NAME="rk3399pro-toybrick-prod-linux.dtb"
DTB_PATH="${TOP_DIR}/arch/arm64/boot/dts/rockchip/${DTB_NAME}"
INITRAMFS_PATH="${TOP_DIR}/../tb_kernel/initramfs-toybrick-${VERSION}.img"
RESCUE_PATH="${TOP_DIR}/../tb_kernel/rescue.sh"
DEFAULT_TOOLCHAIN="${TOP_DIR}/../prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"

if [[ "${BOARD}" != "prod" ]]; then
	echo "Only the prod board is supported by this helper right now." >&2
	exit 1
fi

if [[ -z "${CROSS_COMPILE:-}" ]]; then
	if [[ -x "${DEFAULT_TOOLCHAIN}gcc" ]]; then
		export CROSS_COMPILE="${DEFAULT_TOOLCHAIN}"
	elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
		export CROSS_COMPILE="aarch64-linux-gnu-"
	else
		echo "No usable aarch64 cross compiler found." >&2
		exit 1
	fi
fi

if [[ ! -f "${INITRAMFS_PATH}" ]]; then
	echo "Missing initramfs: ${INITRAMFS_PATH}" >&2
	exit 1
fi

if [[ ! -f "${RESCUE_PATH}" ]]; then
	echo "Missing rescue script: ${RESCUE_PATH}" >&2
	exit 1
fi

make ARCH=arm64 rockchip_linux_defconfig
make ARCH=arm64 Image rockchip/${DTB_NAME} -j"${JOBS}"

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/extlinux"

cp -f "${IMAGE_PATH}" "${STAGE_DIR}/extlinux/Image"
cp -f "${DTB_PATH}" "${STAGE_DIR}/extlinux/toybrick.dtb"
cp -f "${DTB_PATH}" "${STAGE_DIR}/extlinux/toybrick-default.dtb"
cp -f "${INITRAMFS_PATH}" "${STAGE_DIR}/"
cp -f "${RESCUE_PATH}" "${STAGE_DIR}/"

printf '%b' \
	"label rockchip-kernel-6.1\n" \
	"\tkernel /extlinux/Image\n" \
	"\tfdt /extlinux/toybrick.dtb\n" \
	"\tappend earlycon=uart8250,mmio32,0xff1a0000 initrd=/initramfs-toybrick-${VERSION}.img root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rw rootwait rootfstype=ext4\n" \
	> "${STAGE_DIR}/extlinux/extlinux.conf"

rm -f "${TOP_DIR}/boot_linux.img"

if command -v mke2fs >/dev/null 2>&1; then
	mke2fs -F -b 4096 -d "${STAGE_DIR}" -i 8192 -t ext2 "${TOP_DIR}/boot_linux.img" "$((64 * 1024 * 1024 / 4096))"
elif command -v genext2fs >/dev/null 2>&1; then
	genext2fs -b 32768 -B "$((64 * 1024 * 1024 / 32768))" -d "${STAGE_DIR}" -i 8192 -U "${TOP_DIR}/boot_linux.img"
else
	echo "Neither mke2fs nor genext2fs is available." >&2
	exit 1
fi

echo "Generated ${TOP_DIR}/boot_linux.img"