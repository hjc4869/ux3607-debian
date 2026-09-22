#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
archive_path="$project_dir/work/asus-ux3607oa-bsp.exe"
extract_dir="$project_dir/work/asus-bsp"
package_dir="$project_dir/work/firmware-package"
firmware_dir="$package_dir/usr/lib/firmware/qcom/glymur/ASUSTeK/UX3607OA"
archive_url='https://dlcdnets.asus.com/pub/ASUS/nb/Image/Driver/DriverPackage/50616/SOCPackage_forWebSite_Qualcomm_Z_V1.312.4500.0_50616.exe?model=UX3607OA'
archive_sha256=e8f2389ac5d4dfd30a1a8481ec3c1e282f24baea2898414351d0b6eb1fa8a0b3

mkdir -p "$project_dir/work" "$project_dir/artifacts/packages" "$firmware_dir" \
    "$package_dir/DEBIAN" "$package_dir/usr/share/doc/firmware-ux3607oa-local"
if [[ ! -f $archive_path ]]; then
    curl -fL --retry 3 -o "$archive_path" "$archive_url"
fi
printf '%s  %s\n' "$archive_sha256" "$archive_path" | sha256sum -c
7z x -y -o"$extract_dir" "$archive_path" > "$project_dir/work/asus-extract.log"
adsp_dir="$extract_dir/QualcommBSP/Subsystem/qcsubsys_ext_adsp8480"
cdsp_dir="$extract_dir/QualcommBSP/NPU/qcnspmcdm8480"
for filename in qcadsp8480.mbn adsp_dtbs.elf adspr.jsn adsps.jsn adspua.jsn; do
    install -m 644 "$adsp_dir/$filename" "$firmware_dir/$filename"
done
for filename in qccdsp8480.mbn cdsp_dtbs.elf; do
    install -m 644 "$cdsp_dir/$filename" "$firmware_dir/$filename"
done
install -m 644 "$extract_dir/QualcommBSP/Subsystem/qcsubsys_ext_soccp8480/soccpr.jsn" "$firmware_dir/"
cat > "$package_dir/DEBIAN/control" <<'EOF'
Package: firmware-ux3607oa-local
Version: 1.312.4500.0-1
Architecture: all
Maintainer: UX3607OA Local Image Builder <builder@ux3607oa.invalid>
Section: non-free-firmware/kernel
Priority: optional
Depends: initramfs-tools
Description: Locally extracted ASUS UX3607OA DSP firmware
 Board-specific ADSP and CDSP firmware from the checksum-verified ASUS
 UX3607OA support archive. Vendor licensing applies; not for redistribution.
 SoCCP binaries are not included: normal boot uses the UEFI-loaded subsystem.
EOF
cat > "$package_dir/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
    update-initramfs -u -k all
fi
EOF
chmod 755 "$package_dir/DEBIAN/postinst"
printf 'ASUS UX3607OA support archive\nVersion: 1.312.4500.0\nURL: %s\nSHA256: %s\n\nLocally extracted for use on the owner\047s UX3607OA. Vendor terms apply.\nNo redistribution permission is asserted. No installer or BIOS code was executed.\n' \
    "$archive_url" "$archive_sha256" > "$package_dir/usr/share/doc/firmware-ux3607oa-local/PROVENANCE"
(cd "$firmware_dir" && sha256sum ./*) > "$project_dir/artifacts/board-firmware-sha256.txt"
cp "$project_dir/artifacts/board-firmware-sha256.txt" \
    "$package_dir/usr/share/doc/firmware-ux3607oa-local/SHA256SUMS"
dpkg-deb --root-owner-group --build "$package_dir" \
    "$project_dir/artifacts/packages/firmware-ux3607oa-local_1.312.4500.0-1_all.deb"