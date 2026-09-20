# Independent review — Round 12 FARM

Review date: 2026-09-20

## Reviewed sources

- Baseline: `68ad8bb1`
- Candidate: `a1f1541fb3a1be48a7fa19ffdf82e053b468d9ce`
- Worktree: `/tmp/grug-r12-farm`
- Contracts: `docs/research/round12-plan/farming.md`, the Round 12 checkpoint, `docs/design/farming.md`, `docs/research/round12-farming-evidence.md`, and the workflow review checklist

I authored none of this package and made no candidate or user-world changes.

## Findings

### High — destructive harvest accepts missing or foreign helper positions and performs a partial organism transaction

`mods/ITEMS/grug_farming/init.lua:296-305` appends an expected upper position only when it currently contains the matching owned helper. A loaded `air`, foreign helper, or unrelated node is silently skipped instead of invalidating the plan. `dig_crop` then protects and removes only the shortened list (`:314-330`), removes the root, and pays the full seed/mature ingredient drops.

**Reproduction:** grow mature three-node Corn, replace its middle helper with a loaded foreign node (or remove it), then dig the root or remaining valid top helper. `whole_crop_positions` returns the root plus any helpers that still match; the dig succeeds and pays Corn + seed while leaving the foreign/remaining structure behind. This violates the frozen rule that a blocked or partially formed organism resolves atomically, and that every occupied/mismatched expected position refuses before any mutation/drop.

**Concrete fix:** in `whole_crop_positions`, require every expected level to be loaded **and** to contain the exact helper for the same crop, stage, root and level; otherwise return `nil`. Add focused cases for loaded air, a helper from another stage/family, and an ordinary foreign node, from both root and upper-segment dig entry points, asserting zero node changes and zero drops.

### Medium — the three berry families remain the same silhouette with palette/detail swaps

The actual stage plate shows Blightberry, Sunberry and Jungle Berry using the same four-stage strawberry geometry. Alpha-mask measurement confirms identical occupied pixels for all three families at every stage. `mods/ITEMS/grug_nodes/crop_visual.lua:3-23` changes only selection bounds (`bush` versus `wide_bush`); selection boxes do not change rendered plantlike sprite geometry.

**Player consequence:** the three adjacent berry families are distinguished mainly by tint, contrary to the frozen requirement that Sunberry be warmer/more open and Jungle Berry visibly broader/tropical rather than all berries reading as palette swaps.

**Concrete fix:** author or license distinct stage art: retain a thorny compact shape for Blightberry, use a rounded/open shrub for Sunberry, and create broad leaves with hanging fruit for Jungle Berry. Regenerate both plates and add a silhouette-mask assertion that the three mature shapes differ.

### Medium — Cane and Bamboo do not show the required stage or family shapes

All four Sugar Cane stage files share one identical texture hash within their family, and all four Bamboo stage files share another identical texture hash. In the geometry plate, growth is represented only by stacking repeated full-height segments. The required root tuft → segmented cane progression and small shoot → thicker/leafier bamboo progression are absent; Bamboo reads as slightly recolored cane rather than a distinct family. `crop_profiles.lua:14-17` and selection bounds in `crop_visual.lua:19-20` provide correct heights but cannot create the required rendered shapes.

**Player consequence:** a newly planted retained base already looks like a mature stalk segment, and players cannot visually distinguish Cane from Bamboo except by stack height/color.

**Concrete fix:** add stage/segment-specific cane and bamboo sprites, including a root tuft/shoot at stage 1 and visibly thicker leafy bamboo uppers. Keep the shipped 1/2/3/4 and 1/1/2/3 helper heights, then regenerate the geometry plate and assert stage texture diversity.

## Verified behavior

- The profile registry contains exactly 17 families and the approved six lifecycle classes.
- Annual, regrowing, salt, retained-base and Corn stage/reset numbers match the frozen matrix.
- Root nodes own timers and drops; helpers have no timers and empty engine drops.
- Growth transitions preflight root/upper load, protection and blockers before mutation; blocked growth retains the owner and retries through its bounded timer.
- Protected-root upper digging and unloaded expected helpers are refused in the supplied focused fixture.
- Mature valid whole-Corn removal settles one drop pair; regrowing and retained families reset to their specified stages.
- Wet/dry partial progress persists and resumes through the root timer.
- Wild ecology code, source catalog, density, renewal budgets, habitats, identities and drops are unchanged. The only mapgen edit passes explicit `wild` visual context; wild sources remain single-node.
- No Hades bytes were imported. Corn derivative provenance and reproduction script are documented.

## Visual assessment

I inspected `crop-stages-17x4.png` and `crop-geometry-17x4.png` at actual supplied resolution. Corn clearly progresses through one/two/three-node geometry and concentrates the mature cob/foliage toward the upper structure. Grain, Fire Pepper, Cave Cap, Ember Moss and the low root families have readable maturation. The berry and Cane/Bamboo issues above remain concrete acceptance failures; several ground-fruit sprites are also stylized, but Pumpkin and Frost Melon are distinguishable enough that I do not raise an additional blocking finding without an engine render.

## Verification and verdict

The focused real-code LuaJIT integration KAT and 17-family/68-stage profile KAT pass. I did not run PUC runtime, a broad suite or a mapgen fleet. Existing parser/static evidence is internally consistent.

**Verdict: REVISE — 1 High, 2 Medium, 0 Critical/Low.** Re-review the High fix and visually inspect regenerated berry/Cane/Bamboo plates before merge.

## Correction recheck — `44d928893e7d278c1190b08c730178e1c25b8a45`

### Verdict: PASS

All three findings from the original review are resolved. No new finding was introduced in the bounded correction diff from `a1f1541fb3a1be48a7fa19ffdf82e053b468d9ce`.

- The whole-organism preflight now requires every loaded upper position to contain the exact helper name for the root crop, stage and level, in addition to passing the existing ownership metadata check (`mods/ITEMS/grug_farming/init.lua:296-307`). A missing helper, ordinary foreign node, wrong-stage helper, wrong-family helper or unloaded segment returns before protection checks, removals and drops (`init.lua:316-332`). The focused fixture exercises all four invalid loaded nodes through both root and upper-segment dig entry points and confirms the organism and drop count remain unchanged before a valid exact-once harvest (`tools/r10_farm/farming_completion_kat.lua:269-297`). This closes the prior High finding without altering the valid/protected paths.
- Blightberry, Sunberry and Jungle Berry now use visibly different growth silhouettes and mature alpha masks. Mandatory inspection of the updated stage and registered-geometry plates shows a low spreading bramble, a compact fruiting shrub and a taller dense berry bush respectively. This closes the first Medium art finding.
- Sugar Cane and Bamboo now use stage-specific artwork and exact per-level slices. The registered-geometry plate shows continuous 1/2/3/4-node cane and 1/1/2/3-node bamboo organisms rather than repeated full sprites; Bamboo also progresses from shoot to branched leafy stalk. This closes the second Medium art finding.

Mandatory visual inspection covered the updated `crop-stages-17x4.png` and `crop-geometry-17x4.png`, including enlarged crops of their berry and vertical-family regions. Their SHA-256 values match the updated evidence document (`0e49d7c8...37a89` and `09368412...62747`). `bash tools/r12_farming/visual_assets_kat.sh /tmp/grug-r12-farm` reports three distinct mature berry masks, eight distinct vertical-family stage masks and PASS. `git diff --check a1f1541f 44d92889` passes. No PUC runtime or broad suite was run.
