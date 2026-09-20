# TODO — Round 10 scope and Playtest 12 follow-ups

Status: planning, 2026-09-20. Accepted user decisions are recorded in
`TODO-round9.md` §4.47–56. This file tracks the remaining questions and package
boundaries; it is not an implementation-completion record. Before implementing
each package, fold its resolved rules into the named `docs/design/` owners.
Delete this TODO once the remaining questions are settled and the work is
represented in design/BACKLOG. PERF continues independently in Round 9.

**Hold for independent drift audit (user 2026-09-20):** compare the current
repository with tested baseline `2a308891`. Do not implement gameplay
corrections from this file until the audit findings have been presented to and
discussed with the user. The package boundaries below remain proposals, not
accepted architecture.

The completed [Playtest 12 design-to-code audit](docs/research/playtest12-audit/README.md)
records seven source-confirmed implementation deviations and four unresolved
choices. Its coordinator dispositions distinguish missing open-WP work from
historical defects and preserve the already-decided independent mastery and
profession-tier ladders. No audit correction is authorized by the report alone.

## Visual selection pilot — user-approved scope, 2026-09-20

The user approved a first visual-selection pass over armor and animal loot,
followed later by other nonweapon item families. Weapons remain untouched.
The pilot compares 26 live items (12 armor, 14 loot), using actual current
texture expressions and visually inspected reference candidates. It proposes
VoxeLibre metal armor as the leading source direction, with Grudgelands material
adaptation still pending; cloth candidates and individual loot replacements
remain choices. No matching Boar Tusk inventory sprite was found in the inspected
candidate set, so dedicated artwork is an explicit gap rather than a false match.

Gold/blue armor-trim previews are visual proposals only. Their meaning for
refinement, enchants or rarity is undecided. Worn texture compatibility with the
actual player mesh is unverified; the pilot shows labeled UV source samples,
not fabricated engine screenshots. No graphics or gameplay were replaced.

The offline gallery, report, source pins/licenses and item mapping are retained
in `/home/jan/projects/grudgelands-orchestration/w9/visual-audit/` (`index.html`,
`report.md`, `mapping.json`, comparison PNGs). Source/per-file licensing,
material palettes, worn-model compatibility and final in-game inventory/drop
appearance remain implementation gates after the user selects a direction.

## Accepted direction and proposed package boundaries

| Package | Accepted work | Design owner / dependency |
|---|---|---|
| Base recipes | Universal base equipment; quantities and exact grid cells from pinned VoxeLibre, translated to our materials | `items_crafting.md` §3.0.3; freeze non-Minecraft shapes and feedstock access below |
| Profession split | Weaponsmith + Armorsmith replace Blacksmith, seven primaries with two player slots | `professions.md`; trainer/station placement touches mapgen and must serialize with CAP/MAP-B |
| Refinement and affixes | Keep +15%, complete existing-item transformation and enchant workflow, readable result previews | `items_crafting.md` §6b; retain WP22 durability deferral |
| Recipe books | Exclusive Basics/profession books; readable alternatives per ingredient slot; separate whole routes via arrows; Cooking remains on the ordinary grid/furnace model | `professions.md`, `inventory_equipment.md`; verify Sweetroot duplication independently of crafting authorization |
| Farming artwork | Import appropriate existing crop/inventory/stage art instead of tint-only placeholders | `docs/reference_projects.md` farming/x_farming allow-list; `LICENSE-media.md`; no foreign modpack import |
| Roaming and dragons | At most one-node idle descents; visible dragon walks between resting spots; target-gated abilities that treat `peaceful_player` as non-hostile | `biomes_mobs.md`, `combat_stats.md`; one shared cliff-probe owner |
| Mount usability | First-person-only mesh hiding, top-right status, automatic half/full-block steps, T1 6.4 nodes/s | `mounts.md`; existing status API needs an explicitly cleared runtime-only untimed entry |
| Cave investigation | Explain thin roofs at the concrete seed/position before changing terrain | `world_zones.md`; diagnosis is separate from PERF's byte-preserving optimization |

Housing (WP24), Scout, WP46 terrain-damage protection, WP47 skills tab and WP49
audit refreeze remain planning candidates from the handover. This acceptance of
playtest follow-ups does not mark them implemented or schedule the entire list
concurrently. The remaining Round 9 mapgen chain is PERF -> CAP -> MAP-B -> DOCS.

## Recipe evidence to preserve

Pinned source locations, to be read before implementation:

- `reference_projects/VoxeLibre/mods/ITEMS/mcl_tools/crafting.lua`:
  sword 2 material + 1 handle, pick 3 + 2, shovel 1 + 2, axe 3 + 2,
  including the actual shaped/mirrored alternatives.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_farming/hoes.lua`:
  hoe 2 material + 2 handles and its mirrored form.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_armor/init.lua` and `api.lua`:
  head/chest/legs/feet quantities 5/8/7/4, with their exact empty grid cells.

