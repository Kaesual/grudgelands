# WP40 R8 real-engine pilot record

**Status:** four diagnostic attempts stopped before generation. Each exposed
one real-engine integration boundary that the mocked R7 evidence could not
exercise. Attempt 4 proved that contested outposts were being validated and
typed through political territory instead of their authenticated race-bound
garrison. The narrow correction and regressions are pending final review and a
fresh sequential pilot.

## Attempt 1 -- diagnostic failure

- Date: 2026-09-02
- Candidate: `a1dc04b89d6e54945fb3507bf92967c4d6c0a86c`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `981cf1169e5565128cb1bf50613182e016787835b9da779d8e89c7dd6ad83883`
- Result: stopped before mapchunk generation; reverse order not started
- Process result: exit 1 after 0.58 seconds; launcher peak RSS 19,248 KiB;
  these startup-only numbers are not a G2 projection
- Failure: `get_mapgen_setting_noiseparams("mgv7_np_terrain_base").spread`
  carried the engine's builtin vector metatable, which the R7 validator
  incorrectly rejected as non-plain
- Forward console-log SHA-256:
  `14938afdb49a6a669c8d3107106802ea565c6e17358a58e06ee7ca7873c1f222`
- Forward server-log SHA-256:
  `c785edab6bdf4247b7729b5803bfd9f128ddee95c08609d3f480bab954a8b2bb`

The disposable world was removed by the runner trap. The diagnostic logs and
exact input copies remain under the ignored but permanent
`tools/wp40/results/r8/<capture-id>/` tree; the hashes and conclusion above are
the durable repository record. No mapchunk, native-event, order-equality,
timing, RSS, shutdown or release claim is accepted from this attempt.

## Correction and rerun rule

The correction is deliberately narrow: accept a readback `spread` table only
when its metatable is exactly `vector.metatable`, while continuing to accept
the legacy/plain fixture shape and reject unrelated metatables. It changes no
noise value, seed, native registration or writer behavior. Because production
Lua changed, final frozen bytes require a replacement compact PUC 5.1/LuaJIT
micro-KAT pair. The complete sequential pilot must then run from a new exact
reviewed commit and will receive its own immutable capture ID.

The runner correction also writes probe events through the test-only trusted
environment into the exact durable capture directory. Its interrupt trap
stops and waits for parallel wrappers, then repeats the process-group sweep so
a late-published engine group cannot survive scratch-world cleanup.

## Attempt 2 -- diagnostic failure

- Date: 2026-09-02
- Candidate: `2cbe52748eaaa8bba1efbae83b2700bc1231c480`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `7171368d88152980ec26399c05f6abea51bb1577969852744a2644b679cc01f9`
- Result: stopped before mapchunk generation; reverse order not started
- Process result: exit 1 after 0.56 seconds; launcher peak RSS 19,004 KiB;
  these startup-only numbers are not a G2 projection
- Failure: the effective global and mapgen settings both returned the exact
  string `1`, but the R7 validator required the real `core.settings` object to
  have Lua type `table`; Luanti exposes its Settings object as `userdata`
- Forward console-log SHA-256:
  `9d145f2feef3e2cf79095642a9d33b6f4e626bc94d88e36ee71f0627d5bec47e`
- Forward server-log SHA-256:
  `8ce021e9c289037aa7ab42482dde60a5010e3e3296e4c4bf8de10999015319ed`

An isolated pre-loader diagnostic confirmed
`core.settings:get("num_emerge_threads") == "1"` and
`core.get_mapgen_setting("num_emerge_threads") == "1"`. The correction admits
the engine's userdata Settings object as well as the test seam's table, while
still requiring a callable `get` method and the exact string value `1`. The
final micro-KAT now models this boundary with a userdata proxy.

## Pre-pilot review of the second correction

The Settings correction was committed as
`354a01a024f6e7f965657a7108adadf3f972a1ec`. A fresh independent review
accepted that change itself, but rejected another pilot after proving three
remaining real-engine shape mismatches:

- `core.read_schematic()` returns `size` with the builtin
  `vector.metatable`;
- `register_on_generated` supplies `minp` and `maxp` with that metatable; and
- `VoxelManip:get_emerged_area()` returns both positions with that metatable.

The pure R6 planner/template/settlement boundaries intentionally reject
arbitrary metatables. The narrow adapter correction therefore accepts only
plain XYZ tables or the exact builtin vector metatable, checks an exact
three-field shape and passes plain tables into the planner/template seams.
The VM halo readback retains its exact coordinate, integer and bounds checks.
The production values and placement policy are unchanged.

