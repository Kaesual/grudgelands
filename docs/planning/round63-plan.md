# Round 63 — fortified mining camps and faction heraldry

Initial user authorization, 2026-10-26: implement the accepted browser
proposal, sync to local Luanti, **do not commit before the user's in-game
review**. After the reported GUI issue and its correction below, the user
explicitly authorized **committing all changes, without pushing** on the
same day; this supersedes the earlier hold.
Production remains 0.55.1. Version 0.63.0 needs a **map reset**, already
planned with the pending rounds; no migration step, no production action.

## Scope

- Twelve templates cover six race palettes and two sizes, shared by the 20
  guild mining camps and 16 Battlegrounds mining camps.
- Capital guild-house headframes, muted canvas tents, timber fortification
  on stone plinths, attached faction banners, and inventory faction icons.
- Preserve garrison, raid, quest and vendor roles and stable socket IDs.
  Rotate surface lift columns and underground rooms together.
- Keep the existing browser viewer/editor. Art is generated offline; the
  game loads ordinary templates, nodes, B3D meshes and PNG textures.
- One functional adjustment to the visual proposal: remove the short rail
  directly in front of the lift and replace its grille floor with a full
  timber block, satisfying the travel module's safe-arrival contract.
- The large camp keeps the commander's five-node distance through its
  mirrored yard marker; the west tower guard faces the open lane.

## Reproduction

From the repository root:

```sh
python3 tools/r63_camp_art/build.py --check
python3 tools/r63_camps/build_templates.py --check
```

Omit `--check` to regenerate. Art generation needs Python with Pillow and
ImageMagick `convert` with SVG support; template generation uses the existing
viewer/editor modules and LuaJIT. Neither runs in the shipped game.

## Validation

Independent production review completed without remaining findings. Verified
against the pinned engine's B3D loader: supported chunk hierarchy, material
buffers, index offsets, bone weights, direct UVs and per-side normals.

Completed checks:

- All 281 portable fixtures: initial full run 278 pass / 3 fail; the three
  failures (old node-registration mock, commander spacing, tower facing)
  were fixed and passed targeted reruns. Related farm/mailbox mocks and the
  new 72-combination reachability fixture also pass.
- Template gate: 278 templates, six layouts, six rosters, no errors. Its
  23 warnings include twelve camp templates selected by code instead of a
  town layout and eleven existing template warnings.
- Template validator self-test passes; viewer template tests: 56 checks;
  editor tests: 644 checks, all pass.
- Lua 5.1 parser and all six sweeps; asset and template reproducibility;
  release-mode source audit; upgrade declaration against origin/main pass.

Final isolated Luanti boot passed (240 seconds). Local sync completed and
changed runtime files were verified byte-for-byte; no world was changed.
The full seed fleet passed **304 of 304 seeds**, zero failures (35 min 26 s,
with the worker count adjusted as other checks finished). All 32 seeds that started before the final
actor-marker fixes passed a targeted rerun. The final byte-order comparator
was independently reviewed and proved to preserve every palette and cell in
all 72 combinations under the fleet's C locale; its fixture and Lua gates
pass. The corrected file was synced to local Luanti.

The full game-data validator passes with zero errors (17 existing advisory
warnings); the economy price check and ridden-mesh reproduction check pass.
All technical gates for this change are complete. The user has authorized
the local commit; pushing remains prohibited.
GUI acceptance remains the user's.

## GUI correction — mesh units and transparent heraldry (2026-10-26)

The user's in-game screenshot exposed an export bug missed by the headless
and structural checks: canvas and banners were one tenth of their intended
size, while node boxes were correct. Animated B3D node meshes use ten engine
units per node (`reference_projects/luanti/doc/lua_api.md`, node `mesh` field;
`src/client/node_visuals.cpp`, `NodeVisuals::updateMesh`); the exporter had
written node-space coordinates directly.

The art exporter now multiplies vertex positions by ten, preserving normals,
UVs, bone rest transforms and the node-space selection/collision boxes. Its
validation checks independent expected engine-space bounds and was verified
to reject both old meshes. ImageMagick's default white SVG background was
also replaced with transparency; both faction banners and both inventory
icons now assert transparent corners and an alpha range of 0–255.

Asset regeneration, reproducibility, the 18-node fixture and independent
review pass. This is a **compatible art correction** within
0.63.0: no placement or saved-state change, no additional map reset. Local
Luanti receives the corrected assets; restart the local game to reload them
in existing camps. The original Round 63 generation change still requires
the previously declared map reset.

## GUI checklist

Use a newly generated test world (or the existing map-reset workflow).
Existing generated camps do not change merely by copying game files.

- Inspect a camp for each faction, including a large Battlegrounds camp:
  canvas slopes, race materials, timber walls, gate, headframe and towers.
- Check banner orientation and the metal-to-cloth attachment from both sides.
- Walk through the gate, reach the vendor and foreman, and open their dialogs.
- Travel down the mining lift and return safely to the timber deck.
- Check camp guards/captain and an applicable camp quest place.
- Open the inventory for each faction and inspect the top-left heraldry.
- Repeat visual/interaction checks on desktop and web before release.

Commit authorized by the user on 2026-10-26; **do not push**. Full desktop
and web GUI acceptance is not recorded by this commit authorization.
