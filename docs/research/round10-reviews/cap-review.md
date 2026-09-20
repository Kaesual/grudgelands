# Independent CAP source review

## Verdict and scope

**CLEAN SOURCE — 0 Critical, 0 High, 0 Medium, 0 Low findings.**

- Candidate: `b80b2037ab204ba27153769f4c2925e3cbb25767`
- Base: `e9e9433ec3d3723b7be56b9b0fda4e4af2820933`
- Reviewer: independent native GPT-5.6 Sol; I did not implement CAP.
- Reviewed the complete 126-file candidate diff, production callback/security paths, geometry/projection consumers, design/completion record, committed immutable evidence and the prior independent geometry/callback preflights. No candidate edit, PUC run, engine run or personal-world access was performed.

This is a source verdict. Root's integrated compact PUC/LuaJIT parity pair, six-capital engine fleet, six-start forward/reverse cold/reload gate, and regenerated post-ART gear-binding sheet remain pending and are not implied by CLEAN SOURCE.

## Verified requirements

### Geometry and projection

- The civic ring is radius 48; each real asymmetric gatehouse emits through `+-49`, and the R7 core bound is `[-49,49]`. Avenue approaches begin immediately beyond the core. All six core builders and their KAT oracles were updated rather than forced through a symmetric invented gate shape.
- Nhal Veyr's pane orientation follows the owning wall axis. The real pre-ring writer reports zero ordinary building/ring overlaps for all six capitals, with intentional corner joins classified separately.
- Every one of the six actual plot builders invokes the shared service decorator after its native composition. The immutable geometry artifacts cover all 48 service rooms; planner evidence uses real `r7_manifest.new`/`planner.plan_slice` consumers. The historical R7 roster remains 157.
- Root separately inspected all six riding cutaways, the seven Highcourt service cutaways, stand views and gear detail without finding clipping/framing defects. The conservative posed-AABB check reads actual B3D pose data and tests against emitted non-air nodes.

### Exact service population and closed vocabulary

- Each capital maps exactly eight existing outer plots: Riding, Forge, Tailor, Alchemist, Cooking, Leatherworker, Woodcarver and Goldsmith.
- Each emits eight primary/Cooking trainers, one distinct Riding trainer, seven public stations, four tier-tagged mount displays and three gear displays. Across six capitals this is 48 profession trainers, 6 Riding trainers, 42 stations, 24 mount displays and 18 gear displays.
- Weaponsmith and Armorsmith are separate trainers sharing one authored Forge. The retired `blacksmith` registration and the old capital-core trainer/station projection are removed without aliases. Start settlements retain Cooking only and have no Riding path.
- Socket compilation closes role, profession, mount-tier, gear-kind and station-tag vocabularies. Real terrain-resolved sockets, not trainer-relative offsets, own station positions.

### Riding authorization and transaction

- Opening and every receive-fields event revalidate a living player, faction, exact capital, exact `riding_trainer` role/socket identity, live NPC position, player distance (8 nodes) and NPC-to-authored-socket distance (2 nodes). Forms carry unique session names; quit, death and leave clear state; replacement forms stale the old one; multiple buy fields cannot transact.
- The transaction calls the unchanged real purchase path, which enforces level, ordered prerequisite, price/funds, inventory capacity, persistent ownership and owner-bound item issuance. The corrected immutable fixture enters through the real villager right-click and covers all four exact debits plus refusal and owner-use/drop cases.
- Profession trainer forms contain no Riding hook. Riding remains outside the profession slot system.

### Display lifecycle and intrinsic safety

- Capital displays are nonphysical, unpointable, immortal static entities with no `on_step`, AI, combat, riding, inventory or drop path. Activation validates saved identity, claims the established socket lease before configuration, and uses the shared removal/deactivation bookkeeping. Grounding is recomputed absolutely from the authored floor and evaluated pose, preventing cumulative reload drift.
- Mount appearance selection uses the existing race/faction catalog and exact four tiers. Gear displays resolve registered item identities.
- The 14 service-decor nodes are non-diggable, have empty drops, return no blast drops, expose no inventory, reject inventory callbacks and have no fuel/liquid/falling/growing/cooling groups. Decorative lava is an inert node, so buckets and cooling cannot convert it into collectible material.

### Stations, furnace and alchemy

- Public station authorization is an exact `(station, position)` registry derived from `public_station` sockets. Refinement stations retain their live player, distance, access, family/profession and capacity-before-mutation checks.
- The furnace vendor patch changes only protection authorization for an exact registered public hearth. It rechecks a living nearby player and an actual inactive/active furnace node. Private furnaces keep normal protection. The current-version LBM initializes only wholly absent furnace inventories and preserves populated metadata.
- Cooking output remains gated/progressed on the real extraction path; metadata moves cannot bypass it. Brewing registration now follows the exact authored stand socket, preserving its adapter and output gate.

### Evidence integrity

- `tools/r10_cap/evidence/geometry/inputs.sha256` SHA-256: `39fc3f82b805468cb960f5f985903c89a40d8ed1d7048b439449666619ec7362`.
- `artifacts.sha256`: `7830c389ddf279d28a93ba28d9dab2328516171e04d04b8a4848c6f2ae661827`.
- Full WP13 LuaJIT TSV: `7becaf2ae6986709b319ade53ea9d2428bbf0ee947c46f61de176315b3c16fc0`.
- Static-final log: `89925e0c8c2f378c10466b51b35599e9dbc01233b575eb4ac054cd499aa4f379`.
- Planner integration log: `2a599f8f8df47e22c54fa35e4e77fc10f56c5cb2505ea65e6a1f9b879ee11b55`.
- Ring-overlap log: `db94d8ba353e31e7415bf06b6834a884d9c79de9808813031b05910b8402399b`.

The committed completion record accurately labels CAP as an implementation candidate and explicitly leaves integrated engine/parity gates pending.

## Review calibration

The independent sequence found one Low stale-geometry documentation issue in the first geometry checkpoint and one Medium evidence gap in the first callback checkpoint. Both were corrected and independently closed before this final review. Two focused correction rounds preceded this full frozen-candidate review; this review adds no findings.

## Remaining integration gates

1. Integrate CAP atomically with EQUIP and the already accepted ART/GAME/WORLD dependencies.
2. Apply the capital-engine harness strengthening recorded in `/tmp/grudgelands-r10/engine-preflight.md`: exact service node/entity witnesses and a constrained ring/gate accepted-delta record. Do not weaken the old overlay or six-start oracles.
3. Run the root-owned one final compact PUC 5.1/LuaJIT parity pair on integrated frozen bytes.
4. Run all six capital full isolated passes and the unchanged six-start forward/reverse cold/reload gate.
5. Regenerate only the small gear-binding view on integrated ART bytes; the frozen CAP image intentionally predates the ART icon replacement.
