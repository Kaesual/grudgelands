# Round 11 FARM implementation evidence

Status: FARM implementation complete, **awaiting independent review**.
Implementer: native Sol, with the water/hoe base and initial ecology attempt
inherited from commits `e3469484` and `14cb3a14`; reviewer/calibration pending.
No PUC runtime by the user's explicit Round-11 override.

## Water/hoe slice

- Neutral `grug_core.world_alterable` consults installed zone territory and
  registered system guards; no empty-player bypass. Future Housing can register
  its reservation/claim guard; no Housing implementation is claimed.
- Water guard uses on_flood before non-air callbacks and liquid-transformed
  exact old-node restoration. One query/read/write maximum per transformed
  node plus fixed registered guards; no cache, queue or polling allocation.
  100 synthetic boundaries ×16 nodes ×10 cycles require exactly16000 restores.
- Engine contracts read: `reference_projects/luanti/doc/lua_api.md:6774,11009`,
  `src/servermap.cpp:1172,1246`, `src/serverenvironment.cpp:654`,
  `src/script/lua_api/l_env.cpp:171,231`. swap_node preserves metadata and uses
  ordinary node/light updates; no direct destruction/drop callbacks. Real engine
  lifecycle/flow remains an integrated targeted check, not proven by mocks.
- Buckets exchange the one wielded stack directly (stackmax1), needing no extra
  inventory space. Only actual ordinary/river source nodes fill; family metadata
  survives in the filled item. Invalid family/failed write/unloaded/protected/
  unreachable interactions leave the stack unchanged. No Creative duplication
  exception. Recipe reads pinned VoxeLibre mcl_buckets/init.lua:34-41.
- Hoes: `grug_farming:hoe` = Wooden Hoe, plus `hoe_bronze`, `hoe_iron`,
  `hoe_steel`, `hoe_silversteel`, `hoe_embersteel`, `hoe_abyssal_steel`. Budgets
 64/128/192/256/384/512/768. `_grug_hoe_uses` is the repair/tool budget; integer
 `_grug_wear_remainder` stores fractional wear without premature destruction.
 A repaired wear=0 resets this remainder on next use. Wear65535 means broken;
 operation refuses but stack/metadata remain. Two mirrored reference layouts.
- ART still owns material palette completion/seed silhouettes; imported hoe and
  bucket sprites are unchanged licensed reference copies with local ledger.
  FARM supplies material-specific hoe palette modifiers and consumes ART's pure
  `seed_visuals.lua` map after integration.

## Ecology slice

- The renewable inventory is exactly 27 sources: all 14 WP40 plant rows except
  Salt Crust, all 11 P9G gathering rows except Rock Salt, plus the existing
  Apple and Blueberry source nodes. The six cultural wood/material rows and all
  ores/minerals remain outside ecology. Apple/Blueberry are reused template
  fruit identities rather than independent density-hash rows, so their initial
  template populations are unchanged.
- `wp40/habitat_registry.lua` is the pure shared authority for renewable
  membership, doubled initial denominators and runtime host/zone matching.
  Both mapgen writers and runtime ecology consume it. The 14 WP40 and 11 P9G
  denominators double; Salt Crust and Rock Salt retain their exact values.
- The inherited `14cb3a14` aggregate `ecology_at` bridge was replaced because it
  duplicated policy at the runtime boundary. `zones.lua` now publishes only
  direct read-only delegates for static exclusions, housing masks, functional
  surfaces and hard rows; `r7_loader` exposes the actual
  `build_authority().planner_source` object.
- Generated and loaded natural identities form the exact baseline. Dig callbacks
  create debt immediately; the same bounded scheduler reconciles replacement or
  destruction without a callback. It never infers absence from unseen terrain.
  Persisted baseline identities survive reload, while zero debt/due values are
  omitted. Player-placed sources and changed/farmed/player-placed support do not
  qualify.
- One 10-second global pass deduplicates visible 64x64 cells through a coordinate
  index and caps work at 8 cells, 64 candidates, 384 node reads and 2 placements,
  independent of player count. `get_node_or_nil` is the only runtime node access;
  unloaded candidates defer and nothing requests emergence.

## Targeted evidence

`tools/r11_farm/evidence/` holds parser/SETGLOBAL/five sweeps, water transactions
plus repeated boundary cost, seven exact hoe lifetimes, the retained 17-crop
lifecycle KAT and ecology output. The ecology KAT covers the 27-source inventory,
exact baseline/reload, dig and non-dig debt, first delay, protected refusal,
retry and the global limits with 100 synthetic players. The focused WP40 R7
unit gate and LuaJIT micro-KAT exercise the real planner constructor and manifest
consumer; the micro-KAT now calls all four geometry delegates. Only expected
top-level mod globals remain; sweep hits are comments/strings. Runtime commands
use `chrt --idle 0 ionice -c3 luajit`; each is well under 1 second.
No broad census, seed population, fallback PUC or personal-world mutation.
