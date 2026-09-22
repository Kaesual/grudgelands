# Round 16 F independent review

## Verdict

**CLEAN — no Critical, High, Medium or Low correctness findings.**
Reviewed commit `681f0943e029889152dc39d1bf3034a7d4b513da`, tree
`fac20db3219fe6c1052ed4fba3d1a3f4094783ba`, against base `1b2f0458`
in `/tmp/grug-r16-atmosphere`. No production files were edited.

## Verified scope

- The 0.1875–0.8125 day phase spans 15 virtual hours: speed 60 gives 900 real
  seconds. Its complementary nine hours at speed 108 give 300 seconds. The
  existing mob clock shares the phase boundaries. The one-second accumulator
  updates the live clock without setting/jumping time; bounded phase-edge
  polling and the engine's five-second client clock packet interval mean the
  15/5 durations are a target, not subsecond timing precision. Pinned engine
  `src/environment.cpp:281-308` and `src/server.cpp:697-709` substantiate both
  speed units and the live setting read. Shutdown restores the original setting.
- The lighting owner composes the natural ratio, exterior floor 0.30 and Cave
  Draught floor 0.45; it releases the override when natural light is brighter.
  `src/script/lua_api/l_util.cpp:657-665` returns the normalized natural ratio;
  `l_object.cpp:2727-2747` accepts a ratio or nil. The API sunlight-only contract
  (`doc/lua_api.md:9553-9557`) supports retaining darkness where sunlight is
  absent; no global cave ambient light is introduced. Actual client appearance
  remains a GUI acceptance check. The ratio cache prevents unchanged packets.
- Cave Draught refresh/expiry and death use the shared owner. Core atmosphere
  alone clears its name-indexed ratio/effect state on leave; alchemy no longer
  calls the setter after that cleanup. Status replacement does not run the old
  expiration callback (`grug_core/status.lua:151-156`), so refresh cannot erase
  the newly installed effect. Current leave/death status cleanup was inspected.
- Food changes only add audio after successful status installation and item
  consumption. Refused food and potion paths remain silent. Drinking occurs in
  the common successful potion/elixir consumption helper. The binding plan
  specifies gain 0.5 for eating only; normal drinking gain is compliant (also
  confirmed by the coordinator). Engine sound spec/ephemeral call contracts
  were checked in `l_server.cpp:506-521`.
- All four imported OGG files were independently compared byte-for-byte with
  the pinned references and their SHA-256 ledger entries. Lord of the Test
  `f164140154945f0b356521ae721a86e9c7a0e0cf` stamina README credits
  sonictechtonic/recording 242215, CC BY 3.0; VoxeLibre
  `c2dbc520ff4e1637072d33b06c3a2404e0f08df7` mcl_potions README licenses sounds
  CC0. Per-mod ledgers provide source, author, license and unchanged-byte status.
- Ambient density is applied once in the existing central spawn-row wrapper:
  chance divided by 1.3, cap multiplied by 1.3 with integer rounding. Existing
  night-cap treatment remains afterward. Normal/elite fightable surface rows
  and huntable animals qualify; critters and NPCs do not. Current underground
  registrations (including the second Giant Rat row, spiders, golems, miners,
  Glowwing and bats) return before density adjustment. Named rares, authored
  guards, kings/dragons and encounter/summoned adds retain their dedicated spawn
  paths and counts. No distribution table, AI budget or benchmark campaign was
  introduced. Approximate realized population remains dependent on local caps
  and activity, as the approved design explicitly allows.

## Evidence and limits

Inspected the full production/documentation diff and relevant callers; read the
Round 16 F contract, workflow full review checklist and interpreter strategy.
Reviewed the callable `tools/r16_atmosphere/portable.lua`, the real food/status
fixture `tools/r16_ui/food_hud.lua`, the atmosphere regression changes and the
WP40 stub-only compatibility adjustment. The author's handoff reports passing
LuaJIT runs for those first three applicable fixtures and
`tools/r8_mob1/{clock_policy_kat,start_zone_kat,night_families_kat,zero_asset_kat}.lua`,
plus changed-file PUC parser/SETGLOBAL and all five source sweeps. The author
retained no transient execution logs; this review therefore distinguishes the
inspected immutable fixture sources and independently checked asset bytes from
execution success reported by the author. No duplicate suite or new runtime
was run by the reviewer. Final combined frozen PUC/LuaJIT evidence and native
integration remain the coordinator's pending gates; this report does not
certify those future executions.

No PUC runtime, world run, timing run, PERF campaign, production edit or commit
was performed in this review.

## Independence and calibration

Implementer: native GPT-5.6 Sol. Reviewer: native GPT-6 Astra, independent of all
F changes (the reviewer authored B combat only, which is excluded here).
Classification: non-trivial gameplay/engine integration. Critical/High: 0/0;
Medium/Low: 0/0. Fix rounds: 0. Elapsed review time: not instrumented.

User runtime plan: observe dawn/dusk and exterior night versus an enclosed cave;
drink and refresh Cave Draught, then expire/die/reconnect; verify eating volume
and silence on rejected consumption; check ordinary wildlife presence while
critters and authored encounters retain their prior counts.
