# Independent all-building table batch review — 2026-11-10

Reviewer: `tables_study`, independent of the coordinator's batch implementation.
Verdict: **MERGE**, no blocking findings. Classification **map reset** is correct.
Scope is `install.py` and its 153 shipped-template outputs. Runtime helper and
general decor-node changes are a separate review scope.

## Independent checks

Read all 153 preserved before files and all 153 installed outputs, checked their
SHA-256 values against `save-report.json`, and independently parsed their semantic
cells. Recomputed candidates from the old `table_top`/`table_leg` role entries,
rather than trusting recorded edit coordinates. Confirmed:

- **575 exact aligned leg/top pairs**, occupying **1,150 changed cells**.
- Every former leg cell now contains `node grug_decor:xdecor_table`; every former
  upper slab cell is explicit air. No other semantic cell changes.
- All points (except parsed source-line metadata), origins, pivots, sizes, races
  and template metadata remain unchanged.
- High-floor tables use their actual former leg heights; Moot House wall/roof
  cells above the tops remain untouched.
- The inn-bed repair is outside the batch: `dawnmere_harvest_inn.tpl` has an
  existing `board_table`, not a paired leg/slab, and is not among the 153 files.
- The inventory's 36 scaffold slab/fence pairs remain outside the batch. No blind
  fence/slab or global palette replacement was made.

Read the bounded installer against the existing editor implementation:

- Builds each candidate through `Editor.edited_text`, retaining editor canonical
  serialization, legend cleanup and input shape validation.
- Passes the complete replacement set to shared `check.validate(..., builds=True)`
  before any shipped writes. Existing known-defect matching uses the same
  identity tuple as the editor. Unrelated unknown errors remain blocking, so the
  batch is stricter than per-file editor saves in that respect.
- Performs all-source stale checks before the first write, then per-file stale
  checks and `serve.write_atomic`, with durable exact before snapshots.
- Records exact output hashes; an already-completed invocation verifies those
  outputs rather than writing/revalidating again.

Read the completed candidate gate receipt: **0 errors, 59 warnings**, complete
batch built. No global validator or fixture was repeated by this reviewer.

## Actual-template rendering

`render.py` reads the saved before files and the installed current files through
the actual roster palettes. It exports 12 cutaway scenes for a cottage, tavern,
scriptorium, market, raised Moot House and undead workshop. `index.html` embeds
all six before/after pairs; `scenes.html` permits free camera inspection. The
same crop and camera are used within every pair. Crop bounds and source hashes
are recorded in `render-sources.json`.

All 12 captures completed without missing media or script errors. All six
installed scenes were visually inspected: contiguous thin tops meet their
supports; seating and surrounding furniture retain their original positions.
`gallery.py` verifies every capture input hash, PNG hash and dimensions before
embedding. These are shared-renderer previews, not native client acceptance.

The reviewer authored only inventory/review/preview evidence in this folder.
No shipped implementation was changed during the review.
