# Round 14 final documentation/code drift review

Date: 2026-09-21. Reviewer: fresh native GPT-6 Astra, independent of all
production implementation and design edits. Authors: root Astra and native Sol
lane authors. Scope: final Round 14 living decisions, production seams and
completion claims, plus the final portable evidence driver. No CLI delegation,
native engine execution or interpreter runtime was performed by this reviewer.

Initial verdict: **0 Critical, 0 High, 0 Medium, 2 Low findings**. Final verdict:
**PASS; all findings closed after one documentation correction round.**
Elapsed wall time: unknown. This review does not replace the lane reviews or
the user's GUI acceptance.

## Verified findings

1. **Low — living class roadmap still postpones shipped party frames (closed).**
   `docs/design/classes.md:583` groups party frames with future skill-tree
   work. Production `mods/PLAYER/grug_parties/hud.lua` now supplies the
   accepted name/HP/offline frame, so following that roadmap would wrongly
   schedule the shipped slice again. Separate remaining buffs/auras from the
   Round 14 party HUD and link `parties.md`.
2. **Low — living catalog summaries omit the delivered starter slice (closed).**
   `docs/design/README.md:28,40` and `docs/design/progression.md:4` still
   place quest catalogs wholly with WP8/WP9. Production
   `mods/PLAYER/grug_quests/content.lua` contains the reviewed six-culture
   starter catalog; distinguish those 66 quests from the still-open broader
   progression and PvP story. This is a status-description defect, not a
   finding that WP9 should be closed.

The coordinator owns corrections to shared documents. Historical reports and
their original candidate paths/hashes remain historical evidence.

## Decision and implementation checks

Read AGENTS.md, the workflow review checklist/model policy and the Lua 5.1
verification rules; inspected the execution/completion records and state,
runtime, UI/story and world reviews, including the final POI polish closure.
Searched living design authorities, BACKLOG, ROADMAP, README and AGENTS for
obsolete party-credit, fog and contested-flight rules.

- `quests.md`, `progression.md`, `story.md` and the quest state/HUD/catalog
  agree on 20 active quests, three tracked quests, ordinary item hand-ins,
  shared damage/effective-heal eligibility and V1 overworld-only content.
  `grug_mobs/init.lua:201–247` publishes the same online/40-node participant
  set after XP settlement and before cleanup, including gray-XP participants;
  party membership introduces no credit or XP multiplier.
- `parties.md` matches the canonical storage and runtime checks in
  `grug_parties/init.lua`: same-faction 2–10 membership, indefinite offline
  leadership, inviter-bound short-lived invites, acceptance-time capacity and
  authority validation, dissolution at one member and deterministic voluntary
  leader departure. Logout removes invitations, never membership.
- `world_map.md` and the atlas renderer/page/marker seams preserve no fog,
  seven bounded authored views, separate interactive markers and no travel
  unlock. The delivered atlas makes no generated-terrain or player-building
  fidelity claim.
- `world_preparation.md`, `preparation_plan.lua` and `starts_preload.lua`
  agree on first-boot immutable selection, 320-node margin, persisted plan
  and completed cursor, one request in flight and dispatch only from the
  throttled server step. Recorded native stop/resume evidence remains a
  separate gate from the portable fixture; full-world generation is not
  falsely claimed as tested.
- Fishing's actual `BITE_WINDOW = 1.5` and manual reel flow agree with
  `items_crafting.md`. Mount/world-zone policy allows both factions across
  ordinary contested mainland while keeping ocean, islands and enemy safe
  homes restricted. The shared production predicate is covered by the compact
  flight matrix.
- Completion/fix/playtest records accurately keep Cooking cross-player
  behavior unresolved and request real two-client diagnostic evidence if it
  recurs. Callback isolation is not represented as a production fix.
- Final POI review distinguishes immutable decorative displays from ordinary
  mutable shells. The final builder hash in portable evidence matches the
  independent world review's visual-polish candidate.

## Portable final evidence inspection

`tools/r14_final/micro.lua` loads 13 bounded fixtures in fresh environments,
copies mutable standard-library tables, and binds nested loadfile/loadstring/
dofile chunks to the fixture environment. This prevents fixture-installed
helpers and production globals leaking into the next fixture. The party-core
fixture suppresses only the two explicitly named appended UI/HUD loads;
unexpected paths assert, and the separate production UI fixture covers them.

The selection fixture now supplies `id="warrior"`, consistent with the real
`grug_classes.register_class` invariant (`init.lua:14–15`). The initial PUC
failure at `%s` with a nil fake-class id was a fixture schema error exposed by
the interpreter, not a reason to relax production validation or omit the
selection fixture. Its captured diagnostic is retained in final evidence.

Inspected `static.py` and `evidence/static.txt`: 66 changed/new Lua files,
including tools, pass the plain-5.1 parser. Production SETGLOBAL writes are
the declared owning mod tables; the remaining writes are fixture stubs.
All five prescribed sweep patterns are present; listed matches are strings
or comments. No unreviewed executable hit was found.

Read both final interpreter logs and independently compared their bytes:
13 fixtures pass with SHA-256
`e553a3e219d50aa2c44fa118689ec555f32368a15e217a2361f66b543b25c7a3`.
Verified `evidence/sources.sha256` against current files without rerunning
any interpreter. The recorded times are 0.424 s PUC and 0.144 s LuaJIT.
This proves the bounded portable cases, not the engine's fallback GUI build.

## Focused closure

Re-read both corrections: the class roadmap now links the delivered party
contract, and progression/design-index summaries distinguish 66 starter quests
from the still-open WP9 story. BACKLOG, ROADMAP and README consistently close
WP8/WP12/WP20 while retaining WP9/WP13 scope. The listed 27 completed tracked
identities reconcile with the updated README list. No further Round 14 status
or design contradiction was verified. Final completion accurately retains the
two failed bounded PUC attempts and replacement-pair explanation, plus the
runtime review's known approximately 25-minute duration.

Inspected final native log and both compressed snapshot manifests. Verified
all three evidence-index hashes and every one of the 2,011 production snapshot
files against the checkout: no mismatch. The executed snapshot differs in
exactly the three declared instrumentation files and adds only the probe mod.
Actual manifest entry and exactly three planner entries appear in the log;
66/24 catalog validation, 12,670 authored cells, functional roots and four live
NPCs pass. This closes the bounded native consumer gate without extending it
to all POIs/seeds or GUI acceptance. No native or interpreter run was repeated.

Merge/sync/push remain coordinator actions and must be recorded according to
actual completion, not inferred from this review. The linked user playtest
retains multiplayer, visual and fallback-engine acceptance as separate gates.
Calibration: authors Astra/Sol; reviewer fresh Astra; initial C/H/M 0/0/0;
initial Low 2; documentation correction rounds 1; final open findings 0;
elapsed wall time unknown.
