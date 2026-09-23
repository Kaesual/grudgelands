# Round 19 D and living-document drift — independent review

Final verdict: **PASS after one focused correction round**; 0 unresolved findings. Initial verdict: CHANGES REQUIRED (1 High, 1 Low). Snapshot `/tmp/grug-r19-review-map` at `17786aef`, baseline `3b23a8f8`; D author commit `d823b0ce`, integrated by `0b90752a`. Read-only review, no implementation authorship and no production edits. Lane A's earlier PASS remains unchanged.

Initial historical calibration: D implementing model GPT-5.6 Sol; reviewing model GPT-6 Astra. Initial findings: 0 Critical / 1 High / 0 Medium / 1 Low (Low is documentation drift); fix rounds 0; elapsed wall time unknown. Integrated documentation author: GPT-6 Astra coordinator, distinct from this independent reviewer.

## High — billboard sizes do not inherit the parent's visual scale

`mods/CORE/grug_core/tag_carrier.lua:160` divides the explicit dragon sprite dimensions by the parent's visual size, making the intended 3.0 by 0.25-node bar only 0.375 by 0.03125 nodes on both current scale-8 dragons.

Concrete scenario: injure either dragon while inside its observer range. The metadata is correctly preserved and its anchor is lowered, but the emitted sprite properties are `{x=0.375,y=0.03125}`. The actual native billboard renderer never restores the missing factor of eight, so the bar remains very small rather than gaining its declared dragon-appropriate size.

Engine proof:

- `reference_projects/luanti/src/client/content_cao.cpp:774` creates a billboard scene node; `:779` sets its size to `visual_size * BS`.
- `reference_projects/luanti/irr/src/CBillboardSceneNode.cpp:90` uses absolute position (which inherits parent attachment transforms), but `:103-109` builds the horizontal/vertical dimensions directly from `Size` and `TopEdgeWidth`, without parent scale.
- `:124-127` constructs already-world-space vertices; `:75` renders them with the identity world matrix. Its own `:136` comment explicitly notes that scaling does not scale its vertices.
- Attachment translation is different: `content_cao.cpp:1465-1471` parents the matrix node under the parent's scene node and installs raw attachment translation. The `anchor_y * 10 / sy` conversion should remain.

Required correction: return `anchor_y * 10 / sy, width, height` in the explicit dragon-profile branch. Correct the adjacent explanation and `tools/r19_hud/fixture.lua:230-250`, whose expected values currently codify the false size-inheritance assumption. Correct `docs/research/round19-hud-report.md` accordingly. The native registration probe confirms metadata survives registration but cannot detect this client rendering defect; successful probe output does not resolve it.

The generic pre-existing branch at `tag_carrier.lua:167` contains the same size assumption. Under the Round 19 requirement to preserve ordinary mobs/guards, the smallest scoped correction leaves that branch numerically unchanged and clearly distinguishes its prior behavior. A broader correction would need an explicit scope decision plus appropriately scaled ordinary-mob coverage; do not silently retune it while fixing dragons.

## Low — living spec still advertises superseded talent KAT semantics

`docs/design/skill_trees.md:1055-1061` says the current `tools/wp11/talent_ui_kat.lua` covers select-then-buy and raw/effective/cap rendering, in present tense and without a historical qualifier. This conflicts with the Round 19 first-click purchase/current Character-only statistics contract in the same living file.

Concrete scenario: a maintainer follows this validation paragraph after changing the current talent UI and treats the historical two-click/raw-header fixture as the current oracle. The lane report correctly calls that fixture historical, but the living specification still directs otherwise. Mark this paragraph as historical/superseded and identify the Round 19 current UI fixture, or remove the obsolete current-validation claim.

## Other reviewed boundaries

- `grug_mobs.register_mob` publishes a copied profile after the actual mobs_redo registration whitelist, so the registered prototype and new instances can expose it. `mods/ENTITIES/mobs/api.lua:4037` confirms the whitelist boundary. The profile is bounded server-authored presentation data, not a player input or a travel/combat authority.
- Only the two adult dragon definitions install profiles. Whelp definitions do not copy these records. Ordinary fallback geometry is unchanged in the candidate.
- Injured-only visibility, health fraction, observer hysteresis/filtering, settings and ephemeral removal remain on the unchanged tag-carrier path. No global boss HUD, new scanning loop, migration, dynamic scaling policy or per-bone tracker was added.
- Explicit anchors 5/4 match the existing dragon eye heights and are below their prior collision tops 8/6.4. Actual animated head alignment and combat-distance readability remain user GUI gates.
- Reviewed changed living design docs and AGENTS against the approved Round 19 contract: atlas zoom/scroll/session rules, Character/Help/Talents separation, Skills hint, party default, top-center status and Sprint ownership are otherwise aligned. The coordinator's pending exact 5/4 and 3x0.25 numerical documentation addition is appropriate but cannot resolve the implementation's size conversion defect.

