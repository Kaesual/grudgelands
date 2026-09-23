# Round 18 independent design-drift and visual review

Date: 2026-09-23. Reviewer: native GPT-6 Astra (`r18_review_docs_art`).
Snapshot: `/tmp/grug-r18-review-docs`, `85c162ab` against `7460c49d`.
Implementers: native Sol/Astra lanes and Astra coordinator. Reviewer authored
none of the reviewed implementation, artwork, design decisions or documents.
Classification: non-trivial. No provider CLI, tests, PUC execution, performance
run, art regeneration or repository edits. Report only written outside snapshot.
Observed elapsed wall time: unknown. Initial findings: **0 Critical / 0 High /
1 Medium / 2 Low**. Fix rounds reviewed: 0.

**Verdict: FIX FIRST (documentation); visual artifacts PASS, GUI acceptance pending.**

## Findings

### Medium D1 — Generic pursuit rules still contradict the approved ambient exception

`docs/design/combat_stats.md:521` says every chasing mob slows to walking beyond
25 m, while `mods/ENTITIES/mobs/api.lua:2693` expressly excludes
`damage_pursuit`. `docs/design/mounts.md:254` and `docs/design/scout.md:280`
still describe 25/40/45 m rules as the general mob speed/pursuit foundation.
The revised §4 correctly gives ordinary mobs damage-sustained pursuit, so the
same living design now supplies incompatible expected behavior to a future
implementer or playtester pulling an ordinary mob beyond 25 m. Scope the old
soft-deaggro description and rationale to encounter-bound actors where still
applicable, and describe the ordinary incoming-damage timeout. The WP6 shipped
summary at `BACKLOG.md:132` should likewise mark its old chase rules as historical
or refer to the current R18 policy during the delivery update. No code change
is requested by this finding.

### Low D2 — Secondary living docs still claim weapon-based or deferred active icons

`docs/design/skill_trees.md:975` says `classes.md` §2c still parks signature
ability icons, which that revised section no longer does.
`docs/design/items_crafting.md:1554` still explains a spell's appearance as the
ability icon's weapon appearance. Following those references suggests active
icons are unimplemented or weapon composites, despite all 22 new action assets
and the implemented inventory/wield separation. Preserve deferred passive talent
art, but remove the obsolete active-icon comparison; change the counter-damage
explanation to equipped/held weapon presentation. No new artwork is needed.

### Low D3 — The current contract's proposed playtest still requires deferred torch light

`docs/research/round18-plan.md:448` asks for two-player moving torch light and
trail cleanup, while the same contract's lane I, the living revision and the
actual round18-playtest.md all correctly defer it after preflight. A user or
future coordinator following the contract's ordered list would test and reject
an explicitly omitted feature. Remove the torch clause or clearly label it
future-only; the current checklist itself is already correct.

## Design/contract assessment

All nineteen feedback topics are represented in the approved contract and living
revision, including the approved native-minimap reduction and both deferrals.
Topic documents consistently cover no XP loss, level-60 saturation, living-only
upward HP/mana refill with unchanged rage and one burst, species minima and
zone-fixed variants, corrected starter objectives, trainer success/confirmation,
Cooking permanence, weapon-slot guidance, inventory selection/hotbar clarity,
semantic active icons, managed stable tags, atlas coverage and waiting before
creation with one-shot failure reopening. Pick/shovel semantics are present in
the living R18 revision, not only in a research report. The recorded light
preflight respects the optional simplicity condition without substituting a
client overlay. Fresh-world and standard-client boundaries remain explicit.

No extra feature was identified in this review's scope. Detailed code correctness
for C/D/G belongs to the separate world reviewer; A/B/E/F/H2/J belongs to the Sol
reviewer. A possible interaction of exclusive loose-material capabilities with
cultural shovel routes was passed to the coordinator for that code review rather
than duplicated or reported here without proof.

README, BACKLOG and design index correctly say implementation is in progress,
with no premature whole-WP completion claim. Their pending delivery updates and
the unfinished final execution/completion receipts are expected at this review
stage. Final delivery must replace that status consistently and preserve GUI
acceptance as pending. No finding is raised for those intentionally pending gates.

## Actual visual inspection

Viewed `tools/r18_art/contact-sheet.png` with the image tool, including every
32-pixel normal cell and its illustrative cooldown/charge cells, and all enlarged
cells. Read the gallery and builder to verify displayed sizes and provenance of
the illustrative states. Also opened the actual packaged Strike, Opening,
Snare Shot, Pinning Shot, Frost Nova and Glacial Ward PNGs individually with
original image detail. This is actual visual inspection, not inference from
filenames or author claims.

