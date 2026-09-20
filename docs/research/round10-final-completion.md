# Round 10 technical completion

Date: 2026-09-20. Integration coordinator: GPT-6 Astra; ordinary implementation
and independent reviews: native GPT-5.6 Sol. World and performance implementation
used native GPT-6 Astra. No Claude or same-provider CLI delegation was used after
the user's routing correction; the permanent execution-channel rule is recorded
in AGENTS.md and the process policy.

## Scope and result

The accepted EQUIP, GAME, WORLD, ART, CAP, FARM and MAP-B packages are implemented
and independently reviewed. They cover exclusive recipe books and familiar base
recipes, seven professions and refinement, mounts/falls/mob and dragon behavior,
nonweapon visuals, capital profession premises and riding stables, functional
cave boundaries, world ingredients and the seventeen-family farming loop.
The [fresh-world checklist](round10-next-playtest.md) is the user acceptance gate.

The final interpreter pair passed: LuaJIT and plain PUC5.1 produced identical
80,495-byte output, SHA256
`7a45a740503855b654015428ca801ecee1fa3a874b4ae33cb60f5cfba1fe3579`.
All7,888 resolved input files passed their post-run checks. Input-manifest SHA256:
`c1b4b80db105eaf04349cfc200a1caff5d6f8babed0b037042cb6878233f2716`.
The [accepted pair and manifests](../../tools/r10_integration/evidence/final-parity/README.md)
retain the exact interpreter identities, output and unchanged-input proof.

The reviewed runtime and evidence were merged to main as
`c02dd91e9c2495dfb9669e07f518c61ae42ac58d`, synchronized from main to the
Luanti Flatpak game directory, and pushed to `Kaesual/grudgelands`.
A checksum-based dry comparison confirms identical `mods/`, `menu/` and all
three game configuration files, with no extra installed files. The
[delivery receipts](../../tools/r10_integration/evidence/delivery/) retain the
successful sync/push logs and installed-file verification. The following final
status-documentation commit changes no shipped runtime files.

## Frozen source and checks

The real-engine candidate was `8dd1c8e463a13ccc356cdade123875471b398707`.
The final interpreter freeze is `35432bdf232e88a6d633e861b84571fc3411e404`;
production, game configuration, decided design and AGENTS bytes are identical.
The intervening changes archive reviewed evidence and select the reviewed current
capital overlay oracle. Final documentation/evidence commits do not alter runtime
or the tested fixture source. The final input manifest binds resolved input bytes.

- All six capital engine processes completed with zero errors. Service,
  precinct and Alchemy witnesses passed: eight profession trainers plus a separate
  Riding Trainer, seven public stations and seven protected displays per capital.
  All original wrapper exits remain recorded as 1 because seven historical
  geometry comparisons differed. The independently reviewed coordinate proof
  explains every difference; retained readbacks match all eighteen current
  expectations. No engine rerun is claimed for the oracle-only update.
- All six starts passed cold generation and same-world disk reload in forward
  and reverse order. All four canonical digests are
  `27ab0ba785073e61c6a8f83249f5da08e675cdb1066dbe983347063acddcc96f`.
- Plain-5.1 parser, SETGLOBAL and five static sweeps passed for the 185-file
  runtime candidate. Two later attribution-only Lua helpers have separate parser,
  zero-SETGLOBAL disassembly and sweep evidence. The fresh-server check passed. Preserved historical log/TSV
  whitespace is recorded separately and was independently assessed.
- Licensed-media provenance and unchanged reference pins are retained. The earlier
  PERF measurements remain package-specific evidence; no new whole-Round-10
  performance improvement is inferred from correctness runs.

Runtime/static evidence lives in
[`tools/r10_integration/evidence/final-v3/`](../../tools/r10_integration/evidence/final-v3/).
The [independent review index](round10-reviews/README.md) preserves original
verdicts and later closure reports instead of rewriting historical reviews.
The [capital attribution](../../tools/r10_capital_phase/ATTRIBUTION.md) and
[current expectations](../../tools/wp13/evidence/20260920-capital-round10/README.md)
retain historical oracles unchanged. The misleading historical `dfb32cd5` stamp
is corrected by exact source-hash provenance to `6cd971b0`; it is not silently
used as the historical source identity.

## Integration findings and calibration

The first six-capital integration run exposed a High-severity crash: generic NPC
placement invoked a mob-only yaw method on plain display entities. Sol fixed it
in `561a9c2b`; independent Sol review and the actual engine witnesses closed it
in one fix round. The first interrupted PUC attempt is preserved as incomplete,
not a passing parity result.

A later geometry comparison exposed avenue lamp/pier cadence shifting when the
inner endpoint moved. Astra made the old phase explicit in `ccd10d96`; independent
Sol source review and exact old/pre-CAP/current coordinate attribution are CLEAN.
The second interrupted PUC attempt likewise remains incomplete. All seven changed
regions are attributable to accepted inner-capital changes or earlier world
terrain changes; eleven regions match exactly, with zero unexplained coordinates.
Attribution and current-oracle reviews each have zero findings and zero fix rounds.

This integration is non-trivial. Package-specific initial findings, correction
rounds and model identities remain in the review index and package records;
observed elapsed wall time is unknown. The [final independent evidence review](round10-reviews/final-evidence-review.md)
is CLEAN: zero findings, zero fix rounds. The dynamic-document review identified
one Low reference-count error; the final wording changes nine to thirteen pinned
references. The [focused final wording review](round10-reviews/final-docs-delivery-template-review.md)
is CLEAN with zero remaining findings; GUI acceptance remains separate.

## Remaining limits and next test

Technical completion does not stand in for the user's GUI playtest. Check the
crafting/refinement route, all six capitals and trainers, mount cameras and steps,
percentage falls, idle mobs and dragons, crops and the new armor/loot art.
The whole-WP count stays 22 shipped of 53 tracked, with one canceled and thirty
open/in progress. Housing, global durability, Scout/playable bows, remaining POIs
(including the decided-width-24/source-width-16 bandit discrepancy), WP46/WP47,
WP49 and the documented first-public-release world/resource gates remain open.
There is no full census, reference repin, old-world migration or R7 157-file
source-audit refreeze in this delivery.
