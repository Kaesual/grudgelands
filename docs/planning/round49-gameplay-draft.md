# Round 49 draft: gameplay fixes and polish

Draft for the Round 49 plan (written 2026-10-15 from a read-only study of
main at 1ef11b5e; main is now at c05f205a, which adds only the mapgen plan
and the MGPROF tools); accepted by the user on 2026-10-15. It covers the
user's non-mapgen points; the mapgen part is planned separately
([mapgen plan](mapgen-native-plan.md)), and both merge into
`round49-plan.md`. Section numbers follow the round plan layout
([round workflow](../process/round-workflow.md) §2.1). File facts below were
checked against the code; lanes re-check them at their base commit.

## 1. Lanes

| Lane | Topic | Size | Wave |
|---|---|---|---|
| UI | Mail postage computed at Send; tooltips on the merchant's Sell rows | small | 1 |
| INV | Claim Stone anywhere in the carried inventory; the Housing Steward's button; starter kit on hotbar 7/8; a granted skill makes room on a full hotbar | medium | 1 |
| MOB | Kill XP −10 % per level below; rare tier between normal and elite | small | 1 |
| NAV | Diagnose short-range chase failures (zombies, giant rats behind bushes and trees), then fix; ranged mobs path to regain line of sight | medium | 1 (diagnosis), then fix |
| VIS | Node items 70 % in the third-person hand; the onion half buried | small | 1 |

All lanes touch disjoint files except the docs listed in §7.

## 2. Rulings (the user, 2026-10-15)

1. **Postage at Send.** The Write tab shows the rule, not a computed
   figure: "Postage: 5c per letter + 30c per filled slot". Send charges the
   slots as they are at the click; no quote, no refused first Send. The
   result line names the amount: "Letter sent to X. Postage paid: 65c."
   (The form is never resent on an inventory move: a resend drops text typed
   since the last event, engine `GUIFormSpecMenu::regenerateGui`.)
2. **Sell rows show the item tooltip** on hover, with the stack's own
   description (quality, enchants), like the mail attachments do.
3. **The Claim Stone may lie anywhere a normal item may lie in the carried
   inventory:** hotbar, `main` and every bag's content list. It stays out
   of everything else (chests, stations, mail attachments, bank and storage,
   equipment, trades, trash). One stone per player stays. Dropping still
   destroys it. Skills stay hotbar-only. The give helper (the steward's
   hand-out, picking a placed stone up) and the sort treat the stone like
   any other item: no special case puts it into `main`.
4. **The Housing Steward shows "Receive Claim Stone" only when the player
   can receive one.** Otherwise the window shows the reason in place of the
   button (level below 20, stone placed in the world, stone carried in any
   list). Exception: a full inventory keeps the button (the player can make
   room) and refuses on the click as today. After a successful hand-out the
   window shows the reason ("You already carry a Claim Stone.") in place of
   the button. The existing checks already cover the bags (`holds_stone`
   scans every list) and the placed stone (the claim registry).
5. **Kill XP below the player's level: −10 % per level.** 1 below 90 %,
   9 below 10 %, 10 or more below 0 XP and gray. Mobs above the player stay
   +10 % per level, at most 150 %. The target frame's colours and the
   "no XP" hint follow the new gray line.
6. **Rare tier between normal and elite:** HP ×2.5, XP ×2, damage ×1.4,
   armor 90. Scale 2 and the violet tint stay (recognition), the elite loot
   table and the rare-only behaviour (larger leash, no density culling, no
   dawn despawn) stay.
7. **Short-range chase:** diagnose first (§4 NAV), then fix by what the
   diagnosis shows. The Round 42 detector (stuck after 0.5 s below 30 % of
   the expected movement, then `core.find_path`) stays the only one (Round
   42 ruling 17). **Ranged mobs** (the ground `dogshoot` families, e.g.
   skeleton archer and raider, bandit archer, golem, dungeon master, bog
   witch) may use the pathfinder to regain line of sight to their target,
   then stop and shoot; their melee phase uses it like any melee mob. Fliers
   (e.g. the ember wisp) stay without (coordinator default: `core.find_path`
   is ground-only).
