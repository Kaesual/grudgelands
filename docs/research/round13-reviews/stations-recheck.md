# Independent STATIONS fix re-review

2026-09-21. Reviewer: native GPT-6 Astra, independent of the correction author.
Final verdict: **approved; all three original findings are closed, no new findings**.
The coordinator's final native/restart evidence has been inspected.

Reviewed root working files frozen on parent commit
`93631dfd8c4034f8a949fa998032310411082d7d`, compared with STATIONS integration
commit `f99393ce40f23c487e99f0744b699e967469cf59`.
Production fix scope: `mods/PLAYER/grug_jobs/workspaces.lua`, `registry.lua`,
`stations.lua`. Original review: `/tmp/r13-stations-review-28ef4d85.md`.
Authority: root `docs/design/crafting_equipment_revision.md`, SHA-256
`352a8d74a8a699202c85e04e83ee4fc4f7ce157f25d4379cd996a1546a0d1a32`.

## Closure and engine contracts

- **Original High, shared output consumed after return to ingredients:** the
  allow-time receipt now freezes precisely the previously occupied ingredient
  slots and counts. The successful take debits that receipt, so a result newly
  inserted by the engine into an empty shared craft slot is not included.
  Partial remainder handling and once-only progress remain unchanged. Swaps
  that would put a foreign item back into output are still denied.
- **Original Medium, private data broadcast and idle writes:** owner records
  are marked private before the first set_string, with comparison before
  writing. The periodic evaluator saves only changed inventory/thermal/recipe
  state, not a clock-only idle change. Private names need not already exist:
  pinned `src/nodemetadata.cpp:73–84` and `src/script/lua_api/l_nodemeta.cpp:78–97`
  implement this directly. `src/nodemetadata.cpp:25–40` excludes those keys from
  network serialization while preserving them on disk. Current-version record
  persistence is retained without a migration path.
- **Original Medium, new inputs receive prior elapsed time:** every permitted
  personal automatic put/move/take settles the pre-edit inventory first. If
  settlement changes any inventory slot, the allow callback returns zero;
  the next action uses the settled inventory. State-only changes update the
  clock before a mutation can occur; the post-action save includes that clock.
  Closing/reopening still accounts only elapsed server game time.
- **Engine safety of settlement inside allow callbacks:** the pinned
  `src/inventorymanager.cpp:383–443` gates ordinary moves and swaps with these
  allow results and returns before actual movement at zero. The drop path
  likewise applies zero before calling item_OnDrop (`:721–757`). The
  evaluator writes existing fixed-size lists; `src/script/lua_api/l_inventory.cpp:215–233`
  forces the existing list size, `src/script/common/c_content.cpp:1548–1575`
  updates that existing list, and `src/inventory.cpp:510–520` does not resize
  when the size is unchanged. No detached inventory/list removal occurs in
  this allow path, so the engine's borrowed list references remain valid.
- Removed `quality_mode` registry storage and optional quality-gate calls are
  consistent with the separately approved deterministic ENCHANTS workflow;
  ordinary profession qualification remains in place.

## Frozen source hashes

```text
5d1e538ee68a347f419b427b95c215ef1d9e971e7b148bc11f9d4f663b14feef  mods/PLAYER/grug_jobs/workspaces.lua
e6bde473a5bc117288cfdf7c4cb94a8706bf9570e916f4257b2398756668ef6b  mods/PLAYER/grug_jobs/registry.lua
19f6f3f2dedf8a22103897eda7d3ac0d467ff1f29991a5400917cf6956b935ff  mods/PLAYER/grug_jobs/stations.lua
90db14ffea1396c69dac9283e479a82afb0cf803b90f3ade1cda121888824f1f  mods/PLAYER/grug_jobs/automatic.lua
```

Fix diff SHA-256 over the three changed production files from f99393ce:
`778fbe3271a9daa34efdedbffa18ccb17ce486d9ff194bcef71d188e3a2ce504`.

## Validation boundary

Inspected the added source-on_take/destination-on_put regression for a single
result and partial output returned to shared inputs; also the retained out-of-
range view, fresh input/fuel, five actual seconds of cooking, private-before-write
instrumentation, and idle-write counter. Existing probe uses real engine
ItemStack/InvRef/metadata with controlled players and explicitly driven callback
order, not client packets. The combined fixture now directly verifies the new
zero-return branch: settlement consumes the old grain and creates bread, the
stale grain take is refused, and a fresh bread take succeeds at the same clock
time with exactly one transfer.

Final inspected execution evidence (no reviewer rerun):

- `tools/r13_stations/evidence/integrated-native.log`: 55 assertions PASS,
  SHA-256 `885897d2b7f654087b38db09b33f7d95c025b841af57161284be4096dd8744f1`.
- `tools/r13_stations/evidence/integrated-restart.log`: 5 same-world restart
  assertions PASS, SHA-256
  `bf5db5f1ccb67f1542d5061246ffc30ddb2cb0e8bc96dc9e15b8c5d6b6e7955c`.
- `tools/r13_integration/evidence/strict-native.log`: 1,871 assertions PASS,
  656 catalog routes, 456 book operations, five actual selected-operation Apply
  transactions and the stale-grain/fresh-bread boundary above; SHA-256
  `229a2ece025dd6079096e1cdea56cfa121dd72a99bd4a29fb402ae78f837e99b`.
- `tools/r13_equipment/evidence/integrated-static.log`: parser, SETGLOBAL and
  sweep evidence inspected; SHA-256
  `511f819f0d2f47d8d4ef3b96d726c781112e7fc21d9a95b2b2d5fcceec4b8852`.

The reviewed production hashes above still match; independently compared them
with the successful integration engine's staged game in
`/tmp/grudgelands-headless.UI1rxU/user/games/grudgelands`, with no differences.
Final station scenarios SHA-256:
`a45d64a66d9893011629ed15cdc2aa41871272374a0430b431585ea2005a517b`;
station probe init SHA-256:
`a7ff76d47bcd23c4a60596b10d696d58611ec985ed96d63753380051b07a676e`;
combined scenarios SHA-256:
`86966079bfb7030ab5f12e70c3cc48fc7d15236633de0646bd47b0baeaad96b3`.

The reviewer ran no PUC runtime, native server, GUI, mapgen or broad suite and
made no repository changes. Native evidence is produced once by the coordinator
and inspected here rather than duplicated. Separate ENCHANTS delta approval and
earlier repair-service integration finding are unaffected by this re-review.

Calibration: correction implementer native GPT-6 Astra coordinator; reviewer
native GPT-6 Astra independent agent; original 0 Critical / 1 High / 2 Medium;
source re-review 0 new findings; fix rounds 1; elapsed wall time unknown.

User runtime: with two clients test shared output dragged back into an empty
ingredient slot and partial extraction, then a personal furnace after leaving
range and returning. Confirm delayed work does not accelerate newly inserted
contents, stale transfers can be retried safely, and closing/restarting preserves
only the already-settled contents and progress.
