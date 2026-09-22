#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $EUID != 0 ]]; then
    exec sudo -n unshare --mount --propagation private bash "$0" "$@"
fi
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
work_dir="$project_dir/work"
artifacts_dir="$project_dir/artifacts"
cli_root="$work_dir/rootfs-cli"
kde_root="$work_dir/rootfs-kde"
mounts=()
loop_device=''

cleanup() {
    local mount_index
    for ((mount_index=${#mounts[@]}-1; mount_index>=0; mount_index--)); do
        umount "${mounts[mount_index]}" || true
    done
    mounts=()
    if [[ -n $loop_device ]]; then
        losetup -d "$loop_device"
        loop_device=''
    fi
}
trap cleanup EXIT

mount_chroot() {
    local root_dir=$1
    mkdir -p "$root_dir"/{dev,proc,sys,run}
    mount --bind /dev "$root_dir/dev"
    mounts+=("$root_dir/dev")
    mount -t devpts -o newinstance,ptmxmode=0666,mode=0620 devpts "$root_dir/dev/pts"
    mounts+=("$root_dir/dev/pts")
    mount -t proc proc "$root_dir/proc"
    mounts+=("$root_dir/proc")
    mount -t sysfs -o ro sysfs "$root_dir/sys"
    mounts+=("$root_dir/sys")
    mount -t tmpfs tmpfs "$root_dir/run"
    mounts+=("$root_dir/run")
}

policy_rc() {
    printf '#!/bin/sh\nexit 101\n' > "$1/usr/sbin/policy-rc.d"
    chmod 755 "$1/usr/sbin/policy-rc.d"
}

bootstrap() {
    [[ ! -e "$work_dir/bootstrap.complete" ]] || return 0
    [[ ! -d $cli_root ]] || { printf 'Incomplete root exists: %s\n' "$cli_root" >&2; exit 1; }
    mmdebstrap --architectures=arm64 --variant=important --format=directory \
        --components=main,contrib,non-free,non-free-firmware \
        --include=systemd-sysv,initramfs-tools,linux-base,grub-efi-arm64-bin,network-manager,wpasupplicant,sudo,locales,ca-certificates,nano,less,curl,openssh-client,usbutils,pciutils,iproute2,iputils-ping,rfkill,bluez,firmware-qcom-soc,firmware-atheros,firmware-misc-nonfree,alsa-utils,alsa-ucm-conf,dbus,systemd-timesyncd,zstd \
        sid "$cli_root" https://deb.debian.org/debian
    touch "$work_dir/bootstrap.complete"
}

configure_cli() {
    [[ ! -e "$work_dir/cli.complete" ]] || return 0
    bootstrap
    [[ -s "$artifacts_dir/kernel/release" ]]
    local kernel_release
    kernel_release=$(< "$artifacts_dir/kernel/release")
    [[ -f "$artifacts_dir/packages/linux-image-${kernel_release}_7.3~rc4-1+ux3607oa2_arm64.deb" ]]
    policy_rc "$cli_root"
    mkdir -p "$cli_root/usr/local/share/ux3607oa/repository" "$cli_root/etc/initramfs-tools/conf.d"
    cp "$artifacts_dir/packages/"*.deb "$cli_root/usr/local/share/ux3607oa/repository/"
    (cd "$cli_root/usr/local/share/ux3607oa/repository" && dpkg-scanpackages . /dev/null > Packages)
    printf 'deb [trusted=yes] file:/usr/local/share/ux3607oa/repository ./\n' \
        > "$cli_root/etc/apt/sources.list.d/ux3607oa-local.list"
    printf 'MODULES=most\nCOMPRESS=zstd\n' > "$cli_root/etc/initramfs-tools/conf.d/ux3607oa"
    printf 'RESUME=none\n' > "$cli_root/etc/initramfs-tools/conf.d/resume"
    printf 'en_US.UTF-8 UTF-8\n' > "$cli_root/etc/locale.gen"
    printf 'LANG=en_US.UTF-8\n' > "$cli_root/etc/default/locale"
    printf 'ux3607oa\n' > "$cli_root/etc/hostname"
    printf '127.0.0.1 localhost\n127.0.1.1 ux3607oa\n::1 localhost ip6-localhost ip6-loopback\n' > "$cli_root/etc/hosts"
    mount_chroot "$cli_root"
    chroot "$cli_root" locale-gen
    chroot "$cli_root" apt-get update
    chroot "$cli_root" apt-get install -y ux3607oa-boot-support firmware-ux3607oa-local
    chroot "$cli_root" useradd --create-home --shell /bin/bash --groups sudo,audio,video,render,plugdev,netdev debian
    printf 'debian:debian\n' | chroot "$cli_root" chpasswd
    chroot "$cli_root" chage -d 0 debian
    chroot "$cli_root" passwd -l root
    chroot "$cli_root" systemctl enable NetworkManager.service systemd-timesyncd.service
    chroot "$cli_root" systemctl set-default multi-user.target
    chroot "$cli_root" apt-get check
    [[ -z $(chroot "$cli_root" dpkg --audit) ]]
    cleanup
    sanitize_root "$cli_root"
    touch "$work_dir/cli.complete"
}

configure_kde() {
    [[ ! -e "$work_dir/kde.complete" ]] || return 0
    configure_cli
    if [[ ! -d $kde_root ]]; then
        mkdir -p "$kde_root"
        cp -a --reflink=auto "$cli_root/." "$kde_root/"
    fi
    policy_rc "$kde_root"
    rm -f "$kde_root/etc/resolv.conf"
    cp -L /etc/resolv.conf "$kde_root/etc/resolv.conf"
    cat > "$kde_root/etc/apt/sources.list.d/ux3607oa-desktop-snapshot.list" <<'EOF'
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260910T000000Z/ sid main contrib non-free non-free-firmware
EOF
    cat > "$kde_root/etc/apt/preferences.d/ux3607oa-desktop-snapshot" <<'EOF'
Package: *
Pin: origin snapshot.debian.org
Pin-Priority: 1001
EOF
    mount_chroot "$kde_root"
    chroot "$kde_root" apt-get update
    if [[ ${1:-} == --simulate ]]; then
        chroot "$kde_root" apt-get --simulate --allow-downgrades install kde-plasma-desktop sddm plasma-nm konsole dolphin \
            pipewire-audio wireplumber libgl1-mesa-dri mesa-vulkan-drivers mesa-utils \
            firefox-esr fonts-noto-core fonts-noto-color-emoji
        cleanup
        return 0
    fi
    chroot "$kde_root" apt-get install -y --allow-downgrades kde-plasma-desktop sddm plasma-nm konsole dolphin \
        pipewire-audio wireplumber libgl1-mesa-dri mesa-vulkan-drivers mesa-utils \
        firefox-esr fonts-noto-core fonts-noto-color-emoji
    chroot "$kde_root" systemctl enable sddm.service
    chroot "$kde_root" systemctl set-default graphical.target
    chroot "$kde_root" apt-get check
    [[ -z $(chroot "$kde_root" dpkg --audit) ]]
    cleanup
    sanitize_root "$kde_root"
    touch "$work_dir/kde.complete"
}

sanitize_root() {
    local root_dir=$1
    rm -f "$root_dir/usr/sbin/policy-rc.d" "$root_dir/var/lib/dbus/machine-id"
    truncate -s 0 "$root_dir/etc/machine-id"
    ln -sf /etc/machine-id "$root_dir/var/lib/dbus/machine-id"
    rm -f "$root_dir/var/lib/systemd/random-seed" "$root_dir/etc/ssh/ssh_host_"*
    rm -f "$root_dir/etc/resolv.conf"
    ln -s /run/NetworkManager/resolv.conf "$root_dir/etc/resolv.conf"
    chroot "$root_dir" apt-get clean
    find "$root_dir/var/log" -type f -exec truncate -s 0 {} +
}

refresh_packages() {
    local root_dir=$1
    policy_rc "$root_dir"
    rm -f "$root_dir/etc/resolv.conf"
    cp -L /etc/resolv.conf "$root_dir/etc/resolv.conf"
    cp "$artifacts_dir/packages/"*.deb "$root_dir/usr/local/share/ux3607oa/repository/"
    (cd "$root_dir/usr/local/share/ux3607oa/repository" && dpkg-scanpackages . /dev/null > Packages)
    mount_chroot "$root_dir"
    chroot "$root_dir" apt-get update
    chroot "$root_dir" apt-get install -y ux3607oa-boot-support firmware-ux3607oa-local wireless-regdb
    chroot "$root_dir" apt-get check
    [[ -z $(chroot "$root_dir" dpkg --audit) ]]
    cleanup
    sanitize_root "$root_dir"
}

assemble_image() {
    local variant=$1 root_dir=$2 size_gib=$3
    local image_path="$artifacts_dir/debian-sid-ux3607oa-$variant.img"
    local mount_dir="$work_dir/mount-$variant"
    local root_uuid esp_uuid
    [[ ! -e "$image_path" ]] || { printf 'Image already exists: %s\n' "$image_path" >&2; exit 1; }
    truncate -s "${size_gib}G" "$image_path"
    sgdisk --clear --new=1:2048:+512M --typecode=1:ef00 --change-name=1:UX3607-ESP \
        --new=2:0:0 --typecode=2:8300 --change-name=2:UX3607-ROOT "$image_path"
    loop_device=$(losetup --find --show --partscan "$image_path")
    udevadm settle
    mkfs.vfat -F 32 -n UX3607ESP "${loop_device}p1"
    mkfs.ext4 -q -L "UX3607-${variant^^}" -m 1 "${loop_device}p2"
    root_uuid=$(blkid -s UUID -o value "${loop_device}p2")
    esp_uuid=$(blkid -s UUID -o value "${loop_device}p1")
    mkdir -p "$mount_dir"
    mount "${loop_device}p2" "$mount_dir"
    mounts+=("$mount_dir")
    rsync -aHAX --numeric-ids "$root_dir/" "$mount_dir/"
    mkdir -p "$mount_dir/boot/efi" "$mount_dir/etc/ux3607oa"
    mount "${loop_device}p1" "$mount_dir/boot/efi"
    mounts+=("$mount_dir/boot/efi")
    printf 'UUID=%s / ext4 defaults,noatime 0 1\nUUID=%s /boot/efi vfat umask=0077 0 2\n' \
        "$root_uuid" "$esp_uuid" > "$mount_dir/etc/fstab"
    printf 'ROOT_UUID=%s\nESP_UUID=%s\nVARIANT=%s\n' "$root_uuid" "$esp_uuid" "$variant" \
        > "$mount_dir/etc/ux3607oa/image.conf"
    mount_chroot "$mount_dir"
    chroot "$mount_dir" update-ux3607oa-boot
    chroot "$mount_dir" dpkg-query -W "-f=\${binary:Package}\t\${Version}\n" \
        > "$artifacts_dir/$variant-packages.tsv"
    chroot "$mount_dir" grub-script-check /boot/grub/grub.cfg
    test -s "$mount_dir/boot/efi/EFI/BOOT/BOOTAA64.EFI"
    sync
    cleanup
    sgdisk --verify "$image_path"
    if [[ -n ${SUDO_UID:-} ]]; then
        chown "$SUDO_UID:${SUDO_GID:-0}" "$image_path" "$artifacts_dir/$variant-packages.tsv"
    fi
}

mkdir -p "$work_dir" "$artifacts_dir"
case "${1:-all}" in
    bootstrap) bootstrap ;;
    kde-simulate) configure_kde --simulate ;;
    refresh-cli) refresh_packages "$cli_root"; assemble_image cli "$cli_root" 12 ;;
    refresh-kde) refresh_packages "$kde_root"; assemble_image kde "$kde_root" 28 ;;
    cli) configure_cli; assemble_image cli "$cli_root" 12 ;;
    kde) configure_kde; assemble_image kde "$kde_root" 28 ;;
    all) configure_cli; assemble_image cli "$cli_root" 12; configure_kde; assemble_image kde "$kde_root" 28 ;;
    *) printf 'Usage: %s [bootstrap|cli|kde-simulate|kde|refresh-cli|refresh-kde|all]\n' "$0" >&2; exit 2 ;;
esac