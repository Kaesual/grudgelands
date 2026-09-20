# Independent Round 11 FARM review

Reviewer: native GPT-5.6 Sol (`/root/r11_farm_review`), independent of all candidate commits.  
Candidate: `e5486a85afdd5c22babe553f865b27b6b443f770` on `wp33-r11-farm`; base `16b7449c`.  
Disposition: **CHANGES REQUESTED** (evidence-integrity correction; no production-code defect found).

## Findings

### Medium — the checked-in input hash receipt is stale on the frozen candidate

`tools/r11_farm/evidence/water-hoe-inputs.sha256:1-10` presents hashes for the water/hoe input set, but `sha256sum -c` fails for three tracked candidate files:

- `mods/ITEMS/grug_farming/init.lua`
- `mods/ITEMS/grug_farming/hoes.lua`
- `mods/ITEMS/grug_farming/mod.conf`

Concrete scenario: integration or independent review uses the receipt to establish that the reviewed final files are the files exercised by the recorded KAT/static evidence. The receipt rejects the actual frozen files, so it cannot establish that link. The final correction commit changed `init.lua` and `hoes.lua` (including the ART hook and hoe palette), while the manifest retained earlier hashes; `mod.conf` is stale as well. This conflicts with the workflow rule that changed final bytes require current immutable evidence and blocks a clean review even though rerunning the three focused LuaJIT KATs succeeds.

Required correction: regenerate the receipt from the final candidate bytes, include every file that the receipt claims to cover, rerun the focused checks whose inputs changed, and record the final commit/hash relationship. The ecology/mapgen evidence should likewise identify its final-byte input set or explicitly state that the review relies on source inspection plus fresh reviewer execution rather than an immutable hash receipt.

### Low — the candidate fails the repository whitespace gate

`tools/r11_farm/evidence/crops.txt:7` contains a blank line at EOF. `git diff --check 16b7449c..e5486a85` exits 2 with `new blank line at EOF`.

Required correction: remove the extra blank line and rerun `git diff --check`.

## Reviewed behavior

No additional material defect was found in the full candidate diff.

- The actor-neutral alteration seam fails closed until zone authority exists, admits only the four mutable territory classes, and composes registered guards. The water wrapper vetoes ordinary/river water before an existing non-air flood callback and restores exact old node name/param2 for engine-reported air/liquid transformations. It adds no queue, scan, timer, or cache.
- Bucket fill accepts only actual ordinary/river source nodes; placement preserves the family in stack metadata, validates reach/protection/alterability/buildability, and changes the held item only after `core.set_node` succeeds. Flowing water, lava, unloaded nodes, invalid metadata, failed writes, and protected targets fail without inventory mutation.
- Seven hoes share the same conversion and exact 64/128/192/256/384/512/768 use budgets. Wear reaches 65535 on the authored last use without destroying the stack; a broken tool refuses work, zero-wear repair resets the fractional remainder on the next successful use, and failed/already-tilled/Creative/protected actions spend no wear.
- The renewable inventory is 27 identities: 14 renewable WP40 rows, 11 renewable P9G rows, Apple, and Blueberry. The shared pure habitat registry doubles exactly the 25 density-driven plant denominators while leaving Salt Crust, Rock Salt, and the two template-reuse populations unchanged. Both real mapgen writers consume the registry. Runtime calls the existing planner instance through four narrow direct delegates; it does not construct a second geometry authority.
- Ecology records only observed/generated identities, excludes player-placed plants and changed/farmed/player-placed support, persists current-version baseline/debt/due state, schedules first debt at 4–8 hours and failed retries at 30–60 minutes, and reconciles non-callback disappearance lazily. The global 10-second service caps eight cells, 64 inspected candidates, 384 charged `get_node_or_nil` reads, and two placements. Visible cells are deduplicated across players; no emergence, whole-cell scan, ABM, or per-plant timer was introduced.
- The FARM commit deliberately depends on accepted ART commit `28ef659a` for `seed_visuals.lua` and its assets. That commit exists in the root repository and contains the required file/assets; the FARM branch alone is therefore not loadable, but this is a declared integration dependency rather than missing delivery.

## Fresh reviewer verification

Executed read-only against `e5486a85`:

- `luajit tools/r11_farm/water_kat.lua .` — PASS
- `luajit tools/r11_farm/hoes_kat.lua .` — PASS
- `luajit tools/r11_farm/ecology_kat.lua .` — PASS
- `luajit tools/wp40/r7/micro_kat.lua .` — exit 0; exercises real planner construction/consumers
- `tools/bin/luac51 -p` for every changed Lua file — PASS (parser only; no PUC runtime)
- `git submodule status` — all pins exact, no `+`, `-`, or `U`
- `sha256sum -c tools/r11_farm/evidence/water-hoe-inputs.sha256` — FAIL for the three files above
- `git diff --check 16b7449c..e5486a85` — FAIL for the blank line above

Per the explicit Round 11 override, I ran no PUC runtime, broad census, seed population, or personal-world operation. I made no repository edits or commits.
