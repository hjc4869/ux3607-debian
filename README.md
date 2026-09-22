# Debian sid for ASUS Zenbook A16 UX3607OA

Build date: 2026-09-22. Target: **UX3607OA, Qualcomm Glymur / Snapdragon X2 Elite Extreme**.
Do not use these device trees on a Zenbook A14 or another UX3607 variant.

These are experimental, persistent Debian installations on raw GPT disk images,
not installer ISOs. They do not install to or repartition the laptop's internal
drive. Hardware operation on a real UX3607OA has not been tested here.

## Images

| Image | Logical Size | Minimum USB Capacity | Default Boot |
| --- | --- | --- | --- |
| `artifacts/debian-sid-ux3607oa-cli.img` | 12 GiB | 16 GB | Text login |
| `artifacts/debian-sid-ux3607oa-kde.img` | 28 GiB | 32 GB | KDE Plasma / SDDM |

Each image contains a 512 MiB FAT32 EFI System Partition and an ext4 root
partition. Changes persist on the USB drive. Compressed `.img.zst` copies and
SHA-256 checksums are provided in `artifacts/` after verification.

Initial local login: **`debian` / `debian`**. Change the password when prompted;
sudo then uses the new password. Root is locked and no SSH server is installed.
If the desktop greeter cannot perform the mandatory password change, use
Ctrl+Alt+F3, log in and change it, then return to the greeter.

## Upstream Progress

