#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=versions.sh
source "$project_dir/scripts/versions.sh"
package_dir="$project_dir/work/support-package"
ucm_dir="$package_dir/usr/share/alsa/ucm2"
rm -rf "$package_dir"
mkdir -p "$package_dir/DEBIAN" "$package_dir/usr/sbin" \
    "$package_dir/usr/share/initramfs-tools/hooks" \
    "$package_dir/etc/kernel/postinst.d" "$package_dir/etc/kernel/postrm.d" \
    "$package_dir/etc/initramfs/post-update.d" "$project_dir/artifacts/packages" \
    "$ucm_dir/Qualcomm/glymur/ux3607oa" "$ucm_dir/conf.d/glymur"
cat > "$package_dir/DEBIAN/control" <<EOF
Package: ux3607oa-boot-support
Version: $support_package_version
Architecture: arm64
Maintainer: UX3607OA Local Image Builder <builder@ux3607oa.invalid>
Section: admin
Priority: optional
Depends: linux-image-$kernel_release (= $kernel_package_version), initramfs-tools, linux-base, grub-efi-arm64-bin, util-linux, wireless-regdb, firmware-qcom-soc, firmware-atheros, alsa-ucm-conf (>= 1.2.16)
Description: USB boot integration for ASUS Zenbook A16 UX3607OA
 Device-tree-aware removable UEFI boot, Qualcomm initramfs dependencies,
 kernel update hooks for the locally packaged Debian-derived kernel, and
 the upstream ALSA UCM speaker/microphone profile for this laptop.
EOF
install -m 755 "$project_dir/packaging/update-ux3607oa-boot" "$package_dir/usr/sbin/"
install -m 755 "$project_dir/packaging/ux3607oa-initramfs-hook" \
    "$package_dir/usr/share/initramfs-tools/hooks/ux3607oa"
for ucm_file in ASUS-Zenbook-A16-UX3607OA.conf ZenbookA16-HiFi.conf; do
    install -m 644 "$project_dir/config/alsa-ucm2/$ucm_file" "$ucm_dir/Qualcomm/glymur/ux3607oa/"
done
ln -s ../../Qualcomm/glymur/ux3607oa/ASUS-Zenbook-A16-UX3607OA.conf \
    "$ucm_dir/conf.d/glymur/GLYMUR-ASUS-Zenbook-A16-UX3607OA.conf"
for hook_path in etc/kernel/postinst.d/zz-ux3607oa etc/kernel/postrm.d/zz-ux3607oa \
    etc/initramfs/post-update.d/zz-ux3607oa; do
    printf '#!/bin/sh\nset -e\nexec /usr/sbin/update-ux3607oa-boot\n' > "$package_dir/$hook_path"
    chmod 755 "$package_dir/$hook_path"
done
cat > "$package_dir/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
    update-alternatives --set regulatory.db /lib/firmware/regulatory.db-upstream
    update-initramfs -u -k all
    update-ux3607oa-boot
fi
EOF
chmod 755 "$package_dir/DEBIAN/postinst"
printf '%s\n' /etc/kernel/postinst.d/zz-ux3607oa /etc/kernel/postrm.d/zz-ux3607oa \
    /etc/initramfs/post-update.d/zz-ux3607oa > "$package_dir/DEBIAN/conffiles"
chmod -R go-w "$package_dir"
dpkg-deb --root-owner-group --build "$package_dir" \
    "$project_dir/artifacts/packages/ux3607oa-boot-support_${support_package_version}_arm64.deb"