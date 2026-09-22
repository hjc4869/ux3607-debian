# UX3607OA Kernel Patch Series

Base: Linux v7.3-rc4, commit `93f51579e7df248780214094418f205253383cc5`.
Apply in [series](series) order. These are pending upstream submissions, not a
claim that every change has been merged or tested on this laptop.

## Sources

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

Patches 1-4 are imported from the original messages. Patch 5 adjusts context
for the base kernel's newer `PCI_DEVICE_SUB` table; its added QCC2072 match is
unchanged. Patch 6 adjusts include context after an upstream header removal and
switch context after patch 4 adds QCC2072. Its power-sequencing logic is unchanged.
No RB3, Monza or Eliza device-tree changes are applied to the ASUS board.

The eDP pair is an explicit prerequisite in the ASUS submission. A
[same-model follow-up](https://lore.kernel.org/all/20260808171321.133028-1-jesse.casco@gmail.com/T/)
reports native HBR2, four lanes, 2880x1800 at 120 Hz after applying it. Test the
normal boot entry, not the recovery entry that blacklists MSM.

## Build Integration

The build retains the pristine `work/linux` checkout and creates a detached
worktree named by the patch manifest's hash. Patches are applied sequentially
with `git apply --index`. The indexed tree hash is recorded and unexpected
source changes cause a later build to stop rather than discard those changes.
No Git commit or branch is created by patch application.

`artifacts/kernel/patches.sha256` identifies the series and patch contents.
`source-commit` records the base commit and `source-tree` the patched tree.
`LOCALVERSION` is explicitly empty in the build environment so the configured
`-ux3607oa` release name does not acquire an accidental dirty-tree suffix.

## Limits

- `CONFIG_PINCTRL_SM8650_LPASS_LPI=m` is a separate Debian-config delta for the
  live LPASS pinctrl compatible. Correct A16 audio topology/UCM assets are
  still needed; no CRD speaker configuration is substituted.
- The Wi-Fi board-data change is in the separately versioned firmware package,
  not a kernel source patch. It adds the exact `105b:e14f`/`UX3407Q` entry.
- The UART patch requests `ornbtfw*`, `ornnv*` and `ornbcscal*`. Debian's
  firmware-atheros 20260810-1 includes the revision-11 set. The ASUS Windows
  bundle includes a different `cln*10` family; no speculative rename is made.
  Bluetooth firmware/NVM suitability still needs validation on the laptop.
- The DP PUSH_IDLE failure guard is already in the base kernel; it is not
  applied twice. The separate HDMI `com_aux` clock issue has no established
  root-cause patch here. The USB-only QCC2072 series is not applied to the
  board's UART Bluetooth path.