# Round 18 H2 — skill icons and stable display tags

Date: 2026-09-23  
Implementation model: GPT-6 Sol  
Scope: H2 code integration only

## Result

All 22 active class and talent abilities now register their corresponding
`grug_abilities_skill_<id>.png` as the unchanged inventory image. Inventory,
hotbar and Skills catalogue views therefore share the semantic icon without a
weapon overlay, tint or orb composition. The stack's `wield_image` override
still resolves from the equipped weapon, including per-stack image overrides;
weapon replacement, empty-slot restoration and the Scout bow draw overrides
retain their existing paths. Cooldown/charge wear, range metadata, equipment
authority and combat behavior were not changed.

Capital mount displays now keep their parent nametag empty and create one tag
through `grug_core.create_tag_carrier`. This reuses the existing NPC lilac
color, 25/30-node per-observer hysteresis and one-second manager pass. Repeated
configuration reuses the manager's parent mapping. Switching display type or
deactivation removes the managed carrier, and the NPC-category display does
not qualify for an injured-mob HP bar.

## Evidence

`tools/r18_icons_tags/fixture.lua` executes the production skin function body
and the real capital-display module under a bounded engine stub. It checks all
22 PNG bindings, stale inventory-overlay removal, weapon replacement,
empty-slot restoration, bow-stage-to-equipped-wield restoration, malformed
wield fallback, parent/tag separation, repeated configure deduplication,
display-type cleanup and deactivate cleanup. Its canonical result is:

```text
r18_icons_tags_v1 icons=22 wield=weapon_swap_empty_bow_contract tags=dedup_remove_npc_peaceful
```

The development fixture passed under LuaJIT. Plain Lua 5.1 was used only for
the parser/static gates in this lane; the coordinator owns the round's frozen
final PUC/LuaJIT micro-KAT pair.

Coordinator correction: the registered empty-slot wield fallback remains the
neutral colored orb. A weapon depicted in an action icon is not falsely held
when no weapon is equipped. Inventory icons remain semantic at all times.
