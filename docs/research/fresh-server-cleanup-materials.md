# Fresh-server cleanup: materials and camp anchor

Date: 2026-09-13

Scope: `grug_materials`, its WP43 handoff/tests, and the Grug camp-fire alias.

## Decision applied

Grudgelands is developed for fresh servers until the user explicitly announces
a release. Development-era item names are therefore not aliases for current
content, and saved-world conversion code is not loaded. Current-version
persistence, reconnects, entity activation and VoxelManip initialization remain
supported.

## Material boundary

`grug_materials/content_curation.lua` now removes the vendored registrations
that are outside the current Grudgelands vocabulary. The roster contains only
items and nodes that the loaded `default` and `stairs` mods actually register:

- eight Mese/Diamond tools;
- ten Copper/Tin/Bronze/Steel/Gold ingot and block registrations;
- thirteen Mese/Diamond resource, storage and light registrations;
- the Steel sign and ladder plus twenty generated storage stair/slab shapes.

The canonical sign, ladder and stair/slab nodes are cloned before their source
registrations are removed. The curation pass installs no alias. Its startup
audit requires every source registration to be absent.

Recipe removal remains current content selection. Outputs outside the current
vocabulary, the Steel verification pick, the mobs_redo Lasso and the Level 2
Protection Rune stay uncraftable. The surviving temporary recipes name current
inputs directly:

| Current output | Canonical input |
|---|---|
| Bronze pick, shovel, axe and sword | `grug_materials:bronze_bar` |
| Default Steel shovel, axe and sword | `grug_materials:iron_bar` |
| Locked Chest | `grug_materials:iron_bar` |
| mobs_redo Shears and Saddle | `grug_materials:iron_bar` |
| mobs_redo Protection Rune | `grug_materials:gold_block` |

WP29 still owns the final tool catalog and WP26 owns processed-material and
storage recipes. The current derivative nodes remain recipe-free until those
packages define them.

## Camp anchor boundary

`grug_mobs:camp_fire` was only a development-era alias and is removed. The
current node is `grug_nodes:camp_fire`.

The two camp initialization LBMs remain. R7 places camp fires and guard banners
through VoxelManip, which does not call `on_construct`; the idempotent LBMs arm
their node timers during normal fresh-world mapblock activation. Empty metadata
fallbacks also remain for that same current placement path.

## Explicitly retained dependencies

- `grug_core.zone_authority`'s `session.compatibility` table is a live bundle of
  accepted zone query functions used by current consumers. It is not a saved
  format adapter.
- mobs_redo staticdata serialization/deserialization is required for ordinary
  same-version entity unload and activation.
- Lua 5.1 fallbacks and engine-facing `mapgen_*` aliases are current runtime
  contracts.

## Verification surface

`tools/wp43/materials_test.lua` executes the real material owner against loaded
source shapes, proves every curated registration is absent, proves no material
alias catalog/resolver exists, scans all retained fixture recipes for removed
inputs and reruns curation to prove idempotence. `tools/wp43/source_audit.sh`
rejects the old migration file, alias APIs and missing canonical recipe/removal
contracts. `tools/wp43/fresh_server_fixture.lua` is the bounded callable used by
the final PUC/LuaJIT parity pair; it returns canonical receipt bytes after those
same material assertions pass. The R7 micro-KAT requires the current camp node
behavior with no old camp-fire alias.
