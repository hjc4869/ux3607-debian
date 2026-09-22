#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$project_dir/work/support-package"
mkdir -p "$package_dir/DEBIAN" "$package_dir/usr/sbin" \
    "$package_dir/usr/share/initramfs-tools/hooks" \
    "$package_dir/etc/kernel/postinst.d" "$package_dir/etc/kernel/postrm.d" \
    "$package_dir/etc/initramfs/post-update.d" "$project_dir/artifacts/packages"
cat > "$package_dir/DEBIAN/control" <<'EOF'
Package: ux3607oa-boot-support
Version: 1.0-4
Architecture: arm64
Maintainer: UX3607OA Local Image Builder <builder@ux3607oa.invalid>
Section: admin
Priority: optional
Depends: linux-image-7.3.0-rc4-ux3607oa (= 7.3~rc4-1+ux3607oa2), initramfs-tools, linux-base, grub-efi-arm64-bin, util-linux, wireless-regdb, firmware-qcom-soc, firmware-atheros
Description: USB boot integration for ASUS Zenbook A16 UX3607OA
 Device-tree-aware removable UEFI boot, Qualcomm initramfs dependencies,
 and kernel update hooks for the locally packaged Debian-derived kernel.
EOF
install -m 755 "$project_dir/packaging/update-ux3607oa-boot" "$package_dir/usr/sbin/"
install -m 755 "$project_dir/packaging/ux3607oa-initramfs-hook" \
    "$package_dir/usr/share/initramfs-tools/hooks/ux3607oa"
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
dpkg-deb --root-owner-group --build "$package_dir" \
    "$project_dir/artifacts/packages/ux3607oa-boot-support_1.0-4_arm64.deb"