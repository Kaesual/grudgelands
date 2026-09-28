# Playtest fixes 2026-09-28 — receipt and GUI checklist

Delivered locally on 2026-09-28 from the user's nine playtest findings (food
RMB placement, bow draw swing, draw power meter, eating visual, crosshair range
feedback, fish on land and drops, first-person rod, recipe-book navigation,
Blink targeting). Rulings were agreed with the user before implementation; the
decided rules are folded into `docs/design/` (classes.md, scout.md,
skill_trees.md, combat_stats.md, items_crafting.md, biomes_mobs.md,
world_zones.md). No remote push.

Routing this session: Opus coordinated; Opus agents implemented each lane in its
own worktree; every lane had an independent Opus review, and every High finding
a focused re-review.

## Lanes and merges

| Lane | Merge | Content | Review |
|---|---|---|---|
| E Blink | `d9a6bd6b` | Land on the aimed ground/ledge, eye-height lift for air landings, body-box room checks, horizontal back-search, line of sight, no cost under 1.5 m | 1 High (slight downward aim with no hit) fixed, re-review PASS |
| F Node formspecs | `9f230aa0` | Bookshelf, signs, vessels shelf, furnace, mob spawner open from `on_rightclick` via `default/node_formspec.lua`; no formspec in node metadata (the client opens those itself on press) | Low fixes (narrowed `show_formspec` session wrapper, dig closes viewers, VENDOR.md) |
| D Recipe book | `9729c5fe` | Ingredient cells with a known recipe open it across books, Back history (20), invisible overlays (grid byte-identical), inverse slab/unpacking routes never make mined materials clickable | Approve + focused re-review of the inverse-route rule |
| A Input | `93be4fe4`, `08252c6f` | Food: click < 200 ms places/interacts on release, hold eats (also over doors, chests, NPCs), combat refusal at the hold point; VoxeLibre-style eating visual; bow meta `range="0"` while drawn; movement stances (eating ×0.35, bow ×0.5) that immunity and sprint cannot lift | Medium timing fixes; re-review found 1 High (node place repeats read as new presses), fixed, re-review PASS |
| C Swimmers/rod | `77c6bab7` | Shared swimmer guard (stepheight 0, water-only flight check) for Reed Angelfish and Kraken; angelfish drops 1 raw fish; rod `wield_image` transformed for first person, third person keeps the original via `_grug_world_wield_image` | Approve; probe now requires movement floors |
| B Crosshair/bow | `f7d96448` | Identical own `crosshair.png`/`object_crosshair.png`; server overlay (red hostile in skill range, green ally in heal range, light blue interactable in hand reach) using the cast's own aim rule; 2.5 s draw, Loose damage ×(0.2 + 2.8 f²), Fletching 2.25/2.0/1.75/1.5 s; draw power ring | 1 High (HUD scale used a non-existent ObjectRef method) fixed, re-review PASS |

The VoxeLibre reference submodule was updated (275 upstream commits) to study
its eating animation and is committed with this receipt.

## Final gates on merged main (`f7d96448`)

All run in parallel through `tools/luanti_headless.sh` (isolated, `LC_ALL=C`),
no server left running:

| Gate | Result |
|---|---|
| Plain headless boot (120 s) | PASS |
| `tools/pt_fixes/lane_a/run.sh` | PASS, 318 checks |
| `tools/pt_fixes/lane_b/run.sh` | PASS, 276 checks |
| `tools/pt_fixes/lane_c/run.sh` | PASS, 34 checks |
| `tools/pt_fixes/lane_d/run.sh` | PASS, 42 checks |
| `tools/pt_fixes/lane_e/run.sh` | PASS, 254 checks |
| `tools/pt_fixes/lane_f/run.sh` | PASS, 140 checks |
| `tools/r22_ability_punch/run.sh` | PASS, 65 checks |

Performance, reported not targeted: the crosshair overlay adds about +4 to
+14 µs per player per 0.05 s pass (base pass 6–8 µs); HUD packets only on state
change. The swimmer guard costs about 1 µs per swimmer step.

## GUI checklist (user)

1. **Food:** short RMB with an apple on the ground places exactly one on
   release, with no ghost node on press; holding eats (large jittering apple,
   crumbs, slowed walk) also in front of a chest, door, bookshelf, sign and an
   NPC/trader; a short click on those opens/toggles them. In combat a hold is
   refused at once.
2. **Bow:** holding RMB shows no repeated swing at blocks (one swing on the
   press may remain); the ring fills over 2.5 s and turns gold when full;
   walking is slowed while drawn; damage feel of tap / half / full draw.
3. **Crosshair:** new crosshair look; red on hostiles inside the selected
   skill's range (Strike 3, Charge 12, Fireball/Smite 20, Loose 25), green on
   allies with a heal selected, light blue on NPCs, drops and chests within
   4 m; how the server latency feels when sweeping.
4. **Fish:** fish and the Kraken stay in lakes; killing a fish drops one raw
   fish.
5. **Rod:** line and bobber hang down in first person; third person unchanged.
6. **Recipe book:** grid looks unchanged at rest and on hover; stone pickaxe →
   stick opens the stick recipe, stone/cobble does nothing, Back returns.
7. **Blink:** slight downward aim lands on the aimed spot; low ledges are
   stepped onto, 2-high walls stop you; air and cliff blinks go full distance.
8. **Node UIs:** bookshelf, vessels shelf, sign (special characters survive)
   and furnace/hearth open and work as before.

## Known limitations and open user decisions

- Click versus hold is judged on server control snapshots (~0.09 s): the
  effective boundary is about 0.18–0.36 s. A double click at a node whose
  release the server misses loses at most one click.
- Combat that starts mid-eat is refused only at the 1.5 s end (the ruling
  covers the 200 ms point).
- Overlay and ring also draw in the third-person front view (accepted).
- Blink: passes a 1×1 window if there is room behind it; liquids are passable
  (aiming at a lake lands on its bed); aiming slightly up over a 2-high wall can
  land on top of it. Each is a possible later ruling.
- With seeds or a bucket in hand, bookshelf and sign no longer open (the item's
  own placement runs first), as already for chests and workbenches.
- A dropped fishing rod shows the rotated sprite (cosmetic).
