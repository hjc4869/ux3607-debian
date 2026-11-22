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
is in Linux 7.3. That release also contains the board's QSEECOM allowlist entry,
SoCCP support, TCSR support, basic Glymur display PHY support, and PCI
power-control support. The board DTS alone does not provide all working-device
prerequisites. The build applies the 17-patch
[kernel series](patches/linux/README.md):

- the missing eDP v8 programming fixes;
- generic QCC2072 UART/M.2 Bluetooth support;
- mainline 7.4 fixes for Glymur USB votes, A16 microphones, Adreno X2 power
  votes, PMIC GLINK and ath12k;
- the Wi-Fi 7 MLO handshake fix;
- the ASUS EC driver and device-tree node, for fan RPM, EC temperatures and the
  keyboard backlight.

No speculative HDMI clock workarounds are applied.

Kernel: **7.3.4-ux3607oa**, upstream stable tag `v7.3.4`, commit
`7595a62d45ee1a2297eafa5f2ef5d0a45142d84d` (2026-11-10).
This is an upstream stable release, but this local build gets no automatic
Debian security updates.

## CPU Frequency Scaling

Earlier builds inherited Debian's `# CONFIG_ARM_SCMI_CPUFREQ is not set`. The
laptop's firmware answered SCMI (its boot log shows `scmi-perf-domain:
Initialized 3 performance domains`), but no cpufreq driver attached. The cores
stayed at whatever speed UEFI left them: no scaling up for load, no scaling down
at idle, and no CPU cooling devices.

Kernel `+ux3607oa1` builds `scmi-cpufreq` in and builds the CPUCP mailbox driver
in, rather than as a module. The A16 community investigation found that a
modular mailbox lost completion interrupts for SCMI performance requests, and
that building it in restored them. Ubuntu Concept also enables SCMI cpufreq.
After booting, check:

```sh
cat /sys/devices/system/cpu/cpufreq/policy*/scaling_driver   # expect: scmi
grep . /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq
sudo journalctl -k -b | grep -iE 'scmi|cpufreq'
```

If `scmi-cpufreq` probes but logs `-110` timeouts, report that log. The fallback
used on the A16 community tree is `arm,no-completion-irq` on the `scmi` node,
which is not applied here.

## Debian Configuration And Packaging

The baseline is Debian sid's own standard 4 KiB-page ARM64 configuration for the
same upstream release, `linux-config-7.3_7.3.4-1_arm64.deb`, SHA-256
`cac059543a40e3c0aa5a126676d00d82d92f7f8c2873ad2f6d3bddf831be25c3`.
It is migrated with `olddefconfig`, not replaced with ARM64 defconfig.

[config/kernel.config](config/kernel.config) contains the small local delta:
kernel identity/signing settings, Glymur clocks/interconnect, its required M31
eUSB2 PHY, the SM8650 LPASS pinctrl fallback used by Glymur audio, simpledrm
fallback with `CONFIG_SYSFB_SIMPLEFB=y` for EFI handoff, built-in SCMI cpufreq
and CPUCP mailbox, and the ASUS EC driver. Debian 7.3.4 still lacks all of these
except the CPUCP mailbox, which it builds as a module.
Pinned versions and input checksums are in [scripts/versions.sh](scripts/versions.sh).
Debian's module, security, filesystem and
debug/BTF settings are retained where supported by upstream and the toolchain.
Removed/new symbols and unavailable Rust settings are recorded in
`artifacts/kernel/debian-config-delta.txt`; the untouched baseline and final
configuration are saved alongside it.

New image builds install these packages through apt from a root-owned local
repository:

- `linux-image-7.3.4-ux3607oa`, version `7.3.4-1+ux3607oa1`:
  upstream `bindeb-pkg` image, modules, DTBs, configuration, System.map, and
  standard Debian kernel maintainer hooks.
- `ux3607oa-boot-support`, version `1.0-7`: board-aware GRUB generation,
  initramfs contents, firmware dependencies, kernel/initramfs update hooks, and
  the upstream A16 ALSA UCM profile ([config/alsa-ucm2](config/alsa-ucm2/README.md)).
  GRUB adds a **previous kernel** entry when an older `-ux3607oa` kernel is
  still installed.
- `firmware-ux3607oa-local`, version `1.312.4500.0-3`: locally extracted ASUS
  ADSP/CDSP firmware, exact-model Wi-Fi board data, and the A16 audio topology
  from upstream linux-firmware, with provenance/hashes.

The latest build is a **kernel/package update**, not a rebuilt pair of USB disk
images. Existing `.img`/`.img.zst` files keep their older packages until they
are explicitly rebuilt or upgraded. The running laptop is not changed by
building these packages.

The pristine source stays in `work/linux`; the patched source is a separate
detached worktree identified by the patch manifest hash. Unexpected source
edits are rejected rather than overwritten. Patch hashes and the patched Git
tree ID are saved in `artifacts/kernel/patches.sha256` and `source-tree`.

To upgrade a booted installation, transfer the three new packages to it, then
run this there with the USB EFI partition mounted at `/boot/efi`:

```sh
sudo apt install ./linux-image-7.3.4-ux3607oa_7.3.4-1+ux3607oa1_arm64.deb \
   ./ux3607oa-boot-support_1.0-7_arm64.deb \
   ./firmware-ux3607oa-local_1.312.4500.0-3_all.deb
