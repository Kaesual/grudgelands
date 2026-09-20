# Independent Round 11 engine-probe review

Reviewer: native GPT-5.6 Sol (`/root/r11_farm_review`), independent of fixture authoring.\
Reviewed fixture commit: `bb166bf5` in integration checkout `/home/jan/projects/grudgelands` (current checkout head also contains the later reviewed SPEC merge).\
Disposition: **CLEAN for deferred execution after SCOUT and REPAIR integration**.

## Static review result

No blocking fixture defect was found.

- The probe is a disposable mod staged only through `tools/luanti_headless.sh`. That launcher copies the checkout into a newly created `/tmp/grudgelands-headless.*` tree, sets isolated Luanti/XDG paths, binds loopback with announcements disabled, writes only inside the scratch world, and deletes the new run directory by default. The fixture itself writes its receipt through `core.safe_file_write(core.get_worldpath() .. "/r11-integration.txt", ...)`; it has no path to the user's GUI world.
- The fixture disables the six-start preload through the existing late-bound `grug_core.request_starts_preload` seam. It requests one exactly aligned 16×16×16 VoxelManip area at y=9008..9023, writes a synthetic stone block, and edits four short channels. This may generate that one scratch mapblock when absent, but it does not request a landscape, population, seed fleet, `emerge_area`, broad scan, or user-world generation.
- `assert(jit and jit.version)` fails closed if the Flatpak server is not using LuaJIT. The fixture invokes no PUC interpreter or external process.
- The liquid geometry covers four independent channels: ordinary water and river water each flow toward one allowed floodable plant and one protected target. The protected targets alternate between air and a floodable plant carrying param2/metadata. This reaches the two distinct pinned engine boundaries: `on_flood` runs before mutation only for non-air floodable nodes (`servermap.cpp:1172-1175`), while changed air is reported after mutation through `register_on_liquid_transformed` (`servermap.cpp:1246`; `lua_api.md:6774-6779`). Final assertions require protected air restoration, protected plant name/param2/metadata preservation, and ordinary/river control flow. Callback counters establish that the native boundaries actually fired.
- The probe node is registered before `register_on_mods_loaded`, so FARM's water guard can wrap its real `on_flood` callback. The probe's own liquid-transformed observer is additive and does not replace the product callback.
- Catalog checks load the integrated `seed_visuals.lua`, require every one of its exactly 17 entries to match a registered seed's real `inventory_image`, require both bucket items, count exactly seven registered `_grug_hoe_uses` tools, and require each hoe to resolve through the REPAIR purchase-price seam. It also requires the registered Scout class. The declared dependencies intentionally defer execution until the SCOUT and REPAIR packages exist.
- `tools/bin/luac51 -p` accepts the fixture source; `git diff --check bb166bf5^..bb166bf5` passes. Reference submodule pins are exact.

## Execution boundary

Per instruction, the probe was **not run**. Its eventual invocation should use `PROBE=tools/r11_integration/engine_probe tools/luanti_headless.sh ...` only after accepted SCOUT and REPAIR bytes are present, then require both the `[R11_INTEGRATION] COMPLETE` log marker and the scratch-world `R11_INTEGRATION_PASS` receipt. No PUC runtime or broad mapgen run belongs to this gate.

No repository edits or commits were made by the reviewer.
