#!/usr/bin/env bash
set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=versions.sh
source "$project_dir/scripts/versions.sh"
pristine_source_dir="$project_dir/work/linux"
patch_dir="$project_dir/patches/linux"
build_dir="$project_dir/work/kernel-debian-$kernel_release"
jobs=${JOBS:-$(nproc)}

mkdir -p "$build_dir" "$project_dir/artifacts/kernel" "$project_dir/artifacts/packages"
if [[ ! -d "$pristine_source_dir/.git" ]]; then
    git clone --depth 1 --branch "$kernel_tag" "$kernel_git_url" "$pristine_source_dir"
fi
if ! git -C "$pristine_source_dir" cat-file -e "$kernel_commit^{commit}" 2>/dev/null; then
    git -C "$pristine_source_dir" fetch --depth 1 "$kernel_git_url" tag "$kernel_tag"
fi
[[ $(git -C "$pristine_source_dir" rev-parse "$kernel_tag^{commit}") == "$kernel_commit" ]]
[[ -z $(git -C "$pristine_source_dir" status --porcelain --untracked-files=no) ]]
mapfile -t patch_series < <(grep -vE '^[[:space:]]*(#|$)' "$patch_dir/series")
[[ ${#patch_series[@]} -gt 0 ]]
for patch_name in "${patch_series[@]}"; do
    [[ $patch_name =~ ^[0-9]{4}-[a-z0-9-]+\.patch$ && -s "$patch_dir/$patch_name" ]]
done
(cd "$patch_dir" && sha256sum series "${patch_series[@]}") \
    > "$project_dir/artifacts/kernel/patches.sha256"
patchset_hash=$(sha256sum "$project_dir/artifacts/kernel/patches.sha256" | cut -d ' ' -f 1)
source_dir="$project_dir/work/linux-patched-${patchset_hash:0:12}"
patch_state="$project_dir/work/kernel-patches-$patchset_hash.tree"
if [[ ! -e "$source_dir/.git" ]]; then
    git -C "$pristine_source_dir" worktree add --detach "$source_dir" "$kernel_commit"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$kernel_commit" ]]
if [[ ! -f $patch_state ]]; then
    [[ -z $(git -C "$source_dir" status --porcelain) ]] || {
        printf 'Refusing to overwrite unexpected changes in %s\n' "$source_dir" >&2
        exit 1
    }
    for patch_name in "${patch_series[@]}"; do
        git -C "$source_dir" apply --check --index "$patch_dir/$patch_name"
        git -C "$source_dir" apply --index "$patch_dir/$patch_name"
    done
    git -C "$source_dir" write-tree > "$patch_state"
fi
[[ $(git -C "$source_dir" write-tree) == "$(< "$patch_state")" ]]
git -C "$source_dir" diff --quiet
[[ -z $(git -C "$source_dir" ls-files --others --exclude-standard) ]]
git -C "$source_dir" diff --cached --check

if [[ ! -f "$project_dir/work/$debian_config_package" ]]; then
    curl -fL --retry 3 -o "$project_dir/work/$debian_config_package" \
        "https://deb.debian.org/debian/pool/main/l/linux/$debian_config_package"
fi
printf '%s  %s\n' "$debian_config_sha256" "$project_dir/work/$debian_config_package" | sha256sum -c
debian_config_dir="$project_dir/work/debian-config-${debian_config_name%.config}"
dpkg-deb -x "$project_dir/work/$debian_config_package" "$debian_config_dir"
xz -dc "$debian_config_dir/$debian_config_member" \
    > "$project_dir/artifacts/kernel/$debian_config_name"

export KBUILD_BUILD_USER=ux3607-builder KBUILD_BUILD_HOST=debian KBUILD_BUILD_VERSION=1
export DEBFULLNAME='UX3607OA Local Kernel Builder' DEBEMAIL=builder@ux3607oa.invalid
export KDEB_PKGVERSION=$kernel_package_version KDEB_SOURCENAME=linux-ux3607oa
export KDEB_CHANGELOG_DIST=unstable KBUILD_DEBARCH=arm64
export LOCALVERSION=
export DEB_BUILD_PROFILES='pkg.linux-ux3607oa.nokernelheaders pkg.linux-ux3607oa.nokerneldbg'
export DPKG_DEB_COMPRESSOR_TYPE=xz
SOURCE_DATE_EPOCH=$(git -C "$source_dir" show -s --format=%ct HEAD)
KBUILD_BUILD_TIMESTAMP=$(date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M:%S UTC')
export SOURCE_DATE_EPOCH KBUILD_BUILD_TIMESTAMP
make_args=(-s -C "$source_dir" "O=$build_dir" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-)

install -m 644 "$project_dir/artifacts/kernel/$debian_config_name" "$build_dir/.config"
"$source_dir/scripts/kconfig/merge_config.sh" -m -O "$build_dir" \
    "$build_dir/.config" "$project_dir/config/kernel.config"
make "${make_args[@]}" olddefconfig
while IFS= read -r setting || [[ -n $setting ]]; do
    if ! grep -Fqx -- "$setting" "$build_dir/.config"; then
        printf 'Unresolved kernel setting: %s\n' "$setting" >&2
        exit 1
    fi
done < "$project_dir/config/kernel.config"

"$source_dir/scripts/diffconfig" "$project_dir/artifacts/kernel/$debian_config_name" \
    "$build_dir/.config" > "$project_dir/artifacts/kernel/debian-config-delta.txt"
if [[ ${1:-} == --configure-only ]]; then
    make "${make_args[@]}" -j"$jobs" qcom/glymur-asus-zenbook-a16-ux3607oa.dtb
    exit 0
fi
[[ $(make "${make_args[@]}" kernelrelease) == "$kernel_release" ]]
make "${make_args[@]}" -j"$jobs" bindeb-pkg
install -m 644 "$project_dir/work/linux-image-${kernel_release}_${KDEB_PKGVERSION}_arm64.deb" \
    "$project_dir/artifacts/packages/"
install -m 644 "$build_dir/arch/arm64/boot/Image" "$project_dir/artifacts/kernel/Image"
install -m 644 "$build_dir/arch/arm64/boot/dts/qcom/glymur-asus-zenbook-a16-ux3607oa.dtb" \
    "$project_dir/artifacts/kernel/glymur-asus-zenbook-a16-ux3607oa.dtb"
install -m 644 "$build_dir/.config" "$project_dir/artifacts/kernel/config-$kernel_release"
install -m 644 "$build_dir/System.map" "$project_dir/artifacts/kernel/System.map-$kernel_release"
printf '%s\n' "$kernel_release" > "$project_dir/artifacts/kernel/release"
printf '%s\n' "$kernel_package_version" > "$project_dir/artifacts/kernel/package-version"
printf '%s\n' "$kernel_commit" > "$project_dir/artifacts/kernel/source-commit"
install -m 644 "$patch_state" "$project_dir/artifacts/kernel/source-tree"
fdtget "$project_dir/artifacts/kernel/glymur-asus-zenbook-a16-ux3607oa.dtb" / compatible
file "$project_dir/artifacts/kernel/Image"