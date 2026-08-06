# TODO — Combat UX: offhand & carried light, mob nameplates, stealth

Open design questions raised 2026-08-06 (after the WP2 runtime test).
Decisions get folded into `docs/design/` (combat_stats.md / a new
items design doc), then this file is deleted.

## 1. Offhand slot & carried torch light

**Context.** The engine has NO native offhand — only the wielded item.
VoxeLibre implements offhand itself: inventory list `"offhand"` + HUD slot
(`mods/HUD/mcl_offhand`) with `mcl_shields` on top (blocking via right-click,
`offhand_item` flag in item defs). GPL, directly adoptable.

VoxeLibre 0.92.1 (newer than our 0.91.2 checkout) added a carried-torch
light radius. Technique (known from the classic `wielded_light` mod, engine
has no dynamic lights): an invisible `light_source` node is placed at the
player's head position and moved when the player crosses a node boundary.
Performance: every move triggers a C++ lighting recompute + mapblock remesh
+ resend to nearby clients. Manageable with mitigations:

- update only when the player's *node position* changes (never on a timer),
- only while a torch is actually equipped,
- skip updates when ambient light is already bright (cheap `get_node_light`
  check),
- one light node per player, removed promptly on unequip/logout.

**Proposal (leaning yes).**

- Build `wob_offhand` following the mcl_offhand pattern.
- **Torch in offhand = mobile light.** Strong synergy with destructibility
  R2: you cannot *place* torches in enemy territory, but you can *carry*
  light — at the cost of your offhand (no shield/second weapon) and of
  being visible to enemy players at night. Darkness stays a feature,
  carrying light is a tradeoff, not a freebie.
- Equip rules (enforced centrally): two-handed weapons require an empty
  offhand; shields for Warrior; Mage focus item (e.g. tome/orb) as a
  stat offhand; dual wield reserved for the Rogue (Phase 2).
- Endgame hook: rare items with a built-in light radius (no offhand cost).

**Open questions.**

- MVP scope: full offhand system with WP4 (abilities), or torch+shield only
  first? (Recommendation: torch + shield with WP4/WP5; class-specific
  offhands when the items exist.)
- Prototype the walking light early behind a setting and profile it with
  `/profiler` before committing to it for crowded servers.

## 2. Mob nameplates & con colors (level color coding)

**Proposal (user).** HP bar + level near the mob (proximity-based), WoW
color coding relative to the viewer's level L:

| Relation | Color | XP |
|----------|-------|----|
| mob ≤ L−10 | gray | **none** |
| L−10 < mob ≤ L | green | normal |
| L < mob ≤ L+5 | red | normal |
| mob > L+5 | skull | normal |

**Technical constraint.** An entity nametag is ONE global string — it
cannot be colored per viewer, but the con color depends on the viewer's
level. Split therefore:

- **Nametag (global, viewer-independent):** name + level + HP, e.g.
  "Boar [Lv 3] 20/20" — mobs_redo already updates nametags on punch;
  extend `wob_mobs.register_mob` to always set it. Neutral color.
- **Target frame (per player, WoW-style):** small HUD element; a raycast
  (or punch/look target) picks the mob, the frame shows name/level/HP in
  the correct con color for THAT viewer. This is where gray/green/red/
  skull lives.

**Recommendations.**

- Adopt the gray-mobs-give-no-XP rule (kills trivial-mob farming); goes
  into combat_stats.md §3 once decided. Implementation: XP award in
  `wob_mobs` compares `_wob_level` vs killer level.
- Skull mobs: **no extra damage modifier** — mob damage already scales
  with level; the skull is information ("cannot judge this"), not a
  mechanic. Keeps the level curves honest.
- Implementation slot: nametags + XP rule fit WP6 (mob tiers); the target
  frame HUD can be a small WP alongside it.

**Open questions.**

- Nametag visibility distance (engine renders nametags quite far; may need
  a distance-based show/hide in the mob step or just accept it).
- Does the borderland PvP need player con colors too (nametag already
  faction-colored)?

## 3. Rogue stealth (Phase 2 — parked here so it isn't lost)

MVP classes stay **Warrior / Mage / Priest** (decided, WP3); Rogue comes
in Phase 2 with Paladin/Warlock/Shaman.

User sketch for stealth, WoW-like: slower movement while stealthed
(improvable via talents), bonus for the opener (e.g. higher crit on the
first attack), stealth-only special attack (e.g. stun opener). Skill tree
details come later.

Engine notes for the eventual design:

- Visibility is global (`set_properties` texture alpha / `is_visible`) —
  there is NO per-viewer invisibility, so "enemies can't see you, allies
  can" is not directly possible. Options: semi-transparent for everyone,
  or fully invisible + drop the nametag while stealthed.
- Mob reactions are fully ours via the threat/aggro system (stealth = no
  threat generation until the opener, reduced aggro radius).
- Damage taken breaks stealth (same pattern as the Home Stone cast
  interrupt).
