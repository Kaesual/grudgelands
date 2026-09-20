# Integrated development evidence

Source checkpoint `9a5afb48`: reviewed EQUIP/GAME/WORLD/ART/CAP/FARM and initial
CLOSE documentation. One LuaJIT-only run of the new integrated tail passed;
`composition_tail.lua` is copied exactly from the integration section of the
final runner with its repository argument header. It is not the final PUC pair.
Full WORLD/MAP-B and engine acceptance remain pending.

`gear.tsv` was produced by the real gear registration helper on the integrated
ART catalog. `gear-bindings.png` uses `render_gear_bindings.py` and those current
textures; `gear-inputs.sha256` binds the source inputs. This replaces the CAP
candidate's old armor contact sheet for visual binding only; no mesh, clearance,
layout or runtime change was made. Root visually inspected the new bronze chest.
The contact sheet is not an engine wielditem screenshot.
