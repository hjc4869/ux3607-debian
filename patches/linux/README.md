# UX3607OA Kernel Patch Series

Base: Linux v7.3.4 (stable), commit `7595a62d45ee1a2297eafa5f2ef5d0a45142d84d`.
Apply in [series](series) order. Patches 1-6, 15 and 17 are pending upstream
submissions. Patches 7-13 and 16 are mainline commits from the 7.4 merge window,
backported unchanged. Patch 14 is a 7.3-only Wi-Fi fix (see below). None of this
has been validated on the laptop by this build.

## Sources

### Display and Bluetooth (carried since 7.3-rc4)

1. [0001-phy-qcom-edp-split-power-on.patch](0001-phy-qcom-edp-split-power-on.patch)
   by Bjorn Andersson: [split power-on sequencing by PHY version](https://lore.kernel.org/all/20260622-glymur-edp-phy-v1-1-814b45089ac9@oss.qualcomm.com/).
2. [0002-phy-qcom-edp-v8-programming.patch](0002-phy-qcom-edp-v8-programming.patch)
   by Bjorn Andersson: [update v8 power-on programming sequence](https://lore.kernel.org/all/20260622-glymur-edp-phy-v1-2-814b45089ac9@oss.qualcomm.com/).
3. [0003-dt-bindings-qcc2072.patch](0003-dt-bindings-qcc2072.patch)
   by Rahul Samana: [QCC2072 Bluetooth binding](https://lore.kernel.org/all/20260727-rb3-industrial-bt-uart-v2-1-2d100f30e202@oss.qualcomm.com/).
4. [0004-bluetooth-qca-qcc2072.patch](0004-bluetooth-qca-qcc2072.patch)
   by Vivek Sahu, with Yepuri Siddu and Rahul Samana:
   [QCC2072 UART support](https://lore.kernel.org/all/20260727-rb3-industrial-bt-uart-v2-2-2d100f30e202@oss.qualcomm.com/).
5. [0005-pwrseq-m2-qcc2072.patch](0005-pwrseq-m2-qcc2072.patch)
   by Krishna Chaitanya Chundru: [QCC2072 M.2 PCI identification](https://lore.kernel.org/all/20260727-rb3-industrial-bt-uart-v2-3-2d100f30e202@oss.qualcomm.com/).
6. [0006-bluetooth-qca-m2-pwrseq.patch](0006-bluetooth-qca-m2-pwrseq.patch)
   by Manivannan Sadhasivam: [M.2 Bluetooth UART power sequencing](https://lore.kernel.org/all/20260710-monza-wireless-v3-1-46253587af64@oss.qualcomm.com/).

The Ubuntu Concept 26.10 kernel (`linux-qcom-x1e` 7.3.0-31.31) carries the same
eDP pair and the same M.2 Bluetooth power-sequencing change.

### Added for 7.3.4

7. [0007-glymur-usb-clock-power-votes.patch](0007-glymur-usb-clock-power-votes.patch):
   mainline [0f8d35f04a12](https://github.com/torvalds/linux/commit/0f8d35f04a126fb17134728ec441a177a35babb5),
   missing USB clock, power-domain and interconnect votes for Glymur.
8. [0008-zenbook-a16-mic-sample-rate.patch](0008-zenbook-a16-mic-sample-rate.patch):
   mainline [73f0a1026210](https://github.com/torvalds/linux/commit/73f0a1026210c008ba4414b3181fa679096ef968),
   correct A16 DMIC sample rate.
9. [0009-drm-msm-a6xx-rpmh-dep-votes.patch](0009-drm-msm-a6xx-rpmh-dep-votes.patch):
   mainline [eab0aff8965e](https://github.com/torvalds/linux/commit/eab0aff8965ee17cf972a37eb6456032c45b7acd),
   build the GPU's RPMh dependency-vote table from the GPU OPP table.
10. [0010-drm-msm-a8xx-perfmode-bw.patch](0010-drm-msm-a8xx-perfmode-bw.patch):
    mainline [db6a2e4a7ebd](https://github.com/torvalds/linux/commit/db6a2e4a7ebd4378d03a97f4bef22f8c157240ad),
    A8x (Adreno X2) votes ACV only above the perf-mode bandwidth threshold.
11. [0011-pmic-glink-early-rpmsg-probe.patch](0011-pmic-glink-early-rpmsg-probe.patch):
    mainline [0c79a829af36](https://github.com/torvalds/linux/commit/0c79a829af36a94143c747a0ab8f0a8563b17cfa),
    battery/USB-C PMIC GLINK no longer loses an early rpmsg probe.
12. [0012-ath12k-regd-update-completion.patch](0012-ath12k-regd-update-completion.patch):
    mainline [f2576dc0f894](https://github.com/torvalds/linux/commit/f2576dc0f894ef33045ba7ed057ec417988bba8a).
13. [0013-ath12k-dangling-channel-pointers.patch](0013-ath12k-dangling-channel-pointers.patch):
    mainline [507478f6f938](https://github.com/torvalds/linux/commit/507478f6f93864978a399173d4f54c8a987c8235).
14. [0014-ath12k-qcc2072-mlo-4way-handshake.patch](0014-ath12k-qcc2072-mlo-4way-handshake.patch)
    by Miaoqing Pan: [fix MLO 4-way handshake timeout on QCC2072](https://patchwork.kernel.org/project/linux-wireless/patch/20260815014329.3748059-1-miaoqing.pan@oss.qualcomm.com/).
    Fixes the Wi-Fi 7 (MLO) "wrong password" / `4WAY_HANDSHAKE_TIMEOUT` reported
    on A16s in the Ubuntu Concept thread. Upstream marked it rejected because 7.4
    reworked the mac80211 RX API and removed the affected function; 7.3 still has
    the bug. It is a 7.3-only carry, tested on QCC2072 by its author and carried
    by the A16 community tree. Drop it when moving to 7.4.
15. [0015-dt-bindings-asus-zenbook-a16-ec.patch](0015-dt-bindings-asus-zenbook-a16-ec.patch)
    by Konrad Dybcio: [EC binding v4](https://patchwork.kernel.org/project/linux-arm-msm/patch/20261015-topic-asus_ec-v4-1-af6305ffcb10@oss.qualcomm.com/),
    reviewed by Krzysztof Kozlowski.
16. [0016-platform-asus-glymur-ec.patch](0016-platform-asus-glymur-ec.patch):
    mainline [db3a9dddab5f](https://github.com/torvalds/linux/commit/db3a9dddab5f34fd3e6fd23271db37e56e75d27d),
    ASUS Glymur EC driver: fan RPM and EC temperatures through hwmon, keyboard
    backlight LED, EC events and modern-standby notifications. Taken from the
    merge commit, before 7.4's tree-wide `devm_kzalloc_obj()` conversion that
    7.3 cannot build.
17. [0017-zenbook-a16-embedded-controller.patch](0017-zenbook-a16-embedded-controller.patch)
    by Konrad Dybcio: [A16 EC device-tree node v4](https://patchwork.kernel.org/project/linux-arm-msm/patch/20261015-topic-asus_ec-v4-3-af6305ffcb10@oss.qualcomm.com/),
    reviewed by Abel Vesa.

Patches 1-4 and 6 are unchanged from the 7.3-rc4 series. Patch 5 is the same
one-entry addition, with context refreshed for 7.3.4's Lenovo WCN7850 entry.
Patches 7-17 keep their original headers.

## Considered But Not Applied

- Ubuntu Concept's other 7.3 changes are for other machines (PCIe3 controller
  nodes, other boards' device trees, CSI PHY camera stack), or have no
  traceable upstream source (GPU devfreq registration order).
- A16 community tree (FixItFoundry/zenbook-a16-linux, 158 patches on 7.3):
  its local CPU/LLC cooling maps, SCMI polling override, PCI suspend skips,
  private review rollups and camera stack are left out. The SCMI change is
  replaced by building the CPUCP mailbox driver in, as that tree's own notes
  recommend.
- `arch_topology: seed capacity_freq_ref with boost-aware max freq` (pending
  upstream) only matters if this firmware exposes boost OPPs while boost is
  disabled. Check `/sys/devices/system/cpu/cpufreq/boost` on the laptop first.

## Build Integration

The build keeps the pristine `work/linux` clone and fetches the pinned stable tag
into it when needed. It creates a detached worktree named by the patch
manifest's hash. Patches are applied sequentially with `git apply --index`. The
indexed tree hash is recorded, and unexpected source changes make a later build
stop rather than discard them. No Git commit or branch is created by patch
application.

`artifacts/kernel/patches.sha256` identifies the series and patch contents.
`source-commit` records the base commit and `source-tree` the patched tree.
`LOCALVERSION` is explicitly empty in the build environment, so the configured
`-ux3607oa` release name does not get an accidental dirty-tree suffix.
Versions and pinned inputs live in [scripts/versions.sh](../../scripts/versions.sh).

## Limits

- The UART Bluetooth patch requests `ornbtfw*`, `ornnv*` and `ornbcscal*`.
  Debian's firmware-atheros includes the revision-11 set. The ASUS Windows
  bundle includes a different `cln*10` family; no speculative rename is made.
  Bluetooth firmware/NVM suitability still needs validation on the laptop.
- The separate HDMI `com_aux` clock issue has no established root-cause patch
  here. Keep HDMI unplugged for first tests.
- The Wi-Fi board-data change is in the firmware package, not a kernel patch.
