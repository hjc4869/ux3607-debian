#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_dir="$project_dir/work/linux"
build_dir="$project_dir/work/kernel-debian"
kernel_commit=93f51579e7df248780214094418f205253383cc5
jobs=${JOBS:-$(nproc)}
config_package=linux-config-7.2_7.2.6-1_arm64.deb
config_sha256=3077a50e9fb9764ac3e7b0e92200ba1fa23747857ce55213ab26ee81e3eb120c

mkdir -p "$build_dir" "$project_dir/artifacts/kernel" "$project_dir/artifacts/packages"
if [[ ! -d "$source_dir/.git" ]]; then
    git clone --depth 1 --branch v7.3-rc4 https://github.com/torvalds/linux.git "$source_dir"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$kernel_commit" ]]
[[ -z $(git -C "$source_dir" status --porcelain --untracked-files=no) ]]

if [[ ! -f "$project_dir/work/$config_package" ]]; then
    curl -fL --retry 3 -o "$project_dir/work/$config_package" \
        "https://deb.debian.org/debian/pool/main/l/linux/$config_package"
fi
printf '%s  %s\n' "$config_sha256" "$project_dir/work/$config_package" | sha256sum -c
dpkg-deb -x "$project_dir/work/$config_package" "$project_dir/work/debian-config"
xz -dc "$project_dir/work/debian-config/usr/src/linux-config-7.2/config.arm64_none_arm64.xz" \
    > "$project_dir/artifacts/kernel/debian-arm64-7.2.6.config"

export KBUILD_BUILD_USER=ux3607-builder KBUILD_BUILD_HOST=debian KBUILD_BUILD_VERSION=1
export DEBFULLNAME='UX3607OA Local Kernel Builder' DEBEMAIL=builder@ux3607oa.invalid
export KDEB_PKGVERSION=7.3~rc4-1+ux3607oa2 KDEB_SOURCENAME=linux-ux3607oa
export KDEB_CHANGELOG_DIST=unstable KBUILD_DEBARCH=arm64
export DEB_BUILD_PROFILES='pkg.linux-ux3607oa.nokernelheaders pkg.linux-ux3607oa.nokerneldbg'
export DPKG_DEB_COMPRESSOR_TYPE=xz
SOURCE_DATE_EPOCH=$(git -C "$source_dir" show -s --format=%ct HEAD)
KBUILD_BUILD_TIMESTAMP=$(date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M:%S UTC')
export SOURCE_DATE_EPOCH KBUILD_BUILD_TIMESTAMP
make_args=(-s -C "$source_dir" "O=$build_dir" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-)

install -m 644 "$project_dir/artifacts/kernel/debian-arm64-7.2.6.config" "$build_dir/.config"
"$source_dir/scripts/kconfig/merge_config.sh" -m -O "$build_dir" \
    "$build_dir/.config" "$project_dir/config/kernel.config"
make "${make_args[@]}" olddefconfig
while IFS= read -r setting; do
    if ! grep -Fqx -- "$setting" "$build_dir/.config"; then
        printf 'Unresolved kernel setting: %s\n' "$setting" >&2
        exit 1
    fi
done < "$project_dir/config/kernel.config"

"$source_dir/scripts/diffconfig" "$project_dir/artifacts/kernel/debian-arm64-7.2.6.config" \
    "$build_dir/.config" > "$project_dir/artifacts/kernel/debian-config-delta.txt"
if [[ ${1:-} == --configure-only ]]; then
    make "${make_args[@]}" -j"$jobs" qcom/glymur-asus-zenbook-a16-ux3607oa.dtb
    exit 0
fi
make "${make_args[@]}" -j"$jobs" bindeb-pkg
kernel_release=$(make "${make_args[@]}" kernelrelease)
install -m 644 "$project_dir/work/linux-image-${kernel_release}_${KDEB_PKGVERSION}_arm64.deb" \
    "$project_dir/artifacts/packages/"
install -m 644 "$build_dir/arch/arm64/boot/Image" "$project_dir/artifacts/kernel/Image"
install -m 644 "$build_dir/arch/arm64/boot/dts/qcom/glymur-asus-zenbook-a16-ux3607oa.dtb" \
    "$project_dir/artifacts/kernel/glymur-asus-zenbook-a16-ux3607oa.dtb"
install -m 644 "$build_dir/.config" "$project_dir/artifacts/kernel/config-$kernel_release"
install -m 644 "$build_dir/System.map" "$project_dir/artifacts/kernel/System.map-$kernel_release"
printf '%s\n' "$kernel_release" > "$project_dir/artifacts/kernel/release"
printf '%s\n' "$kernel_commit" > "$project_dir/artifacts/kernel/source-commit"
fdtget "$project_dir/artifacts/kernel/glymur-asus-zenbook-a16-ux3607oa.dtb" / compatible
file "$project_dir/artifacts/kernel/Image"