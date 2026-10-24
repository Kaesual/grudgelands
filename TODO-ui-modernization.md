# TODO — UI modernization visual decisions

Open design questions for the [proposed UI round](docs/planning/ui-modernization-plan.md).
Status: planning, 2026-10-24. The first browser study's overall appearance is
well received; the full game's window layouts are not approved yet. Atlas 03 revises the full census study after the user’s functional-fidelity
feedback; its artifact and validation receipt are in the
[round plan](docs/planning/ui-modernization-plan.md#browser-atlas-03--2026-10-24).
The item
inspector is **omitted**, not an open question.

## 1. Navigation with all entitlements

There can be 13 main tabs. Atlas 03 compares two layouts with selectable
permissions, long labels and enlarged scale. Review these before code.
Existing ruling 10 in the
[crafting/UI plan](docs/planning/ui-crafting-rework-plan.md#2-rulings-the-user-2026-10-08)
keeps the non-map tabs at today's window size. The current frame is about
13.5 × 13.673 real units; [inventory/ui.lua](mods/PLAYER/grug_inventory/ui.lua)
asserts that the full inventory layout fits it. Admin Mail already places
controls near its bottom. The full/short views must retain seven/two rows.
A larger frame or reduced capacity is a separate user decision, not implied
by picking a navigation style.

The current native `tabheader[]` sits above the content and uses
`sfinv_nav_tabs` in [sfinv/api.lua](mods/BASE/sfinv/api.lua). A new two-row or
button navigation needs an explicit rendering/dispatch adapter and behavioral
tests, preserving sfinv's authoritative page lifecycle and visibility checks.
The mockups must budget actual header space, not just add a row above old
content and assume it fits:


- Two stable rows of tabs, all visible; costs some vertical space.
- A single row with explicit previous/next controls; keeps more content space
  but requires an extra action to reach some pages.

Compare both within the current geometry first, without shrinking slots or
making ordinary users look at empty privileged tabs. If two rows do not fit,
show the required window-size trade-off for an explicit decision; do not
silently overlap content or reduce visible inventory rows. A single-row
approach can reuse more of the current tabheader/dispatch, but paging still
needs correct index mapping and visibility checks. No automatic adoption,
sidebar, new tab grouping or new hidden submenu is implied.

User feedback on Atlas 02: Map & Quests should directly expand into its larger
view and keep the tab bar, without an intermediate Open button. This direction
is recorded in the plan; the map's precise dimensions and tab handoff remain
to be worked out. It does not approve larger dimensions for every other tab.
Atlas 03 shows this direct expanded view with shared tabs.

## 2. Window families and transparency

Atlas 03 covers all census families, including a chest and running furnace,
a quest dialog with long text and choice rewards, a Riding Trainer, and
Admin Mail with all main tabs visible. It includes compact confirmations,
text input states and the game's long Help texts. Review these against the
approved visual direction, real slot counts and realistic text lengths.

Discuss window proportions, action placement, reading-panel opacity and how
much world remains visible. The working proposal is one palette and control
style with task-appropriate dimensions; creation keeps its opaque world cover.
Show rarity/quest/talent states and admin status colors over the proposed
backgrounds too: existing translucent overlays change appearance when their
base changes. Do not silently retune semantic colors during implementation.
The user's expanded request for every UI is fulfilled by the atlas; the shared
rules can still be decided through representative families.

## 3. Quiver count presentation

The existing opaque cover for counts above 100 does not suit translucent
slots. The [documented fallback](docs/technical/upstream-workarounds.md#4-the-quiver-count-relies-on-an-undocumented-item_image-count)
is to remove the cover/count image and keep the total in the existing adjacent
label. Confirm this simpler presentation in Character's Scout sample; no new input
mode or inventory mechanics. The final label must remain clear at small scale.

The user explicitly permits rearranging existing controls for better looks
or usability, provided their basic functions and mechanisms survive. The
current [confirmed rulings](docs/planning/ui-modernization-plan.md#confirmed)
record the one-page creation, progress, source-content and control-placement
corrections. These are settled constraints, not new approval questions.

## Closing this TODO

After the user decides, fold the approved rules into the inventory/UI design
owners and the round's rulings. Delete this TODO when it has no remaining
questions and repair its incoming links. Until then, technical planning may
continue but the undecided navigation/layout must not be implemented.
