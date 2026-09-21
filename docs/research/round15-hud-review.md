# Round 15 HUD independent review

Date: 2026-09-21. Reviewer: native Astra, independent of the HUD implementation.
Candidate: `146c551fb6d24cf510f9abf5b6f6a06654f70bb8` (source implementation
`75370cc7`). Scope: all five production files and `tools/r15_hud` consumers,
figures, fixture and evidence. The reviewer authored POI composition, not HUD.

Decision: **PASS after focused correction**. The original Medium R15-HUD-1
finding below is resolved. No open Critical, High or Medium findings remain
within this lane. Final interpreter/native gates and GUI acceptance remain
with the coordinator and user.

## Findings

### Resolved Medium R15-HUD-1 — text and HUD geometry incorrectly shared one scaling factor

Locations: `mods/CORE/grug_core/hud_layout.lua:243` and `:261`,
`mods/PLAYER/grug_parties/hud.lua:23`, and
`tools/r15_hud/render_layout.py:11` / `:24`.

The new responsive width calculation assumes nine **HUD units** per text
character, and the diagram scales its font and line height with HUD scaling.
Luanti actually scales HUD text with **GUI scaling** and display density:
`reference_projects/luanti/src/client/hud.cpp:391–403` obtains the default font;
`src/client/fontengine.cpp:259–261` multiplies font size by display density and
`gui_scaling`. HUD image dimensions and offsets instead use `hud_scaling` times
density (`src/client/hud.cpp:140–141`, `:423–424`, `:496–505`). Both independent
values are already available from `get_player_window_information`
(`src/script/lua_api/l_server.cpp:300–306`).

Concrete scenario: desktop 640×480, density 1, default GUI scaling 1 and default
Arimo font size 16, with HUD scaling 0.5 (the engine explicitly supports this
minimum). The ten-member party places its first label at y=166.5, but its HP
bar at y=175.5..178.5. The actual shipped Arimo-Regular 16px glyph bounds for
`* viewer  123/456` occupy y=169.5..181.5, so the bar crosses the label. The
nominal 18-unit text-to-bar gap became nine pixels while the text did not shrink.
The same wrong coupling allows up to 38 quest characters in this configuration
instead of estimating text width at its real GUI scale. Increasing GUI scaling
independently produces the converse underestimation even at HUD scaling 1.

This is not a demand to support arbitrarily small windows or custom fonts:
640×480 is an explicit acceptance case and 0.5 is a supported HUD setting. The
party's fixed spacing predates this patch, but the new responsive layout and
scaling acceptance leave that concrete readability failure unresolved. The new
side-width helper and evidence assume the same incorrect font scaling.

One targeted LuaJIT run of the **actual supplied fixture**, with
`{size={x=640,y=480}, real_hud_scaling=0.5, real_gui_scaling=1}`, returned PASS
and emitted `/tmp/r15-hud-review-half.tsv`, demonstrating that its current
centering/idle assertions miss the overlap. Font bounds above were measured
with Pillow against the checked-in Arimo font; engine scale authority is the
C++ cited above, not the schematic. No PUC or native engine process was run.

Required correction: distinguish GUI text scaling from HUD offset/image scaling
in responsive text widths and party text/row spacing. Keep the shared layout
owner and update existing rows on either relevant window-information change.
Add one unequal-GUI/HUD-scale case to the bounded fixture/diagram, rendering
fonts at GUI scale instead of HUD scale. This needs no new per-tick writes or
broad test suite. A focused source/evidence re-review is sufficient.

## Verified passing areas

- All six entries in `tools/r15_hud/evidence/sha256.txt` match the reviewed
  production/fixture bytes. Parser, SETGLOBAL and five-sweep logs were inspected;
  the only listed global write is the existing `grug_xp` table.
- Window lookup uses the correct player-name API, tolerates the documented nil
  result and rereads current window data through existing throttled refreshes.
  Text wrapping updates after a resize; unchanged party/quest fields are cached.
- Right alignment is genuinely per line and vertical centering uses the full
  multiline height (`src/client/hud.cpp:419–440`), not a left-aligned multiline
  block merely placed against the right edge. Saved toggle/empty-state consumers
  remain intact.
- Party row removal/recentering preserves membership order, offline labels and
  empty offline bars. One half-second refresh has no unchanged HUD writes after
  caches settle. The fixture drives real production consumers rather than
  reproducing their functions.
- XP uses the current level span, zero at the next-level boundary, a full bar at
  cap and a separately cached level label. The old numeric HUD line is removed;
  `/xp` remains exact. Zero-width images are explicitly skipped by
  `src/client/guiscalingfilter.cpp:160–162`, so a zero fill neither becomes full
  width nor divides by zero. Other shared rows retain their order and separation.
- Both actual OBJ meshes have y=-0.30..0.54. Empty-bone parenting uses the
  parent's visual node and attachment translation directly
  (`src/client/content_cao.cpp:1457–1470`); mesh scaling is applied at `:705`.
  Thus `24.84 + 5×0.54 = 27 + 0.54` fixes the upper extent and expands downward.
  The existing observer partitions, state precedence, lifecycle cleanup and
  shared visibility/hysteresis owner are unchanged.
- Current NPC visual scale is one. The real tag carrier copies the parent's
  selection box and attaches at zero (`mods/CORE/grug_core/tag_carrier.lua:152–161`),
  consistent with the documented 2.0-node name anchor and 2.334-node marker
  lower bound. Pixel-level name overlap at distance still requires GUI playtest;
  the implementation report correctly distinguishes this from geometry proof.

## Focused correction review

The reviewer inspected the frozen correction directly in the root checkout:
`hud_layout.lua` SHA256 `9d4149be4a08eb52b5090ddefead2a9da49c62c2d38d3c487773ac3c6655aee7`,
party HUD SHA256 `2024a9a97db563ce90280adf5a91d733a493331c3f274e0daa64f973ba92f546`,
and fixture SHA256 `6179422b73133ac29dcb0a4da57963ea39a2a8e797500afb3938d01f348788c0`.
All six current evidence hashes match. The focused diff correctly converts a
20-GUI-unit default-font slot into HUD coordinates using the GUI/HUD ratio,
keeps bar/gap dimensions in HUD units, and centers the complete block.
The current window snapshot reaches both newly created and existing rows.
Side wrapping reserves HUD-scaled geometry before dividing by GUI-scaled text
width. The change avoids replacing existing HUD IDs and retains compare-first
writes.

The strengthened actual-consumer fixture now checks physical text/bar clearance,
row separation, recentering, GUI-only/HUD-only changes and zero unchanged
packets. Its updated LuaJIT/static logs were inspected without another execution.
The reviewer also opened both regenerated unequal-scale diagrams. At the
original failing GUI1/HUD0.5 setting, the first text starts at y111.5 and its
bar at y131.5: the original collision is removed. The diagrams now load the
shipped Arimo font at GUI scale independently of HUD positions/images.

The corrected diagram exposes pre-existing overlap among the central combat
labels at extreme unequal scaling. The coordinator explicitly retains that
unchanged central-column behavior outside this focused correction; it is not
claimed as certified here. Arbitrary client-selected fonts and extremely small
viewports remain the documented GUI-playtest limitations. R15-HUD-1 is closed.

## Remaining gates

The coordinator owns final frozen PUC/LuaJIT parity and native integration;
neither was duplicated here. User runtime checks remain the three tracked
quests, full party, independent HUD/GUI scaling, resizing, XP gain/reset, and
both marker types near/far at racial quest givers.
