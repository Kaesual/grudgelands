# Round 19 execution ledger

2026-09-23. **Active, explicitly approved.**
Baseline: `3b23a8f8` on main. Contract: [round19-plan.md](round19-plan.md).
Integration branch: `wp19-atlas-interface-fixes`. Root native Astra;
three parallel native workers, no provider CLI or Claude.

| Lane | Model | Branch/worktree | Status |
|---|---|---|---|
| A atlas | Astra | wp19-map / /tmp/grug-r19-map | integrated c9e8c95c; independent Astra PASS |
| B menus | Sol | wp19-ui / /tmp/grug-r19-ui | integrated with spacing/Help corrections; independent Sol PASS |
| C party/status | Sol | wp19-hud / /tmp/grug-r19-hud | author db9d9927 integrated; independent Sol PASS |
| D dragon bars | Sol | C lane after C | integrated 0b90752a; High billboard-size correction in progress |

Root owns living docs, final integration/gates and receipt. Authors own only
assigned code/tests plus their lane report. Independent reviewers have no
implementation authorship in reviewed scope. Final one compact PUC/LuaJIT pair
only after frozen bytes; no world-generation or PERF campaign.

Remote push is still blocked by automatic approval review from Round 18;
new round Go authorizes implementation, not a bypass of that block. Local main
merge/sync is authorized. Keep remote delivery pending unless renewed explicit
permission is received and accepted.

## Integration notes

A author `15d86299`; root `c9e8c95c`. Reviewer `r19_review_map` independently
reviews frozen c9e8c95c at /tmp/grug-r19-review-map. Native scrollbar focus and
stationary-thumb/live-refresh interaction remain explicit user GUI checks.
Higher-resolution world raster inspected by root; no new world geometry.
C author `db9d9927` integrated; D continues in the same isolated author worktree.

A independent review PASS, 0 C/H/M/L; /tmp/r19-review-map.md. B initial candidate
2f7b1ba9 integrated 0db5c853; reviewer r19_review_ui owns B/C. Root identified
possible Skills mount-row/passive-heading overlap introduced by hint insertion;
confirmed and fixed in author e9feef38 / root 7d9fca99; the generated-form
fixture checks mount-bottom versus heading-top using the engine coordinate ratio. Root also requested
C fixture load actual hud_layout rather than asserting a hardcoded anchor and
exercise expiry/leave paths; author includes that bounded test correction in D.

B Help wording Low corrected (author7875b336/root0d7e53a7). Final B/C review
snapshot17786aef includes both Bcorrections and Cfixture correction. D author
d823b0ce integrated0b90752a; report17786aef. Wyrmglass/Stormscale world anchors
5/4, both bars3x0.25. Ordinary bars retain their existing conversion unchanged. Reviewer r19_review_map
independently checks D plus living-doc drift; A production remains unchanged.
Final fixture roster: r19_map/micro.lua, r19_ui/fixture.lua, r19_hud/fixture.lua.

Independent D review found native billboard dimensions do not inherit parent
scale, unlike attachment positions. The explicit dragon override must retain
world width/height without division; Sol author is correcting code, fixture and
report. The generic bar path remains unchanged in this round. Root corrects the
living spec and historical talent-test wording. Focused independent re-review
is required before final gates. B/C final review PASS at 17786aef; initial one
Medium (Skills spacing) and one Low (Help wording) are closed.

The initial isolated native registration check passed in
/tmp/grug-r19-integration-p7mne4_m. It verifies registration metadata, not client
sprite rendering, and predates the D correction; it is development evidence,
not the frozen final acceptance run.
