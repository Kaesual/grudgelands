# Independent final documentation review

Date: 2026-09-23. Reviewer: native Astra, independent of all candidate authors.
Candidate: `b1587c54`; baseline: `d6937b31`. Read-only review; this report is the
only reviewer write. No runtime, PUC, PERF, synchronization or remote operation.

## Verdict

**Changes requested: three Medium findings and one Low finding.** No Critical
or High finding. The consolidation substantially improves authority/navigation,
preserves future design rather than adopting runtime as authority, and stays
inside the documentation-only boundary. The remaining problems are concentrated
in the new active planning layer, where old imperatives survived extraction.

## Findings

### M1 — WP22 still orders the retired durability budget and unapproved repair scope

`docs/planning/work-package-scopes.md:83` calls material/profession repair a
remaining redesign; line 85 orders preservation of the `3000/6000` combat-event
budgets. This directly conflicts with the candidate's corrected
`docs/design/durability_repair.md:15` (T1–T6: 1000/1500/2000/2500/3000/4000)
and lines 81–83 (material/profession repair is only a possible future topic,
not approved WP22 behavior). The items audit explicitly warned root about the
stale budget. A future WP22 implementer following the linked detailed scope can
restore removed refinement-era wear or schedule unauthorized repair design.
Replace that imperative with the current tier budgets/pointer and separate
optional future discussion from approved remaining pick calibration/Housing.

### M2 — WP13's active scope retains contradictory implementation history and loses the actionable geometry discrepancy

`docs/planning/work-package-scopes.md:51` is still the entire incremental
chronicle, including “Nothing is wired into a settlement yet”, “Nothing is wired
into the WP40 seam”, five capitals without cores, three walled capitals, and
old preparation behavior. These conflict with the delivered status and the
corrected `settlements.md`/`world_preparation.md`; the beginning-of-file disclaimer
does not make this a usable current remainder. The active scope also prints
full 100-anchor counts after mentioning 18 delivered regional POIs, rather than
an explicit remaining inventory. This invites rebuilding delivered work.

Separately, BACKLOG lines 20–21 and its WP13 row retain only “geometry
discrepancy”, and ROADMAP says it is explicit in BACKLOG, but neither BACKLOG
nor the detailed scope names the actual requirement. The historical backlog
at lines 551–552 preserves **decided 24-node versus implemented 16-node
`bandit_frontier` building-core width; design stays 24**. This unique open
requirement must be directly discoverable in the current WP13 remainder, with
its evidence pointer. It is preserved in history, so this is a routing/active
scope defect, not irreversible evidence loss.

Replace the active chronicle with delivered slices, remaining roster/shipwright
and socket ownership, the explicit geometry discrepancy, and pending GUI gates.
Keep construction history in the existing archive.

### M3 — WP34 still treats the delivered depth-level curve as unimplemented

`docs/planning/work-package-scopes.md:157` says to implement the “corrected
depth-level curve”. `docs/design/combat_stats.md:623–637` already defines the
approved three-levels-per-50-node curve, and current
`mods/MAPGEN/grug_mapgen/wp40/zones.lua:1140–1149` implements that exact rounding
and cap. The new TODO correctly says the curve is decided and distinguishes
the unimplemented pulse; the technical guide also says the underground term
already supplies the three steps. The active WP34 detail should identify that
curve as delivered infrastructure to retain, while the pulse, camp renewal,
lava/resource remainder and two unresolved content questions remain open.
Otherwise a future implementer is sent to redo a solved mechanic and may assume
the remaining TODO concerns the curve rather than placement/servant roster.

### L1 — Deferred friendly-guard healing routes to a backlog with no matching item

`docs/design/playtest_quality_revision.md:17` routes both deferred moving light
and friendly-guard healing to BACKLOG. The latter is absent there (it remains
in `combat_stats.md` and ROADMAP). Either route healing to its actual topical
owner or add the short deferred requirement/owner to BACKLOG. The rule itself
is not lost, but this new routing endpoint does not contain what it promises.

## Verified safeguards and positive results

- Diff roster contains only Markdown plus the inventory TSV; no game code,
  runtime fixtures, media, reference pins, root README or license ledger change.
  Independently hashed all 10,270 existing paths in the protected baseline
  manifest: zero mismatches. Root check-result also reports zero protected
  changes and zero missing local file targets.
- Independently counted all 53 WP table identities: 27 delivered, one canceled,
  therefore 25 open/partial. No new gameplay completion is implied.
- Fresh-server/no-migration, native-provider delegation, no Claude in this
  session, standard-client boundary and pending remote authorization remain.
- The four process diffs retain independent review/freshness and runtime Lua
  gates/budgets. The docs-only exception does not waive runtime-relevant gates.
- Technical guide now describes universal brewing completion with qualified
  mixture progress, separate Weaponsmith/Armorsmith without blacksmith alias,
  selected fixed-tier enchants without refinement, and the whole-world atlas
  with v4/native scrolling/shared outer-window sizing. No stale seven-view
  atlas instruction remains in its active Atlas entry.
- WP37 is explicitly paused; no resolution or density change is inferred.
- WP44 target economy remains distinct from current prices/buy-back. Profession
  book visibility remains reported code/design drift, not a rewritten rule.
- Housing/claim travel, boats, PvP, deeper resources, story/encounters and
  broader item finishes retain approved future status. Innkeeper return is
  clearly separate in the core current design/status summaries.
- R19 GUI acceptance, first-public-release/native fallback evidence, demand-
  driven sampler limitations and historical-candidate evidence boundaries
  remain explicit. No runtime certification is claimed by this review.
- `git diff --check d6937b31 b1587c54` passes.

## Coverage and limitations

Reviewed the complete changed-path roster, substantive changed design/process
sections, all four author reports, active BACKLOG/ROADMAP/detailed planning,
status/navigation/maintenance additions and technical-guide risk seams.
Historical extraction was inspected through diffs and archive provenance;
large historical bodies and the 106,098-line corpus were not all reread in full.
Planning archive copies rebase relative links, so they are not literal byte
copies of the original root files; their baseline provenance is explicit.
The source-bound code spot check above establishes the depth implementation,
not a fresh runtime test. Link validation here relies on the recorded structural
check and targeted navigation inspection; it does not certify every fragment
anchor or old file:line citation. The inventory is structural coverage, not
substantive per-file approval.

Author-reported possible specialist mastery/catalog mismatch remains an honest
coverage concern. Existing D1–D4 findings and the user's GUI/release gates are
not resolved by this review. Root should fix the findings above, rerun bounded
documentation checks, and record the disposition on the final candidate.
