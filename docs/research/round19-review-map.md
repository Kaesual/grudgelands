# Round 19 A — Independent atlas review

Verdict: **PASS for lane A source/contract review; final integrated technical gates and user GUI acceptance remain pending.** No verified Critical, High, Medium or Low findings.

Review snapshot: `/tmp/grug-r19-review-map`, commit `c9e8c95c`, baseline `3b23a8f8`; atlas author commit `15d86299`. Read-only review; no production changes. Reference symlinks were read only, not staged. The snapshot's ordinary `git status` cannot traverse its intentionally symlinked reference submodules; scoped commit diff/read operations remain available.

Calibration: implementing model GPT-6 Astra; independent reviewing model GPT-6 Astra; initial findings 0 Critical / 0 High / 0 Medium / 0 Low; fix rounds 0; observed elapsed wall time unknown. Reviewer authored none of the reviewed implementation.

## Verified boundaries

- Read the approved full Round 19 contract, map living specification, lane report, project instructions, model policy, workflow technical checklist and Lua language/test requirements. Scope is A only; other lanes and integrated documentation drift are not certified here.
- `mods/PLAYER/grug_map/atlas.lua:17` and `page.lua:199`: integer scroll range `(zoom-1)*1000` and `(scroll+500)*new/old-500` preserve viewport world center before edge clamps. Only 1/2/4 stops can be reached. Existing inclusive world bounds and north-up projection remain unchanged.
- `page.lua:65` uses the entire 9:8 viewport. `page.lua:148` selects formspec v4 and real-coordinate wrapper sizing; the engine defaults to real coordinates for v2+ before calculating form size (`reference_projects/luanti/src/gui/guiFormSpecMenu.cpp:3295`). No retained legacy-size multiplier adds an unused band.
- `page.lua:73` nests a full-scaled-width vertical clipper under the viewport-width horizontal clipper. The engine creates distinct clipper/mover parents and applies negative displacement from the specified factors (`guiFormSpecMenu.cpp:341`, `guiScrollContainer.cpp:113`). The full inner width continues to cover the viewport at maximum horizontal displacement. Explicit ranges allow all four corners at each zoom.
- All marker buttons share both clipping ancestors; their sizes are literal fixed dimensions. Navigation, selected details, Home and scrollbars are outside both containers. Button/image-button clipping defaults and `reference_projects/luanti/irr/include/IGUIElement.h:237,263,745,836` make hit testing respect ancestor clipping; no off-canvas marker hitbox is deliberately left over controls.
- `page.lua:136` forces focus to an external scrollbar. Engine `parseSetFocus` honors forced focus for new inventory-form strings (`guiFormSpecMenu.cpp:2903,3629`); autoScroll follows only focused descendants (`:3936`). Ordinary rebuilds therefore do not auto-center an old focused marker.
- `page.lua:179` validates complete CHG/VAL strings and clamps values before button actions. Engine field serialization matches these formats (`guiFormSpecMenu.cpp:4296`). Scroll input does not render or overwrite the last-sent semantic signature. `page.lua:133,222` excludes scroll/focus from that signature, defers during CHG activity, and sends pending real marker/heading changes afterward.
- `page.lua:154,194,208` resets only page entry and uses the no-transition sfinv refresh for Home, zoom and detail. Actual sfinv implementation (`mods/BASE/sfinv/api.lua:124,130`) confirms the distinction. Close/death return to Character; leave removes active polling. There is no saved zoom/scroll migration or broad inventory polling.
- Marker identity/provider ordering and current authorization remain unchanged. Unknown marker fields have no effect; a recognized click triggers fresh collection and clears a vanished selected marker. Home uses `grug_home.return_home`, whose unchanged request path revalidates current binding, life/combat/cooldown, faction/race and pending request state at settlement (`mods/PLAYER/grug_home/travel.lua:48,69,107`). No submitted marker or scroll field can choose a travel destination.
- World PNG is 2700x2400 RGBA. The documented reproduction uses the existing authored-geometry SVG renderer and rasterization, not runtime world or terrain generation. Old regional PNGs and regional page controls are removed.

## Evidence and limits

One authorized bounded LuaJIT fixture was run:

`luajit -e 'print(dofile("tools/r19_map/micro.lua")("."))'`

Output: `r19_map: whole-world, projection, center-zoom, clipping-structure, fixed-markers, scroll-signature, lifecycle PASS`.

The fixture loads both changed production modules and checks the principal arithmetic/session/event regressions, including unsent movement surviving CHG. It stubs sfinv/core and does not certify client pixels. The engine contracts above were independently read from the pinned references. No reviewer PUC runtime, native engine run or performance run was performed. The author reports parser/SETGLOBAL/five-sweep success; the coordinator still owns inspection and execution of final integrated static gates and the one frozen PUC/LuaJIT pair.

Reviewed SHA-256:

- atlas.lua: `bacfd5d1c13f2ea273087cf4f6a0d14717bdb6905afd7bde687feef1505037a3`
- page.lua: `58f839165f37eb57dde188b231b7ad8d7972e2c14e027d41e57a314993dcf306`
- world PNG: `e32c60e1069cfdbbcdad4d99cac00313c1863355f03b863a8bc9c3ce3d87f6a6`
- map micro fixture: `ff59a2c88d000bdf4ba7ba98af993ce7b412c7a48c6add97ff8cd4185a570af5`

User runtime plan: at normal and smaller window sizes, verify full overview fit, all four corners at 2x/4x, fixed-size markers/tooltips, no clipped-marker interception of controls, center-preserving zoom, Home/detail/live updates retaining position, and close/reentry reset. Include a sustained moving scrollbar drag and a stationary held thumb while another party marker moves. The latter can still overlap a later client widget replacement after the quiet interval; this documented native-GUI acceptance case is not claimed proven by the offline fixture.
