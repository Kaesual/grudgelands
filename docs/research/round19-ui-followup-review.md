PASS

Reviewed the uncommitted `fix/r19-map-window-consistency` diff against `main` for `mods/PLAYER/grug_map/page.lua` and `docs/design/world_map.md`, with the relevant Luanti formspec parser and shared `grug_inventory.UI` geometry as references.

- `formspec_version[4]size[10.4,11.1]real_coordinates[false]` makes the initial sizing calculation use the same legacy coordinate mode and exact shared dimensions as normal inventory tabs. The later `real_coordinates[true]` occurs in page content after sfinv navigation, so it changes only subsequent map elements.
- `PAGE_W = 13.5` and `PAGE_H ~= 13.6731` correctly reproduce the engine's legacy outer rectangle in image-size units: padding, 5/4 and 15/13 spacing, final slot extent, and button allowance all match `guiFormSpecMenu.cpp`.
- The derived map is exactly 9:8 (`12.37 x 10.9956`), centered with the reserved vertical-scrollbar gutter. Its scrollbars and optional Home button remain inside the shared outer rectangle.
- Map projection and marker positions still use the same derived `MAP_W`/`MAP_H`; constant marker sizes, nested clipping, zoom-center preservation, scroll clamping, focus handling, polling, and session lifecycle are unchanged.
- The design text accurately states the implemented shared-window and aspect-preserving behavior. Scope is limited to the requested correction.

No actionable defects found. Per review instructions, I did not edit repository files, run tests, or require a resolution matrix; GUI acceptance remains the user gate.

## Talent presentation follow-up — PASS

Reviewed the final `mods/PLAYER/grug_classes/talents_ui.lua` and `docs/design/skill_trees.md` worktree diff against `main`, including Luanti's `hypertext[]` parser/renderer and markup documentation.

- Available talents remain the same named purchase buttons and therefore retain the existing first-click route and authoritative server checks. Their unselected style now has the requested local green background and native border; the selected branch still delegates to the shared gold selection style.
- Locked and maximum-rank entries are rendered as dark inset tiles containing an unnamed `hypertext[]`. There is no `<action>` tag, so the engine has no clickable action to submit; the purchase field names are absent from these states.
- `<global margin=0 halign=center valign=middle>` is valid engine markup and matches forms used by Luanti itself. The engine applies `halign` to the root text style and `valign` to the whole text block as intended.
- The markup is correctly formspec-escaped. The interpolated label is derived solely from the closed, authored talent catalogue plus fixed rank/status text; the current catalogue contains no hypertext control characters (`<`, `>`, or backslash), so it cannot alter markup. Introducing general hypertext escaping for hypothetical future catalogue content is outside this bounded presentation correction.
- Tooltip construction and all selection, spend, rank, respec, tree, refresh, and authorization logic are unchanged. The living design paragraph accurately records presentation-only behavior and does not introduce unrelated design changes.

No actionable defects found. Per review instructions, I did not run tests or edit repository files.
