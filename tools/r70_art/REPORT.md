# Round 70 lane ART — pass 2 delivery

**User's picks (2026-11-07): Thread A, Grinder B, Smelting furnace A,
Iron A, Steel A, Silversteel A, Embersteel A, Abyssal Steel A.**

**Furnace A always burns.** This supersedes pass 1's cold/no-fire/no-light
rule for A only. Every proposal remains available.

**Upgrade classification: compatible, tooling and media only.** Branch
`r70-art`, pass 1 predecessor `6b5a551c`. Every change is under
`tools/r70_art/`; no game code, registered content, saved state, version,
upgrade declaration or template changes. Lane GUILD's installation joins
Round 70's map reset.

[Self-contained page](page.html) · [Final files](candidates/final/) ·
[Installation handoff](INSTALL.md) · [Reproduction](README.md) ·
[Media inventory](LICENSE-media.md)

## Delivered in pass 2

- The eight confirmed picks appear at the top of the page and in all proposal
  cards. All 24 proposals stay present. Historical recommendations are labelled;
  the user's Grinder B takes precedence over the former recommendation A.
  Stale browser choices cannot replace these recorded decisions.
- **Burning Furnace A:** original yellow-orange flames, dull coals and painted
  hearth warmth behind the grate. A narrow dull-hot channel on the pouring lip
  suggests residual heat; the casting remains solid. No particles or moving
  geometry. The shaft and footprint remain unchanged; aperture, jamb/lintel
  edges and grate align to the native 1/16-node grid so each bar occupies one
  dark texel. The largest bound adjustment is 0.0525 node.
- **Fire numbers:** eight vertical frames, each 16 × 16 px, in 16 × 128 sheets;
  nominal **0.1875 s/frame**, **1.5 s/loop**. Normal Luanti
  `vertical_frames`, `aspect_w = 16`, `aspect_h = 16`, `length = 1.5`.
  Only the front faces of hearth cells (0,0,0), (1,0,0), (0,1,0), (1,1,0)
  animate. Proposed **light_source 8** on those four cells, zero elsewhere.
- Front, hall corner and dim hall views run inline at the same scale as
  before. The selected machines use the actual final cell textures and box
  geometry. Pause, hidden-tab suspension and live reduced-motion handling
  are included. The dim light is illustrative, not an engine-light claim.
- **One final folder: 128 files** — the Thread icon, five stone faces, 120
  machine-face PNGs (four animated), and two cell-construction JSONs.
  No alternate or comparison media is included. Thread and all five stone
  picks are byte-identical to pass 1.
- **INSTALL.md** lists every final file, role, proposed item/node name and
  licence. It includes exact machine cells/boxes and six-face mapping through
  the JSONs, animated cells and light levels, required template space,
  Thread's precise inventory-image replacement and desktop/web GUI checks.
  Sound is explicitly lane GUILD's, reusing the existing furnace loop.
- All original media/geometry is **GPT-6 Astra, CC0-1.0**. Final textures
  contain no borrowed pixels; the newly animated/dim hall previews retain
  their comparison textures' CC BY-SA 3.0 notices.

## Verified inputs and construction

The shipped normal and dual active furnace sheets are both 16 × 128; both
definitions use a 1.5-second vertical loop and light 8. They were inspected
for pixel scale and pacing only. Their hashes and definition hashes are
recorded in the source manifest. The engine stores the nominal 187.5 ms frame
time as 187 integer milliseconds, exactly as for those existing furnaces.

The read-only pinned engine source establishes both `length` as the complete
loop and node-box UV orientation. Its six tiles belong to the node, not each
box. The new `installation.py` therefore clips geometry by cell and bakes
ordinary six-face tiles. Its JSONs include local boxes in [−0.5,0.5] and
ordered tile objects; installation does not need a custom material system.
This native pixel projection is also what the selected previews display.

The original footprint finding still applies: the sorter at (1,1,10), facing
east, stands beside x=0's west wall, table x=2 and storage (1,1,11). The chosen
2-deep machines cannot fit directly behind that unchanged socket. INSTALL
specifies their reservations and leaves final work-bay positioning to GUILD.
The depth/nether TODOs do not block this package.

## Checks

- `python3 tools/r70_art/build.py --check`: **230 generated outputs reproduce
  byte for byte**, including the final folder, INSTALL, page and licence table.
  Unexpected generated files are rejected.
- Native dimensions/alpha, shipped metal palettes, all geometry bounds and
  references, the exact final-file inventory, four animated front tiles and
  their frame/timing/light metadata pass the generator's validation.
- **126 inline PNG instances** decode; anchors resolve; eight disabled
  selection groups each retain A/B/C and exactly the recorded pick.
  CSP forbids external resources and network connections.
- `node --check tools/r70_art/picks.js` and in-memory compilation of both
  Python sources pass. Ad-hoc execution of the page script with a mock DOM
  covers all eight frames, loop wrap, synchronized views, pause/resume,
  tab visibility, initial/live reduced motion, saved theme with stale picks,
  missing/malformed storage, copy and its fallback. No fixture was added.
- Selected icon/stone identity, retained alternate candidates, local Markdown
  links, per-final-file licence coverage and `git diff --check` pass.
- The front, normal/dim hall, final Grinder B and fire frames were inspected
  directly. The fire reads through the grate at the retained scale.

**Browser limit:** Chromium 151 failed before page load with
`setsockopt: Operation not permitted` (exit 133). No browser screenshot,
phone interaction or desktop/web game acceptance is claimed.

## Handoff

No delivery blocker. GUILD owns registration, hall placement, the reused
ambient loop and the desktop/web checklist in INSTALL. The coordinator's
independent review remains required before integration.

No Lua, game server, fixture, other worktree/main changes, other agent, merge
or push was used.
