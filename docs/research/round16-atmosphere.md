# Round 16 atmosphere, audio and density handoff

Implementer: native Sol. Source commit `681f0943`; tree
`fac20db3219fe6c1052ed4fba3d1a3f4094783ba`. Independent review and final integrated
evidence are recorded in the completion record.

## Behavior

- The shared 04:30–19:30 day phase runs at speed 60, giving 15 real minutes.
  The remaining nine game hours run at speed 108, giving five real minutes.
  Smooth dawn/dusk remain inside those phases. Shutdown restores the original
  `time_speed`; the clock is the game's server-side rule, not a new setting.
- A 0.30 minimum sunlight ratio improves night visibility. It does not create
  light where both node-light banks are dark. Cave Draught's 0.45 ratio uses the
  same owner; brighter natural light wins. Expiry/death clears the temporary
  override, while leave cleanup belongs solely to the atmosphere owner.
- Three Lord of the Test eating samples play with gain 0.5. The VoxeLibre drink
  sound uses its default gain. Both play privately only after successful item
  consumption. Exact pinned sources, authors, licenses and hashes are recorded
  in the food and alchemy `LICENSE-media.md` files. Audio bytes are unchanged.
- Ordinary fightable surface rows, including neutral huntable wildlife, divide
  spawn chance by 1.3 and multiply integer caps by 1.3 with nearest rounding.
  Existing night multipliers apply afterward. Critters, NPCs, bosses, dedicated
  rares, authored guards/adds and underground rows remain unchanged. No species
  or zone distribution changes and no PERF campaign.

## Author validation and limits

Author reports passing LuaJIT runs for `tools/r16_atmosphere/portable.lua`, the
updated 24-route food/HUD fixture, WP13 atmosphere (14 presets/10 moods), and
actual clock/start/night/zero-asset mob registration fixtures. These are bounded
consumer checks; root's final retained evidence independently runs the portable
fixtures against the integrated source. No per-lane PUC runtime was run.

All eight changed/new Lua files passed the plain-5.1 parser. The only owning
top-level global write is `grug_food`; source sweeps and diff whitespace checks
are reported clean. Imported eating samples are mono (first sample 0.624036 s);
the drinking sample is mono, 0.5 s. File hashes are in the media ledgers.

Real client brightness, audible volume and perceived population remain GUI
playtest judgments. The clock actively owns `time_speed` during server runtime.
No world generation or personal Luanti deployment was performed by the author.