sudo reboot
```

The new kernel has a new release name, so the 7.3.0-rc4 kernel stays installed
and appears as the last GRUB entry, **previous kernel 7.3.0-rc4-ux3607oa**. Use it
if 7.3.4 misbehaves. Remove it with `apt remove linux-image-7.3.0-rc4-ux3607oa`
once 7.3.4 is confirmed good.

Use the **normal ASUS boot entry** to test native display; the recovery entry
deliberately blacklists MSM. Keep USB Ethernet/SSH available and HDMI unplugged
for the first test. The raw updated kernel is `artifacts/kernel/Image`.

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

The local firmware package adds the board-data entry from
[the exact UX3607OA report, kernel bug 221984](https://bugzilla.kernel.org/show_bug.cgi?id=221984):
PCI subsystem `105b:e14f`, QMI chip 33, board 255, variant `UX3407Q`. The pinned
reporter's payload is encoded into Debian firmware-atheros 20260810-1's board
container using a checksum-pinned `ath12k-bdencoder`. Validation requires exactly
one board addition with no existing calibration or regulatory entries changed.
The package installs it under `/usr/lib/firmware/updates/ath12k/QCC2072/hw1.0/`,
so Debian's original file remains owned and maintained by Debian. This override
takes precedence even after a Debian firmware upgrade; remove/rebuild the local
override when the correct entry becomes available upstream. The payload differs
from the ASUS BSP copy and is recorded separately in the package provenance.

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

Speaker playback was reported by the patch author. Debian's firmware and UCM
packages still lack the `GLYMUR-ASUS-Zenbook-A16-UX3607OA` profile, so the local
packages now supply both upstream pieces:

- **Topology:** linux-firmware commit `466e500db134` ships the A16 AudioReach
  topology. It is byte-identical to the Glymur CRD topology Debian already
  ships; the kernel only needs it under the A16 card name. It is installed
  under `/usr/lib/firmware/updates/qcom/glymur/`.
- **UCM:** Konrad Dybcio's upstream alsa-ucm-conf commit `d260eedd1900` provides
  four-speaker and two-DMIC routing for this laptop. Every codec file it
  includes is identical in Debian's alsa-ucm-conf 1.2.16.1.

Mainline's A16 microphone sample-rate fix is in the kernel series. Speakers and
microphones are still untested on hardware here; headphone and HDMI audio are
not in the upstream profile.

Wi-Fi 7 routers using MLO could reject the A16 with `4WAY_HANDSHAKE_TIMEOUT`,
which looks like a wrong password. Kernel patch 14 fixes the link lookup that
dropped EAPOL frames. If it still happens, limit the router or the connection to
Wi-Fi 6 and report the kernel log.

The UART Bluetooth patch requests the
`orn*` firmware family; Debian includes the revision-11 set, but the laptop's
controller revision and NVM/calibration compatibility still need physical
validation. No ASUS `cln*` files are renamed to another firmware family.
The separate HDMI `com_aux` clock failure remains unresolved.
Camera, suspend/resume, video acceleration, NPU, touchscreen, battery runtime and
thermals are also not validated here. The EC driver exposes fan RPM and EC
temperatures through hwmon (`sensors`, or `/sys/class/hwmon/*/name` =
`asus_glymur_ec`) and the keyboard backlight as `asus::kbd_backlight`. The fan
curve stays under EC control.

## Ubuntu Concept Comparison

Reviewed on 2026-11-17 against the
[Ubuntu Concept 26.10 Snapdragon thread](https://discourse.ubuntu.com/t/ubuntu-concept-26-10-snapdragon-edition/88518),
its `linux-qcom-x1e` 7.3.0-31.31 kernel source and configuration, and the
`ubuntu-x2e-settings` 34 package.

Adopted, in the forms described above:

- SCMI cpufreq enabled.
- The eDP v8 pair and M.2 Bluetooth power sequencing (already carried).
- The A16 topology and UCM that thread users installed by hand.
- The Wi-Fi 7 handshake fix for the failure thread users reported.

Not adopted:

- **Global `clk_ignore_unused pd_ignore_unused regulator_ignore_unused`.**
  `ubuntu-x2e-settings` sets these on every X2 boot. Here they stay limited to
  the basic-display recovery entry, as documented under Black-Screen Recovery.
- **`qcom-firmware-extract`.** Its A16 entry copies the same ASUS ADSP/CDSP
  files that `firmware-ux3607oa-local` already takes from the checksum-pinned
  ASUS bundle.
- **Other boards' changes.** Ubuntu's PCIe3, camera and other-board patches do
  not apply to the A16; Ubuntu carries no A16-specific kernel patch beyond the
  ones above.

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
   troubleshooting and preserves firmware-enabled clocks and power domains.
   The third entry is **only for QEMU**, never the laptop. A fourth entry,
   **previous kernel**, appears only after an in-place kernel upgrade.

The GPT/root filesystem does not automatically expand to fill a larger stick.
Use a partition editor if additional persistent space is needed.

## Black-Screen Recovery

If the laptop keeps running but its display goes black shortly after early boot
messages, highlight the **basic display** GRUB entry, press **e**, and append
the following to the line starting with `linux`:

```text
clk_ignore_unused pd_ignore_unused
```

Keep the existing `root=`, `acpi=off`, console and other arguments. Press
**Ctrl+X** or **F10** to boot this one-time edit. On the normal entry, append the
complete fallback instead:

```text
nomodeset module_blacklist=msm clk_ignore_unused pd_ignore_unused
```

The first two arguments prevent native MSM graphics takeover; the last two
stop unused-clock/power-domain cleanup from shutting down display resources
left enabled by UEFI. This is a diagnostic workaround, not a confirmed native
display fix. It relies on a usable UEFI framebuffer and can increase power use;
do not make these flags global defaults. For an intermediate test that keeps
native graphics enabled, add only `clk_ignore_unused pd_ignore_unused` to the
normal entry.

The original image contained `simpledrm` but had `CONFIG_SYSFB_SIMPLEFB` disabled
and no `efidrm` driver. It could use legacy efifb for early text, but not the
intended EFI-to-simpledrm fallback. Kernel package revision `+ux3607oa3` enables
that handoff; boot-support `1.0-5` includes all four recovery arguments only in
the basic-display entry. The default hardware boot entry is unchanged.
The image verifier checks the config, initramfs module, and separation between
normal and recovery arguments. The actual panel/eDP/clock drivers and Gen8 GPU
firmware were already present in the original CLI initramfs.

These build checks cannot establish why native display fails on this laptop.
Physical verification is still required; no QEMU graphics testing is used.
Once the recovery entry gives a console, enable persistent kernel logging:

```sh
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo journalctl --flush
```

For a diagnostic native boot, use the normal entry without `nomodeset` or
`module_blacklist=msm`, and append `drm.debug=0x1ff log_buf_len=8M`. If it goes
black, shut down gracefully with the power button, boot the recovery entry,
and collect the previous boot's kernel log:

```sh
sudo journalctl -k -b -1 --no-pager > ux3607oa-native-kernel.log
```

That log can distinguish a failed panel/DP probe, deferred dependencies,
firmware loading errors and resource shutdown. Without it, adding unrelated
driver patches would be speculative.

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