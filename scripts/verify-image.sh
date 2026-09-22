#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $EUID != 0 ]]; then
    exec sudo -n unshare --mount --propagation private bash "$0" "$@"
fi
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
variant=${1:?Specify cli or kde}
[[ $variant == cli || $variant == kde ]]
image_path="$project_dir/artifacts/debian-sid-ux3607oa-$variant.img"
[[ -f $image_path && ! -L $image_path ]]
mount_dir=$(mktemp -d "$project_dir/work/verify-$variant.XXXXXX")
loop_device=''
cleanup() {
    if mountpoint -q "$mount_dir/boot/efi"; then umount "$mount_dir/boot/efi"; fi
    if mountpoint -q "$mount_dir"; then umount "$mount_dir"; fi
    if [[ -n $loop_device ]]; then losetup -d "$loop_device"; fi
    rmdir "$mount_dir"
}
trap cleanup EXIT

sgdisk --verify "$image_path"
loop_device=$(losetup --find --show --read-only --partscan "$image_path")
udevadm settle
fsck.vfat -n "${loop_device}p1"
e2fsck -fn "${loop_device}p2"
mount -o ro,noload "${loop_device}p2" "$mount_dir"
mount -o ro "${loop_device}p1" "$mount_dir/boot/efi"
file "$mount_dir/boot/efi/EFI/BOOT/BOOTAA64.EFI"
file "$mount_dir/boot/efi/EFI/BOOT/BOOTAA64.EFI" | grep -Eq 'Aarch64|ARM64'
kernel_release=$(< "$project_dir/artifacts/kernel/release")
[[ -s "$mount_dir/boot/vmlinuz-$kernel_release" && -s "$mount_dir/boot/initrd.img-$kernel_release" ]]
if ! grep -qx 'CONFIG_SYSFB_SIMPLEFB=y' "$mount_dir/boot/config-$kernel_release"; then
    printf 'Missing EFI-to-simpledrm framebuffer handoff configuration\n' >&2
    exit 1
fi
grep -Eq '^CONFIG_DRM_SIMPLEDRM=[ym]$' "$mount_dir/boot/config-$kernel_release"
if grep -qx 'CONFIG_DRM_SIMPLEDRM=m' "$mount_dir/boot/config-$kernel_release"; then
    lsinitramfs "$mount_dir/boot/initrd.img-$kernel_release" \
        | grep -E '(^|/)simpledrm[.]ko([.](xz|gz|zst))?$' > /dev/null
fi
dtb_path="/usr/lib/linux-image-$kernel_release/qcom/glymur-asus-zenbook-a16-ux3607oa.dtb"
[[ $(fdtget "$mount_dir$dtb_path" / compatible) == 'asus,zenbook-a16-ux3607oa qcom,glymur' ]]
chroot "$mount_dir" grub-script-check /boot/grub/grub.cfg
recovery_arguments=$(awk '/^menuentry .*basic display/ {recovery=1} recovery && $1 == "linux" {print; exit}' "$mount_dir/boot/grub/grub.cfg")
default_arguments=$(awk '$1 == "linux" {print; exit}' "$mount_dir/boot/grub/grub.cfg")
for argument in nomodeset module_blacklist=msm clk_ignore_unused pd_ignore_unused; do
    [[ " $recovery_arguments " == *" $argument "* ]]
    [[ " $default_arguments " != *" $argument "* ]]
done
chroot "$mount_dir" dpkg-query -W "-f=\${Package}\t\${Version}\t\${db:Status-Status}\n" \
    "linux-image-$kernel_release" ux3607oa-boot-support firmware-ux3607oa-local wireless-regdb
[[ -z $(chroot "$mount_dir" dpkg --audit) ]]
[[ -z $(chroot "$mount_dir" dpkg --verify "linux-image-$kernel_release" ux3607oa-boot-support firmware-ux3607oa-local) ]]
[[ $(chroot "$mount_dir" readlink -f /lib/firmware/regulatory.db) == /usr/lib/firmware/regulatory.db-upstream ]]
[[ ! -s "$mount_dir/etc/machine-id" && ! -e "$mount_dir/usr/sbin/policy-rc.d" ]]
if [[ $variant == kde ]]; then
    chroot "$mount_dir" dpkg-query -W plasma-desktop sddm libqt6core6t64
    [[ $(readlink "$mount_dir/etc/systemd/system/default.target") == */graphical.target ]]
else
    [[ $(readlink "$mount_dir/etc/systemd/system/default.target") == */multi-user.target ]]
fi
printf 'Read-only disk and package validation passed: %s\n' "$variant"