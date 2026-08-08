# TODO — which Troll jungle does `grug_jungle_fringe` mirror?

Opened 2026-08-08 out of the WP36 review. WP36 gave `grug_deep_jungle` a
ground node of its own, and thereby split a phrase that used to name exactly
one thing into a phrase that names two. The implementer picked a reading,
shipped it and wrote it into `docs/design/biomes_mobs.md` as settled; the
reviewer found the reading **defensible but not clearly correct**. This file
holds the open half, because `docs/design/` may hold no open questions
(AGENTS.md, "Documentation layers").

**Nothing is broken.** What ships is measured, verified and internally
consistent; this is a question about which of two spec readings the design
actually intends, not a bug report.

## 1. The context

`biomes_mobs.md` §8.4 (a 2026-08-06 decision point) reads:

> **Jungle fringe reuses the troll jungle nodes 1:1** on the Accord side
> (max drop symmetry, zero new assets).

At the time the Throng had exactly one jungle ground node
(`default:dirt_with_rainforest_litter`, shared by `grug_jungle_edge` and
`grug_deep_jungle`), so "the troll jungle nodes" named one node set and the
sentence was unambiguous in practice.

WP36 (2026-08-08) gave `grug_deep_jungle` its own top,
`grug_nodes:dirt_with_canopy_litter`, to break a biome monopoly on the Throng
side (`biomes_mobs.md` §1.3, "The Throng biome monopoly"). From that moment
"the troll jungle" names two different node sets, and §8.4 no longer decides
which one the Accord's fringe reuses.

## 2. The two readings

### Reading A — the fringe follows `grug_jungle_edge` (what ships)

`grug_jungle_fringe` keeps `default:dirt_with_rainforest_litter`.

Evidence:

- "The troll jungle" is most naturally the **settled Troll biome**, the one
  the Troll race actually lives in; `grug_deep_jungle` is the *wild*
  back-country variant, and §1.2 calls it "universal jungle (Throng side)",
  not "the troll jungle".
- §8.4's stated purpose is "max drop symmetry, **zero new assets**". Reading A
  keeps that literally true: the fringe needs no new node, no new texture and
  no new licence row.
- It is the only reading under which the WP36 monopoly fix leaves *both*
  continents with three distinct eastern tops rather than moving the shared
  look from one continent to the other.

### Reading B — the fringe follows `grug_deep_jungle`

`grug_jungle_fringe` would take `grug_nodes:dirt_with_canopy_litter`.

Evidence, and it is not thin — **three sections pair the fringe with the deep
jungle structurally, none pairs it with the jungle edge**:

- §1.3's registration table gives them **one row**:
  `grug_deep_jungle / grug_jungle_fringe`, i.e. they are the mirrored pair.
  The jungle edge's mirror in that table is `grug_elf_forest`.
- §3.1 heads the roster block **"Jungle group — `grug_deep_jungle` (T) ↔
  `grug_jungle_fringe` (A)"**, with the jungle edge listed separately.
- §3.2's binding drop-table row reads **"jungle tables (panther/serpent) |
  jungle fringe (east flank) | deep jungle"**.
- §2's flora table also gives the two one row, and §6 pairs them again as the
  two crimson-lotus T3 sources.
- §2's note on that row **said the opposite of what stands there now** before
  WP36 ("fringe = same nodes/roster, Accord side"); the WP36 commit replaced
  that sentence rather than reconciling it.

Under Reading B the fringe is the Accord mirror of the *wild* jungle in every
respect, which is what the rest of the catalog treats it as, and
`default:dirt_with_rainforest_litter` becomes a Throng-exclusive top.

## 3. What currently ships

- `mods/MAPGEN/grug_mapgen/biomes.lua`: `grug_jungle_fringe` →
  `default:dirt_with_rainforest_litter` (Reading A).
- Therefore `default:dirt_with_rainforest_litter` is **the only band top that
  exists on both continents**. That is load-bearing for two shipped
  decisions: §4's outer/coast filler slot deliberately does *not* give
  Plaguehide Bear / Pale Spider that node (they carry no `_grug_spawn_check`
  and would tint the Accord fringe Throng — `grug_mobs/bear.lua`,
  `spider.lua`), and `wp6_spawn_budget.md` §2.2 carries jungle edge and
  jungle fringe as two rows sharing one roster.
- `grug_mapgen/decorations.lua` places the jungle flora on `JUNGLE_FLOOR`
  (`RAINFOREST` + `CANOPY`), so the decoration layer is already agnostic and
  would need no edit either way.

## 4. What changing it would cost

Measured with `tools/biomecheck` (this world's seed, step 10, both
continents) — the swap is a **no-op for every mapgen distribution number**:
Throng monopoly 42.83 %, Accord monopoly 29.50 %, largest visible top
43.07 % / 30.54 % — identical before and after, because the fringe's
uncontested flank strip x 1251..1500 stays a one-visual strip either way and
only the identity of that visual changes.

So the cost is not in the mapgen. It is:

1. **A one-line `node_top` swap** in `grug_mapgen/biomes.lua`.
2. **A §1.5 spawn re-derivation**, because the gate is `node_top × zone`:
   - `jungle fringe × war_coast` goes **2 / 10 → 2 / 7**. The Skeleton
     Archer's war-coast node list is the five *settled* tops, and canopy
     litter is not one of them, so the fringe's war coast would lose its
     archer at night. Either accept it or add canopy litter to that row.
   - `outer` and `coast` are unchanged (11 / 8 and 6 / 8 on both tops).
   - Conversely `default:dirt_with_rainforest_litter` would become
     Throng-exclusive, which **removes the leakage argument** that currently
     keeps it off Plaguehide Bear and Pale Spider. Adding it then becomes
     legal and would take `jungle edge × outer` to 13 by day and 12 at night
     — level with the night peak, not over it. That is a separate decision,
     not an automatic consequence.
3. **Nothing else**: no new asset (the canopy-litter node exists), no
   decoration edit, no licence row, no ore row.

## 5. Decision state

**Open — owner's call.** No WP is blocked on it: WP36 ships Reading A and
every number in `biomes_mobs.md` §1.3/§1.4/§1.5 and in
`docs/research/wp6_spawn_budget.md` §2.2 was measured against it.

When it is decided, fold the result into `biomes_mobs.md` §8.4 (rewrite the
point so it names a biome, not "the troll jungle"), §1.3's monopoly note and
§2's flora row, drop the pointers those three carry to this file, and delete
this file.
