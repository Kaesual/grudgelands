# Round 11 living-spec authority audit

**Date:** 2026-09-20

**Scope:** living `docs/design/` rules affected by Round 11 and the technical
primer in `AGENTS.md`

**Authority:** approved `docs/research/round11-plan/README.md` and its GEAR,
COMBAT, WORLD and ART annexes, checked against the accepted Round 11 runtime
and media state

This audit reconciles the living specifications after GAME, WORLD, GEAR,
COMBAT and ART. FARM, REPAIR and SCOUT remain pending packages; the edits do
not describe their consumers as shipped. Historical decision records remain
history where they are clearly labelled and cannot be read as current rules.

## Conflicts corrected

- `docs/design/inventory_equipment.md` §2 now names all six weapon families,
  the active bow and starter bow, the bow/quiver zero-hand exception and the
  current hand costs. Trinkets no longer imply armor contribution or the
  retired percentage-armor cap.
- `docs/design/items_crafting.md` §§3.1, 6.2, 6b and 9 now use raw armor
  rating, attacker-level mitigation and the universal 70% reduction cap.
  Shield rating, Stoneskin, cultural finishes and affix caps use the same
  unit. Ordinary equipment has one prefix and one suffix; the older two-plus-
  two rule remains only in the labelled decision history with an explicit
  supersession note. Spellbooks replace the retired scepter/orb route, and
  the drop rule no longer hard-codes an obsolete weapon/armor family count.
  The active bow item, arrow recipe and quiver foundation are distinguished
  from the still-pending SCOUT ballistic consumer, and the bow affix pool is
  Dexterity, Crit, draw speed, HP and Mana.
- `docs/design/combat_stats.md` §2 now records the bow/quiver exception and all
  six weapon families. It distinguishes the ability token, which never wears,
  from the equipped main hand, which remains wear-free until REPAIR integrates
  the approved once-per-settled-action hook.
- `docs/design/scout.md` now treats GEAR and ART as delivered dependencies:
  seven bow identities including the starter, the four-stack quiver, the
  24-item leather line, licensed bow sprites, dedicated leather textures and
  the center-grip pose. Its active bow affix pool matches GEAR. Old statements
  about a nonexistent bow, disabled leather, generated sprites and borrowed
  cloth are retained only as labelled historical quotations. SCOUT still owns
  the ballistic entity, abilities, class registration and talents.
- `docs/design/progression.md` and `docs/design/skill_trees.md` now describe
  the approved four-class talent design as decided while keeping the Scout
  implementation pending. The targeted Round 11 Ironbound/Unbroken armor-
  rating slice remains explicitly narrower than the rest of the future talent
  lane.
- `AGENTS.md` now gives the current armor-rating pipeline (`A`, attacker-level
  `K`, 70% cap and Unbroken ordering), the seven-primary profession roster,
  active bow/item foundation with pending SCOUT consumer, the bow/quiver
  exception, the pending REPAIR wear boundary and the island dragons' actual
  fixed level 70.

## Remaining package obligations

No unresolved authority contradiction remains in the audited living sections.
Two requirements in `docs/design/scout.md` §7 are still implementation work,
not stale design: SCOUT must add the bowyer bracket integration and the tanner
shelf entries. The approved Round 11 plan did not revoke either requirement,
so they must not be silently dropped when SCOUT is scoped.

FARM's `seed_visuals` interface is a delivered dependency whose registration
hook remains FARM work. REPAIR owns durability consumption and repair UI/code.
Neither pending boundary changes the active rules documented here.

## Validation

The audit changes documentation only. The final diff was checked with
`git diff --check`; no Lua/runtime test applies.
