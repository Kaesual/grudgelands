# Independent shared-fixture integration review

## Verdict

**CLEAN for the bounded six-tool adaptation — 0 Critical, 0 High, 0 Medium,
0 Low.**

- Candidate `0c03af16` against integration parent `3e0d9726`.
- Reviewed files: `micro_kat_fixture.lua`, `anchor_activation_kat.lua`,
  `contract.lua`, `contract_kat.lua`, `material_salt_fixture.lua`, and
  `vendor_fixture.lua`.
- This is an independent native GPT-5.6 Sol source/evidence review. I did not
  author these changes and did not run either interpreter.
- The verdict covers these shared fixture adaptations only. It is not the
  forthcoming MAP-B production verdict.

## Verified boundaries

The population and reference arithmetic is internally closed and agrees with
the current MAP-B production source: 84 accepted R6 rows plus six cultural
rows produce the 90-entry production name map; the 12 gathering sources plus
22 world-content names produce the 34-entry P9G window. Consequently the
successor windows are P9G 91–124, anchors 125–126 and settlement content 127+.
The R6 writer uses the same `+34` and `+36` offsets. Anchor activation now
derives its production base from `anchor_content.successor_base_ref`, while the
isolated fixture explicitly supplies and asserts base 124. The old stale base
100 is not retained.

The contract and contract KAT advance the gathering catalog schema to v3 and
the Stage-B name population to 90 while retaining the closed-field schema
checks. The micro fixture checks the real manifest factory receives the world
rules, the real runtime passes those rules through `world_content.lua`, and
the successor receives the resulting world configuration as its fifth
argument. Its ordered successor fixture covers world bind/settle between P9G
and anchors. This tests the actual factory/composition seams rather than only
constructing a receipt.

The compact production fixture includes all 22 world-content names in content
registration and semantics, asserts the complete 25-node natural-ground
projection, and updates the accepted/content/manifest identities consistently.
The historical changed-production roster remains exactly 157 files; the new
world-content assertions do not rewrite that frozen historical denominator.

The visual initialization path captures `grug_gear` from the real
`gear_catalogue_kat` execution of `mods/ITEMS/grug_gear/init.lua`, requires its
six real materials, and passes that captured table into the real visual init.
It does not synthesize a replacement gear catalog. The vendor fixture's only
environment extension maps `grug_nodes` to its real mod path, allowing the
existing isolated loader to follow the new production dependency without
weakening its unknown-API failure behavior.

`material_salt_fixture.lua` now models the full 34-entry P9G contract and a
90-entry production prefix before exercising the real salt selector. Its
world-content suffix is loaded from the actual pure catalog, so the shifted
reference range is covered without duplicating the 22 names in the fixture.

## Evidence inspected

The supplied LuaJIT output reaches the complete shared micro receipt and
records the expected 84/90/34 content model, successor refs
`91/124/125/125/127/127`, 25 natural grounds, catalog-v3-derived identities,
and `source/changed_production_lua_count=157` with the matching executed-module
count. The static record reports parser success for all six changed tools and
all five compatibility sweeps. I treated these as development evidence only;
the final integrated interpreter pair remains Root-owned and pending after the
MAP-B freeze.

## Remaining scope

The frozen MAP-B production/new-fixture diff, its final pins and engine
witness still require their separate full independent review. The final
integrated compact PUC/LuaJIT parity pair and actual engine gates remain
outside this bounded verdict.
