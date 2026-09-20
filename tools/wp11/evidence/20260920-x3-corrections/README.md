# Round 12 X3 corrective candidate

Author: native Astra. Base: `5799c524` on `wp11-r12-talents`.
Independent review: **CLEAN** at worker commit `65aaf78c`; see
`docs/research/round12-reviews/x3.md`. Root integrated the corrections with
Skills; final integrated evidence lives under `tools/r12_integration/evidence/`.

## Finding and requirement matrix

| Finding | Correction | Production behavior evidence |
|---|---|---|
| H1 acceptance | Exact attacker/target settlement captures accepted mob callbacks or real player HP loss; `on_accepted(amount, critical, action_id)` runs after restoring nested punch state. Recompense, Whitehot and Last Word/drain commit there. Published pre-armor damage remains the drain amount. | Cancelled Smite/drain/critical Fireball; fully absorbed Word; dodged Smite; unrelated target callback; nested damage; accepted effects and ICDs. |
| H2 Turn Aside | Ranked contribution modifier belongs to named PWS on its recipient. Consumption, refresh, expiry and caster death/leave/respec remove it. Stats retain Scout window bonuses and add the shield modifier once. | Real rank-3 Priest shielding Warrior, self-cast once, untalented refresh, expiry at 24 seconds, remote lifecycle cleanup, normal dodge cap. |
| H3 action identity | Broadstroke receives the accepted swing context; Smite and drain reuse their accepted action across support. Repair accepts opaque table identities as well as captured string receipts. | Actual equipment wear equals one 3000-action increment for Smite+absorb, Word+heal, Broadstroke with accepted/refused secondary targets, and Brand primary+splash. Cancelled/absorbed actions wear zero. |
| H4 Cinderfall | Shared structured current ray supplies the physical intersection for nodes, hostiles, friendly objects and blockers. Empty/out-of-range contacts refuse before payment. | Node and friendly first contacts; exact 3 m/6 m boundaries; empty/21 m rejection; stale enemy memory ignored; enabled cast diagnostics. |
| M1 Brand | Fixed 2 m radius; rank changes damage only. | Actual native Fireball entity `on_step` → collision → production `on_hit`, ranks 1–3 at 1.99 m/2.01 m. |
| M2 Recompense cost | Central resolver snapshots 6% before affordability and spending. | Exact 162/2696 mana, ordinary 5%, cooldown duplicate refused, insufficient mana has no punch/payment/cooldown. |
| M3 spell modifiers | Fully assembled Brand, Rimebite, Cinderfall and Word formulas use the shared multiplier once. Brand snapshots at launch with its primary. | Real 50% spell status and production damage fit; Glacial Ward unchanged by hostile spell modifier. |
| M4 Hold Ground lifecycle | Own talent window records movement immunity; its lifecycle clears only Hold Ground immunity. Neutral-pool absorb has no spell-power multiplier. | Actual movement state, root refusal, respec/admin reset/death/leave; exact 40% neutral-pool absorb. |
| M5 Last Light | All shipped writers use explicit source names; old implicit PWS wrapper removed. Same-source refresh and deterministic shortest-expiry consumption remain. | Last Light + PWS coexistence, refresh, earliest consumption and total max-HP cap. |
| H5 behavior evidence | Replaced the source-token and mocked-closure X3 fixtures with a bounded native production-module scenario. Runner requires the result marker and rejects swallowed punch/projectile errors. | **110 assertions PASS**; also real Bellow, Frostbind/Rimebite, Hearten, Renew four ticks at ranks 1–3, Ruination cap restoration/ICD, Tendon Cut, and existing Scout/Unbroken behavior. |

Additional concrete consumer fixes: Frostbind passes `hostile` when acquiring
its remote target instead of its base registration's `self`; Tendon Cut uses
the real player hard-root flag, then the independent slow countdown. Existing
untalented Frost Nova movement values are preserved. The repair expression was parenthesized for clarity; its old Lua `and/or`
expression already fell back to the opaque table, so that rewrite is behaviorally
equivalent. The actual wear correction shares one accepted action identity across
primary and support/secondary effects; the real-wear assertions cover that rule.

## Reproduction and results

- `tools/wp11/run_x3.sh 40`: PASS, `checks=110`, native
  `LuaJIT 2.1.1784272936`. `launch.log` identifies the isolated `/tmp` world;
  `native.log` contains every assertion and enabled combat diagnostic. The
  probe disables startup start-area preloading, runs no mapgen population,
  and uses idle scheduling. No user world/profile is touched.
- `chrt --idle 0 ionice -c3 luajit -e 'local output,err=dofile("tools/wp11/talent_tree_kat.lua")("."); assert(output,err); io.write(output)'`:
  PASS (`wp11_talents_result PASS 0`), including the existing Scout fixture.
  Only dependency stubs for the new absorb accessor/cleanup were added there;
  it is supplementary model evidence, not the settlement oracle.
- `/home/jan/projects/grudgelands/tools/bin/luac51 -p` and `-l -p` on all
  changed Lua, plus all five documented `rg` sweeps over `mods/*/grug_*` and
  explicitly over changed tool Lua: PASS. `static.log` records all hits;
  matches are comments, UI strings, delimiters or frozen multiline manifest
  data. The only global writes are existing owning mod tables.
- `git diff --check` and `bash -n tools/wp11/run_x3.sh`: PASS.
- No PUC runtime, parity claim, broad suite, seed fleet, merge, sync or push.
  Native runs used one process at a time; the final standalone model check
  overlapped at most one native process (two idle LuaJIT processes maximum).

The native probe uses synthetic PlayerRef/mob adapters and deterministic
engine-facing clocks/ray intersections so it needs no GUI client. It retains
the real loaded talent parser, stats, cast and held-swing dispatchers, native
projectile entity lifecycle/callback, damage/HP-change settlement, movement,
status, inventory notification and repair consumers. Mob acceptance/refusal
is supplied at the existing accepted-hit boundary; this is not a claim that
an automated client exercised network packets or rendered the HUD. GUI
runtime testing and a true fallback-engine run remain separate user gates.
The Skills execution/normalization changes at coordinator commit `eaac9849`
are integrated separately; these tests use the pre-integration Skills version.

The earlier `20260920-x3` evidence remains historical rejected-candidate
material. Its source-token and mocked-closure fixtures were removed because
they did not establish X3 acceptance. The replacement is `run_x3.sh` and its
`probe_x3/scenarios.lua`, with hashes in `files.sha256`.
