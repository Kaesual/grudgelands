# WP43 Material Progression Retrofit — implementation brief

Status: implementation contract for branch
`wp43-material-progression-retrofit`, based on main
`607a96bef016053caff5d2c9a7897f5b7c02fa2a`.

This brief translates the decided design into implementation packages. It does
not change the authoritative rules in `docs/design/`.

## 1. Starting inventory

The WP25 runtime is concentrated in `grug_materials`: its `TIERS` entries carry
engine `level`, `level_for_tier()` exposes that value, strata and custom ores
carry non-zero `level`, and `overrides.lua` uses pick `maxlevel` as the depth
gate. `grug_mapgen/ores.lua` still places `default:stone_with_mese` and
`default:stone_with_diamond`; `grug_nodes/ore_respawn.lua` mirrors those names.
The only active public-API consumer outside the owner mod is the respawn
fallback through `stratum_node_for(y)`.

The remaining runtime consumers of reinterpreted Mese/Diamond IDs are the
vendored default recipes, the vendored mobs compatibility recipe table,
`grug_mobs` golem loot, `grug_traders` pricing and the legacy-tool hide list in
`grug_gear`. There is no jobs or quests mod yet. Harvest settlement must
therefore publish a callback seam without fabricating future profession,
quest or XP systems.

`TODO-design-crafting-rework.md` B22 leaves final pick speed/durability
calibration to WP22/WP26/WP29. `TODO-design-depth.md` leaves pulse geometry and
servant roster to WP34. Neither is a WP43 blocker: WP43 authors internally
consistent explicit values and proves invariants, but does not claim final
runtime calibration.

## 2. Runtime ownership and public contract

`grug_materials` is the sole owner of:

- the ordered six-tier registry (Bronze, Iron, Steel, Silversteel,
  Embersteel, Abyssal Steel), inclusive depth caps and stratum IDs;
- canonical resource IDs, G1/G2 grade membership, cultural resources,
  signature woods and race-region rows;
- natural-node and natural-resource registration/classification;
- pick-tier lookup, `max_depth_for_pick_tier(tier)`,
  `can_mine_natural_at(pick_tier, y)` and a structured full mining decision;
- harvest requirements, shortfall multipliers and successful-harvest
  settlement callbacks;
- shared failure/shatter feedback and startup contract audits.

`TIERS`, `tier_at(y)` and `stratum_node_for(y)` remain public. The new depth
helper replaces `level_for_tier`; no compatibility alias may keep the old
engine-level meaning alive. Other mods may consume registry/API values but may
not copy depth boundaries, stratum IDs or harvest tiers.

The mining decision order is fixed: protection/territory, natural target-y
depth, then resource harvest. A depth refusal must occur before node removal,
wear, drops or settlement. An allowed under-tier resource dig uses the
authored x4/x6/x8/x10 time, removes the node, spends exactly one ordinary
pick-use event, emits shatter feedback, produces no drop and invokes no
settlement callback. The ordinary dignode chain still runs so renewable ore
nodes enter their depleted/refill state. Crafted/storage/building nodes are
not natural resources and bypass both depth and harvest gates.

Natural classification is registration/group based; no per-node map metadata
is permitted. Harvest timing must be expressed with explicit tool/group
capabilities or an equivalently server-authoritative mechanism. Engine
`level`, pick `maxlevel` above zero and `leveldiff` must not participate.

## 3. Canonical IDs and migration matrix

The implementation may add helper IDs only when they represent a decided
concept. Hidden test doubles must be unmistakably test-only, have no recipe
and not appear in normal creative/player catalogs.

| Legacy source | Canonical target / treatment |
|---|---|
| `default:stone_with_mese` | `grug_materials:stone_with_emberglass` |
| `default:mese_crystal` | `grug_materials:emberglass` |
| `default:mese_crystal_fragment` | `grug_materials:emberglass_shard` |
| `default:mese` | `grug_materials:emberglass_block` |
| Mese lamps/posts | canonical Emberglass-named nodes; old IDs are force aliases |
| `default:stone_with_diamond` | `grug_materials:stone_with_diamond` |
| `default:diamond` | `grug_materials:rough_diamond` |
| `default:diamondblock` | `grug_materials:diamond_block` |
| Mese tools | matching Steel tool through force aliases; the Mese tier is retired |
| Diamond tools | matching Steel tool through force aliases; Diamond is not a tool material |
| Emberstone item/API names | Emberglass targets only; references survive only in migration or shipped history |
| Grudgesteel item/API names | Abyssal Steel targets only; no runtime legacy ID currently exists |

