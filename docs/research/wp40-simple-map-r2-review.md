# WP40 Simple Map R2 Independent Review Record

Status: **CLEAN**. No open R2 findings remain.

## Reviewed change set

The reviewed R2 tree is based on branch revision
`4eb1d1efb169496c80b4e79d85e33e72e4019c92`. The change set freezes the
accepted V1d horizontal source, implements the allocation-free production
classifier, adds exact metadata/core/water/route/grid/housing validators and
publishes the canonical R2 artifact and SVG. The implementation, evidence and
this closeout record land together; the review was performed against the
complete uncommitted tree before that commit.

The initial independent reviewer was the user-authorized Claude Opus model at
xhigh effort. Focused correction reviews used GPT-5.6 Sol at xhigh effort in a
fresh read-only context. Neither reviewer participated in implementation, and
neither changed repository files.

## Findings and resolution

The initial full review returned **REJECTED**, with **0 Critical, 0 High,
3 Medium and 7 Low** findings:

1. The four coastal-core promises were metadata rather than realized and
   exhaustively measured classifier geometry.
2. The live rebase plan did not yet distinguish historical V1d evidence from
   current R2 evidence or carry a complete R2 closeout record.
3. The required absolute and WP18-relative classifier benchmark was absent.
4. Realized bay width was not derived conservatively through the warp.
5. Per-reach hydrology evidence was absent from the canonical artifact.
6. The grid validator retained dead owner-label state.
7. The R2 shell runner lacked the production runner's `os.execute` guard.
8. The sole nonzero zone bias was not bound as an exact roster.
9. Route difficulty omitted locally owned planned-water spans.
10. One validator initializer was an unnecessary Lua declaration hazard.

The first correction round realized the four coastal guarantees as exact
mutable vertical capsules, scanned every capsule member and wholly contained
101 by 101 centre, added the canonical evidence/digest and comparative
benchmark record, and closed all seven Low evidence/code defects. The focused
review confirmed those ten findings closed but returned **REJECTED**, with
**0 Critical, 0 High, 2 Medium and 0 Low** new findings:

1. The canonical SVG still drew each capsule's full rectangular envelope,
   visually promising 19,321 corner nodes per ordinary core that production
   did not guarantee.
2. The current engineering authority still said R1 was next and retained the
   retired 61-contact allowlist, omitted coastal-core precedence and required
   dry-only routes instead of deterministic planned-water grading.

The second correction round renders the exact rounded capsule envelopes and
updates the engineering authority to the implemented R2 classifier, route and
contact semantics. Its focused rereview returned **ACCEPTED**, with
**0 Critical, 0 High, 0 Medium and 0 Low**. Final disposition: **CLEAN** after
two correction rounds.

## Verification and canonical evidence

The authoritative LuaJIT R2 run validates all 46,093,601 horizontal nodes in
the 7,201 by 6,401 authored extent. It reports three land components, all 38
territories connected, 57 frozen routes, zero route/POI/ingress columns on
forbidden water, maximum adjacent and route difficulty delta 1 against limit
2, all 12 fixed cores, all 84 candidate sets, all four bays, both channels,
ten housing masks and 230 deterministic packing orders.

The canonical artifact body digest is
`73165e1ad9e9dd03bc608b544e5906a10df2bf7b2c23779b311ad3cbdadf4f7b`;
the complete artifact SHA-256 is
`02585d6644265e8889edb3311045d76c2dd7152700dff33563bd8daabc13c339`.
All 14 embedded executable-input hashes match the reviewed tree. The seed-0
KAT is
`0a945840673d3170ce545c3c12af1422dcd12da5398a88faaf39c42d5346056d`,
and the final XML-valid capsule-honest SVG SHA-256 is
`0739e7568a254b5883f8ed2d3fe4ac182056e017dc6d8274b441c5a27136dadc`.

Review and implementation gates passed Lua 5.1 syntax, zero `SETGLOBAL`, all
five Lua portability sweeps, shell syntax, deterministic LuaJIT/PUC 5.1 KAT
parity, repeated SVG byte identity, XML parsing, artifact arithmetic and
input-hash verification, `git diff --check`, and unchanged reference-submodule
pins. The final narrow review independently rechecked exact capsule
land/owner/exclusion/eligibility membership and 1,499,010 route-difficulty
edges without regenerating repository artifacts.

The published LuaJIT classifier measurement remains comparative evidence, not
a fixed acceptance limit. R3 still owns global height, actual terrain grading
of planned-water path spans, vertical relief, waterfalls/transitions, final 3D
anchors and the at-most-12-node coastal-housing relief proof. The real
fallback-engine GUI/runtime pass remains user-executed at the later runtime
gate.
