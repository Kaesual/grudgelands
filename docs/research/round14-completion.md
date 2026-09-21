# Round 14 completion record

Status: all technical and independent review gates passed; delivery pending.
Date: 2026-09-21. Authoritative decisions remain in `docs/design/`.

## Delivered scope and limits

- Quest framework: 20 active quests, item/kill objectives, transactional hand-in,
  own tab and optional three-quest HUD, per-viewer 3D markers, shared eligible
  damage/effective-heal participation. Six V1-overworld starter chains contain
  66 quests and 24 named quest-giver identities. The Nether is expansion one.
- Persistent same-faction groups of 2–10, offline membership/leadership,
  inviter-bound invitations, management tab and optional name/HP HUD. No group
  XP, kill-credit, tap or loot semantics were added.
- Seven-view drawn atlas with interactive markers. It approximates authored
  macro geography rather than drawing generated terrain or player buildings;
  no fog, full-generation prerequisite or waypoint travel authority.
- Eighteen structures at existing home-region anchors: six villages, six
  outposts and six bandit camps. Existing terrain, roads, functional roots and
  NPC activation own their respective seams. Only the decorative displays are
  made immutable; this is not blanket POI protection.
- First-boot-bound starts/full preparation, one in-flight mapchunk, persistent
  cursor, normal shutdown/resume, progress/ETA and creation/reconnect stasis.
  Full mode uses the approved 320-node water margin. It is optional and can
  take many hours; only isolated tiny worlds were generated for acceptance.
- Corrected faction flight policy and interactive fishing float/bite/reel flow
  with transient catch notification. Cooking cross-player behavior remains
  unreproduced: diagnostics and callback-isolation evidence are included, not
  a claimed production fix.

WP8, WP12 and WP20 are technically complete. WP9 and WP13 remain open for
broader progression/PvP questlines and the remainder of the 100-anchor roster.
No public-release claim or existing-world migration is introduced.

## Independent review calibration

| Scope | Authors | Independent reviewer | Initial C/H/M | Correction rounds | Final open |
|---|---|---|---|---|---|
| Quest/party state | Astra | fresh Astra | 0/0/0 | 0 | 0 |
| Preparation, selection, flight, fishing | Astra/root + Sol | fresh Sol | 0/0/0 | 0 | 0 |
| UI/story | Sol + root Astra | fresh Sol | 0/1/2 | 1 | 0 |
| POI/atlas | Sol + Astra correction | fresh Astra | 0/2/3 | 1 plus bounded visual polish | 0 |
| Final docs/code drift | Astra/Sol | fresh Astra | 0/0/0 (2 Low) | 1 | 0 |

Reports: [state](round14-state-review.md), [runtime](round14-runtime-review.md),
[UI/story](round14-ui-story-review.md), [world](round14-world-review.md), and [final drift](round14-drift-review.md).
Runtime review elapsed approximately 25 minutes; other review times were not recorded. No Claude or same-provider CLI agent
was used. Root performed bounded integration/selection/fishing work and never
served as its own independent reviewer.

## Final evidence

Final static and portable parity evidence belongs in `tools/r14_final/`;
[isolated native integration](round14-integration.md) records actual manifest,
planner and loaded-POI checks. Development fixtures are not fallback-engine GUI
acceptance. Native stop/resume evidence is recorded separately in
[preparation work](round14-pregen-work.md). Reviewers inspect evidence instead
of repeating heavy or PUC runs.

The [fresh-world playtest checklist](round14-playtest.md) covers multiplayer
markers/credit, invitations/offline groups, atlas, fishing, POIs and flight.
The Cooking report requires two real clients if it recurs. Full-world generation
is an optional operator check, not part of the short GUI pass.

## Frozen-byte verification outcome

All 66 changed/new Lua files passed the plain-5.1 parser. Production global
writes are only the eight owning mod tables; tool writes are explicit fixture
stubs. All five source sweeps passed after inspection of comment/display-string
hits. Final canonical parity is SHA-256
`e553a3e219d50aa2c44fa118689ec555f32368a15e217a2361f66b543b25c7a3`: thirteen bounded
fixtures in one replacement PUC process (0.424 s) and one LuaJIT process (0.144 s).
Exact timings are observations, not performance targets.

The first final PUC attempt failed because the selection fixture's fake class
record lacked its required `id`. LuaJIT accepts nil for `%s`, while PUC rejects
it. A diagnostic repeat recovered the error after the initial wrapper failed
to retain stderr. The production registry already asserts `def.id`; only the
fixture was corrected to match that real schema. The final replacement pair
then passed. Thus two failed bounded PUC attempts preceded the accepted pair;
no intermediate exhaustive PUC suite or population ran. The diagnostic output
is retained rather than hiding the failed attempt.

The isolated native final snapshot passed in roughly 44 seconds: actual
`r7_manifest.new`, exactly three `planner.plan_slice` calls, 66/24 registry,
12,670 loaded cells, preserved banner/camp-fire roots, clear supported sockets,
and four live NPCs with exact quest titles. The production preparation scheduler
was disabled only in the disposable integration snapshot to keep this gate at
three chunks; its actual starts/full lifecycle was independently tested in the
separate bounded stop/resume evidence. No full world or user world was generated.
