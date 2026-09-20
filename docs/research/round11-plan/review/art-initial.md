# Round 11 ART independent review

Reviewed frozen candidate `2f1ffc29015fa5ffdd360d0b5003624002177f1a`, covering ART commits `c76e6bba`, `edb0d7b3` and evidence-binding commit `2f1ffc29`, with merged GEAR correction `67cd7c4b` treated as a dependency rather than ART authorship. Sources included the approved Round 11 plan, `character_visuals.md`, workflow/model policy, Lua strategy, full media/licence ledgers, frozen hashes and both rendered evidence images. Reviewer independence: I authored none of the candidate. Review was read-only; no repository files or commits were changed.

## Finding

### Medium — Iron and Embersteel shields retain copper and gold material colours

`mods/ITEMS/grug_gear/init.lua:124-127` binds each shield directly to its renamed PNG, and `:506-515` publishes that string unchanged as `inventory_image`; there is no runtime tint or other material treatment. Byte comparison confirms `grug_gear_shield_iron.png` is the unchanged upstream `lottarmor_inv_shield_copper.png`, while `grug_gear_shield_embersteel.png` is unchanged `lottarmor_inv_shield_gold.png`. This matches the actual `media-sheet.png`: the item named **Iron Shield** is saturated orange/copper, and **Embersteel Shield** is bright yellow/gold. By contrast, the accepted ladder and the candidate's other items establish Iron as dull grey and Embersteel as a red/warm ember metal. The mismatch makes the representative art communicate the wrong material identity.

Concrete trigger: place an Iron Shield or Embersteel Shield beside the same-tier sword or armor in inventory. The shield visibly reads as a different named metal, even though its description and gameplay bracket say Iron or Embersteel.

Required correction: apply deterministic material treatments to those two shield assets (baked files or explicit native modifiers) so Iron reads grey and Embersteel reads red/warm ember while preserving the accepted shield silhouette. Update the media sheet, frozen hashes, licence treatment column and binding fixture expectations to the final runtime strings. Review all six resulting runtime images together after the correction.

## Verified

- Both required images were inspected at original resolution. The bow evidence shows the arc midpoint in the fist across all four sampled arm angles, and the new `grug_bow` dispatch precedes generic weapon groups. The pose uses a centre anchor and exact `(90,45,-90)` rotation without disturbing the tool, axe or upright paths.
- All frozen source, production-media and view manifests verify. The final source manifest correctly follows the GEAR merge. The main checkout's reference pins are exact and clean; imported bag, shield and bow bytes were compared against pinned sources.
- Licence attribution is consistent with upstream per-file records: LotT small/medium bags are Amaz CC BY-SA 3.0; `bags_large.png` is Brett O'Donnell BSD-3-Clause; the nine selected `x_farming` seed files are in SaKeL's CC BY-SA 4.0 list; shields/bows use LotT's otherwise-media CC BY-SA 3.0 rule; VoxeLibre station/book/arrow sources are recorded under CC BY-SA 4.0. The generated quiver has its own CC0 ledger entry and makes no false upstream claim.
- Station appearance remains data-only and factory-owned. Every station texture referenced by `station_visuals.lua` exists; the four-box anvil, cube loom, dark-based muted-gold Goldsmith treatment and upright Woodcarver geometry preserve the existing station behavior path.
- Silversteel weapon and gathering-tool forms preserve the existing silhouettes and wooden handles; inventory armor and worn overlays use the same neutral HSL correction. Catalog registration, composition and media references contain no missing texture found in the reviewed paths.
- `seed_visuals.lua` is a pure complete 17-key map over nine shipped source sprites. Its FARM registration consumer is intentionally pending on the FARM branch; the interface is suitable for that dependency and is not an ART defect.
- The shipped runtime has no dependency on `reference_projects/`; all imported bytes live under the owning mods. No upstream code or unwrapped model texture is used as an icon.
- The frozen focused LuaJIT receipt reports the real gear registration, bow dispatch/geometry and media checks clean. Static evidence records successful Lua 5.1 parsing, SETGLOBAL inspection, five sweeps and `git diff --check`. No PUC runtime was run, per the explicit session constraint.

**Verdict: FINDINGS — not clean.** Zero Critical, zero High, one Medium, zero Low.
