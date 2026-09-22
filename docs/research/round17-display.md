# Round 17 DISPLAY implementation report

Status: implementation candidate on `wp17-display`; independent review and
root integration remain external gates.

## Result

The existing `grug_core:tag_carrier` now applies one startup-selected color
pair to each of the six global roles. The role is fixed when the carrier is
created: players are `player`; ordinary mobs use their canonical live
`_grug_disposition`; ordinary and royal guards use `guard`; all other tagged
entities, including villagers, elders, traders and innkeepers, use `npc`.
Kings and other bosses/adds keep their registered combat disposition. Mounts
still have no tag carrier of their own.

The carrier's existing one-second 25/30-node observer pass also owns one
optional injured-health sprite per eligible parent. Only `aggressive`,
`neutral` and `guard` parents can receive it. It is absent at full health and
death and is never created for players, critters or peaceful NPCs. The child
copies the carrier's observer set, changes its texture only when rounded
integer HP percentage changes, and is removed through the carrier lifecycle.
Its 0.8 by 0.1-node world size and selection-box-relative position are divided
by parent visual scale, keeping it stable from small mobs through scaled bosses
and below the engine's nametag offset.

## Startup settings

The engine's `settingtypes.txt` grammar has no `color` field type, so these
settings are declared as strings and validated once at mod startup with
`core.colorspec_to_colorstring`. An absent or invalid value uses the listed
fallback. Eight-digit RGBA strings preserve alpha.

| Setting | Default |
|---|---|
| `grug_nametag_aggressive_foreground` | `#ff4b4b` |
| `grug_nametag_aggressive_background` | `#00000040` |
| `grug_nametag_neutral_foreground` | `#ffd447` |
| `grug_nametag_neutral_background` | `#00000040` |
| `grug_nametag_guard_foreground` | `#b76cff` |
| `grug_nametag_guard_background` | `#00000040` |
| `grug_nametag_npc_foreground` | `#d8c5ff` |
| `grug_nametag_npc_background` | `#00000040` |
| `grug_nametag_player_foreground` | `#ffffff` |
| `grug_nametag_player_background` | `#00000040` |
| `grug_nametag_critter_foreground` | `#ffffff` |
| `grug_nametag_critter_background` | `#00000040` |
| `grug_injured_mob_hp_bars` | `true` |

All backgrounds therefore default to black at alpha 64/255, about 25 percent
opacity. The boolean and all colors are read once; changing them requires a
server restart.

## Engine evidence

- `reference_projects/luanti/doc/lua_api.md:6404-6412` specifies that invalid
  ColorSpecs return `nil`, which is the fallback boundary used here.
- `reference_projects/luanti/doc/lua_api.md:10107-10118` defines nametag
  foreground/background ColorSpecs and alpha-zero hiding.
- `reference_projects/luanti/src/client/content_cao.cpp:774-781` constructs a
  sprite as an Irrlicht billboard and sizes it from `visual_size`, establishing
  the camera-facing 2D behavior.
- `reference_projects/luanti/src/client/content_cao.cpp:1426-1467` parents an
  attached child's scene matrix to its parent node. Combined with the
  documented ten-times attachment coordinates at
  `reference_projects/luanti/doc/lua_api.md:8864-8875`, this is why the helper
  compensates both sprite size and offset for parent scale.
- `reference_projects/luanti/doc/lua_api.md:9002-9023` defines managed and
  effective observers, including attachment intersection. The HP sprite uses
  exactly the carrier's already-computed set rather than another scan.
- `reference_projects/luanti/doc/lua_api.md:10134-10137` confirms that
  `static_save = false` prevents persistence across unload.

## Verification

`tools/r17_display/kat.lua` loads the production carrier module under LuaJIT
and covers all six category colors, configured colors, invalid-color fallback,
shared observer visibility, integer-percent write suppression, parent-scale
compensation, full-health removal, eligibility and lifecycle cleanup. The
same fixture's `DISABLE_HP=1` path verifies the startup kill switch. The
pre-existing `tools/r8_tags/kat.lua` and
`tools/r14_quests/visibility_kat.lua` remain green after their engine mocks
were extended for the newly used settings and `ObjectRef:is_player` APIs.

No PUC runtime was run in this lane. Root owns the one final integrated
PUC/LuaJIT parity pair. The lane runs the required Lua 5.1 parser, SETGLOBAL
inspection and five source sweeps separately.