No runtime process was needed for these source-proven findings. No PUC, native engine or performance run was performed. Root retains ownership of final static evidence, native registration probe and frozen PUC/LuaJIT pair; those must use corrected final bytes. Focused independent re-review is required for the High correction.

Reviewed SHA-256:

- tag_carrier.lua: `4d465c2913fb7fb4198af9e57a81cc001e9be57bcd185b8ca72500664a85b528`
- grug_mobs/init.lua: `7bdf8c7427af349a794b55c44e54da23b05ccd8e52cf4f39e10fc46c1720847d`
- boss_dragons.lua: `4f5e74f7c52454ca341354a10ef1fa65216116d280a19290a08fe3a563ac87e2`
- HUD fixture: `de248edb75fdc4716c9738ba4af9b0ec2e2e583ea1ee0ce93742f7228ad8ea2d`

User runtime plan after correction: injure both dragons, confirm readable bars close to head/body at normal combat distance, restore full HP, remove/unload/reload them, and verify no stale bars. Compare a rat, humanoid, guard and whelp with their existing presentation.


## Focused re-review closure — e398c90f

Reviewed immutable commit objects at `e398c90f6be3118cae758510c5efcbacc73c1cb4`
(author correction `f6b59890a8575037f0b584280e002f39a5935804`), including its
ancestor documentation correction `7ee6533da04f4cfd66627f4ca3f8b5282590f1bc`.
The review worktree itself remained at the initial snapshot; `git show`/`git diff`
read the exact final commit objects without modifying it.

**High closed.** The explicit branch now returns `anchor_y * 10 / sy, width,
height`. Thus attachment offsets remain 6.25/5 engine units while both native
billboards receive direct 3x0.25 dimensions. This matches the independently read
Irrlicht renderer cited above. Both dragon fixture expectations now assert those
values. The lane report removes the false inherited-size claim and accurately
limits the unit-scale ordinary fixture. The generic production arithmetic is
unchanged, as required by the coordinator's scoped decision; no ordinary retune
was introduced. Its old generic-size comment remains historical technical debt,
not a claim made by the corrected explicit branch or current living spec.

**Low closed.** `skill_trees.md` explicitly marks the WP11 two-click/raw-header
fixture historical, rejects it as a current UI gate, and points to the current
Round 19 fixture/final runner. `combat_stats.md` states exact 5/4-node anchors,
3x0.25-node dimensions and the correct position-versus-billboard distinction,
while describing ordinary geometry as unchanged rather than scale invariant.

Final calibration: implementing model GPT-5.6 Sol; reviewing model GPT-6 Astra;
initial C/H/M/L 0/1/0/1; unresolved 0/0/0/0; fix rounds 1; elapsed unknown.
No runtime suite was duplicated. Root must still run and preserve final static,
registration and frozen interpreter evidence. User GUI acceptance remains as
listed above; PASS is source/contract acceptance, not a client visual test.

Final frozen source update: reviewed comment-only `15f994a1` after `e398c90f`.
It also corrects the old generic-path comment to describe its unchanged inverse
sizing without claiming world-size invariance. No further source concern remains;
PASS applies to `15f994a1` (including the prior correction and docs).


## Final evidence acceptance

**PASS**, read-only artifact/hash inspection, no runtime duplication. The final
source roster in `tools/r19_final/evidence/source.sha256` matches both the
current checkout and immutable frozen commit `15f994a1`, including the corrected
production file, fixtures and probe. Static output records 18 parsed Lua files,
only the established grug_mobs/grug_parties globals, and five sweeps whose three
hits are comments or a literal string delimiter.

PUC 5.1 and LuaJIT archived outputs are byte-identical and contain all three
successful final fixtures, including the corrected 16-check HUD fixture.
Independently recomputed SHA-256:
`8cec59ed485583831ee6afcded43fb8704e6f18d11ae8d4d5483efd4a69b81cf`.
`parity.json` records zero exit status for both at the frozen commit.

The archived production manifest contains 2,077 files, all independently
hash-matched to the checkout. Its executed manifest contains 2,079 files; the
only existing-file delta is the declared scratch starts-preload scheduling stop,
whose exact replacement hash was verified. The only additions are the integration
probe and its mod.conf. The native log identifies the isolated
`/tmp/grug-r19-integration-mim__g8n/world`, records the expected registration PASS
and shutdown, and contains no ERROR entries. This confirms real registration
metadata survives the vendor adapter; it does not claim rendered GUI acceptance
or prove the billboard renderer by executing a client.

Final technical-evidence acceptance adds no new findings. Both initial findings
remain closed after one correction round. User GUI checks remain pending.
