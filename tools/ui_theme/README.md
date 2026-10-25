# UI theme and real-client fidelity review

`build.py` regenerates the original geometric theme textures; `--check` checks
byte identity. See the [presentation contract](../../docs/technical/ui-presentation.md)
and the mod's media licence. Pillow/zlib versions affect exact PNG encoding.

`capture.sh OUT_DIR` captures 16 real-client views: Inventory, Achievements,
Talents, Crafting, chest, quest giver, Map & Quests and all 13 permitted tabs,
each on a controlled dark stone/night and bright snow/day scene. The probe
only enters a disposable staged game/world. It uses the real creation and
formspec routes, a real quest definition with an NPC position stand-in, a
level-30 character and a learned profession. It does not edit production data.

Run through the workstation's shared Lua queue, reserving two slots. Set
`XVFB` to the available Xvfb binary and optionally `WIDTH`, `HEIGHT`,
`GUI_SCALE`, `SETTLE`, `SEED`. `CAPTURE_REPO` selects an immutable baseline
archive; the probe remains the current one for identical scenarios. The
launcher uses private `/tmp` user/config/world paths, `LC_ALL=C LANG=C`, and
cleans only its own client, server and Xvfb. It never uses the personal
Luanti folder. `check_capture.py OUT_DIR` rejects missing/blank images.

Capture `before-small`, `before-large`, `before-scale15` and corresponding
`after-*` directories (1035×696 GUI 1, 1920×1080 GUI 1, 1035×696 GUI 1.5).
Copy the matching Atlas 03 originals into an `atlas/` sibling, then run
`python3 tools/ui_theme/contact_sheets.py REVIEW_ROOT`. It produces eight
full-frame Atlas/before/after sheets and a local `index.html` linking the
unretouched full-resolution originals. Images are fitted, never cropped or
painted. Content/scene differences from the illustrative Atlas are explicit.

This checks desktop rendering at the selected sizes. Native interaction,
other characters/data, translations, and the actual web client remain on the
user's GUI acceptance checklist. Failed intermediate captures are receipts,
not accepted comparison images.
