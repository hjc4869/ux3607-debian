#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=versions.sh
source "$project_dir/scripts/versions.sh"
archive_path="$project_dir/work/asus-ux3607oa-bsp.exe"
extract_dir="$project_dir/work/asus-bsp"
package_dir="$project_dir/work/firmware-package"
firmware_dir="$package_dir/usr/lib/firmware/qcom/glymur/ASUSTeK/UX3607OA"
archive_url='https://dlcdnets.asus.com/pub/ASUS/nb/Image/Driver/DriverPackage/50616/SOCPackage_forWebSite_Qualcomm_Z_V1.312.4500.0_50616.exe?model=UX3607OA'
archive_sha256=e8f2389ac5d4dfd30a1a8481ec3c1e282f24baea2898414351d0b6eb1fa8a0b3

download_verified() {
    local destination=$1 url=$2 checksum=$3
    if [[ ! -f $destination ]]; then
        curl -fL --retry 3 --max-time 300 -o "$destination" "$url"
    fi
    printf '%s  %s\n' "$checksum" "$destination" | sha256sum -c
}

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

atheros_package="$project_dir/work/firmware-atheros_20260810-1_all.deb"
encoder_path="$project_dir/work/ath12k-bdencoder"
wifi_blob="$project_dir/work/ux3607oa-ncm820a-board.elf"
wifi_commit=d2d3e6a9ac17dd2e4f0ac64fec2afc10d3978e8c
wifi_url="https://raw.githubusercontent.com/misyltoad/asus-zenbook-a16-wifi-firmware-patch/$wifi_commit/bdwlan_qcc2072_1p0_ncm820A.elf"
wifi_sha256=960e9e93da708f5e1086ce15d82d3e44d846ec9441eac40e1725467d357965d8
# deb.debian.org drops superseded versions from the pool; snapshot.debian.org keeps
# the pinned build permanently, so the board-data baseline stays reproducible.
download_verified "$atheros_package" \
    https://snapshot.debian.org/archive/debian/20260818T205150Z/pool/non-free-firmware/f/firmware-nonfree/firmware-atheros_20260810-1_all.deb \
    69b36b88f042776af239c690bfd942088c4e58c39c9edc5510f800f2c06bbeee
download_verified "$encoder_path" \
    https://raw.githubusercontent.com/qca/qca-swiss-army-knife/6df4dae3e2f5e4c2903f3cafd40996fc1b3639ce/tools/scripts/ath12k/ath12k-bdencoder \
    fdcc8dc9628d67e500d496a1de22e82e136ddeaec32669ea1b3add93f2980652
download_verified "$wifi_blob" "$wifi_url" "$wifi_sha256"
dpkg-deb -x "$atheros_package" "$project_dir/work/atheros-baseline"
board_baseline="$project_dir/work/atheros-baseline/usr/lib/firmware/ath12k/QCC2072/hw1.0/board-2.bin"
board_override="$package_dir/usr/lib/firmware/updates/ath12k/QCC2072/hw1.0/board-2.bin"
board_name='bus=pci,vendor=17cb,device=1112,subsystem-vendor=105b,subsystem-device=e14f,qmi-chip-id=33,qmi-board-id=255,variant=UX3407Q'
install -D -m 644 "$board_baseline" "$board_override"
python3 "$encoder_path" --add-board "$board_override" "$wifi_blob" "$board_name" \
    > "$project_dir/artifacts/wifi-board-diff.txt"
grep -Fx "$board_name" "$project_dir/artifacts/wifi-board-diff.txt"
grep -Fx '1 board image(s) added, 0 changed, 0 deleted, 4 in total' "$project_dir/artifacts/wifi-board-diff.txt"
grep -Fx '0 regdb image(s) added, 0 changed, 0 deleted, 1 in total' "$project_dir/artifacts/wifi-board-diff.txt"
python3 "$encoder_path" --info "$board_override" > "$project_dir/artifacts/wifi-board-info.txt"

# Upstream linux-firmware ships the A16 AudioReach topology (BSD-3-Clause) under the
# card name the kernel requests. Debian's firmware-qcom-soc does not include it yet.
tplg_commit=466e500db134efb2090d52b9b6b1104ce43e8ed2
tplg_name=GLYMUR-ASUS-Zenbook-A16-UX3607OA-tplg.bin
tplg_url="https://gitlab.com/kernel-firmware/linux-firmware/-/raw/$tplg_commit/qcom/glymur/ASUSTeK/UX3607OA/$tplg_name"
tplg_sha256=ea851335b7e8e13977a597250f2c0f1b6434d68f2248ae85a332e158fd64db57
tplg_dir="$package_dir/usr/lib/firmware/updates/qcom/glymur"
download_verified "$project_dir/work/$tplg_name" "$tplg_url" "$tplg_sha256"
install -D -m 644 "$project_dir/work/$tplg_name" "$tplg_dir/ASUSTeK/UX3607OA/$tplg_name"
ln -sfn "ASUSTeK/UX3607OA/$tplg_name" "$tplg_dir/$tplg_name"

cat > "$package_dir/DEBIAN/control" <<EOF
Package: firmware-ux3607oa-local
Version: $firmware_package_version
Architecture: all
Maintainer: UX3607OA Local Image Builder <builder@ux3607oa.invalid>
Section: non-free-firmware/kernel
Priority: optional
Depends: initramfs-tools, firmware-atheros (>= 20260810-1)
Description: ASUS UX3607OA DSP firmware and Wi-Fi board data
 Board-specific ADSP and CDSP firmware from the checksum-verified ASUS
 UX3607OA support archive. Vendor licensing applies; not for redistribution.
 Includes the exact-model QCC2072 calibration entry from kernel bug 221984
 as a firmware override without replacing Debian-owned board data.
 Adds the upstream linux-firmware AudioReach topology under the A16 card name.
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
printf '\nQCC2072 board data: kernel bug 221984, exact 105b:e14f variant UX3407Q.\nURL: %s\nSHA256: %s\nDebian baseline: firmware-atheros 20260810-1.\nEncoder: qca-swiss-army-knife 6df4dae3e2f5e4c2903f3cafd40996fc1b3639ce.\nThe board payload differs from the ASUS BSP copy and follows the exact-model report.\n' \
    "$wifi_url" "$wifi_sha256" >> "$package_dir/usr/share/doc/firmware-ux3607oa-local/PROVENANCE"
printf '\nAudioReach topology: linux-firmware %s, BSD-3-Clause (LICENCE.linaro).\nURL: %s\nSHA256: %s\nInstalled under firmware/updates so a future Debian copy cannot conflict.\n' \
    "$tplg_commit" "$tplg_url" "$tplg_sha256" >> "$package_dir/usr/share/doc/firmware-ux3607oa-local/PROVENANCE"
(cd "$package_dir" && find usr/lib/firmware -type f -print0 | sort -z | xargs -0 sha256sum) \
    > "$project_dir/artifacts/board-firmware-sha256.txt"
cp "$project_dir/artifacts/board-firmware-sha256.txt" \
    "$package_dir/usr/share/doc/firmware-ux3607oa-local/SHA256SUMS"
chmod -R go-w "$package_dir"
dpkg-deb --root-owner-group --build "$package_dir" \
    "$project_dir/artifacts/packages/firmware-ux3607oa-local_${firmware_package_version}_all.deb"