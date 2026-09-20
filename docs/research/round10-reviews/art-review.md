# Independent ART review

**Verdict: FIX FIRST**

- Candidate: `6cfbea3cca76657ce31fefde543efc1f43efec33`
- Base: `1831ec68babe7a317239a5d0eab0f175f45122f0`
- Reviewer: native GPT-5.6 Sol, independent non-author review
- Working tree: clean; `git diff --check` clean; all reference pins present at the recorded commits
- Manifest: 292 data rows plus header, SHA-256 `76f3aa70ea618a211164df0ced9943c795df818865b8e53b44199cf19299352d`
- Prior fix rounds visible in the candidate: initial visual implementation and one salt-crust correction
- Runtime policy: no PUC or LuaJIT rerun by this reviewer; the final portable pair remains pending after the findings below are corrected

## Findings

### Medium — the claimed exact source/output manifest is not exact for new harvest and loot files

`docs/research/r10-visuals/source-manifest.tsv:2-29,30-44` records the new/changed loot and all fifteen new cooking harvest sprites with `source = see owning LICENSE-media.md and tools/r10_art`, `source_sha256 = -`, and generic `owning ledger` licensing. This does not meet the brief's exact pinned source, author, license, modification and source-hash requirement.

The harvest ledger makes the problem concrete: `mods/ITEMS/grug_cooking/LICENSE-media.md:19-25` says the exact source-to-concept mappings live in `tools/r10_art/import_crop_stages.sh` and `docs/research/r10-visuals.md`, but that script only creates farming stage textures and neither file lists the fifteen harvest source paths. The broad four-project allow-list also cannot identify which file, author exception or license applies to an individual output. The loot ledger at `mods/ENTITIES/grug_mobs/LICENSE-media.md:593-601` supplies usable human-readable origins for the seven changed loot icons, but their manifest rows still omit source paths/hashes; the generated tusk row also omits an immutable source/result record and its mechanical downsample recipe even though `docs/research/r10-visuals.md:29-36` discloses a machine-local source path and prompt summary.

**Required correction:** replace the generic rows for every newly shipped harvest and changed loot file with its exact pinned repository path or generated-source provenance, source hash where an upstream/generated source exists, exact author/license, and actual transformation. Add or correct the deterministic harvest import mapping so the documented reproduction claim is true. The result PNG hash remains useful but does not replace source provenance.

### Medium — the proposed final portable micro-KAT includes the full legacy mount suite and binary mesh audit

`tools/r10_art/final_micro.lua:1-7` loads all of `tools/r9_mounts/mounts_kat.lua`. That suite is not a compact ART binding check: at `tools/r9_mounts/mounts_kat.lua:688-735` it opens and parses all eight B3D meshes through `b3d_audit.lua`, alongside much broader mount/gameplay fixtures elsewhere in the file. Scheduling this as the final PUC/LuaJIT pair conflicts with the repository's bounded final-micro policy and repeats unchanged binary/runtime coverage merely because icon bindings changed.

**Required correction:** make the ART portable runner cover the changed icon/catalog/meta bindings, armor composition/bindings, crop registrations/media paths and deterministic digest only. Keep the full mount KAT and B3D audit as LuaJIT development evidence. Freeze the corrected runner before Root executes the one final PUC/LuaJIT pair.

## Visual and binding verification

No additional blocking visual defect was found in the inspected candidate bytes.

- `armor-inventory-sheet.png` shows all metal, cloth and leather tier/slot assets at native and enlarged scale. Metal silhouettes and palettes are distinct; cloth sets are coherent; leather retains a common readable silhouette with tier treatment. Weapons are absent from the diff.
- `worn-model-sheet.png` shows all 18 complete sets, six race stature scales and front/back/side/walk views. Face openings, limbs and seams remain visible; the inspected alpha composition does not erase the base skin. ART provides the leather assets and lookup; final leather registration remains an EQUIP integration seam rather than an isolated ART claim.
- `crop-stages-sheet.png` and `crop-node-visual-proof.png` show all 17 families. Cane and bamboo use upright plant geometry with stage scaling. Salt uses the new shallow nodebox/crystal progression; early stages read as evaporation surfaces, consistent with the cited source. No opaque full-cube placeholder is presented as plant growth.
- The seven changed loot icons visibly depict a tusk, feather, two leather/pelt cuts, sleek pelt, slime and rotting flesh at 16×16.
- `mount-icons-sheet.png` contains twelve framed model renders with transparent padding. Horse/boar blank material slots are preserved by the renderer; wolf/tiger faces are visible and flying silhouettes are unclipped. `mods/PLAYER/grug_mounts/state.lua:23-34` writes the resolved model icon into owner-bound stack metadata, so the generic registered fallback at `items.lua:41-50` does not mask the race/faction result.
- The inspected mount renderer uses the shipped model/texture/tint rows, bounded `timeout` calls and a scoped scratch directory/trap. Proof sheets are explicitly documented as offline evidence rather than engine screenshots.

Proof hashes inspected:

