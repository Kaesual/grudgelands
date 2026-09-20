# Independent capital overlay attribution review

Date: 2026-09-20  
Reviewer: native Sol (`/root/playtest_professions`)  
Evidence commit: `462810d1ca05716abc4bdd3813106acb6e4ef27e`  
Production source represented: `8dd1c8e463a13ccc356cdade123875471b398707` (MAPGEN bytes identical to reviewed phase source)

## Verdict

**CLEAN — all 18 frozen overlay regions are fail-closed and all seven changed regions are completely attributed. Zero unexplained coordinates remain.** This verdict covers attribution evidence only; it does not itself update the seven current baselines or replace the final interpreter pair.

## Independent checks

- The 205-entry artifact manifest verifies byte-for-byte. Manifest SHA-256 is `8659fa48b5758133a49029a3b7865651e099166525703e859556c0d96a1e9f37`; the captured verification transcript is `/tmp/grudgelands-r10/reviews/capital-attribution-manifest-check.txt`, SHA-256 `0648ce7dedb73905a30e1001a0d77ea543ef0dffe61058451ef75fb1ec22e4c8`.
- The 18-row summary SHA-256 is `66df371f1018a2f948ea145a4373eb348eb0f28bf7652552b74cbdb5121bf08e`. It contains exactly 18 regions: 7 attributed changes and 11 exact matches.
- All four gates and all four corners are exact historical matches. Dur Brannoc, Gor Drazhak and Nhal Veyr ramparts match. Highcourt rampart has 267 prior-world changes. All six avenues change.
- Changed-coordinate totals reconcile exactly: Highcourt avenue `863 = 522 accepted + 341 prior`; Highcourt rampart `267 = 0 + 267`; Dur Brannoc `430 = 430 + 0`; Gor Drazhak `410 = 410 + 0`; Nhal Veyr `430 = 430 + 0`; Lethariel `983 = 356 + 627`; Kezamba `533 = 60 + 473`. Every unexplained column is zero.
- The comparator independently binds each old digest/count to the frozen WP13 file and each new digest/count to the `8dd1c8e...` engine receipt. It checks all currently authored cells against engine rows, requires non-avenue inner changes to be empty, bounds avenue changes to the accepted inner band, and refuses any coordinate outside the explicit prior-world/height/foundation classifications.
- Highcourt's controlled replay reproduces every pre-CAP row, including the 267 rampart changes. Lethariel's 405 surface-only coordinates require differing real terrain heights and silver litter exactly at the respective height. Gor's 78 non-palette foundation coordinates require a changed writer mask and exact castle-stone/dry-dirt engine values. These are semantic coordinate checks, not count-only explanations.
- The retained package's four source hashes match actual source `6cd971b0...`; the report correctly avoids treating the misleading `dfb32cd5` label as source authority. The historical snapshot separately binds `game.conf`, `minetest.conf`, `settingtypes.txt`, and the absence of menu/textures.
- Fresh historical full-engine retries for Gor Drazhak and Lethariel both report `exit=0 errors=0 complete=1` and reproduce every old overlay hash/count. The omitted-config failures remain preserved and are not used as passing evidence. No reduced run is presented.

## Calibration

- Initial independent findings: **0**.
- Fix rounds requested by this reviewer: **0**.
- Final severity count: **0 High / 0 Medium / 0 Low**.
- Runtime duplication: none; review used committed source/evidence and a manifest checksum only.

The proposed baseline update must change exactly the seven changed expectation pairs to the summary's new SHA/count values, leave the eleven matching pairs untouched, and retain this attribution evidence as the reason for accepting those deltas.
