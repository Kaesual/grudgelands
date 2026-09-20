# WP47 / Round 12 plan: Skills tab, retained mount tiers, and generic held-item pose

## Outcome and frozen player-facing rules

This package adds a `Skills` sfinv page that always shows every ability the
character has currently unlocked and every riding tier the character has ever
bought. This implements the already-open `BACKLOG.md` WP47 rather than creating
a second package. The page is an entitlement catalogue and recovery surface: its icons
can be dragged into the visible main inventory only when that exact item is
absent from `main`, `craft`, and all four bag-content lists. It does not expose
locked talents, abilities belonging to another class, or unpurchased mounts.

Ability and mount item stacks become disposable representations. They may live
in `main` or the four player-owned bag-content lists, but never in chests or
other external inventories. Dropping one
returns an empty stack directly: it does not create a `__builtin:item`, transfer
the representation to another player, revoke the underlying ability/riding
entitlement, or toggle/remove an active mount controller. The player can recover
the representation from `Skills` once no copy exists in the scanned inventory
lists. Recovery never resets a cooldown, charge, cast cadence, target, resource,
or mount runtime state.

Bought mount tiers remain individually usable forever. Buying T2 retains T1;
buying T4 retains T3. Each item summons its own original tier at its original
speed (T1 6.4, T2 8, T3 8, T4 12 nodes/s); lower-tier items never inherit the
highest tier's speed. Persistent highest-land and highest-flight metadata remain
the compact entitlement authority: ownership of a tier is derived from the
already-decided sequential ladder (`highest >= tier_id` within its mode).

Generic held-item art gains a centred forward pose rotated 90 degrees from the
current upright fallback. Existing sword/tool/staff, axe, and bow transforms
remain byte-for-byte unchanged. Explicit pose metadata wins first; established
weapon-family group dispatch wins next; only otherwise-unclassified items use
the new forward fallback. This governs the existing attached wield entity seen
in third person, by other players, and on supported humanoid NPCs. Luanti owns
the local first-person wieldmesh through a separate client path; changing that
would be a distinct engine/item-definition package and is outside WP47.

## Explicit replacements of current design text

The implementation must amend the living design documents before or with code:

1. `docs/design/mounts.md` section 1.1 currently says one item per movement mode
   and that T2/T4 atomically replace T1/T3. Replace that representation rule with
   one recoverable item per bought tier. Permanent highest-tier metadata still
   proves all preceding purchases. Replace section 3's "highest purchased tier"
   item wording and automatic restoration/duplicate-removal wording accordingly.
2. `docs/design/mounts.md` currently says mount items are never dropped. Replace
   this with deletion of the representation and recovery through `Skills`.
3. `docs/design/classes.md` says ability items are not droppable and locked to
   `main`. Replace both rules with deletion/recovery and storage in `main` or
   the character's own bag-content lists. Chests and every other external
   inventory remain forbidden. `craft` is checked defensively for duplicates
   but is not an allowed destination.
4. `docs/design/skill_trees.md` section 3.4 says `sync_kit` re-grants on talent
   changes and describes hotbar placement. Replace later automatic insertion:
   talent-unlocked skills appear in Skills with a chat notice and are acquired
   manually. Deleting an unlocked representation does not cause join, talent
   spending, equipment changes, or page refreshes to recreate it.
5. `docs/design/character_visuals.md` currently makes anonymous icons upright.
   Replace the anonymous fallback with the centred forward pose and document the
   explicit-pose precedence. Preserve all weapon and bow transforms.

These are current-design changes, not backward compatibility. Fresh-server mode
means no reader or migration for prior item layouts or metadata formats.

## Package structure and APIs

Create `mods/PLAYER/grug_skills/` with `init.lua`, `page.lua`, `mod.conf`, and a
small focused fixture under `tools/r12_skills/`. Dependencies:

```text
grug_core, grug_classes, grug_abilities, grug_mounts, grug_inventory, sfinv
```

The separate mod avoids dependency cycles: `grug_abilities` and `grug_mounts`
own entitlement/item construction; `grug_skills` only composes their public
catalogues and owns the detached recovery inventory/page.

Add these read/construction seams:

```lua
grug_abilities.is_unlocked(player, ability_id) -> boolean
grug_abilities.unlocked_ids(player) -> ordered array of ids
grug_abilities.stack_for(player, ability_id) -> ItemStack or nil

grug_mounts.owned_tier_ids(player) -> ordered array of tier ids
-- keep and use existing grug_mounts.stack_for(player, tier_id)
```

`unlocked_ids` returns universal abilities first, then the current class's
registration order, including a `talent_gated` definition only when its named
talent rank is positive. Replacement and passive/effect talents remain labeled
talent information rather than draggable catalogue items because they have no
registered usable item. `stack_for` is the only constructor for
an ability representation: it applies effective range, weapon/offhand skin,
swing capabilities, charge-bar parameters, current numeric description, and
the current cooldown/charge wear snapshot. It must not mutate any runtime combat
ledger. Both automatic first grant and Skills recovery call this constructor.
Every cast/use continues to authorize against the server runtime ledger; stack
wear is presentation only, so even a stale catalogue image can never bypass a
cooldown or charge.

### Entitlement and kit synchronization

Refactor private `kit_of`/`sync_kit` around one `is_unlocked` predicate. On
class creation, join, and each talent change:

- compute the current ordered unlocked set;
- purge foreign, newly locked, and duplicate ability representations while
  preserving one valid copy in either `main` or any owned bag-content list;
  clear defensive strays in `craft` and forbidden lists;
- refresh metadata on existing valid stacks without moving the player's chosen
  hotbar order;
- never auto-grant a newly talent-unlocked id; the talent-change path instead
  announces that it is available in Inventory > Skills.

On join, normalize/purge existing stacks but do not grant missing ones. This is
what makes deletion persist until explicit recovery. A full respec removes newly
locked talent items; re-buying the talent exposes it for manual drag again. The
current no-class-change decision remains.

There is one direct spec conflict resolved by the implementation default:
`BACKLOG.md` WP47 says learning never inserts a skill, while
`docs/design/classes.md` currently promises the base kit at class pick. The
package preserves the one-time character-creation starter kit
(universal plus base class abilities) so a new character remains immediately
playable, while every later talent unlock is manual through Skills. Class
changing no longer exists, so this exception has one bounded call site. If
"no auto-insertion" is intended literally even for initial class creation,
remove that grant as well and open Skills automatically after class selection.
This is a frozen implementation default for the Round-12 Go, not a blocker.

Do not clear cooldowns/charges merely because a stack is recovered or metadata
is refreshed. Preserve the existing runtime reset rules on reconnect and the
explicitly decided respec reset if the living spec still requires it; class
creation initializes clean state once. Separate `normalize_kit` from any
combat-state reset so a talent callback cannot accidentally reset active
cooldowns on every point spend.

### Mount representation lifecycle

Replace the mode-wide `mode_slots`/`sync_mode` canonicalization in
`grug_mounts/state.lua` with exact-tier normalization:

- purchasing tier N validates prerequisites and money, charges gold, records
  the new highest tier, announces availability in Skills, and inserts no item;
  inventory capacity is irrelevant to learning;
- join/race/faction refresh scans existing exact-tier stacks, removes duplicates
  of the same tier, removes unowned/foreign-owner stacks, and rewrites the kept
  stack through `stack_for` so race/faction art stays current;
- normalization never recreates a missing representation;
- active mount state is independent of representation presence.

Remove the blanket outbound-take refusal that encoded the old owner-bound,
never-delete representation. Keep all transfer gates needed to prevent another
character from using a copied/forged stack (`use_mount` already checks the
owner metadata and persistent ownership). The normal player inventory callbacks
must never upgrade a lower-tier stack into the highest tier or delete a distinct
owned tier.

Add `grug_mounts.register_on_owned_tiers_changed(func)` and fire it only after
a successful purchase commit. The Skills page uses it to rebuild its catalogue;
trainer UI code remains a caller of `purchase` and does not become a second
notification source.

### Skills detached inventory

Create one player-private detached inventory on join, named with a validated
player-derived suffix and passed the engine's `player_name` restriction. Give it
one fixed-size `catalog` list large enough for the maximum current abilities
(seven) plus four mounts, with spare slots only if the registered maximum audit
requires them. Rebuild it on join, class choice, talent change, riding purchase,
and race/faction change; remove it on leave.

Each unlocked entry is always visible. Use detached `allow_take` as the
authoritative transaction gate:

1. authenticate the callback player against the detached inventory owner;
2. resolve the source slot back to an ability id or mount tier rather than
   trusting arbitrary stack metadata;
3. re-check entitlement at take time;
4. scan only `main`, `craft`, and
   `grug_inventory.content_list(1..BAG_COUNT)` for the exact registered item
   name; count any occurrence as present, regardless of metadata;
5. require room in `main` for the exact constructed stack;
6. return `-1` only when all checks pass, using Luanti's documented
   "allow and don't modify source item" detached-inventory behavior.

Rebuild the catalogue whenever the Skills page opens, producing a current
description/skin/wear snapshot. In `on_take`, the preflight guarantee that the
item was absent makes the newly transferred main copy unique; locate that exact
copy and replace it once with a fresh `stack_for` result so recovery also
snapshots the current cooldown/charge ledger. Cast/use authority always reads
the server ledger, never stack wear, even if the displayed source became stale
while the page remained open.

`allow_move` returns zero. `allow_put` accepts only an authenticated unlocked
ability or owned mount belonging to that player and returns `-1` (allow while
leaving the catalogue destination unchanged), thereby consuming the source
representation as WP47 requires; unrelated or forged items return zero. The Skills formspec exposes only the
detached catalogue and the standard visible main/hotbar inventory, so the drag
destination is main. Do not add a listring to craft or bags. The player's normal
inventory allow callbacks remain a second line of defense. A rejected take may
show a throttled inline notice ("Already in inventory" or "Make room in your
main inventory") but must not rewrite inventories.

A separate scrollable read-only section lists currently ranked passive and
replacement talents from the authoritative talent registry: id, title, rank,
current description. It creates no item, detached slot, drag source or duplicate
activation button; talent-granted active skills already appear above. Respec
removes lost entries, and numeric modifiers remain descriptions of their actual
ranked effects. UI owns spacing and scrolling below the active/mount groups.

The page title is `Skills`; place it after `Talents` and before `Help/Crafting`
in navigation. Render abilities and mounts as two labelled rows/sections, using
their real stacks so descriptions and per-character icons appear in tooltips.
The page mutates items only by dragging a catalogue entry to main or dragging a
bound representation back onto its matching catalogue source to delete it. Refresh an
open page only on the rare lifecycle events above or after inventory actions
that can change presence; no globalstep and no per-frame inventory scan.

### Bound-item destination policy (plan-review correction)

SKILLS owns `grug_skills/bound_items.lua`, the sole policy for ability and mount
representations. The existing blanket player `take` refusal must be removed.
The engine gives that callback only source list/index/stack for both drop and
external transfer (`s_player.cpp:318`; `inventorymanager.cpp:202-214,716-741`),
so it cannot decide where an item is going. Return nil there: a genuine Q/drop
then reaches the item's deletion-only `on_drop`.

Enforce destinations instead:

- Player `move`: both endpoints must be main or an owned bag-content list.
- Player `put`: the inventory location's owner must equal the acting player,
  and the destination must be main or an owned bag-content list. Recheck current
  entitlement/owner. Craft, equipment, quiver and bag-container lists refuse.
- Every registered node composes its existing `allow_metadata_inventory_put`
  with an unconditional bound-item refusal, installed after node registration
  by the owning mod's mods-loaded pass. Preserve the previous callback result
  for ordinary items, including counts and -1; if absent, preserve the engine's
  default accepted count. Never replace existing protection/recipe logic.
- Every shipped detached inventory composes the same refusal into `allow_put`,
  except the authenticated player's private Skills catalog, which permits the
  documented delete-on-return. Creative catalog and trash must also refuse bound
  items through this policy; Q/drop and Skills return remain the delete routes.
  Cover both existing and dynamically created detached inventories through the
  known creation sites, not a global replacement of engine APIs.

The actual engine checks destination allowPut before source allowTake and checks
both directions of an occupied-slot swap (`inventorymanager.cpp:401-426`). The
policy therefore rejects a bound item entering a chest even though source take
is allowed. It also refuses swapping a bound item out of player inventory into
an external source. Include both directions explicitly in the fixture.

This is a finite standalone-game contract. Inventory-surface census must cover
all registered node destinations and every `create_detached_inventory` site.
Current detached creators are the two sites in `BASE/creative/inventory.lua`
(per-player catalog and trash); the new Skills site is the only exception.
Fail the source/startup coverage audit for an unguarded site instead of claiming
arbitrary future plugins are protected. Compose guards at the node registration
boundary and at these concrete detached constructors; record any vendor patch
in VENDOR.md with a GRUG PATCH marker. The guard must run before any user action.
Node dependencies/load order must include all current node creators; late node
callback registration cannot overwrite the guard undetected.

Adversarial cases include Q/drop, Skills return, direct drag, shift-click,
occupied-slot swaps in both directions, chest/furnace/station put, Creative and
trash, another player's catalog/inventory, stale entitlement and ordinary-item
preservation. No observer notification or take event mints a replacement item.
This replaces conflicting old filters rather than stacking them.

### Drop behavior

Change ability and mount `on_drop` callbacks to return `ItemStack("")`. Permit
their movement between `main` and `grug_bag1_content` through
`grug_bag4_content`; deny `craft`, equipment/quiver/bag-container lists, node
inventories, other detached inventories, and every external inventory. They do
not call `core.add_item`, `grug_mounts.toggle`, `grug_mounts.dismount`, kit sync,
or detached-inventory rebuild. The ordinary inventory/wield update is sufficient;
the catalogue icon remains available because it represents entitlement, not
physical possession. Confirm from the engine callback contract that the empty
return replaces the wielded stack and suppresses world-item creation.

## Generic forward pose

Extend `grug_visuals.POSE` with `forward`. Add an optional registered-item field
`_grug_wield_pose` whose value must be one of the exported pose strings. Resolve
poses in this order:

1. valid explicit `_grug_wield_pose`;
2. existing bow, edge-down, and diagonal group rules in their present order;
3. `POSE.forward` fallback.

Keep `POSE.upright` for content that explicitly requests it. The proposed
centred forward transform is:

```lua
pos = HAND
rot = {x = 90, y = 0, z = 90}
size = existing stature-compensated size
grip fractions = 0, 0
```

This maps the icon's image-up axis forward while retaining the current sideways
flat normal. Verify the matrix in the existing transform fixture rather than
tuning it by eye. Do not alter `tool`, `edge_down`, or `bow`, their grip anchor,
size, stature compensation, or group membership. Update startup validation so
an invalid explicit pose logs loudly or fails registration audit rather than
silently falling back.

## Files expected to change

- `docs/design/classes.md`
- `docs/design/mounts.md`
- `docs/design/skill_trees.md`
- `docs/design/character_visuals.md`
- `mods/PLAYER/grug_abilities/init.lua`
- `mods/PLAYER/grug_mounts/mod.conf` (declare the existing `grug_inventory` bag API dependency explicitly)
- `mods/PLAYER/grug_mounts/state.lua`
- `mods/PLAYER/grug_mounts/items.lua`
- `mods/PLAYER/grug_mounts/trainer.lua` only if purchase-page refresh needs an
  explicit callback seam
- `mods/PLAYER/grug_visuals/wield_geometry.lua`
- `mods/PLAYER/grug_visuals/apply.lua`
- new `mods/PLAYER/grug_skills/{mod.conf,init.lua,page.lua,bound_items.lua}`
- `mods/BASE/creative/inventory.lua` for the two detached destination guards,
  serialized with UI Food filtering; vendor provenance updated
- page ordering in `mods/PLAYER/grug_inventory/pages.lua` or one deterministic
  `register_on_mods_loaded` insertion owned by `grug_skills`
- focused fixtures under `tools/r12_skills/`, plus the existing mount, talent,
  ability and wield-transform fixtures where their contracts change
- `BACKLOG.md`, `ROADMAP.md`, and README Current State only when the WP is
  completed, following the repository workflow

## Acceptance and adversarial cases

1. Under the recommended initial-kit default, a fresh class receives every
   base/universal ability once. Deleting one and
   reconnecting does not auto-create it; dragging it from Skills restores one
   main-inventory copy.
2. The Skills page lists only the current class's base/universal abilities and
   currently ranked talent-gated abilities. Spending the unlock rank announces
   availability but does not insert the item. Respec removes it from inventory
   and catalogue. Re-unlocking exposes it for manual drag again.
   Ranked replacement/passive effects appear in the separate read-only section
   and never create draggable dummy items.
3. Recovery is refused if the exact item exists in any main slot, craft slot,
   or any active bag-content slot, including a noncanonical/forged metadata
   copy. Equipment, quiver, and bag-container slots are outside the explicit
   duplicate domain and cannot accept these items through their own gates.
   Moving a valid bound item between main and an owned bag succeeds; moving it
   to a chest, craft, equipment, quiver, or another detached inventory fails.
4. Two rapid take attempts, shift-click, detached-source take/drop, put-back
   deletion, full main,
   stale page after respec, forged detached metadata, and reconnect cannot mint
   a second representation or bypass entitlement. The allow callback re-checks
   live state and the source-slot mapping for every transaction.
5. Dropping an ability or mount leaves no `__builtin:item`. Dropping the item
   for an active mount does not dismount, duplicate, or remove its controller;
   standard damage/manual/lifecycle dismount paths remain authoritative.
6. Buying T2 with T1 present leaves both exact stacks; buying T4 leaves T3.
   T1/T2/T3/T4 each summon at 6.4/8/8/12 respectively. Deleting one tier does
   not affect ownership or other tier stacks; recovery restores that exact tier.
7. Purchase is atomic: insufficient money changes neither gold nor metadata;
   inventory fullness never blocks learning because purchase inserts no item.
   After a successful charge/metadata commit, the owned-tier callback exposes
   the tier in Skills. Failure before commit exposes nothing and charges nothing.
8. Race/faction refresh updates every present mount tier's owner, description,
   and icon without recreating a deleted tier or collapsing tiers by mode.
9. Ability recovery during an active cooldown restores the correct remaining
   wear and cannot make the cast ready. Recovery during swing charge preserves
   its clock. Reordering or dropping never changes mana/rage.
10. Generic apples, torches, bags, and similar unclassified items use the new
    centred forward pose. An explicitly upright item remains upright. Every
    existing sword, axe, pick, shovel, staff, equipped weapon, fishing rod, and
    bow produces the exact pre-change transform.
11. Page rebuild and presence checks occur only on page/lifecycle/inventory
    events. No globalstep, radius query, repeated `set_list`, or inventory write
    is introduced for an unchanged player.

## Verification budget

Development uses focused LuaJIT fixtures only:

- a new Skills transaction KAT loading the real entitlement and detached-page
  seams, including all duplicate lists, stale entitlement, rapid repeated take,
  full-main, drop deletion, cooldown/charge preservation, and exact-tier mount
  recovery;
- extend the mount KAT for retained tiers and original per-tier speeds;
- extend the talent/ability fixture for unlock, respec, re-unlock, reconnect,
  and missing-stack behavior;
- extend `tools/wp13/wield_transform_kat.lua` for explicit pose precedence,
  the forward matrix, and byte-identical existing weapon/bow transforms.

On every Lua change run `tools/bin/luac51 -p`, inspect `SETGLOBAL` for every
changed mod file, and run all five repository sweeps from
`docs/research/luanti-lua.md`. Use no intermediate PUC runtime and no broad
world/mapgen suites. This session explicitly runs no PUC runtime, including no
final PUC parity process; record that bounded session override in the evidence
instead of silently substituting another test. The user then runs
the GUI/runtime checklist: page layout and tooltips, drag recovery, drop with
and without an active mount, every retained mount tier's speed, and representative
generic/weapon/bow held poses.

## Review gates and stop conditions

This is a non-trivial cross-mod package and requires an independent strong-agent
review before merge using the full `docs/process/wp-workflow.md` checklist.
Freeze source hashes and focused logs before review; any post-review Lua-byte
change invalidates that review evidence and requires refreshed hashes/checks.

Stop and report a verified engine constraint if testing disproves detached
`allow_take = -1` as an immutable catalogue source during transfer to player
main, or permits a Skills-page take into a destination not visible in that
formspec. Drag-and-drop is an explicit user requirement; do not silently replace
it with buttons or another interaction.

No further user decision is required for the current contract. The frozen
defaults are: one-time starter kit at character creation, manual later skill
acquisition; Skills after Talents; exact-tier mount items; deletion rather than
world drops; owned-bag storage with external inventories denied;
main/craft/bag-content duplicate detection; third-person/world scope for the
pose; and the centred `{x=90,y=0,z=90}` forward fallback validated by the
transform KAT.