8. **Node items in the third-person hand at 70 %** of today's size, only
   items drawn as 3D blocks (cube, nodebox, mesh: dirt, stone, slabs,
   stairs). Flat-drawn items (plantlike, torchlike, signlike nodes, tools,
   craftitems) and the first-person hand stay as they are.
9. **The onion sits half in the ground:** the world textures of the wild
   onion and of the field onion (stages 3 and 4, shared files) are cut at
   about half the bulb, the cut bulb at the bottom edge. The inventory icon
   (`grug_cooking_wild_onion.png`) stays. One version by feel; the user
   adjusts after the GUI test.
10. **Starter kit on the hotbar:** apples in hotbar slot 7, torches in slot
    8. When a granted skill finds no free hotbar slot, a non-skill item on
    the hotbar makes room: it moves into the inventory (the give helper) and
    the skill takes its slot. With no room in the inventory either, the
    skill waits in the catalog as today (coordinator default).

## 3. Shared conventions

- Release: Round 49 ships as 0.49.0 with a map reset
  ([mapgen plan](mapgen-native-plan.md)); none of these lanes needs a
  migration step. Release mode as since 0.41.0 otherwise.
- Every number a lane changes is changed in the game, the Python ledger
  (`tools/r28_design/r28common.py` and what reads it), the tests that pin it
  and the design docs in the same lane.

## 4. Lanes

**UI.** Postage per ruling 1: `grug_mail.send_letter` stops comparing
against a quote (`mods/PLAYER/grug_mail/api.lua:121-145`, the `quoted`
parameter and the "attachments changed" refusal), the Write tab
(`window.lua` `write_tab` 392-427, `session.quote`, the file comment at
9-15) drops the figure from the Send button and the breakdown line. The draw
serial on Send stays (it guards a quick second click). Tests that pin the
quote: `tools/r48_mail/portable_test.lua` 595-608 (B) and 873ff (D, "the
second Send"); docs: `docs/design/mail.md` 81-85. Sell tooltips per ruling
2: the Sell rows keep only the item name today
(`mods/ENTITIES/grug_traders/trade.lua` `current_rows` 127-160) and draw an
`item_image` without tooltip (`render_sell`, 270); keep a representative
stack per row and add an area `tooltip[]` over the image, the pattern of
`attachment_cells` (`grug_mail/window.lua:139-154`).

**INV.** Claim Stone per ruling 3: the guard is generic for the group
`grug_soulbound` (`mods/PLAYER/grug_housing/soulbound.lua:20-29`, "only
main"); the give helper fills soulbound stacks into `main` only
(`grug_inventory/storage.lua:89-104`) and the sort moves a soulbound stack
out of the bags (`storage.lua:376-386`); both special cases go. Allowed
becomes "the lists the give helper fills with ordinary items"; the node and
detached wrappers (`soulbound.lua:31-90`), the inbox refusal
(`inbox.lua:34-38`) and the sort's resize guard (`guarded`,
`storage.lua:305-308`) stay. Update the comments and docs that say "main
only" (`soulbound.lua:1-12`, `grug_housing/api.lua:179`, `mail.md`
"Attachments", `docs/design/housing.md:101` "cannot go into ... bags").
`holds_stone` already scans every list (`grug_housing/api.lua:157-164`).
Steward per ruling 4: the button is unconditional
(`grug_housing/manager.lua:112`); draw the window from `model.can_issue`
(`registry.lua:375-388`). Starter kit per ruling 10: the kit goes through
`grug_inventory.give` since Round 44 (commit 32fa897c), so it lands in
`main[9..]` (`grug_factions/init.lua:200-206`); place it into hotbar 7 and 8
at character creation. Skill room: `place_on_hotbar`
(`grug_abilities/init.lua:2034-2047`) and the stale comment at 1987-1989.

