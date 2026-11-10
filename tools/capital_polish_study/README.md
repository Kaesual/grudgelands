# Capital polish decision studies

**Implemented after user approval:** the decision snapshots below remain frozen.
The actual shipped-template changes, added roof-gap fix, registrar placement,
checks and release classification are in [implementation/README.md](implementation/README.md).

Prepared 2026-11-10 in the existing `character-creation` worktree, at the user's
request while Claude works on main's Expeditions. **Investigation and proposals
only:** no shipped building, NPC assignment, mapgen setting or game version was
changed by this task. Classification: **compatible, tools only**. Existing
character-creation changes in the worktree are a separate, earlier task.

Open `index.html` in a browser. It embeds receipt-checked stills and the actual
capital-core plan SVGs; links lead to the independent topic viewers. Rebuild
that decision page with `python3 tools/capital_polish_study/gallery.py` after
rebuilding any changed sub-study. The pictures are shared-web-renderer studies,
not native Luanti captures, and use existing game materials. No AI raster art.

## Scope and recommendations

| Topic | Finding / proposal | Evidence owner |
|---|---|---|
| Throne | Remove lowest bronze tier; seat 2→1 block, arms 1.5→1 above seat; same 5×3 footprint. | `throne/README.md`, `measurements.json` |
| Core gate | Confirm upper inner-corner stairs with the user. Five capitals share affected geometry; Kezamba differs. Flip proposal only. | `gates_roof/README.md`, `audit.json` |
| Guild tables | Existing thin `xdecor_table` avoids the tall registrar slab and detached supports. Scoped to six guild houses; wood also replaces stone tables in two cultures. | `tables/README.md`, `audit.json` |
| Castle side passages | Prefer joined piers and broad bays; keep closing both passages as the minimal alternative. No chase reliability claim. | `castle/README.md`, `variants.json` |
| Roof ridge | Preserve group shape/height and lower it 0.5 node using existing full block and lower slab. | `gates_roof/README.md` |
| Registrar | Outdoor visibility is useful; near the castle does not consistently mean near the waystone. Compare six actual core plans before choosing. | `castle/README.md`, `registrar-candidates.json` |

## Validation and independent reviews

- Shared renderer reported no missing assets for the studies; corresponding
  receipts verify PNG hashes, scene inputs and same-camera comparisons.
- Root gallery verifies every embedded PNG against its output receipt.
- Throne and gate/roof agents reviewed each other's proposals: **PASS**.
- Gate/roof agent independently reviewed all six table variants and 14 receipts:
  **PASS**; exact changed furniture cells, nodebox heights and support contacts.
- Throne agent independently reviewed the castle variants and six registrar
  map candidates: **PASS**; raw geometry changes, lamp supports, node widths,
 3×3 free paved patches, socket distances and marked straight-line distances.
- The coordinator inspected throne, gate and table details and both castle
  interior states. Python compilation and `git diff --check` pass.
- Browser gallery checks: **7 PASS** at 1600 and 760px wide; all images decode,
  six sections present, no horizontal overflow or JavaScript errors. Captures
  `gallery-1600.png` and `gallery-760.png`; checks in `browser-check.json`.
- No engine chase simulation, native gameplay acceptance or user approval of
  proposed geometry is claimed. Runtime tests would accompany implementation.

`baseline.json` records relevant main/worktree hashes at inspection time.
The six installed castle templates match main. Navigation, boss behaviour and
registrar implementation have advanced on main; the study does not overwrite
or port them. Child checks also found the relevant guild/gate geometry current.

## Next decision

The user reviews the gallery, confirms the highlighted gate location, selects
throne/table/side-wall/roof variants, and chooses registrar placement priorities.
Only then implement the selected changes in the worktree. Future template/core
changes are world-generation changes requiring the normal map-reset declaration
and template gates; there is no implicit approval to rewrite live compositions.
The old registrar socket/clerk and main's concurrent Expedition changes need
explicit integration treatment if relocation is selected. No merge or push.
