# Independent Round 13 recipe-book and Basics integration review

2026-09-21. Reviewer: native GPT-6 Astra, independent of coordinator-authored
UI/catalog changes. Final verdict: **approved; no findings**.

Scope: `mods/PLAYER/grug_jobs/ui.lua`, commit delta `5d850163..230d6cd4`,
and the frozen root `mods/PLAYER/grug_jobs/basics_routes.lua` reconciliation.
This is separate from STATIONS, ENCHANTS and the broader final documentation
review. Authority: current `docs/design/crafting_equipment_revision.md`.

Reviewed source SHA-256:

```text
7d625ba31a2812aaa41a72371756f8bbab268f94dbf4523dbbd4cf53c4431d24  mods/PLAYER/grug_jobs/ui.lua
f11f1ac00a5168859e490b65a0a0d6e9e0b0b716e8c9f6c3ca25789d38d2b69c  mods/PLAYER/grug_jobs/basics_routes.lua
```

## Checked

- Owning profession/station books include the selected-operation catalog.
  Each enchant uses its unique operation ID as its grouping/selection key, so
  the 456 entries do not collapse onto representative output item names.
  Pagination and click selection use those same keys, while image elements
  correctly use real representative item names.
- Exact named operation labels, fixed values, channel/tier information and
  family/minimum-target-tier hints remain available, searchable and escaped
  for formspec rendering. Operation instructions explain that the equipment
  joins the shown materials at the station. The changed multiline text areas
  fit inside the enlarged form coordinates and retain the separate station
  icon; actual GUI wrapping remains a user check.
- Profession qualification and discovery filtering are preserved. Recipe books
  remain informational; no new UI action bypasses the station's transaction.
- The current 656-route Basics declaration preserves unchanged visibility
  policy, moves simple bread/meat/fish roasting exclusively to general/starter
  presentation, adds the profession-owned mixture preparations and universal
  Stone Hoe, and removes retired Wood/Stone weapon and upgrade-kit routes.
  The reconciliation script validates each permitted ownership/add/remove
  class; the final production startup retains strict exact-route coverage.
- Native catalog capture temporarily disables only the declaration bind in a
  throwaway capture copy to enumerate the revised catalog. The final integrated
  55-assertion STATIONS boot runs without that patch and succeeds with strict
  production binding. No audit-disable change is present in the reviewed UI.

## Evidence limits

Inspected reconciliation code, capture records/change list, production bind
assertions, and `tools/r13_stations/evidence/integrated-native.log` (55 assertions,
LuaJIT 2.1.1784272936). Log SHA-256:
`885897d2b7f654087b38db09b33f7d95c025b841af57161284be4096dd8744f1`.
The final combined integration fixture additionally enumerates all 456 named
book records, checks unique operation identity/fixed value/family/tier hints,
and passes 1,871 assertions including five actual station Apply transactions:
`tools/r13_integration/evidence/strict-native.log`, SHA-256
`229a2ece025dd6079096e1cdea56cfa121dd72a99bd4a29fb402ae78f837e99b`.
Inspected final parser/SETGLOBAL/sweep evidence in
`tools/r13_equipment/evidence/integrated-static.log`, SHA-256
`511f819f0d2f47d8d4ef3b96d726c781112e7fc21d9a95b2b2d5fcceec4b8852`.
Both reviewed UI/catalog source hashes still match and were independently
compared with the successful integration engine's staged game in
`/tmp/grudgelands-headless.UI1rxU/user/games/grudgelands`.

No native server, GUI, PUC runtime or broad test was launched by the reviewer.
No repository source was changed. This approval does not certify the graphical
client layout or replace the independent reviews of crafting and enchant logic.

Calibration: implementer native GPT-6 Astra coordinator; reviewer native GPT-6
Astra independent agent; 0 Critical / 0 High / 0 Medium / 0 Low; fix rounds 0;
elapsed wall time unknown.

User runtime: open the Weaponsmith and Goldsmith books, search for a named
prefix/suffix and tier, page through operations with the same representative
item, and verify that each stays individually selectable and readable. Check
that basic roasting appears only in Basics and mixture preparation/finishing
instructions remain in Alchemy.