All 22 families are readable and distinct:

- Strike, Charge, Mighty Blow, Hamstring, Taunt and Hold Ground communicate slash,
  rush, impact, ankle strike, challenge and planted defense respectively.
- Fireball versus Cinderfall separates one projectile from multiple falling
  impacts; Frost Nova versus Glacial Ward separates radial ice from a shield;
  Blink has its own violet portal composition.
- Smite, Flash Heal, Power Word: Shield, Renew and Word of Ruin use lightning,
  healing hands/cross, enclosing bubble, heart/leaves and fractured skull.
- Loose, Snare Shot and Pinning Shot separate a free arrow, rope and pinned boot.
  Sidestep versus Sprint separates a sideways arrow/boot from running stride;
  Opening uses a dagger at an armor gap and differs clearly from Strike.

At 32px the snare is the busiest design but its rope-loop silhouette remains
recognizable; Pinning Shot retains its vertical arrow and boot. Gold/green bars
over the bottom do not erase essential shapes. Heavy hammer/dagger motifs are
action metaphors, not proof of equipped weapon identity. The actual integration
retains equipment-driven wield visuals and the neutral empty-slot orb. No
blocking aesthetic or semantic collision was found. Author contact-sheet before
images and wear states are explicitly illustrative reconstructions, not GUI
captures; actual game rendering/charge transitions still require user acceptance.

## Media provenance and atlas

Read the per-asset manifest and `grug_abilities/LICENSE-media.md`: all 22 generated
assets have source output paths, exact prompts and final hashes, with qualified
project CC0 dedication and no claimed third-party inputs. Read the reference-first
assessment. Independently checked all 22 packaged hashes match and every file is
64×64 RGB. Existing bow stages retain their separate upstream CC BY-SA record.
No new licensing gap was identified in the stated generation provenance.

Viewed the world atlas plus all six actual regional PNGs. Read `atlas.lua`, the
renderer and the bounded coverage fixture without executing it. Bounds form the
approved three columns and two rows over [-3600,3600] × [-3200,3200], with 120
nodes across each internal edge (240-node shared overlap), common runtime/render
geometry and aspect-derived image dimensions. Whole capitals remain well inside
the appropriate view. Fronts and both islands are included in the union; island
edges crossing the north/south seam are visible in the complementary region,
which is consistent with the approved cover. Regional labels remain legible.
No requirement for each island to fit entirely in one regional panel was imposed.
Media inspection does not certify native clickable marker alignment; that remains
covered by code review and the user's runtime pass.

## Runtime acceptance scope

Follow `docs/research/round18-playtest.md`: inspect the real four-class hotbars,
catalogues and equipped/empty weapon presentation, cooldown and bow/swing charge,
six regional maps and minimap toggle/dots, trainer flows, nearby/far stable tags,
population/quest fit, long pull/timeout, XP refill/death, tools, and waiting/menu/
reconnect. Held light and guard healing are not acceptance requirements.

## Focused documentation fix review — PASS

Reviewed frozen `36be14cb` against the initial `85c162ab` snapshot on
2026-09-23. Same independent native GPT-6 Astra reviewer; no implementation
or artwork authored. Inspected only the requested documentation corrections.

- D1 resolved: combat_stats explicitly restricts the old 25-node slowdown to
  bounded actors; mounts and Scout describe the ordinary incoming-damage clock;
  both the WP6 row and BACKLOG architecture summary distinguish historical
  pursuit from the current ordinary/encounter split.
- D2 resolved: skill_trees separates delivered active action icons from deferred
  passive talent artwork; items_crafting now refers to in-hand weapon appearance.
- D3 resolved: the contract's playtest explicitly excludes deferred held light.

**Final scoped verdict: PASS.** No remaining findings from D1–D3. Initial counts
remain 0 Critical / 0 High / 1 Medium / 2 Low; remaining counts are all zero;
one documentation fix round. Elapsed time unknown. The prior visual PASS
continues to apply to unchanged artwork. Final code/native/interpreter gates
and delivery status are outside this focused re-review and remain separately
owned; user GUI acceptance remains pending.

## Final receipt consistency check

Independent reviewer checked completion, README, BACKLOG, ROADMAP, AGENTS,
execution and playtest status: no material contradictions. Cooking correctly
records the user's identified UX issue rather than asserting a player-data leak.
One stale design-index status was corrected to implemented / GUI acceptance
pending. No code tests were repeated for this receipt check.