Static R7 gates and an intermediate LuaJIT micro-KAT passed with all three
real vector shapes represented. Exact correction commit
`bc6386080cb14edbc34211e5108801fa2441f3df` then received independent
**ACCEPT: 0 Critical / 0 High / 0 Medium / 0 Low** for a fresh pilot.

## Attempt 3 -- diagnostic failure

- Date: 2026-09-02
- Candidate: `bc6386080cb14edbc34211e5108801fa2441f3df`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `3724a8afb09bbe8b0b28304379345d44c563d84ff2ffecf0071e80daa1860007`
- Result: stopped during production construction before mapchunk generation;
  reverse order not started
- Process result: exit 1 after 1:27.93; launcher peak RSS 19,040 KiB; these
  initialization-only values are not a G2 projection
- Failure: the production WP43 handoff's complete registry projection did not
  match the smaller historical R7 offline-fixture projection bound into the
  manifest
- Forward console-log SHA-256:
  `9a9a9583d91cfbdb4dbb48579465ca3ae20d02f294d1ced31cfe971e6a63dd22`
- Forward server-log SHA-256:
  `e364a8e9d2d866232d24d8f79c5cc09c626c68bb423c3b33e9ffc0b778352218`

An isolated diagnostic exposed every component digest. R6 catalog, accepted
content, decoded templates, cultural registrations and consumer payload all
matched their frozen values. Only WP43 differed: production hashes the full
`6/23/15/12/2/6/6/6/2` projection population, yielding
`c8088a4b6802c0fc1a74d8826e3df0bb49b64f9ab4c6e93bcbd66aa2a16b9895`;
the R7 fixture hashed only the placement-consumed subset. The correction makes
R7 tooling construct the actual production handoff and binds the resulting
aggregate source projection
`8f1eef2702c631451ee987b3eb4a267d117fcc3ce1d97947d4b6936e0ea3502b`.
It changes no registry value or placement consumer. A focused review, then the
replacement final PUC 5.1/LuaJIT pair and a fresh pilot remain pending.

The targeted LuaJIT owner-VM integration KAT passed with manifest
`9ff0e78818e842c578ecacbf9d5be4426ca72f6c3230f6184b0e8b23f69f369d`.
Its durable [R8 projection receipt](wp40-r8-projection-integration-receipt.tsv)
differs from the accepted R7 integration receipt in exactly that manifest row;
all content, anchor, 512,000 private-tuple, run, replay, multi-y and case rows
are byte-identical. The R8 receipt SHA-256 is
`1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010`.

The projection correction was committed as
`e81663a1b643653d39dadb4e04b23a59cd496d4a` and received a fresh independent
**ACCEPT: 0 Critical / 0 High / 0 Medium / 0 Low** before Attempt 4.

## Attempt 4 -- diagnostic failure

- Date: 2026-09-02
- Candidate: `e81663a1b643653d39dadb4e04b23a59cd496d4a`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `f4e7b1a88ed12dd0d50bbb4f4271252f39ca02f68b8197497711e711b74f67f4`
- Result: stopped during production construction before mapchunk generation;
  reverse order not started
- Process result: exit 1 after 1:31.10; launcher peak RSS 19,140 KiB; these
  initialization-only values are not a G2 projection
- Failure: `grug_core.prepare_zone_authority` rejected outpost row 3 because
  the validator required its coordinate to return the outpost's garrison
  faction from `faction_at`
- Forward console-log SHA-256:
  `58f92fe7f01b07e1763af03e829c21dc192bf8e8559e4a3d0039cd913e33f268`
- Forward server-log SHA-256:
  `0eef30a63987f0dfffe125440568479823ddf5adbba61a8c281a2a0eb93830ed`

The frozen row is not misplaced. It is the first of ten ordinary outposts in
level-31--40 contested zones. Those zones deliberately have no political
`faction`, while their `race_region` still assigns an Accord or Throng
garrison through the authenticated consumer payload. A production-session
diagnostic resolved all 24 stable anchors and confirmed that the ten frontier
rows return nil from `faction_at`; all still resolve to their exact source zone
and race region.

The correction replaces the invalid territorial assertion with an exact
`race_region_at` assertion. The existing hard-coded race-to-faction table
continues to authenticate every payload faction. The consumer KAT now models
both an Accord and a Throng contested outpost with nil territorial faction.
The same review found a downstream manifestation in guard-banner typing: a
contested Throng outpost would otherwise fall back to Accord. Banner typing
now prefers an authenticated `outpost_at` faction and uses `faction_at` only
for non-outpost banners; the final micro fixture covers both paths.

This changes production Lua but no anchor, placement, zone, resource or writer
semantics. Static gates, an exact focused review, a fresh pilot and exactly one
replacement final PUC 5.1/LuaJIT micro-KAT pair on the eventual frozen bytes
remain required.
