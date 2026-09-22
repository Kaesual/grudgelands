# Independent review — Round 16 G and D

Reviewer: native GPT-6 Astra. Reviewed G `b009e77873dac046b8c11d3efd95ce1edaca2503`
and D/XP `cb1ce4d0755b0f50cd1c928e95f08c8adb11d1af` in their separate worktrees.
I authored neither reviewed scope; my separate lane B combat implementation is
expressly outside this verdict. No production/worktree edits were made. No PUC
runtime, new native world, timing sample or generation run was performed.

## Verdict

- **G: one Medium correction required** for the stated restart-authority contract.
  No Critical or High findings.
- **D plus XP-label/admin scope: clean**, subject to the coordinator's final
  frozen-byte static/parity gates and user GUI acceptance.

## Finding G-1 — Medium: fingerprint omits the terrain authority it certifies

**Location:** `mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua:366` and
`mods/MAPGEN/grug_mapgen/wp40/preparation_source.lua:54`.
Consumer: `mods/CORE/grug_core/starts_preload.lua:72`.

The identity passed into the surface adapter is only the full seed plus
`manifest.values.source_projection_sha256`. The latter is the fixed source
projection built in `r7_manifest.lua:452-480`: content catalogs, decoded template
content, native noise/allowlist, gathering, cultural data and the consumer payload.
The consumer payload contains anchor references and rare-route offsets, not the
terrain-column implementation or full terrain/layout source. The adapter adds
only global content reach/vertical extrema and fitted settlement/activation boxes.
Consequently a remote terrain/height change that leaves those boxes and content
inputs unchanged retains the preparation identity.

Concrete consequence: stop a partially prepared world, change the terrain
source/height authority in a region away from the fitted reference points, then
resume the same seed. The scheduler accepts the stored fingerprint and reuses
both its completed prefix and its resolved current Y interval even though the
actual column authority has changed. A previously resolved interval around y=20
can be used for a surface now at y=200. The explicit contract requires mismatched
current authority to stop with an actionable error, rather than trusting old
selection semantics. This is a mismatch-detection defect, not a request for old
world migration or compatibility support.

A bounded LuaJIT reproduction loaded the **real adapter**, held its identity,
templates/cultural/settlement/anchor inputs fixed, and changed only the supplied
column authority from terrain 20 to terrain 200. A deterministic identity callback
returned the serialized fingerprint bytes themselves, so equal identities prove
equal hash inputs without relying on a mock hash collision. Result:

```
same_identity=true;old_bounds=19,23;changed_bounds=199,203
```

Required correction: bind a stable identity for the actual terrain/layout/height
source used by `column_values_at` (and selection semantics) into preparation's
fingerprint, without runtime CIDs. Add a bounded regression where a terrain
change alters the fingerprint and restart refuses an already resolved tile;
preserve identity equality across an unchanged normal restart. No additional
native generation/timing campaign is needed to demonstrate this correction.

## G observations that passed

- The selector retains the horizontal footprint and 320-node margin, derives
  negative-coordinate chunk alignment from actual geometry, traverses tiles in
  deterministic x-within-z order, and persists selected Y interval plus inner
  cursor before dispatch. A tile advances only after every chosen Y chunk.
- Every local column and boundary/content-reach neighbor contributes to the
  min/max envelope; this covers a narrow interior peak and tall exposed cliff
  at a tile boundary. It does not substitute center/corner sampling.
- `preparation_source.lua` reads the actual column tuple positions for terrain,
  water, functional height, transition upper/lower heights. Template rotation
  extrema and cultural cells conservatively bound crowns/support. Deep seabed is
  clipped only for ordinary deep water; shallow visible bed remains included.
- Anchor/reference settlement transforms match `r7_settlement.lua:base_of`.
  Overlay neighborhoods include their authored reach/half width; conservative
  local column heights and structure boxes cover surface-following avenues.
  The six actual start readiness envelopes are included in full mode.
- The scheduler bounds selection to 512 columns per pass, uses one in-flight
  request, distinct-successful mapblock accounting, sticky per-request failure,
  bounded retry and main-step deferred dispatch. Incomplete scans can restart;
  successful inner chunks cannot be silently reinterpreted on unchanged inputs.
- Mode persistence precedes planning and later setting changes are visibly
  ignored. Completed worlds dispatch no more work. Geometry mismatch rejects.
