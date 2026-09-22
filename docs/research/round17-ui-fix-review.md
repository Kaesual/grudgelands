# Round 17 C/D/E focused fix review

Verdict: **MERGE**. L1 is closed.

Reviewed integrated correction `3deb8057` against the original finding in
`round17-ui-review.md`. The correction changes only the PARTY fixture and its
implementation report; C/D/E production code is unchanged. Reviewer: native
Sol, independently re-reviewing correction `f9a8d357` authored by native Sol
`/root/r17_disposition` and cherry-picked by root as `3deb8057`. Review elapsed
wall time: unknown.

## L1 closure

`tools/r17_party/kat.lua:79-121` now loads the real
`mods/PLAYER/grug_parties/ui.lua`, captures the page registered by that module,
enters it, and renders its production content. The fixture asserts the exact
selected `;2;true` dropdown and fixed top-right coordinates, then invokes the
real `on_player_receive_fields` callback with:

- `"1"`, proving the production callback selects and persists `all_green`;
- `"2"`, proving it selects and persists `by_class`; and
- `"bad"`, proving validation refuses the field, preserves the prior mode and
  reports the refusal.

This exercises the seam that L1 identified rather than reproducing its parser
inside the test. The updated claims in `docs/research/round17-party.md:27-36`
now match the executable evidence. The bounded targeted run passed:

```text
round17-party  16
```

`git diff 3deb8057^ 3deb8057 --check` was clean. No PUC runtime or broad suite
was run; root retains the final integrated parity and native GUI gates.

Final findings for the reviewed C/D/E package: Critical **0**, High **0**,
Medium **0**, Low **0** open. Original findings: **0/0/0/1**. Fix rounds:
**1**. No new findings.

Calibration: implementing model native Sol for C/D/E; correction author native
Sol (`/root/r17_disposition`); independent reviewer native Sol; non-trivial package; initial
Critical/High count **0/0**; one fix round; implementation and review elapsed
wall times unknown.