The [2026-07-21 submission](https://lore.kernel.org/lkml/20260721-topic-a16_submission-v1-0-8ea213130d05@oss.qualcomm.com/)
reported working GPU/display, HDMI, keyboard/touchpad, lid switch, charging,
USB-A/USB-C, SD reader, QCC2072 Wi-Fi/Bluetooth, and four-speaker playback.
Touchscreen support was untested. Iris video acceleration was deferred.

The [board commit](https://github.com/torvalds/linux/commit/e8fbbca94db752ab94d9dadf2f65872905eafecd)
is merged into the 7.3 development series, not 7.2. The selected upstream release
also contains the board's QSEECOM allowlist entry, SoCCP support, TCSR support,
Glymur display PHY support, and PCI power-control support. No board patches are
applied on top of the upstream source.

Kernel: **7.3.0-rc4-ux3607oa**, upstream tag `v7.3-rc4`, commit
`93f51579e7df248780214094418f205253383cc5` (2026-09-20).
This is a release candidate, not a stable/security-maintained Debian kernel.

## Debian Configuration And Packaging

The baseline is Debian's standard 4 KiB-page ARM64 configuration from
`linux-config-7.2_7.2.6-1_arm64.deb`, SHA-256
`3077a50e9fb9764ac3e7b0e92200ba1fa23747857ce55213ab26ee81e3eb120c`.
It is migrated with `olddefconfig`, not replaced with ARM64 defconfig.

[config/kernel.config](config/kernel.config) contains the small local delta:
kernel identity/signing settings, Glymur clocks/interconnect, its required M31
eUSB2 PHY, and simpledrm fallback. Debian's module, security, filesystem and
debug/BTF settings are retained where supported by upstream and the toolchain.
Removed/new symbols and unavailable Rust settings are recorded in
`artifacts/kernel/debian-config-delta.txt`; the untouched baseline and final
configuration are saved alongside it.

The images install these packages through apt from a root-owned local repository:

- `linux-image-7.3.0-rc4-ux3607oa`, version `7.3~rc4-1+ux3607oa2`:
  upstream `bindeb-pkg` image, modules, DTBs, configuration, System.map, and
  standard Debian kernel maintainer hooks.
- `ux3607oa-boot-support`: board-aware GRUB generation,
  initramfs contents, firmware dependencies and kernel/initramfs update hooks.
- `firmware-ux3607oa-local`, version `1.312.4500.0-1`: locally extracted ASUS
  ADSP/CDSP firmware, with archive provenance and per-file hashes.

Kernel headers and debug-symbol packages are not built. The generated custom
`linux-libc-dev` package is deliberately **not** installed or shipped; Debian
userspace headers remain managed by Debian. The custom kernel does not claim to
provide Debian's `linux-image-arm64` metapackage and receives no automatic Debian
kernel security updates. Rebuild it or migrate to an adequately configured
official kernel when support is available.

## KDE Snapshot

KDE is installed into a copy of the completed CLI root filesystem. On build day,
current sid ARM64 is mid-transition: `plasma-desktop` requires Qt 6.10.2 private
ABIs while newer packages require Qt 6.11.2. The desktop therefore uses the
**2026-09-10 sid snapshot**, not Debian testing/stable. Apt's solver selected 13
compatible older base-library/systemd packages and removed none.

The snapshot source and priority-1001 pin are in
`/etc/apt/sources.list.d/ux3607oa-desktop-snapshot.list` and
`/etc/apt/preferences.d/ux3607oa-desktop-snapshot`. This freezes desktop updates
and can select older package versions: it is a build workaround, not a long-term
security policy. Remove both files only after the sid Qt transition is complete,
then run `apt update` and inspect `apt --simulate full-upgrade` before upgrading.
The CLI image uses current sid. Both final package manifests are in `artifacts/`.

## Firmware And Hardware Limits

Debian `firmware-qcom-soc` and `firmware-atheros` supply the Gen8 GPU and QCC2072
wireless firmware. `wireless-regdb` uses its **upstream-signed** alternative,
matching this upstream kernel's built-in regulatory verification keys.

The [official ASUS UX3607OA bundle](https://www.asus.com/supportonly/ux3607oa/helpdesk_download/)
version 1.312.4500.0, released 2026-07-23, supplies the exact board ADSP/CDSP
payloads. Its published SHA-256 is
`e8f2389ac5d4dfd30a1a8481ec3c1e282f24baea2898414351d0b6eb1fa8a0b3`.
It is extracted with 7-Zip; no Windows installer, BIOS updater or executable is
run. These local images contain proprietary vendor firmware. **Do not publish
or redistribute them without checking the vendor's licensing permissions.**

SoCCP is normally started by UEFI from SPI firmware; upstream Linux attaches to
that running subsystem. The ASUS INF explicitly describes this handoff. The
standalone `soccp.mbn` and `soccp_dtb.mbn` files are not in the driver bundle and
are not supplied. A BIOS that does not perform early boot, or SoCCP crash/restart,
can therefore require those files from the same machine's firmware/Windows
installation. No firmware from a different Qualcomm board is substituted.

Speaker playback was reported by the patch author, but Debian's installed
firmware/UCM set lacks the exact `GLYMUR-ASUS-Zenbook-A16-UX3607OA` audio profile.
Audio is not promised by these images; a CRD speaker configuration is not forced
onto this laptop. Camera, microphone, suspend/resume, video acceleration, NPU,
touchscreen, battery runtime and thermals are also not validated here.

## Booting

1. Back up data and save the Windows BitLocker/device-encryption recovery key
   before changing firmware settings. Disable Windows Fast Startup.
2. Disable **Secure Boot** for this unsigned local kernel/GRUB build. Keep the
   laptop on external power and use an up-to-date vendor BIOS. No BIOS update
   has been performed by these scripts.
3. Verify `artifacts/SHA256SUMS`, decompress the chosen image if necessary, and
   write it as a **whole disk image** using GNOME Disks or another raw image
   writer. Double-check the destination USB device: writing erases its contents.
   Never select the internal NVMe disk. No physical disk has been written here.
4. Open the laptop's UEFI boot menu (typically Esc while powering on) and select
   the USB device. The removable path is `EFI/BOOT/BOOTAA64.EFI`.
5. Select the default ASUS entry. GRUB supplies the exact board DTB and
   `acpi=off`. The second entry disables the native MSM display driver for
   troubleshooting. The third entry is **only for QEMU**, never the laptop.

The GPT/root filesystem does not automatically expand to fill a larger stick.
Use a partition editor if additional persistent space is needed.

## Rebuilding And Testing

Host prerequisites include an ARM64 GCC/binutils cross-toolchain, make, bc,
bison, flex, libssl-dev, libelf-dev, libdw-dev, pahole, debhelper, dpkg-dev,
rsync, kmod, cpio, xz-utils, zstd, mmdebstrap, dosfstools, gdisk, util-linux,
device-tree-compiler, curl, git, 7-Zip, qemu-user/binfmt, qemu-system-arm,
qemu-efi-aarch64, expect and shellcheck. Passwordless sudo is used with `-n`.

```sh
bash scripts/build-kernel.sh
bash scripts/build-firmware-package.sh
bash scripts/build-support-package.sh
bash scripts/build-images.sh all
bash scripts/verify-image.sh cli
bash scripts/verify-image.sh kde
expect scripts/test-uefi.exp cli
expect scripts/test-uefi.exp kde
```

Build scripts refuse to overwrite existing image files. Intermediate sources,
root filesystems, package-build metadata and build logs remain under `work/`.
Image creation uses a private mount namespace and loop devices backed only by
new regular files. No host bootloader installation or EFI-variable writes occur.
The recipe is repeatable, not a claim of bit-for-bit reproducibility: current
sid moves, and filesystem UUIDs/account hashes are newly generated.

QEMU validation boots the delivered image as a USB device through ARM64 UEFI,
GRUB, the packaged kernel, initramfs and systemd. A disposable snapshot checks
login/password change, root mounting, kernel version, NetworkManager, apt/dpkg
integrity and shutdown. Both variants use serial text mode; the QEMU-only menu
entry selects `multi-user.target`. There are no SDDM, GPU, screenshot or
framebuffer checks. Graphics must be tested on the physical laptop, not QEMU.
It does **not** emulate Qualcomm Glymur hardware.
Successful virtual boot is not proof of physical UX3607OA operation.

## GitHub Actions

[.github/workflows/build-images.yml](.github/workflows/build-images.yml) runs
shell and workflow validation on pushes and pull requests. Full image builds
are manual and restricted to the repository's default branch. Both images are
built in one job so KDE is derived from that run's CLI filesystem and uses the
same Debian-configured kernel and local packages.

Full builds require a **dedicated self-hosted Debian sid amd64 runner** with
the labels `self-hosted`, `Linux`, `X64`, and `ux3607-builder`, passwordless sudo,
at least **16 GiB RAM**, and **100 GiB free space** on its workspace filesystem.
The workflow checks capacity, installs the build dependencies through apt,
enables ARM64 binfmt, and checks loop-device and mount-namespace access. A
normal unprivileged container is not suitable. Standard GitHub-hosted runners
are used only for linting, not the large privileged image build.

1. Push the source repository to GitHub and register the dedicated runner in
   **Settings > Actions > Runners**, adding the `ux3607-builder` label. Protect
   the default branch and run only trusted code on this sudo-capable machine.
   Do not use a runner shared with sensitive workloads or credentials.
2. Open **Actions > Build Debian sid images > Run workflow**, select the
   default branch, and choose the kernel compilation job count. Eight is the
   default; use four on smaller runners.
3. Leave **Upload images/packages** disabled unless you have reviewed the
   proprietary ASUS firmware's licensing and are authorized to upload it.
   Checking this option uploads both compressed images, the kernel/firmware
   packages, kernel configuration, package manifests, and checksums. It does
   not create a GitHub Release or push commits.

The job builds and verifies CLI first, then KDE, including read-only filesystem
checks and text-only QEMU UEFI USB boot tests. It compresses both raw images with zstd and
checks their SHA-256 hashes. Build reports are uploaded even on failure and
retained for 14 days; optional firmware-containing artifacts are retained for
7 days. Actions and the actionlint download are pinned to commits/checksums.

The generated `work/` tree is removed at the end of the CI job, including any
root-owned chroots and local module-signing keys. The `artifacts/` directory
remains in the runner workspace until the next checkout, allowing local
retrieval when uploads are disabled. Do not point the Actions runner workspace
at a directory containing unrelated work. Git ignores both generated trees,
downloaded firmware installers, disk images, packages, and local secrets.

After downloading the optional artifact, verify the compressed files with
`sha256sum --check --ignore-missing SHA256SUMS`. Decompress the chosen image
with `zstd -d`, then repeat the checksum check to verify the raw disk image too.
The KDE sid-snapshot and firmware limitations described above also apply to CI
builds. A successful workflow is not a hardware certification.