- I inspected both corrected native logs: boot one settles cursor 2; boot two
  restores 2 and settles 4; exactly two dispatches per boot; normal shutdown
  occurs with the second request active, with no third dispatch. Five authority
  samples per boot and unchanged semantic identity agree. This proves bounded
  stop/resume integration for the observed case, not full-world coverage.
- `sha256sum -c tools/r16_surface/evidence/native-production.sha256` passed for
  every recorded production source. The static log records plain-5.1 parsing,
  no global writes and all five source sweeps (only literal GUI pipe strings).
  I inspected selector/content fixtures and their retained LuaJIT results.

## D observations that passed

- Catalog rewards are constants tied to authored intended levels. The quadratic
  XP curve gives intervals `100*(2L-1)`; ordinary rewards are 15/20/25% and the
  substantial camp finale is 35%. No hand-in path reads player level to retune
  a reward. The report accounts separately for accompanying same-level kill XP.
- All six quest-six handoffs use the corresponding village steward, who already
  offers quest seven. Registry NPC indexing includes both offer and turn-in
  giver; `state.lua:npc_quests` uses the active quest's turn-in giver, and active
  journal rows publish the same giver. NPC settlement uses that same identity.
  Existing quest/atlas marker state therefore follows the changed handoff.
- Minimum level and named prerequisite titles are appended once to the shared
  catalog description consumed by NPC dialogue and quest journal. The shipped
  catalog registers dependencies before their dependents; the added assertion
  is satisfied by every current route.
- Kill XP receives 1.5 exactly once in `award_kill_xp`, before participant split
  and existing downstream racial handling. The existing one-settlement guard,
  40-node eligibility, gray suppression and faction gate remain. Administrator
  grants call `add_xp` without a reward source, bypassing kill/race multipliers.
- The XP label shows progress inside the current interval and an explicit max
  label. It retains the existing right-hand layout owner. Width at GUI scales
  remains a user visual check rather than claimed offline proof.
- `/xp give` validates caller privilege, online recipient, positive integral
  amount and cap before mutation. NaN/infinity cannot pass the modulo/integer
  test. `/xp` remains a self-query. The quest settlement and XP runtime fixtures
  exercise the intended module boundaries; their engine mocks do not constitute
  a two-client engine test.

## Integration and remaining gates

D's `grug_mobs/init.lua` edit is confined to `award_kill_xp`; B owns separate
combat/control portions of that file. Preserve both hunks at integration and
run the final fixtures against the integrated bytes. Neither D nor G authorizes
reviewing or accepting my own B changes. G's only overlap with core initialization
is indirect via its existing preload module; its R7 adapter publication adds
readonly authority without changing the VM writer/planner tuple.

The final compact PUC/LuaJIT pair was explicitly reserved for the coordinator
and is not present in these lane records. This review does not waive that gate.
No extra PUC run was made. Real fallback-engine and GUI travel/combat/quest tests
remain separate user gates.

Calibration: G implementer Astra, reviewer Astra; D implementer Sol, reviewer
Astra. Both reviews are independent by authored scope. Initial findings:
0 Critical / 0 High / 1 Medium (G), 0 findings (D). Review fix rounds: 0 so far.
Observed review elapsed wall time: unknown.

### Minimal correction recommendation for G-1

The current `r6_identity`/`planner_source` exports a schema and functions, not a
stable live terrain digest. The R5 manifest digest describes fixed engine/settings
contracts and is not a substitute for terrain-source identity. A narrowly scoped
load-time digest of the existing column-authority source bytes is sufficient:
`source/simple_map.lua`, `simple_map.lua`, `height.lua`, `coupled_grade.lua`,
`zones.lua`, and the constructor/math dependencies they are assembled with
(`canonical.lua`, `deterministic.lua`, `index128.lua`, `schemas.lua`, `r5.lua`,
`r6.lua`). Include the actual assembly/selection adapters whose semantics define
that envelope (`r7_runtime.lua`, `preparation_source.lua`, and the core
`preparation_plan.lua`). Read this fixed small roster once at authority
construction, hash paths plus bytes in a fixed order, and append that digest to
the existing identity input. This is a local preparation guard, not a new global
hash/version system or a return to the historical 157-file R7 audit roster.
The author should verify the exact direct dependency roster before committing;
no world-column scan or additional native generation is required.

**D release explicitly independent:** D/XP is clean with zero findings and may
be integrated while G-1 is corrected. Its final common static/parity gates and
GUI checks remain as described above.
