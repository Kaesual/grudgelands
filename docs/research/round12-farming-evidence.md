# Round 12 farming implementation evidence

Date: 2026-09-20. Branch: `wp32-r12-farm`.

## Delivered behavior

The living farming specification now defines all seventeen cultivated families
through six shared lifecycle profiles. The implementation preserves the public
root stage and seed identities, four 200-second logical stages, exact wet-soil
pause/resume, deterministic one-item yield and seed-only immature destruction.

Wild Grain, Carrot, Cassava, Wild Onion, Potato and Corn remain annual crops.
Fire Pepper, the three berries, Cave Cap and Ember Moss regress to stage 2 after
picking; Pumpkin and Frost Melon retain their vine and regress to stage 2; Salt
Crust returns to stage 1. Sugar Cane and Bamboo retain their rooted base and
return to stage 1 after upper harvest.

Corn is one/two/three nodes over its four stages, Sugar Cane one/two/three/four,
and Bamboo one/one/two/three. The root owns state, timer, metadata and drops.
Upper helpers have no timer or independent drop. Growth and harvest preflight
loaded positions, blockers and protection before mutation. A protected root
cannot be bypassed through an unprotected upper segment. Current-version root
activation reconstructs only its expected loaded helper geometry; it does not
scan for or recognize legacy state.

`grug_nodes.crop_visual` now has explicit cultivated/wild context. Wild mapgen
continues to register exactly one node per source with unchanged identity,
drops and ecology. No geography, density, renewal budget or ecology schema was
changed.

## Art and provenance

No Hades Revisited byte was selected. Therefore this package adds neither a
Hades submodule nor a Hades license claim. Hades remains research only until a
future selected-file import first receives a permanent pin and exact authorship
and license verification.

Five Corn segment tiles are deterministic derivatives of the already licensed
and pinned `x_farming` stage-3/stage-4 Corn textures. The revised berry stages
use three independently shaped, pinned source families. Cane and Bamboo use
distinct staged base/shoot/stalk art plus exact vertical slices, so their
cultivated multi-node forms no longer repeat one full-stalk tile. The owning
media ledger records the sources and operations;
`tools/r12_farming/build_corn_segments.sh` and
`tools/r12_farming/build_family_silhouettes.sh` reproduce them.

The enlarged actual-asset plate is
`tools/r12_farming/evidence/crop-stages-17x4.png` (592×2788, SHA-256
`0e49d7c8aae7d2fe3372dd1f3b5c9a6f02b4fb1a723430ba2b608b63ec837a89`).
The registered-height composition plate is
`tools/r12_farming/evidence/crop-geometry-17x4.png` (592×9044, SHA-256
`09368412e7e12b293aea586864b9298b7a506e8d80d2ec331fca3a2ee4c62747`).
Both were visually inspected. The first shows recognizable four-stage source
art for every family; the second makes the 1/2/3-node Corn, 1/2/3/4-node Cane
and 1/1/2/3-node Bamboo ladders explicit. These are offline plates, not a claim
of in-engine GUI acceptance; the user runtime walk remains required.

## Focused verification

No PUC runtime or broad suite ran, per the active Round 12 session override.

- Plain Lua 5.1 parser passed for every Lua file in the touched farming,
  crop-visual, mapgen-call-boundary and focused-tool scopes.
- SETGLOBAL inspection reports only the declared `grug_farming` table in the
  production changes. The five Lua compatibility sweeps have no changed-code
  violation; broad-scope matches are existing strings/comments and historical
  manifest data.
- `tools/r12_farming/family_profiles_kat.lua` under LuaJIT reports 17 families,
  68 visual stages and PASS.
- `tools/r12_farming/visual_assets_kat.sh` reports three distinct mature berry
  alpha masks and eight distinct Cane/Bamboo stage masks.
- `tools/r12_farming/integration_kat.lua` under LuaJIT loads the real farming
  registration and reports 17 complete loops plus PASS. The underlying fixture
  now covers each immature seed-only drop, every mature helper ladder, every
  regrowth reset, blocker refusal/resume, protected-root upper-dig refusal,
  unloaded, missing, ordinary-foreign, wrong-stage and wrong-family middle
  segment refusal from both root and upper dig entry points, exact-once whole
  mature Corn removal, wet/dry progress and planting protection.
- `git diff --check` passes.

## Runtime test plan

In a disposable or fresh user world, plant all seventeen families in a wet
four-stage field. Inspect stages 1 and 4, then verify annual dig/replant,
right-click regrowth, retained Cane/Bamboo bases, whole Corn removal from each
segment, blocker retry, protected upper/root behavior, Creative visibility and
unchanged single-node wild sources. Pay particular attention to selection boxes
and whether Corn's segmented art joins cleanly in the engine renderer.

Implementation model: native GPT-5.6 Sol. Independent review and user runtime
acceptance remain outside this authoring record.
