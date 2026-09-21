# Round 14 POI implementation record

Status: implementation evidence, corrected 2026-09-21. The living authorities
remain `docs/design/world_zones.md`, `docs/design/story.md` and
`docs/design/quests.md`.

The starter-story POI increment fills eighteen existing fixed anchors: the six
home villages (`anchor_013/015/017/019/021/023`), their first outposts
(`anchor_025/029/033/037/041/045`) and their inner bandit camps
(`anchor_049/051/053/055/057/059`). It does not add a placement system or move
an anchor. The existing R7 settlement successor supplies terrain fitting,
mapchunk clipping and authored road spurs. Existing functional root columns
retain their protection; there is no blanket protected POI envelope.

Following independent review, every authored cell, roof overhang and clearance
column stays inside the actual half-open flat terrain core: village/camp
x,z=-12..11 (24 by 24), outpost x,z=-8..7 (16 by 16). The larger fitting
apron is not treated as level ground. Villages have four small usable houses
around a three-node crossroad. Outposts have one watch house and four slender
corner watch posts. Cultural gable roofs alternate full-block and slab courses
without floating ridge gaps; corner timbers, glazed windows, side benches and
rear tables give the small houses readable structure. Watch posts now have
small timber platforms, corner supports and fence rails under shallow pitched
roofs. Their three-wide doorways leave access beside the reserved
central guard-banner root. Camps have four open shelters with roofs at y=3–4,
corner supports, connected stepped roof courses and clear entrances. A fifth canopy houses the captive socket
at (10,1,10), more than twelve nodes from the existing protected camp-fire
root. The root authority, grading and anchors are unchanged.

Six original `grug_mapgen:poi_display_<race>` definitions provide decorative
accents without harvest rewards: `diggable=false`, empty drop, no harvest
or resource groups, no inventory, no recipes and hidden creative entries.
They are registered synchronously before the R7 loader compiles palettes.
Ordinary structures and terrain keep the existing territory alteration rules.
These definitions reuse already shipped minetest_game textures (copper block,
brick, meselamp with the existing emberglass color modifier, stone brick,
desert cobble and clay). No assets or upstream code were imported; the existing
`mods/BASE/default/README.txt` attribution and `license.txt` media license and the emberglass texture provenance in
`mods/ITEMS/grug_materials/LICENSE-media.md` remain their attribution sources.

All three story sockets use role `quest`. NPC titles are not duplicated in
mapgen or mobs data. The placement engine looks up `settlement/socket` in
`grug_quests.npc_by_socket`, then reads the registered NPC title. Until the
quest catalog is active the existing cultural elder label remains a fallback.

Focused evidence lives in `tools/r14_poi/`. `poi_micro_kat.lua` loads all
eighteen adapters through real settlement preparation and the display
registrations. It checks exact footprint bounds, reserved root clearance,
reachable story sockets and house interiors with functional roots treated as
obstacles, captive radius and roof height. Its canonical checksum covers every
ordered cell name/coordinate/param2 and socket identity/position; this fixture
is suitable for the root's single final PUC/LuaJIT parity process. Corrected
LuaJIT development result: `r14_poi_v2 / 18 / 76032 / 1859979146`.
No intermediate PUC runtime was run. The final isolated native boot and POI
mapchunk emerge remain the real R7 manifest/planner consumer gate after the
story catalog is active. No inherited broad WP40 population is required.

`render_gallery.sh` regenerates six representative views with the standard
WP13 renderer and actual shipped textures. A temporary tile-index extension
reads the new display registrations directly; the shared renderer/index is
unchanged. These views omit the separately owned functional root nodes and
runtime NPCs. Independent focused re-review, root final interpreter parity,
native integration and the user's GUI test remain final acceptance gates.