**MOB.** XP per ruling 5: `grug_xp.GRAY_GAP` 7 → 10 and the factor 15 → 10
(`mods/PLAYER/grug_xp/init.lua:28-45`); the target frame's green-to-yellow
span is hardcoded to 6 levels (`grug_mobs/target_frame.lua:50-58`, becomes
9); help text `grug_inventory/help.lua:64`; tests `tools/r46_xp`,
`tools/r28_b3_xp`; docs `progression.md` §XP, `combat_stats.md`. Rare per
ruling 6: `TIERS.rare` in `grug_mobs/levels.lua:70-86`, the comments at
`levels.lua:10-11`, `rares.lua:9,467`, `TIER_MULT` in the ledger, the rare
XP test values, `biomes_mobs.md` §3.3, `combat_stats.md`, `progression.md`.
Round 49 is a map reset, so no rare spawned under the old values survives.

**NAV.** Phase 1, diagnosis (report, no game change): reproduce the user's
cases with the Round 42 probe (`tools/r42_nv1`, `grug_nav.on_event`) in a
small built scene: a zombie chasing a player standing 1-2 nodes higher
behind bushes (`default:bush_*`, `default:blueberry_bush_*`), a giant rat
chasing a player behind a tree trunk, distances 3-8 nodes. Report per case
the event sequence (never stuck / stuck → no path → give up / line exit
loop) and the cause in the code. Candidate causes from the study: the
walkable-line test treats tall collision boxes as one step (`grug_nav.lua`
`settle` 235-238), search jump height 1, the detector measures self-movement
(sliding along a trunk reads as free). Phase 2: the fix the diagnosis
supports, plus ruling 7's ranged mobs (`can_nav`,
`mods/ENTITIES/mobs/api.lua:2510`: today dogfight only). The coordinator
shows the diagnosis to the user before phase 2 when the fix changes a Round
42 ruling.

**VIS.** Wield per ruling 8: the third-person hand is the game's entity
`grug_visuals:wield` (`mods/PLAYER/grug_visuals/apply.lua:113-126`, size
`wield_geometry.lua:222` `SIZE = 0.32`, the same for every item); it is
hidden in first person. Scale `visual_size` by 0.7 for 3D-drawn node items
(blocks use the forward pose with the centre in the fist, so the grip does
not move). NPCs share the path and get the same 70 % (coordinator default:
they look like players). Onion per ruling 9: the textures come from
`tools/r48_artp/generate.py` (`onion`, variant A picked); change the
generator and regenerate `grug_farming_wild_onion_3.png` and `_4.png`.

## 5. Rules

The [round workflow](../process/round-workflow.md) and AGENTS.md as usual;
fixture runs sized per lane (own fixtures plus those that test the changed
behaviour, one full run per lane).

## 6. Verification and GUI checklist

- Mail: drag a stack into a slot after typing the text, Send once: the
  letter goes, the text is not lost, the line names the postage paid.
- Merchant Sell tab: hover an item, a quality item shows its quality.
- Claim Stone: drag it into each bag, sort the inventory (it stays in the
  bag), try a chest and the mail slots (refused). Steward with a carried
  stone, a stone in a bag, a placed stone, below level 20: no button and
  the reason; with no stone: the button.
- New character: apples in hotbar 7, torches in 8.
- Target frame: a mob 9 below is green-ish with XP, 10 below gray "no XP".
- A rare: visibly tougher than a normal, weaker than an elite.
- Chase: zombies and rats reach the player behind bushes and trees; an
  archer walks around a wall to shoot.
- Third-person view and another player's view: a held dirt block is
  smaller, a pickaxe unchanged; first person unchanged.
- Wild onion and field onion half in the ground.

## 7. Orchestration notes

- Start state: main at c05f205a (0.48.1 plus the accepted mapgen plan, not
  pushed); lanes branch from main at the round start.
- Shared files: `CHANGELOG.md`, `docs/STATUS.md` (coordinator after the
  merges); `docs/design/combat_stats.md` (MOB and NAV, different sections).
- Merge order free; NAV phase 2 merges last.
- Independent review for every lane (all change game logic except VIS's
  onion art).