These quantities supersede older Grudgelands per-piece bar/cloth/leather costs
where they differ. They do not import Minecraft item stats, materials or tier
rules. The confirmed sword handle alternatives are wood or same-tier metal;
do not silently accept a metal rod from any tier.

The refinement/affix implementation already has naming and rolled-stat logic
in `grug_quality`; it must not be rebuilt on the false premise that all of WP5
is absent. A likely callback-order issue remains to reproduce: some
`grug_professions` refinements lack a quality mode, allowing terminal crafted
quality processing to select `base`. The confusing unchanged output name in
the recipe book is a separate presentation defect.

## Open choices

1. **Split ownership and physical stations.** Proposed: Weaponsmith owns
   physical weapons/tools and the existing Metal Fittings used by Woodcarver;
   Armorsmith owns metal armor and shields. Decide whether their named work
   areas share one forge or need separate stations, and which existing material
   serves armor refinement. Do not invent a new component only to fill a table.
2. **Universal feedstocks.** Base recipes must be profession-free. Decide
   whether the existing profession-only cloth/leather conversion chains remain
   an intentional trade dependency or whether plain material preparation also
   becomes universal. Recipe permission and access to ingredients are distinct.
3. **Non-Minecraft items.** Dagger, greataxe, staff, wand, scepter and orb
   need explicit base recipes; the cited Minecraft sword/tool patterns do not
   define them. Check relevant pinned references before proposing shapes.
4. **Enchant application operation.** Preserve the two independent decided
   ladders: four mastery bands determine fillable affix slots, while T1–T6
   profession level determines recipe permission (`items_crafting.md`
   §2.1/§6b.5). Specify only the missing player-facing operation for a higher-
   mastery crafter to append later affixes without rerolling existing ones.
5. **Blocked dragon rest-spot travel.** Recommended: stop/rest if a route is
   obstructed and retry another authored spot later; never routine teleport.
   Do not add full pathfinding solely for this idle behavior. Define how the
   shared one-node cliff rule treats fleeing and scripted NPC routes.
6. **Cave exclusion boundary.** The recorded point is in the Dawnmere blend
   envelope, outside the 128-node build square. Verify the actual writer path
   before deciding whether skin filling, natural openings, or both may operate
   there. Preserve true settlement/POI foundations and protection.
7. **Fall damage.** User requested level-independent percentage danger in
   Playtest 12. The proposed implementation rescales engine fall damage by
   maximum HP; armor already does not mitigate it. The reference curve and
   treatment of dwarf reduction/absorption remain undecided. No fall-damage
   implementation was included in the subsequent numbered approvals.

## Investigation evidence and runtime checks

- World `test`, seed `4151598227737528026`, approximate position
  `(-71,19,-2458)`: a read-only LuaJIT source query identifies
  `exclude:anchor:anchor_002:01`, center `(0,-2550)`, width 256.
  `r6_settlement.lua`'s `surface_skin_excluded` uses the default static
  exclusion query and suppresses both filling and opening there. This is not
  yet a reproduced engine-output assertion for every reported thin roof.
- Mounts currently omit LuaEntity `stepheight`, whose engine default is zero
  (`reference_projects/luanti/src/object_properties.h:60`). The pinned
  collision solver uses a strict step-height comparison
  (`reference_projects/luanti/src/collision.cpp:536-540`); choose a minimal
  numerical clearance for a nominal one-node step and verify real slabs, full
  blocks, higher obstacles and low ceilings in the engine.
- **Proposed implementation, not a user ruling:** retain the existing physical,
  targetable mount controller and attach a nonphysical visible child. The
  pinned client hides children of the local player in first person
  (`reference_projects/luanti/src/client/content_cao.cpp:469-475`). Verify that
  the controller still forwards hits to the rider, and verify camera toggles,
  another observer, racial scales, animations and every
  dismount/death/disconnect/failure cleanup path before adopting the proposal.
- Mount status is descriptive, not a second speed authority. It must have no
  fake countdown, derive the bonus from tier speed and clear on dismount.
- Recipe runtime checks include base recipes without professions, denied
  Cooking without learning, correct before/after refinement metadata, per-slot
  ingredient alternatives and exactly one displayed book per recipe route.

Each later Lua-changing package follows `docs/research/luanti-lua.md`'s
interpreter strategy: parse every changed Lua file with `luac51 -p`; inspect
`SETGLOBAL` for changed mod files; run the five sweeps explicitly over changed
tool Lua as well as their normal mod scope; and use LuaJIT for development and
exhaustive checks. Once that package's candidate bytes are frozen, run one
compact final fixture under PUC 5.1 and the same fixture under LuaJIT, requiring
a byte-identical canonical digest; a relevant later byte change replaces that
pair. At most seven interpreter processes run machine-wide, with independent
fleets at idle CPU/I/O priority and isolated outputs. No intermediate PUC
suites, full resource census, fresh-world migrations or unreviewed integration.
