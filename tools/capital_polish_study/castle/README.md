# Castle sides and registrar placement study

2026-11-10. Proposal only, **compatible / tools only**. No shipped template,
world generation, NPC assignment, game version or personal installation is changed.

## Side walls

`build.py` reads the actual Highcourt king's hall through the shared template
reader and its roster palette, then creates two unshipped cell variants. The six
castle templates are byte-identical to current main at inspection time (see the
parent `baseline.json`). Main's navigation, boss and registrar code has advanced;
none is copied into this worktree or modified by this study.

The inner side walls stand at local x=4 and40, with three-wide openings at z19…21,
y3…6. The outer walls at x1/43 and intermittent buttresses at x2/42 leave two
cells behind the inner walls, narrowing to one cell beside a buttress. At z22,
for example, x3 is the sole free cell on the west side. The king's .96-wide body
has only .02 node margin on each side when perfectly centred there. Its final
height is 2.72 (`grug_mobs/bosses.lua`, king definition and elite scale).
`mobs/grug_nav.lua`, `fit`, permits bodies at most one node wide in one column;
this is **not proof that the king gets stuck**, nor proof that chase turns and
multiple guards work reliably there. No engine chase test was run.

The two design alternatives are:

- **Closed:** fill the two existing three-wide service openings (24 cells).
  A later implementation must also retire their now-blocked door points.
- **Pillars, recommended:** open the lower inner side walls up to the band at
  y11, retaining piers at z10/16/22/27. Join those piers to the existing outer
  buttresses and fill the one-cell front pocket at z9. The four side bays have
  widths 5/5/4/2; the narrow gaps behind the piers are filled. Lamps move onto
  the retained piers, and the two obstructing seats per side are removed.
  Upper window strips, roof and throne stay as they are. 374 cell changes in
  the Human preview; `variants.json` records each old/new cell. The initial
  service door points remain in open bays.

The y4 SVG plans are geometry slices, not collision/path simulation. Interior
renders use the actual shared building renderer with bright study lighting,
identical camera and existing textures. This study is a structural proposal;
the reference gameplay geometry remains unchanged. Final native acceptance and
standard template gates belong to a later implementation.

## Registrar

`cores.json` was exported by the existing `tools/r70_design/export.lua blueprints`
from the real core builders. `maps.py` draws those rasters and marks the actual
waystone (W), actual castle entrance (E), and one candidate registration spot (R).
Candidates have an existing 3×3 paved patch with no overhang and no current NPC
socket within 1.5 nodes. They are placement candidates, not approved NPC sockets
or tested walking routes. `registrar-candidates.json` records coordinates and
straight-line distances; the dashed lines on the maps are **not paths**.

Four castle entrances face south, Lethariel's faces east, and Kezamba's north.
The orc forecourt's eastern fighting platform rules out the usual eastern
candidate; its western side is shown instead. The resulting waystone-to-spot
straight distances are 30.4–41.0 nodes in five capitals and 55.9 in Kezamba.
Guild houses are district plots whose positions depend on the world seed;
this study cannot claim the new locations are always closer than the guild.

Recommendation: a clearly marked outdoor registrar is easier to notice than
one behind an indoor counter. If short access from the waystone is the main
objective, prefer a site on the **approach to the waystone plaza**, outside the
reserved open arrival pad, especially in Lethariel and Kezamba. If the royal
entrance is preferred for visual identity, the six R marks provide concrete
alternatives for review. No new table, canopy or NPC has been installed.

The current registrar claims `miners_guild/miners_guild_clerk` through
`grug_core.assign_service_socket` in `grug_expeditions/registrar.lua`. Relocation
requires a new dedicated core socket and reassignment, and a decision about
whether the former clerk returns. Its dialog/session checks use the live NPC's
position and 8-node talking reach. Keep the existing Expedition dialog logic
from main when integrating; Claude is editing it concurrently. Future geometry
or core/socket changes are world-generation changes and ordinarily require a
map reset under the project rules. That is not the classification of this
read-only design study.

## Rebuild

```sh
luajit tools/r70_design/export.lua blueprints tools/capital_polish_study/castle/cores.json
python3 tools/capital_polish_study/castle/build.py
python3 tools/capital_polish_study/castle/maps.py
node tools/character_creation_preview/render-scenes.mjs --directory tools/capital_polish_study/castle --width 1280 --height 900
```

Render receipts include PNG/input hashes; no missing nodes, meshes or textures.
Original and revised pillar views were visually inspected. Media retains the
owning mods' licences; no new external artwork. Main remains untouched.