- armor inventory: `6611f3c0e0d3c0a93977f5d7a0746fae8e78835e1170ce8cfcbf33778bc99530`
- crop nodes: `9fa3168ac2e9057096a1402841d343dbb26eb140355ea9c7b23e1d167d04c90a`
- crop stages: `9fc6f970c101b3fcdbe71bf134725ff1eae55c0553272c6174a7c71ce1b25502`
- mount icons: `c9aa790227d03849fde6517caca856ab87a04b3359fc525a4c9e19b84c5771b9`
- worn model: `1fcbd5760fadf3a1a92faa72d295a16e9469bd651aa9d42b8e36ea0bb42e27d9`
- author development log: `bf722a66607d6b92c9f96c0dcd9b49f8387c73c5926e29088b3a7636a18a2776`

## Re-review boundary

Re-review only needs to verify the corrected exact provenance/mapping rows and the narrowed source-bound portable runner, then visually confirm regenerated harvest outputs are byte-identical if the mapping tool is added. Root can run the final PUC/LuaJIT digest pair after those corrections pass.

## Focused correction re-review — candidate `24698f70e79d6ba40ca127a118d3bd464d0e076c`

**Verdict remains: FIX FIRST.**

### Original provenance finding: CLOSED

The manifest retains 292 data rows and now hashes to
`fd08ef438b27c1e7bfe15c6e2a0228a9cc0ce7994c7e67a961cb958309a068e2`.
All 22 changed harvest/loot rows were independently resolved against the
pinned files (the reference submodules in the main checkout where necessary);
their source and output bytes match the recorded hashes. Each row now states an
author/license and transformation. The fifteen harvest mappings are
deterministically recorded in `tools/r10_art/import_harvest_icons.sh`.
The tusk has a persistent original and exact prompt, with source/prompt hashes
`e5568775...` and `8d13f024...`; `build_boar_tusk.sh` records the
point-filtered trim, resize, centering and metadata stripping.

### Original portable-runner finding: PARTIALLY CLOSED; Medium remains

The full legacy mount KAT and its eight B3D audits are gone from
`tools/r10_art/final_micro.lua`, resolving the excessive-scope half of the
finding. The replacement `art_kat.lua`, however, never loads or executes a
production Lua module. Its binding checks are literal `source:find` assertions
over source text, followed by a media-byte digest. Dead or unreachable binding
code could therefore pass, so this is not meaningful final portable coverage of
the changed runtime seams.

**Required correction:** retain the 259-file media digest, but exercise the real
bounded character-visual and farming registration/composition fixtures and add
a small actual mount catalog/items/state case proving that the owner-resolved
stack receives the catalog icon. Do not restore the full mount gameplay/B3D
suite. Freeze that real-code fixture before the final PUC/LuaJIT pair.

### New Medium — Fire Pepper harvest sprite depicts a carrot

The replacement `grug_cooking_fire_pepper.png` is a 40% red colorization of
`x_farming_carrot.png`, as both the manifest and
`import_harvest_icons.sh` state. Visual inspection at native/enlarged scale
shows an unmistakable tapered carrot root with a carrot-leaf crown. Color alone
does not turn that silhouette into a pepper, so the inventory sprite still
misidentifies the named item and conflicts with the visual-correction goal.

**Required correction:** choose a license-cleared pepper/chili silhouette, or
author a small project-owned replacement with persistent provenance. Update the
manifest/ledger and inspect the final 16×16 result. Do not return to any of the
removed uncertain-license files.

The other replacement harvest sprites inspected in this correction are
recognizable and introduce no additional blocking issue. No PUC or LuaJIT
runtime was rerun by this reviewer.

## Final focused re-review — candidate `dc323374781f2bc27ec60385bb9609b1462bd653`

**Verdict: CANDIDATE CLEAN.**

Both remaining Medium findings are closed.

- The actual 16×16 Fire Pepper output was inspected at native and
  nearest-neighbour enlarged scale. It has a clear curved red chili silhouette
  and green stem, with no remaining carrot form. The persistent generated
  source, exact prompt and output hashes match the manifest:
  `38f20a0d...fed`, `fee6372c...039`, and `4970461e...478`.
  `import_harvest_icons.sh` records the deterministic point-filter trim,
  14×14 resize, centered 16×16 extent and metadata stripping. The 292-data-row
  manifest now hashes to
  `cea7cb8d49aa27c77bdb0d727ecf7ffcf5cf103af48a5afb19d8f5e2a5ad4dc9`.
- `final_micro.lua` now executes the real character-visual fixture, real
  farming registration/runtime fixture, a bounded fixture that loads the
  production mount `catalog.lua`, `items.lua` and `state.lua`, and then
  the 259-file media digest. The mount fixture proves four actual registered
  fallback icons and eight owner-resolved faction/race metadata icons. It does
  not restore the legacy gameplay/B3D audit.

The supplied LuaJIT evidence records all four fixture outputs and hashes to
`12e7a3131ba8c9ac6879aefebb3978286e77eadb61aa1264cba2ec12bc5d0e4e`;
its terminal media result is
`r10_art_v1 files=259 digest=1368124228`. Candidate worktree and diff check
are clean. This reviewer did not rerun LuaJIT or PUC. Per Root's integrated
test plan, the final global PUC/LuaJIT pair remains pending and is not an
ART-candidate finding.
