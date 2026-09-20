# Capital avenue phase correction review

## Scope

- Frozen candidate: `ccd10d965c5ef5235f217f9b0312a03640d7bbcb`, parent `2fcda6086cdf7c78c50e0037935b39933dd67e6b`.
- Reviewed the full 35-file delta, with production focus on the six WP13 capital descriptors and `wp40/r7_settlement.lua`; reviewed every adjusted oracle plus `tools/r10_capital_phase` evidence and projection tooling.
- Read-only review. No Lua interpreter or engine process was started.
- All 27 hashes in `tools/r10_capital_phase/evidence/inputs.sha256` verify against the frozen candidate.

## Production diagnosis and correction

The accepted inner avenue endpoints moved from 48 to 50. The R7 adapter previously derived `lamp_phase` from `run.from`, coupling geometric span to lamp/support cadence. The endpoint move therefore shifted every cadence-controlled cell along affected north/east runs, including cells at outer gate and wall regions.

The correction introduces one optional numeric `lamp_phase` on an authored run. `prepare_overlay` resolves nil to `run.from`, validates the result as an integer in the same bounded local-coordinate domain, carries it into the immutable prepared run and includes it in the overlay identity byte stream. `config` passes the prepared value to the existing run generator. Zero remains valid because production uses an explicit nil test rather than truthiness.

The six descriptors add phase 48 only to the eleven runs whose endpoint moved but whose cadence must remain fixed:

- north and east for Dur Brannoc, Gor Drazhak, Highcourt, Kezamba and Nhal Veyr (10);
- east only for Lethariel (1).

Negative runs retain their unchanged negative starts. Lethariel's separate north lake entrance remains at 22 and continues to derive its phase from that start. Endpoints, widths, reach, junctions and region geometry are otherwise unchanged.

## API and identity review

- The optional field is resolved during preparation, so downstream code receives a concrete integer and clipped writers retain the whole authored run's phase.
- Validation rejects booleans, fractions and out-of-range coordinates through the existing integer validator before any writer configuration.
- The identity stream now includes the resolved phase for every run. This means a phase-only change changes published overlay identity, while an omitted phase remains semantically identical to the historical `from` default. In fresh-server mode no compatibility reader or migration is needed.
- The actual R7 path is exercised: descriptor source → `prepare` → prepared blueprint identity → `config` → run generator. The production writer consumes `run.lamp_phase`; this is not a fixture-only field.
- All WP13 tools that reconstruct production run specifications now forward `run.lamp_phase or run.from`; fixed authored run oracles were updated consistently. Historical evidence scripts under dated evidence directories remain untouched.

## Evidence and oracle quality

The strengthened integration fixture checks all six actual descriptors. It requires the ten ordinary north/east pairs to be endpoint 50 / phase 48, requires Lethariel north to remain endpoint 22 with the default phase, mutates one phase and proves the prepared identity changes, and sets a boolean phase to prove validation fails with the expected field label. Its writer path forwards the authored phase.

The bounded source projection uses actual zones, blueprint loading, R7 preparation/configuration and settlement-tail ownership. It deliberately supplies no synthetic native terrain. Its comparison establishes:

- all twelve rampart/corner/gate authored outputs for the four frozen-gate capitals are byte-identical before and after this candidate;
- the four gate outputs exactly reproduce their frozen digest and cell count; and
- pre-CAP projections remain separately identified where they differ from historical engine expectations, rather than being promoted to new baselines.

The evidence records the full WP13 LuaJIT development suite PASS, the strengthened integration fixture PASS and parser/static checks for all changed Lua. Sweep hits are comments/string delimiters and tool-only `os.exit`; no production portability issue is introduced. `git diff --check` reports only three preserved trailing-tab rows in the immutable WP13 evidence TSV.

## Verdict

**CLEAN SOURCE**, 0 High / 0 Medium / 0 Low.

The change provides the missing independent cadence coordinate, scopes explicit values to the eleven affected authored runs, preserves all other geometry inputs, and binds phase semantics into validation, identity and the real writer path. The evidence is meaningful for source projection and oracle consistency.

This verdict does **not** close the historical overlay deltas and does not claim the overall capital engine gate. The corrected six-capital engine fleet and independent attribution of historical old/new outputs remain required on the integrated candidate.
