# Round 18 J — Pickaxe and shovel material semantics

Date: 2026-09-23

Implementation model: native Sol

Branch: `wp18-tools`

Base: `386f6216`

## Result

Loose dirt, dirt surfaces, gravel, all three sands, ash ground, crop soil and
wet crop soil carry the dedicated `grug_loose` group. The authored stable floor
uses `grug_farming:soil`, so it follows the same rule. Custom dirt/litter nodes
declare the group at registration; swamp mud deliberately does not.

All eight shovels now expose only `grug_loose` digging capability and consistent
`grug_shovel_tier` metadata. They therefore cannot dig stone, sandstone, coal,
ore, clay or snow through the former broad `crumbly` route. All eight picks
retain their cracky, resource, tier and depth capabilities and add a loose
capability whose registered times and `maxlevel` match the corresponding shovel
except for a 2× time multiplier. Matching `maxlevel` matters because Luanti
chooses the fastest group and applies its level-difference divisor before
returning the effective duration.

The existing lifetime normalization remains the sole lifetime authority:
Wood/Stone/bronze/iron/steel/silversteel/embersteel/abyssal steel remain
30/60/300/600/1000/1500/2000/3000 uses. Tool-only zero damage behavior remains
unchanged.

## Evidence

- `tools/r18_tools/fixture.lua` loads the production registry, mining,
  overrides, tool registration and lifetime modules into an engine-shaped final
  registry. Its `core.get_dig_params` implements the inspected Luanti
  `src/tool.cpp` fastest-capability, level-difference and wear semantics.
- LuaJIT result:
  `r18-tools: wood=30,stone=60,bronze=300,iron=600,steel=1000,silversteel=1500,embersteel=2000,abyssal_steel=3000 loose=shovel/pick2x solids=denied depth=denied harvest=shatter stack=override`
- The matrix covers all eight tool rungs against dirt, gravel, sand, ash,
  crop soil and wet crop soil; rejects stone, sandstone, coal and iron ore for
  every shovel; checks final lifetime metadata; verifies stack capability
  override authority; and exercises depth denial and under-tier harvest shatter.
- Plain Lua 5.1 parser passed for every changed Lua file. `SETGLOBAL` inspection
  found no writes in production modules; the fixture intentionally installs
  only its isolated mock `core`, `vector` and `grug_materials` globals.
- All five repository conformance sweeps passed. Reported matches were existing
  comments, strings, historical manifests and documentation examples, with no
  prohibited syntax or calls in changed files.
- No PUC runtime was run; root owns the frozen integration micro-KAT pair.

## Final Lua hashes

| File | SHA-256 |
| --- | --- |
| `mods/ITEMS/grug_materials/mining.lua` | `bb73e62856a92bfea2d19c5a3f74048f6347c4f4d1c1b649634900321302d1d3` |
| `mods/ITEMS/grug_materials/tools.lua` | `7bb6482c19f59ad62385482a9a11136a798e124333b33a597e136f1086b790a5` |
| `mods/ITEMS/grug_materials/overrides.lua` | `d2d43e88cf0a9a419bb2ef49cd45b584f976e925ed56da08ca7e13588471c005` |
| `mods/ITEMS/grug_nodes/init.lua` | `41075026b07776b51ec69f234faadb26d0891d8c8acfa666c8a3ffe883aa74d9` |
| `mods/ITEMS/grug_nodes/crop_soil.lua` | `3118aa70675209fc07a4bb5b9c5d0738fdf8b904e7b167585b0b9ba1edb89b20` |
| `tools/r18_tools/fixture.lua` | `78d329259bbb1964d6a0299eb772229b4a4e9a69d121a131eac7d3baafcc15b2` |

## Limits

This is a bounded registration/capability fixture, not a native client dig or
GUI run. It does not retune broad tool speed, recipes, resource depth policy or
repair behavior. Root performs independent review and the final compact
cross-interpreter run; the user performs the eventual Luanti runtime pass.
