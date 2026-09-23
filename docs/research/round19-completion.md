# Round 19 completion record

2026-09-23. Implementation, independent reviews and final technical gates PASS.
Local main merge/installation are recorded below. Remote push remains blocked
by automatic approval review pending renewed confirmation. Client GUI acceptance
remains user-run. Contract: [round19-plan.md](round19-plan.md); execution:
[round19-execution.md](round19-execution.md); next test:
[round19-playtest.md](round19-playtest.md).

## Delivered scope

- One full-area atlas with 1x/2x/4x zoom, native horizontal/vertical scrolling,
  fixed-size markers, center-preserving zoom and reset on actual tab entry.
  Live refresh preserves the current view; Home and marker details remain.
- Concise Character totals, formulas in Help, first-click talent purchases,
  no combat-stat clutter on Talents, and a short correctly escaped Skills hint.
- Party colors default by class while explicit green preferences remain;
  status text moves top-center; Scout Sprint displays its existing +50%/10s.
- Injured dragon bars use explicit 5/4-node anchors and 3x0.25-node billboards.
  Ordinary mob/guard geometry and all visibility/cleanup rules stay unchanged.

No balance, world-generation, content or whole-WP count change: 27/53 remains.
No client modification, migration, provider CLI or Claude task.

## Review and frozen identities

Baseline `3b23a8f8`; branch `wp19-atlas-interface-fixes`.
Final production/test identity:
`15f994a18d25a7490c8ce161d6a55358de5cce02`.
Later changes are documentation/evidence only.

| Scope | Integration | Independent review |
|---|---|---|
| A atlas | `c9e8c95c` | Astra [map](round19-review-map.md) PASS |
| B menus | `0db5c853`, `7d9fca99`, `0d7e53a7` | Sol [UI](round19-review-ui.md) PASS |
| C party/status | `6aa8070f`, fixture `0b90752a` | Sol UI PASS |
| D dragons | `0b90752a`, `e398c90f`, comment `15f994a1` | Astra [dragon/docs](round19-review-dragon-docs.md) PASS |
| Living docs | root integration | independent Astra drift PASS |

Review fixed Skills row overlap, stale Help wording, a billboard scale error and
historical talent-test wording. Native sprite dimensions do not inherit parent
scale, unlike attachment positions; the corrected dragon path reflects that.
The ordinary pre-existing inverse-size conversion is deliberately not retuned.
No reviewer authored the implementation they reviewed.

## Final evidence

`tools/r19_final/evidence/` preserves outputs and source hashes.

- Plain Lua 5.1 parser PASS on 18 changed/new Lua files including tools;
  SETGLOBAL inventory has only expected `grug_mobs`/`grug_parties` tables.
  All five compatibility sweeps inspected; three hits are strings/comments.
- Exactly one compact final process per interpreter, three isolated fixtures:
  PUC 5.1 0.007680 s, LuaJIT 0.007149 s. Both exit 0; canonical output is
  byte-identical, SHA256
  `8cec59ed485583831ee6afcded43fb8704e6f18d11ae8d4d5483efd4a69b81cf`.
  No intermediate PUC runtime, generation fleet or PERF campaign.
- Final native Luanti registration check PASS in isolated disposable snapshot
  `/tmp/grug-r19-integration-mim__g8n`, with no ERROR or init-clock warning.
  Real vendor registration retains both dragon profiles; ordinary metadata,
  top-center status anchor, world-only atlas and page registration are verified.
  All 2077 production snapshot files match checkout. Compressed production and
  executed manifests identify the scratch-only scheduling stop and probe.
  No personal world/player data or map generation was used. An earlier pre-fix
  registration run is development evidence only; registration does not prove
  native client billboard rendering.
- Diff whitespace and read-only reference pins checked; none moved.

## Calibration

| Scope | Implementer | Independent reviewer | Initial C/H/M/L | Fix rounds | Elapsed |
|---|---|---|---|---|---|---|
| A atlas | native GPT-6 Astra | native GPT-6 Astra | 0/0/0/0 | 0 | unknown |
| B menus | native GPT-5.6 Sol | native GPT-5.6 Sol | 0/0/1/1 | 1 | unknown |
| C party/status | native GPT-5.6 Sol | native GPT-5.6 Sol | 0/0/0/0 | 0 | unknown |
| D dragons + living docs | Sol code / root Astra docs | native GPT-6 Astra | 0/1/0/1 | 1 | unknown |

Root also corrected fixture evidence to load the actual shared HUD anchor and
exercise Sprint removal/expiry/death/leave. B's two small correction commits
belong to one review cycle. All findings are closed.

## Runtime acceptance and limits

Restart Luanti/server, then follow the linked checklist. Prioritize Map zoom,
all corners, marker clipping, live refresh while scrolling, and close/reentry;
then first-click Talents, Skills recovery, party preference and Sprint. Damage
both dragons and compare ordinary mobs; check at your normal window/UI scale.
Native refresh can rebuild widgets while a scrollbar thumb is held motionless;
the server has no reliable drag-end event. Active scroll changes use a quiet
delay and preserve focus/view, but this interaction requires the GUI playtest.
No automated check certifies client font/layout or actual rendered readability.
Fallback-engine runtime remains a separate release gate from interpreter parity.

## Local delivery

Main merge and installed-tree verification pending at receipt creation.
Remote delivery remains pending: prior `git push origin main` was rejected by
automatic approval review because the earlier chat permission was not verifiable
in its context. No retry or bypass is part of this round.
