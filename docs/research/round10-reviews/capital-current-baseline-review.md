# Independent current capital baseline review

Date: 2026-09-20  
Reviewer: native Sol (`/root/playtest_professions`)  
Reviewed tree: uncommitted baseline-only patch on integration source `8dd1c8e463a13ccc356cdade123875471b398707`  
Attribution authority: evidence commit `462810d1ca05716abc4bdd3813106acb6e4ef27e`

## Verdict

**CLEAN — the proposed current oracle contains exactly 18 reviewed values, changes exactly the seven attributed SHA/count pairs, retains the eleven exact pairs, and leaves every historical expectation byte untouched.**

The runner changes one root literal from `20260915-capital-terrain` to `20260920-capital-round10`. It adds no fallback and does not weaken missing-file, digest, or count failures. This correctly separates the immutable historical oracle used by the attribution comparator from the accepted current baseline.

## Independent comparison

I parsed all 18 new expectation files and compared them independently with both `results/summary.tsv` from the reviewed attribution and their matching historical expectation files. The current SHA/count pairs match the attribution's `new_sha256/new_cells` in all 18 cases. The validation JSON has the same complete key set and values.

Exactly these seven pairs differ from history:

- Dur Brannoc avenue
- Gor Drazhak avenue
- Highcourt avenue
- Highcourt rampart
- Kezamba avenue
- Lethariel avenue
- Nhal Veyr avenue

The other eleven are byte-equivalent in meaning to their historical SHA/count pairs. The independent extraction is `/tmp/grudgelands-r10/reviews/capital-current-baseline-extraction.tsv`, SHA-256 `f27b4ea306e18f7325e2b5ea72cd3ac7645193be96d4e27327c959f1e5c951db`.

`git status` shows no modification under `20260915-capital-terrain`; the snapshot list of those retained files is `/tmp/grudgelands-r10/reviews/historical-baseline-after.sha256`, SHA-256 `4dfcb0163fd57f6f72141d475c9ef640ff56466a870e24a304fb53ae2e6e21d5`. `git diff --check` is clean for the patch.

## Calibration

- Initial independent findings: **0**.
- Fix rounds requested by this reviewer: **0**.
- Final severity count: **0 High / 0 Medium / 0 Low**.
- Runtime duplication: none; this was an offline oracle/provenance comparison.

No R7 source baseline is refrozen, and no engine rerun is claimed or needed for this oracle-only update.