Aliases are the saved-world and saved-ItemStack migration mechanism. They
must be repeat-safe, point in one direction only, and never leave a registered
playable legacy item beside the canonical target. A legacy LBM is required
only if an alias cannot migrate the saved node safely. Vendored
`default_mese*.png` filenames may remain as documented third-party asset
sources; they are not player-facing material IDs and must not be copied or
renamed in-place.

Canonical regional gem families are Citrine, Garnet and Jade (G1), and
Diamond, Sapphire and Ruby (G2), using `grug_materials` IDs for natural ore,
rough gem and cut gem concepts. Mapgen in WP43 may place only the already
owned generic schedule after canonical renames; WP40 owns race-column
placement and density redesign. Abyssal Crystal starts in T5, not behind T6.

## 4. Data handed to WP40

The public registry must contain all six race rows:

| Race | G1 | G2 | Cultural material | Signature wood |
|---|---|---|---|---|
| Human | Citrine | Diamond | Sunwax | Oak |
| Dwarf | Garnet | Sapphire | Runeslate | Mountain Pine |
| Elf | Jade | Sapphire | Moonresin | Silverwood |
| Orc | Garnet | Diamond | Red Ochre | Spikethorn Acacia |
| Troll | Jade | Ruby | Spirit Resin | Kapok |
| Undead | Citrine | Ruby | Gravesalt | Gravewood |

It must also publish generic-versus-regional/cultural classification and the
decided density schema: G1 shape; G2 T4/T5/T6 targets 1/12000, 1/6000 and
1/3000 eligible hosts; Abyssal Crystal initial target 1/2048; deep multipliers
1.25 at y -1500..-1999 and 1.5 at y <= -2000. These are data for WP40, not new
WP43 placement code. WP40 must never emit a legacy Mese, Emberstone or
Grudgesteel target ID.

## 5. Implementation packages

### Package A — registry, canonical content and migration

1. Replace the WP25 tier-level table with the final tier/depth/resource/race
   registries and query helpers.
2. Register all canonical resource concepts and canonical Emberglass/Diamond
   nodes/items needed to make legacy aliases resolvable.
3. Add the explicit one-way force aliases, remove the Mese/Diamond tool tiers
   as playable registrations, and add fail-fast alias/registry diagnostics.
4. Remove non-zero `level` from owned natural/storage/stratum nodes; normalize
   reachable vendored Obsidian/storage/stair exceptions without losing any
   unrelated upstream groups.
5. Convert current mapgen, ore-respawn, mob/trader/gear consumers to canonical
   IDs or public registry data. Preserve current placement scope and keep
   stratum registration last.

Package A must be one coherent implementation commit and must not implement
the mining transaction or completion documentation.

### Package B — depth/harvest transaction

1. Implement pick-tier lookup and the structured decision API with exact
   boundary behavior.
2. Route natural digs through protection first and depth second without
   duplicating `core.node_dig` side effects.
3. Implement registry/group-backed resource timing and the accepted/shattered
   settlement paths, including ordinary wear, no-drop suppression and the
   renewable dignode callback path.
4. Publish registration hooks for future successful harvest settlement and
   shared feedback; keep absent jobs/quests/XP consumers absent.
5. Ensure every active Grudgelands pick has `cracky.maxlevel = 0`; six-tier
   verification may use a pure capability builder or hidden no-recipe test
   picks without creating WP29's final catalog.

Package B must be a separate coherent implementation commit.

### Package C — regression harness and consumer audit

Add real-Lua-5.1 WP43 tests under `tools/wp43/`. They must exercise all exact
boundaries, six picks by six strata, protection/depth ordering, refusal
side-effect absence, all harvest tiers/multipliers, valid and shattered
settlement, crafted-block exemption, level/maxlevel normalization, registry
duplicates/completeness, every race row, aliases repeated safely, fresh load,
public-API-only consumers and stale-name classification. Reuse production
files through a small engine stub rather than copying their algorithms into
the tests.

### Package D — shipped-state documentation

Only after production code and tests are green, update `AGENTS.md`,
`VENDOR.md`, the WP43 BACKLOG row, README Current State and any genuinely
derived ROADMAP/design-index text. Do not rewrite the historical WP25
completion record. Recalculate shipped count and ready frontier from the final
dependency graph. Record WP40's handoff against the implemented API, not this
pre-implementation brief.

## 6. Acceptance and review gates

The branch is not complete until all changed Lua parses with
`tools/bin/luac51 -p`, existing relevant tests and `tools/wp43` pass,
`git diff --check` is clean, changed Markdown links resolve, stale references
are classified, no later-WP scope leaked in, and all nine submodule pins are
unchanged and clean. An independent reviewer must inspect the entire branch
against `docs/process/wp-workflow.md`, `docs/research/luanti-lua.md` and the
WP43 transaction/migration lenses. Confirmed findings are fixed by an
implementer; High/Critical fixes receive focused re-review.

