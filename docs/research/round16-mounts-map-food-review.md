# Round 16 independent review — mount lifecycle, atlas, UI/food

Reviewer: native Sol. Review date: 2026-09-22.

## Scope and independence

Reviewed only work I did not author:

- A mount lifecycle: commit `9f178c27b1b8408929f6fe08e781c202a1a2b28b`
- C atlas repair and service markers: commit
  `bddd1edfbf8516b8ec553886f554bc480ad63625`
- E UI/food excluding all XP work: commit
  `1b2f04581bc05b48134d7448eb83283df1c087b3`

My own D/XP implementation was excluded. The review applied the full checklist
from `docs/process/wp-workflow.md`, the Lua 5.1 constraints and interpreter
strategy from `docs/research/luanti-lua.md`, and package contracts A/C/E in
`docs/research/round16-plan.md`. No production files were changed.

## Findings

No Critical, High, Medium or Low correctness findings.

## Verified behavior

### A — mount lifecycle

- `mods/ENTITIES/mobs/mount.lua:47-73` detaches first, clears the entity driver,
  and in teardown mode clears attachment bookkeeping and eye offset without
  accessing player_api animation data. This is compatible with
  `mods/BASE/player_api/api.lua:172-176`, which deletes its player record in an
  earlier leave callback.
- `mods/PLAYER/grug_mounts/entity.lua:85-132` clears active state, mount status,
  warning HUD, controller driver/rider fields, attachment, controller and visual
  through the same transaction. Teardown skips both appearance restoration and
  the deferred velocity callback. Ordinary manual, damage and death paths still
  restore animation and racial appearance.
- Leave and shutdown are idempotent across vendor/owner ordering. Shutdown may
  be followed by leave/deactivation without a second object removal or stale
  active record.
- Vendored changes carry a `GRUG PATCH` marker and are documented in `VENDOR.md`.

### C — atlas

- `mods/PLAYER/grug_map/page.lua:129-136` emits formspec v3 before the wrapper
  size, explicitly keeps wrapper coordinates legacy, then switches only atlas
  content to real coordinates. The pinned engine performs legacy element
  sorting only below v3 (`reference_projects/luanti/src/gui/guiFormSpecMenu.cpp`
  around lines 3490-3500), so definition order now places the map image before
  its marker buttons without changing the existing map projection.
- `mods/PLAYER/grug_map/providers.lua:28-74` derives services and quest givers
  from authored sockets without entity searches or emerge calls. Quest givers
  remain individual; profession/Riding trainers, kings and dragons are static
  location markers. Tooltips contain names only.
- `mods/ENTITIES/grug_mobs/bosses.lua:541-550` returns newly allocated marker
  rows sorted by id and exposes no live presence, health or respawn state.
- Existing open-only 0.5-second refresh, coordinate conversion, region clipping,
  online-party filtering and close-to-Character behavior remain intact.

### E — UI and food, excluding XP

- `mods/ITEMS/grug_food/init.lua:201-222` checks the shared combat authority
  before effect lookup, status installation or `take_item`, so rejection cannot
  consume food or replace the active buff. Successful use retains the authored
  instant heal; only five-second periodic regeneration is doubled. Existing
  combat pause and five-minute status expiry remain authoritative.
- `mods/ITEMS/grug_gear/init.lua:312-345` adds Cloth/Leather/Metal in the shared
  base-description reconstruction used by quality/enchantment regeneration;
  initial registered descriptions carry the same label.
- `mods/PLAYER/grug_jobs/workspaces.lua:164-168` places the recipe-book control
  inside the free right side of the existing 12-unit form. The helper retains
  its old defaults for other callers, and inventory lists and authorization are
  unchanged.
- `mods/CORE/grug_core/combat_hud.lua:1-26` reads the existing combat flag on a
  throttled 0.2-second pass and mutates HUD state only at enter/exit/death
  transitions. Leave cleanup prevents reconnect state leakage.

## Evidence inspected and rerun

The implementation handoffs report successful Lua 5.1 parser, SETGLOBAL and
five-sweep checks and no intermediate PUC runtime. I inspected those records
and did not duplicate the final interpreter gate.

Bounded LuaJIT reruns against the real changed modules passed:

```text
mount-lifecycle:12:ok
r16_map lifecycle=open-only idle-writes=0 close=Character death=clean disconnect=clean
r16_map geometry=pass headings=16 identity=stable party=online quest=individual services=static draw-order=v3 views=clipped
food-hud:24-routes:combat-refusal:double-regen:expiry:hud-lifecycle:ok
```

The mount fixture covers land/flight, leave and shutdown in both owner/vendor
orders, ordinary dismount, death, repeated cleanup and appearance restoration.
The atlas fixture covers draw order, projection, individual giver/service/boss
markers, names-only details, clipping, party disconnect and live-session
lifecycle. The food/HUD fixture covers every tier/role route, pre-consumption
combat refusal, status preservation, instant healing, doubled ticks, combat
pause, expiry and HUD lifecycle.

## Verdict and limits

**PASS — clean independent review.** These commits are suitable for the root
combined final gate and integration. No focused fix review is required.

Rendered marker visibility/hover readability, armor text presentation, furnace
button clearance at user GUI scale, combat-label placement, and real client
mount appearance remain GUI/runtime acceptance items; the implementations do
not claim those as standalone-fixture evidence.

Review calibration: independent reviewer model native Sol; authored scope none;
Critical/High/Medium/Low findings `0/0/0/0`; fix rounds `0`; bounded LuaJIT
fixtures rerun `3`; PUC runtime runs `0`; production edits `0`.
