# Round 26 — Organic capitals, Claim Stone activation, cleanup

Drafted 2026-09-29 after the Round 25 playtest start, the
[work-package audit](wp-audit-2026-09-29.md) and its
[user decisions](wp-audit-2026-09-29.md#user-decisions-2026-09-29).
**Status: in progress.** Lanes S (`377e7cd4`), R (`4e88234c`, Troll
follow-up `ed7d79a1`) and I (`abaaa262`) are merged on local main; Lane W
waits for the user's image approval; Lane D (docs) is under way.

## Goals

1. Capitals get an irregular, individual wall outline and more variety
   between each other, with the city roughly the size it is today.
2. The Claim Stone gets the draft/activation model from the first playtest
   (Round 25 rulings 30–33), and the Housing Manager becomes the Housing
   Steward.
3. Two bounded work packages: the registration cleanup (WP28 with the audit's
   item decisions) and the status-icon HUD package (D10), whose art Astra is
   generating in parallel.
4. BACKLOG, the WP scopes, ROADMAP and the design docs reflect the audit
   decisions.

## Rulings

### Capitals (audit A1–A5, D72)

1. **Stay inside today's reserved 512 square** for this round. Growth up to
   about 193,000 m² fits inside it; the target area stays roughly as today.
   The user may revise this after seeing the images (ruling 5).
2. **Star-shaped outline, only more irregular.** Each ray keeps exactly one
   wall point (the planner's `r_at`/`inside` stay valid). Irregularity comes
   from less smoothing, larger radius variation, terrain-following radii
   (ridges, shores, slopes) and a per-capital character. Real bays and lobes
   are out of scope.
3. **Size and flair.** "Smaller, denser" (Round 22 §11) is no longer a rule.
   The goal is a size that fits the content and a characteristic look, with a
   few well-placed style elements (for example towers or bastions at wall
   bends, emphasised gatehouses), never filler for its own sake.
4. **Capitals should look less alike (D72).** Round 22 noted a shared pattern:
   round outline, central core, a cross of avenues, two rings. This round
   varies that per capital (for example avenue layout, core position, ring
   count or shape) within the planner's existing legality rules. Infill
   houses only where they fit the content (ruling 3).
5. **Images first.** Before merging, the lane shows 2D top-down images of all
   six capitals on three seeds, before and after (the Round 22 prototype in
   `~/projects/grudgelands-orchestration/r22/capital-proto/` is the model).
   The user reviews them and proposes fixes; iterate on the images, not in
   the engine.
6. **The future waypoint pad may sit anywhere in the city.**
7. Required and named plots keep the Round 25 Lane H tiering; the
   load-failure guard stays. The rare named-building drop may improve with
   the new outline; measure it.

### Claim Stone (Round 25 rulings 30–33)

8. **Placing is a draft.** It reserves the square against other claims,
   protects nothing, is half-transparent, can be picked up by the owner at any
   time without a lock, cannot be destroyed by others, and disappears after
   **5 minutes** unless activated (the owner then gets a new stone from the
   Steward at once).
9. **Activation costs at least 5 lumps**, paid at once through a button in the
   stone form; it starts protection.
10. **One lock only:** for **12 hours** after activation the stone cannot be
    picked up. No placing lock; after a pick-up or destruction the player may
    place and activate again at once.
11. **Housing Manager → Housing Steward** everywhere players see it (NPC name,
    dialog, map tooltip, status texts, drop message) and in the docs. The
    internal role id may stay.
12. **Round 25 carry-overs:** an admin command to remove a claim or an
    orphaned stone; a `buildable_to` node (snow) in the arrival cube becomes
    diggable by the owner.

### Registrations (WP28 and audit D5, D6, D9, C6)

13. Remove the mobs_redo utility items (nametag, net, lasso, protector,
    saddle, repellent, shears) and the silver-sandstone recipes.
14. **Unify the tool namespace now:** all tool tiers under `grug_materials:`.
    Fresh-server rule: no migration of old worlds, but keep engine aliases so
    nothing in the repo (recipes, quests, loot tables, traders, fixtures)
    breaks.
15. WP37 remainder: the two surface critters (Bone Weevil, Bog Fowl) get
    ×0.75; the rest of WP37 is closed.
16. WP28's clay clause is stale (clay is generated again); drop it.

### Status icons (audit D10, [icon list](status-icons-2026-09-29.md))

17. A small HUD package: a status icon row with green (buff), red (debuff)
    and gold (neutral) frames drawn by code, icons from
    `grug_status_<id>.png`, the countdown or value as text.
18. Register the effects that work today but never reach the status list
    (Sidestep, move immunity, the six talent windows, poison, slows, roots,
    stuns, Dragon Scorch as a 1.5 s status).
19. **Combat state becomes an icon** (red crossed swords, gold frame) and
    replaces the "Combat" text next to the health bar.
20. Food buffs show the eaten food's own item image where that is
    straightforward, otherwise the generic food icon.
21. No cooldowns on the status row.
22. Class icons (Warrior, Mage, Priest, Scout) appear in the party UI.
23. Placement of the icon row: the lane proposes one (the status list and the
    target frame both sit top-centre today); the user decides on a screenshot.

### Documentation (audit decisions)

24. Apply every audit decision to BACKLOG, `work-package-scopes.md`, ROADMAP
    (V1 scope: boats, waypoints for starts and capitals, WP41, story levels
    41–60 in V1; WP42 scripted battles after V1, PvP POIs allowed in V1) and
    the design docs. That covers closed and merged WPs, rewritten briefs
    (WP44 lighter pass, WP41, WP17 citations, WP46, release gates), removed
    systems (renewable ores, rested XP, out-of-combat regeneration, dragon
    hoard chest, `/unstuck`) and stale lines (`items_crafting.md` G2
    surcharge, `story.md` V1 Nether portals, `world.md` unwalled capitals,
    `bandit_frontier` 16, STATUS "latest game", `findings.md`).

## Lanes

| Lane | Scope | Depends on |
|---|---|---|
| **W — Organic capitals** | Rulings 1–7: outline irregularity, per-capital character and D72 variety in `capital_planner.lua` (and `r7_capitals.lua` only where needed); 2D before/after images of all six capitals on three seeds; protection, `city_edge` and claim distance follow automatically and are re-checked | — |
| **S — Claim Stone activation** | Rulings 8–12 in `grug_housing` (+ the Steward strings in `grug_mobs`, `grug_map`, `grug_home`), fixtures and one end-to-end engine run | — |
| **R — Registration cleanup** | Rulings 13–16 | — |
| **I — Status icons** | Rulings 17–23; starts with placeholder art (the skill icons) and swaps in Astra's icons from branch `art-status-icons` once delivered | Astra's art for the final swap |
| **D — Docs cleanup** | Ruling 24, plus the housing docs for rulings 8–11 and the capital docs once W merges | W and S for their parts |

**Parallelisation and order.**
- W, S, R and I start together; D starts with the audit part at once and adds
  the W and S parts after those merge.
- W is the only lane in capital mapgen; nobody else touches
  `capital_planner.lua`, `r7_capitals.lua`, `city_edge.lua` or
  `capital_protection.lua`.
- W is not merged before the user has approved its images (ruling 5).
- Merge order: S, R, I as they are ready; W after image approval; D last.

**Coordination rules** (as in Rounds 24–25):
- Opus lanes in their own worktrees and branches; an independent review per
  lane; review findings are hypotheses to verify.
- Lanes other than D do not edit BACKLOG, README, ROADMAP, AGENTS or
  docs/STATUS and never sync.
- Checks with judgement (audit E10): portable fixtures first; engine runs
  only through `tools/luanti_headless.sh`, short (≤ 5 min), `pgrep` clean
  afterwards; no PUC.
- W's mapgen timing and any protection or planner cost are reported as
  comparisons; clearly slower preparation or much more complexity goes to
  the user first.
- Afterwards: fresh world, playtest.

**Not in this round:** the depth pulse (WP34, kept for later), WP44, boats and
waypoints (WP17), WP41, the story (WP9), WP5 and WP10.
