# Independent STATIONS review

Reviewer: native GPT-6 Astra, read-only; 2026-09-21. Verdict: changes required.

Scope: candidate `/tmp/grug-r13-stations`, commit
`28ef4d85cfa1e3d21e6e9356bbf84b83b1550e50`, compared with
`5d8501634b338c1e723faf8b8d5e3bf4ad738af4`.
Production diff SHA-256 (`git diff BASE..HEAD -- mods`):
`dad632d1737c031287618450919f3c7cc3bb11e56f9ff65207bbd10ec1a4fd9d`.
Current authoritative root `docs/design/crafting_equipment_revision.md` SHA-256:
`352a8d74a8a699202c85e04e83ee4fc4f7ce157f25d4379cd996a1546a0d1a32`.

## Findings

1. **High — moving a shared preview into its own shared craft grid consumes the new output.**
   `mods/PLAYER/grug_jobs/workspaces.lua:214–217` debits all nine *current*
   source slots after transfer instead of the input slots authorized before
   transfer. The visible output is detached, while the shared craft grid is
   nodemeta: this is a cross-inventory move, so detached `allow_move` does not
   block it. Node `allow_put` at lines 328–333 permits the destination craft
   slot. With a qualified recipe ready, drag its result into an empty slot of
   that station's craft grid. Engine movement installs the result there before
   source `on_take`; the debit loop then removes one newly produced item as if
   it were an ingredient. A one-item result disappears completely, although
   the original ingredients and profession progress are settled. For a
   four-item result, three survive instead of four. The pinned engine proves
   this ordering in `reference_projects/luanti/src/inventorymanager.cpp:404–405`,
   `:473–474`, and `:596–605`. Freeze exact consumed slot counts in the receipt
   (or explicitly disallow this destination before mutation); do not debit
   newly added items. Add this cross-inventory destination to the transaction
   regression, including a one-item recipe and a partial multi-item result.

2. **Medium — personal inventories are publicly transmitted, with recurring idle broadcasts.**
   `mods/PLAYER/grug_jobs/workspaces.lua:55` stores every personal input/output/
   fuel ItemStack and processing state under an ordinary public node metadata
   field. There is no `mark_as_private` call. Owner-limited detached inventories
   therefore do not provide owner-limited visibility of their durable contents:
   every client receiving this mapblock also receives all users' serialized
   records. `advance` changes `process.last` and writes the record even for an
   empty/stopped personal machine (lines 58–64), once a second for every
   accessible viewer (286–291). This repeatedly broadcasts all accumulated
   user records at a busy authored station and dirties idle mapblocks.
   Engine evidence: `src/script/lua_api/l_metadata.cpp:109–110` emits change
   events, `l_nodemeta.cpp:40–58` identifies private fields, `src/server.cpp:1040–1049`
   schedules non-private updates, `:2496–2535` sends complete node metadata to
   nearby clients, and `src/nodemetadata.cpp:25–40` omits only marked-private
   fields from network serialization. Mark personal records private before
   the first write and avoid repeatedly persisting unchanged idle processes.
   This is a verified data-disclosure and unnecessary-work path, not a measured
   100-player throughput claim or an item-withdrawal bypass.

3. **Medium — personal catch-up applies old elapsed time to newly inserted contents.**
   `mods/PLAYER/grug_jobs/workspaces.lua:182–208` permits and saves inventory
   edits without settling the prior interval; only open and the accessible
   one-second viewer pass call `advance`. Concrete callback sequence: open an
   empty personal furnace at game time 100; retain its view while moving out
   of range so the viewer pass skips it; return at time 160 and insert a new
   input and fuel before the next pass. Both allowed edits retain
   `process.last=100`. The next pass processes the newly inserted ingredients
   for about 60 seconds, although they were just inserted. The same boundary
   exists on output-capacity and fuel changes, with a normally smaller window
   between regular ticks. Settle elapsed time against the pre-edit inventory
   at every authorized mutation boundary, with stale-source handling where
   settlement changes the stack involved in an engine transfer. Test an
   inaccessible retained view followed by input/fuel insertion before the next
   globalstep; it must not receive the preceding idle interval as processing.

## Evidence and limits

- All 12 entries in `tools/r13_stations/evidence/final-files.sha256` match.
- Inspected the 45-assertion native fixture, its final log, the five-assertion
  same-world restart fixture/log, and the plain-5.1 static evidence. The fixture
  deliberately models callback order and fake players; it is not a real client
  packet test and does not exercise the cross-inventory same-station destination
  or pre-mutation catch-up boundary above.
- Final log SHA-256: `cbbc92386a36aa9648d846d886920a59ccfe8cf189b24c4e596812efe43fbe4e`.
  Restart log: `c145407235b183a0060a4a66e395ddf6a60021a16dc8576414fc860331c04b11`.
  Static log: `9e9ace0929580ce4c81fe59d4c5c43bcb6d40ce49533ea484f0e25b66c02e7e6`.
- No runtime suite, PUC runtime, GUI, mapgen, CLI delegation, or source mutation
  was performed. Findings are verified against production source and pinned
  engine contracts. No fallback-engine certification is inferred.
- ENCHANTS' operation catalog and `operation_plan` implementation are outside
  this frozen candidate and require combined-branch integration verification.
  The agreed deterministic trinket change and removal of old refinement paths
  are assigned to that separate package and are not reported as STATIONS defects.
- Personal per-physical-node identity/storage, shared viewer qualification,
  partial remainder persistence, node replacement invalidation, automatic
  universal finishing and preparation-owned profession progress were inspected;
  no additional concrete defect is asserted in those paths.
- Calibration: implementing model native GPT-6 Astra (candidate README);
  reviewing model native GPT-6 Astra, independent agent; 0 Critical / 1 High /
  2 Medium; fix rounds 0; elapsed wall time unknown.

Runtime follow-up after fixes: use two clients at a shared Forge; drag a one-item
result into an empty shared input slot, then repeat with partial output and
shift-click. At a personal furnace verify that newly inserted work after an
inactive view gets only subsequent server time, and inspect network-visible node
metadata to ensure other players' records are absent. Retain the existing
restart, capacity, access and selected-enchant integration checks.
