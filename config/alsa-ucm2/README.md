# A16 ALSA UCM Profile

Speaker and internal-microphone use-case files for the
`GLYMUR-ASUS-Zenbook-A16-UX3607OA` sound card, from upstream alsa-ucm-conf commit
[d260eedd1900](https://github.com/alsa-project/alsa-ucm-conf/commit/d260eedd1900dbf3b477047e048d5382a5f50e24)
("ucm2: Qualcomm: add ASUS Zenbook A16 (UX3607OA)", Konrad Dybcio). BSD-3-Clause,
like the rest of alsa-ucm-conf.

| File | Upstream path | Upstream SHA-256 |
| --- | --- | --- |
| `ZenbookA16-HiFi.conf` | `ucm2/Qualcomm/glymur/ZenbookA16-HiFi.conf` | `a57f5e542f2a6516a54135625d15617f005030125793724e6f6aa20e5f455b83` |
| `ASUS-Zenbook-A16-UX3607OA.conf` | `ucm2/Qualcomm/glymur/ASUS-Zenbook-A16-UX3607OA.conf` | `c1dc4e1931015b39b3b426d8bf2e86efa08389f322a745104d01a3d5597c05df` |

`ZenbookA16-HiFi.conf` is unchanged. `ASUS-Zenbook-A16-UX3607OA.conf` differs
in one line: its `HiFi` use case points to
`/Qualcomm/glymur/ux3607oa/ZenbookA16-HiFi.conf`.

`ux3607oa-boot-support` installs both files in
`/usr/share/alsa/ucm2/Qualcomm/glymur/ux3607oa/`. It also installs
`conf.d/glymur/GLYMUR-ASUS-Zenbook-A16-UX3607OA.conf`, which alsa-lib checks
first for this card's long name. Debian's alsa-ucm-conf 1.2.16.1 owns none of
these paths. Every codec and library file the profile includes is byte-identical
in that release. Once Debian ships upstream's `conf.d/glymur/glymur.conf`
dispatcher, this card-name file still wins, and its content is the same.
