# Round 11 FARM implementation evidence

Status: water/hoe slice implemented, **awaiting independent review and ecology**.
Implementer: root native Astra. Base `16b7449c`; reviewer and calibration pending.
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

## Targeted evidence

`tools/r11_farm/evidence/` holds parser/SETGLOBAL/five sweeps, water transactions
plus repeated boundary cost, seven exact hoe lifetimes and the retained17-crop
lifecycle KAT. Only expected top-level mod globals; sweeps empty. Inputs bound
in `water-hoe-inputs.sha256`; later ecology changes replace affected evidence.
Runtime commands use `chrt --idle 0 ionice -c3 luajit`; each is well under1sec.
No broad census, seed population, fallback PUC or personal-world mutation.
