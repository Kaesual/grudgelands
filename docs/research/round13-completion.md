# Round 13 technical delivery

2026-09-21. Approved scope:
[crafting/equipment contract](../design/crafting_equipment_revision.md).
Implementation and code review are complete; the final documentation drift audit
and main/sync/push receipt are still pending. GUI acceptance is user-owned.

## Delivered candidate

Personal authored workspaces persist per player and physical station; all
player-placed stations share their inputs and qualify each viewer's result.
Protected preparation grants current-tier profession progress. Automatic
furnace/dual/brewing completion is universal with no second credit.

Refinement and Imbue/Temper are removed. There are 456 selected fixed-tier
prefix/suffix operations, including 36 trinket operations. Crafted trinkets have
an authored special and initially empty enchant channels; no crafted stats are
random. Replacement retains other metadata and wear. Loot randomness is separate.

Tools and weapons are disjoint, all starter weapons are immediately usable
Bronze, Stone Hoe exists, and the requested tool/combat lifetime ladders apply.
Outgoing accepted combat/healing wears only the main weapon; incoming settled
nonlethal combat HP loss wears one intact armor/offhand. Quivers wear and remain
repairable; broken storage stays retrievable. Repair retains enchanted speed.
Unbroken uses 1.65 to preserve the approved top Protection-vs-dragon target.

## Verification

- [ENCHANTS](../../tools/r13_enchants/README.md): focused LuaJIT checks of all
  456 applications and 36 deterministic trinket base recipes.
- [STATIONS](../../tools/r13_stations/README.md): integrated native **55**
  behavior assertions, then **five** assertions after a real same-world restart.
- [Combined integration](../../tools/r13_integration/README.md): strict production
  boot without staged patch, **1,871 assertions**, 656 exact catalog routes,
  456 book operations, five actual Apply transactions, armor calibration,
  Bronze eligibility, broken quiver and pre-transfer catch-up refusal/retry.
- [Equipment](../../tools/r13_equipment/README.md): exact lifetimes and wear
  settlement, real Money/repair service regression, existing combat integration.
- Plain Lua5.1 parser, SETGLOBAL and five sweeps include changed tool fixtures.
  Production byte hashes match native staging; reference pins are unchanged.
- No PUC runtime, mapgen/performance fleet, user-world writes or GUI claims.

Native fixtures use real engine inventories/metadata and production callbacks,
with controlled players and explicitly simulated callback order. They do not
certify real network/client behavior; use the [playtest checklist](round13-next-playtest.md).

## Independent review and calibration

Every implementation/review lane used native GPT-6 Astra under the user's
session preference. Elapsed wall time is unknown.

| Scope | Independent reviewer | Initial Critical / High | Fix rounds | Status |
|---|---|---:|---:|---|
| Equipment (root author) | ENCHANTS author, separate scope | 0 / 0 | 1 | Clean; one Medium partial-repair issue fixed |
| ENCHANTS 420 base | STATIONS author, separate scope | 0 / 1 | 1 | Clean after shared repair consumer correction |
| Deterministic trinket delta | Fresh STATIONS reviewer | 0 / 0 | 0 | Clean |
| STATIONS | Fresh STATIONS reviewer | 0 / 1 | 1 | Three findings fixed: returned output debit, metadata privacy/idle writes, pre-mutation elapsed time |
| Root book UI / catalog | Fresh STATIONS reviewer | 0 / 0 | 0 | Source/evidence review clean |

Receipts are retained under [round13-reviews](round13-reviews/). The repair finding
in two reports is one defect, not two independent bugs. A suspected PvE tool
issue was withdrawn after verifying the existing early native-punch veto.

The resolved planning TODOs were folded into living design and removed; their
historical discussion is retained in [planning history](round13-planning-history.md).
The user's additional final docs/code drift audit remains required before delivery.
