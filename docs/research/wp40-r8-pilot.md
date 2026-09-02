# WP40 R8 real-engine pilot record

**Status:** ten attempts retained. Attempts 1--4 stopped during
production construction; Attempt 5 exposed and corrected the fresh-engine
read-only halo; Attempt 6 measured and removed redundant native pilot rows.
Attempt 7 completed both schedules cleanly and isolated a real surface-light
defect plus wall-clock liquid aging in the comparison harness. Attempt 8
confirmed the liquid correction and reduced the remaining surface defect to a
fresh vertical `CONTENT_IGNORE` halo above the owner. Attempt 9 confirms the
narrower lighting correction, complete order equality and every G2 gate.
Attempt 10 generated nearly the whole complete corpus without a mapgen error
but correctly failed at the fixed two-hour G3 boundary. The approved
replacement G3 uses two complete forward/reverse shard pairs and four workers.

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

The correction was committed as
`f2599f8af974e66705981139c3b270c92e341643`. A fresh independent GPT-5.6 Sol
review accepted it for the next sequential pilot with **0 Critical / 0 High /
0 Medium / 1 Low**. The Low finding concerned stale territory-only wording in
guard-post comments and one diagnostic; the logic and regression coverage were
accepted. That wording is folded into the next production correction rather
than causing an otherwise byte-only rerun.

## Attempt 5 -- first generated-mapchunk failure

- Date: 2026-09-02
- Candidate: `f2599f8af974e66705981139c3b270c92e341643`
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `0866a31a63cb5b54c602b9e7b5c1483bf05191a9496147c72abb9dc6cdeb86ae`
- Result: startup, production manifest and authority passed; the first
  production mapchunk entered the R7 writer and failed during lighting;
  reverse order was not started
- First request: `human_capital`, mapchunk `-32,-32,-1552`
- Emerge result: 1 errored action and 124 cancelled actions after
  83,989,724 microseconds
- Process result: exit 1 after 2:49.73; no swap; the probe recorded an engine
  RSS peak of 3,027,841,024 bytes
- Failure: `fail_content_ignore: required light context is ignore`
- Forward console-log SHA-256:
  `9c41106ee20dd3c8a2d6c2c3152b3769af8a15410864154733dbf089f11604e4`
- Forward server-log SHA-256:
  `2fde9aa9b95d8d6bff5dec3d67881c3e7b7d4e6aef7e19a51d639a1fe535423b`
- Forward event-stream SHA-256:
  `a2c84f5de0e89ba0a7481d9bed1bd8c57cce68132eb816661fc1b7d1f9340791`
- Forward GNU-time log SHA-256:
  `c9cccebe1b5e3bea9e3079b2c724058b11109d24c9102edd7259202d7fdc2fe6`

The launcher's 19,264 KiB peak is not the engine RSS because Flatpak starts the
engine as a descendant. The in-process probe values above are authoritative.
No order equality, corpus-content, native-event, timing projection or clean
shutdown claim is accepted from this attempt.

Pinned Luanti source and an independent hard-lens show that this is not an
emerge-request sizing defect. A fresh border MapBlock starts as
`CONTENT_IGNORE`; v7 fills the central mapchunk while the 16-node VoxelManip
border remains read-only lighting context. Native `spreadLight` skips ignore.
The runner correctly requested one 80 cubed mapchunk, and the first of its 125
MapBlocks caused the containing chunk to be generated, explaining the one
error and 124 cancellations.

The minimal correction admits ignore only outside the owner in both the pure
R5 adapter and the consolidated R6/R7 writer. Central owner ignore remains a
hard failure. The fresh-halo fixtures require every halo content, `param2` and
light byte to remain unchanged, while existing materialized-neighbor cases
continue to cover committed halo input. A fresh independent review and a new
sequential pilot are mandatory before any G2 claim.

The strengthened intermediate LuaJIT micro-KAT passed with internal digest
`4663822a7adaf9112c7da73c5725e28330d1cc809dd546091d384dc331f02a5f`
and output-file SHA-256
`7c300628ca09d7541b8ddb2f0ab384059fb6838b5f661bd89232bebaa88e1215`.
The production-shaped full owner-VM integration also passed. Its receipt is
byte-identical to the already-retained projection integration receipt, SHA-256
`1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010`.
Thus the fresh-halo fixture changes no accepted central content, `param2`,
light, run, ledger, replay or manifest evidence. The prefreeze source audit
passed with input-set SHA-256
`98fad808c48a32fcb87d06b2b8680dc2a0c7393ab59eeb34e9d94f607b9148ca`.
The final PUC 5.1/LuaJIT pair remains deliberately deferred until successful
real-engine G2/G3 execution freezes the eventual production bytes.

## Attempt 6 -- measured pilot timeout

- Date: 2026-09-02
- Candidate: `ded5a30eba299e1367980c5e07f3c6222c7f0376`
- Review before execution: **ACCEPT, 0 Critical / 0 High / 0 Medium / 0 Low**
- Mode: sequential, Seed `0`, forward order first
- Capture ID:
  `5872815007eb278af3f976041e8166ebb72ca4e75e1f36e70d833e1313981f09`
- Result: five of eight forward requests generated successfully; fixed host
  timeout then stopped the sixth request; reverse order was not started
- Process result: exit 124 after exactly 15:30.00; no swap; the probe recorded
  an engine RSS peak of 3,837,706,240 bytes
- Completed emerge times: capital 189,426,057 us; channel 25,654,300 us;
  exact deep resource 255,431,811 us; native grid cells 176,599,864 us and
  162,147,782 us
- Forward console-log SHA-256:
  `1c80c1866e335526c9078ee721ca6d35c9ce6969a78c62b9d5889b9ee04be9c6`
- Forward server-log SHA-256:
  `4e7ff2b94fd6db6e9ec8fabc1c796142ddfa88dea0518e4b6a8d58e22ce9a30b`
- Forward event-stream SHA-256:
  `b577bf5e01ba5606430c24537966ff9507d76af192e05d2d1a5faa98e58cc7c8`
- Forward GNU-time log SHA-256:
  `5adc59c8a1426bde57af0d13c3a037ffd1ace417bccf8db1afce541ea3c28c0e`

This is a run-budget finding, not a content or writer failure. The three
feature classes and two native rows all returned one generated MapBlock plus
124 in-memory actions; no request errored or was cancelled. There is no clean
shutdown, reverse-order or G2 acceptance claim from the timed-out capture.

The native pilot had five adjacent cells at the same y band, all exercising
the same notification plumbing and none carrying a pilot cave/dungeon event
requirement. Keeping only its first declared cell retains every distinct G2
risk class. From the observed timings, startup plus the three features and one
native cell project to roughly 12--13 minutes per order, below the unchanged
15-minute engine timeout plus 30-second host margin. The full 32-row G3 native
corpus and its blocking event/census requirements are not reduced.

## Attempt 7 -- complete pilot with two isolated findings

- Date: 2026-09-02
- Candidate: `230925ada8bbb4c332d590f54d40811f9d379ad6`
- Review before execution: **ACCEPT, 0 Critical / 0 High / 0 Medium / 0 Low**
- Mode: sequential, Seed `0`, forward order first; three feature requests plus
  the reviewed one-row native prefix per order
- Capture ID:
  `d195544726546baff668b836f72e21c3f2bc8dce9807b9b10f3b624f86dcdbce`
- Process result: both engines exited 0, both controlled shutdown records are
  clean, both error logs are empty and all eight requests completed without an
  errored or cancelled action
- Forward: 12:04.26 wall, 641,157,033 probe microseconds and
  3,755,995,136-byte in-process peak RSS
- Reverse: 12:55.81 wall, 688,381,577 probe microseconds and
  3,749,015,552-byte in-process peak RSS
- Comparison SHA-256:
  `b643d34ef470396ab7ac2cb18829eb3fc80daa2659e0957bfdf65d869b434087`
- Forward console/server/events/time SHA-256:
  `69a479ee3a643a212057fa95f49258777b34fb16afde4b1b8833494c5ba7d488`,
  `09a91c0dcbab74f7ee43ac11fa800486b1b32a9fc2aa1fc7501b48c6c462cecc`,
  `13429f4da8bfefac745ad27f7aa5a55d1da438faa1c525aa13ea841be003b755`,
  `cfcc69bf78421b01c09f3cb732167bfb047f3708c466537e92f58036cbd8b19e`
- Reverse console/server/events/time SHA-256:
  `55773034d43d9a9b025faeb3ce94613285a871eaa454312c9df91f71aa3dd82b`,
  `72950df0f5a08a47fc3e1502bbf16f2c3368a68ec84eb5df6a228efe02ecfac6`,
  `15239413a57cc9f04ad02d4d7b45be80368a614f141c5bec9b2eba71b404d826`,
  `f6ac27edf2093f5451eb96b373447c7fe85afb3ead1a08a22d3be49803445f09`

Startup/engine/seed identity, exact order reversal, feature content, native
census, light digests, source-bound content witnesses and all completed pilot
plumbing agree. The one native row also observed the same large-cave begin/end
notifications in both orders; those events remain non-required in G2.

Two gates correctly prevent acceptance:

1. The open Wyrmglass surface channel contains all 64 sampled water sources
   but every packed light byte is zero. The capital's maximum day/night light
   is only 6/6, emitted by its guard banner, so the former `day_max > 0` check
   did not establish sunlight there either. Pinned engine tracing shows that
   v7 lights temporary geometry before WP40 replaces it, while the inherited
   `propagate_shadow = true` preserves that stale overtop shadow decision.
2. Only the deep-resource raw `param2` digest differs. Its content includes
   724 flowing-lava and 150 flowing-water nodes whose level/fall bits are
   mutated by the periodic server liquid step. The complete schedule is
   snapshotted afterward, so forward and reverse expose those nodes to
   different minutes of world simulation even though content, light and
   semantics agree.

The smallest correction keeps the corpus and comparison strict. Surface light
boxes use the engine's `propagate_shadow = false` boundary only when their top
is above fixed water level 1; deeper boxes retain true, the existing box and
owner/halo rules remain unchanged, and the runtime witness now requires
authored air with packed day/night light 15/0. The disposable server also sets
its periodic `liquid_update` interval to one second beyond the fixed host
timeout. Immediate `finishBlockMake` liquid processing remains active and all
cases are still snapshotted only after the full schedule, preserving the gate
against later requests changing earlier chunks. A fresh reviewed pilot must
confirm both corrections; Attempt 7 itself carries no G2 acceptance claim.

## Attempt 8 -- liquid correction confirmed, surface ignore halo isolated

- Date: 2026-09-02
- Candidate: `2c08f756c899bcc90a60f441c2d05c68b5f7aae4`
- Review before execution: **ACCEPT, 0 Critical / 0 High / 0 Medium / 0 Low**
- Mode: sequential, Seed `0`, forward order first; three feature requests plus
  the reviewed one-row native prefix per order
- Capture ID:
  `f50e4f967d9347b649d1cc1cc28e3acbf37a15474fcdafdc80aa020755f1f57f`
- Process result: both engines exited 0, both controlled shutdown records are
  clean, both error logs are empty and all eight requests completed without an
  errored or cancelled action
- Forward: 12:36.28 wall, 678,632,254 probe microseconds and
  3,894,722,560-byte in-process peak RSS
- Reverse: 12:13.76 wall, 643,291,844 probe microseconds and
  3,932,262,400-byte in-process peak RSS
- Comparison SHA-256:
  `5aebe5ddeba1a85ee5de15fb7fc207d582e45fffba2baab3e477f95fce5bb10f`
- Forward console/server/events/time SHA-256:
  `1c8c0deb55eaa69a9fecfcdf06695af6068134ef4e5241a912643e83a64e60db`,
  `502d3094609bf5511664a887b76c37b50dbf3a48973c3b5c4f5b535173deeab6`,
  `732bd27bc2186014d495b5d88930c29875308e41fe1ebf8ab2434ca8439980f6`,
  `0bd0aa199c67cc9b86a9bc9bdef2c0bfe433f88483118466a5e580efb7179f39`
- Reverse console/server/events/time SHA-256:
  `100124d9d0317c62e372f0a987a2bf16df9602d08ef950b9f74d00ad79f92fdb`,
  `195f6660aa866ed852330ae9f2d699addb5eea18fcde3170b71f9afcea4c1e9b`,
  `cd42c784fd3de33ea0148dec727cfc78fb202006bc36747a8972a4cb8d2b3d8d`,
  `f72106892d8e48dfb2e783e85a03d764d480543fbeaffdac5a1513a270b2e254`

Every order, startup, native, completion and clean-shutdown gate passes, and
the complete snapshots are byte-identical across the reversed schedules. In
particular, the deep case now has the same raw `param2` digest in both orders:
`8b94d3fc51180c3a1f27611b28e8825fdf0522ba20962b2fd5c4e6731f443c4f`.
This confirms the periodic-liquid deferral without weakening final-schedule
comparison or immediate mapgen liquid processing.

The sole failed semantic gate remains surface sunlight. The capital contains
no direct-sun air and reaches only emitted day/night light 6/6; Wyrmglass has
zero direct-sun air and zero light throughout. A fresh independent source lens
found the remaining boundary: `propagate_shadow = false` skips the old
overtop-shadow test, but `calc_lighting` still starts at the enlarged light-box
top. On a fresh mapchunk that top is vertical `CONTENT_IGNORE`, whose node
definition does not propagate sunlight, so the scan stops before reaching the
fully authored owner.

The next correction retains the existing enlarged zero/spread/restore box but,
for the surface-only false path, caps only the `calc_lighting` top at the owner
maximum. Deep boxes keep their original maximum and true propagation. Fixtures
must distinguish the two call boxes, retain an in-owner opaque blocker and
prove every ignored halo byte is restored. Attempt 8 itself carries no G2
acceptance claim.

## Attempt 9 -- G2 accepted

- Date: 2026-09-02
- Candidate: `050ae36bed447c873f7df1ef43f04e73517d89bf`
- Review before execution: **ACCEPT, 0 Critical / 0 High / 0 Medium / 0 Low**
- Mode: sequential, Seed `0`, forward order first; three feature requests plus
  the reviewed one-row native prefix per order
- Capture ID:
  `73da938db983ef34147733882648f7e5523a8f4d649a8b6428f6209f7ab9e944`
- Result: **PASS**; `equal = true`, `semantic_ok = true`, every startup,
  native, order, completion and clean-shutdown gate true, both error counts
  zero and both process exit statuses zero
- Forward: 12:29.78 wall, 662,351,833 probe microseconds and
  3,869,286,400-byte in-process peak RSS
- Reverse: 12:24.78 wall, 661,244,269 probe microseconds and
  3,787,358,208-byte in-process peak RSS
- Comparison SHA-256:
  `88b33d4d378a8471b43450634aa6b976eaf8c6677d956e350a43f08e95597ceb`
- Manifest/checksum-list SHA-256:
  `07a175cb56ecd99140ad906b1282e10f3ea03e56e38c9f01872f43509f08ccf5`,
  `7a6badbcf10decb5dfe1e4f7a6928835c3823e521d6004545c4e657298efa701`
- Forward console/server/events/time SHA-256:
  `f76faa954fb5255bb2ca781fee29ff0dbbeba7eebdc416a8fabe96989085ca0e`,
  `de7cf1aa0c8dea7556908b2dbd17330203eb24551b5734d967586bbdbf27dbe3`,
  `e967d5e6825dcb6e5fac277726099467d60e3bde399f85ec376f531d0c224e4a`,
  `fef1720fa3247faf1f29b5d9005b87502b160b95ed760ec5028de7a8df791117`
- Reverse console/server/events/time SHA-256:
  `6f3275cdc7b3db01160a3395ab4c59647b4ff6418897f5d1128681de2be98e4f`,
  `ea2a80135d9cc62e187eccb3018c377546c8250a692c64006df739cdc058653e`,
  `b7020bf9457d79c1f846eabf2ee5b53327d29436db92f10fb16a64d700a48741`,
  `e1bc1bf77ac03bd4242669a07b98bf87e9c9c61de2712e504a51c65ffb20780f`

The corrected surface results are byte-identical across order. The capital has
70,916 authored-air voxels at direct day/night light 15/0 and light SHA-256
`9e5c907fb45a6de6951b4296c5682357ef89be8e425443594e2af5c6a8545ebc`.
Wyrmglass has 294,400 direct-sun air voxels, all 64 source-bound channel cells
remain water sources, and light SHA-256
`288c90e68a7f1901d1f5326c795d8cec6bba3e7ccc9504012a24a3eb1028a814`.
The deep case retains identical content, light and raw `param2`, including the
previously confirmed `param2` digest
`8b94d3fc51180c3a1f27611b28e8825fdf0522ba20962b2fd5c4e6731f443c4f`.
The pilot therefore accepts the owner-top and periodic-liquid corrections and
closes G2. It does not claim the complete G3 feature/native corpus.

## Attempt 10 -- complete-pair timeout

- Date: 2026-09-02
- Candidate: `4ca1c6564382c1e4ab726fd60a38c3b4461dba05`
- Review before execution: the exact 10+32 corpus and two-hour enforcement had
  focused independent **ACCEPT, 0 Critical / 0 High / 0 Medium / 0 Low**
- Mode: final, Seed `0`, two concurrent engines; each requested the full ten
  feature plus 32 native rows in forward or exact reverse order
- Capture ID:
  `5ff10a91da1d2b6944377902ed4ee7b89027995f9a42051244ba94548a48f502`
- Result: **FAIL (budget)**; both engine wrappers exited 124 at exactly
  2:00:00, so no completion, controlled-shutdown or order-comparison claim is
  accepted
- Forward: 39/42 complete; all ten features, the 25-cell native grid and the
  first four stratum slices completed; event-stream SHA-256
  `0ff3021e2667ff8d8a3862766955316ba30ba5e2ee0c036ca1308b1bff434139`
- Reverse: 40/42 finalized plus `goldmead_inland_housing` completely written
  to the retained partial stream; the full native corpus, native grid and
  eight feature rows completed; finalized/partial event SHA-256
  `f55bfac2fe562e7b0415933ed6b0fb2300a2499cff1cbf332f858825564cd549`
  and
  `1f3a32983b03836b03f7a13e0180230207a73dbf53f820fc33dade391612f143`
- Forward console/server/time SHA-256:
  `8b3b92da2f27cda7cb15f183a1203b801e180b226fd754037cc13ee4e929baf1`,
  `f09f2d058b5bb0d39d688c4dfd1d9c75113ac85ed476a2e1c2e37d0966e020c5`,
  `e7803a636d1bffc1292f39b70913eda5aa5795f0852abade8dfa017f9f3fa52b`
- Reverse console/server/time SHA-256:
  `cdb90e312fbc1040ada68efc4815ef4cf9bb339efc2dbb2cb06b1b6e676fb157`,
  `a5964c8b81050dcf44fbe71178500aaa2c1551775a2f41ec46fc9595d3876149`,
  `6cecdecfa067c3c627eb5926a4a3078c69ed96cc96450cb3304bbd01b28ccb35`

Every finalized emerge returned one generated plus 124 in-memory actions and
no cancelled or errored action. The timeout wrapper ended before the probe
could snapshot and emit the native/event aggregate, so the partial run cannot
establish any final semantic or native gate even though its completed requests
are useful timing evidence. The disposable worlds were removed; all unique
logs and partial events remain in the permanent ignored result directory named
above, whose total retained size is 119,213 bytes.

The server-log errors were emitted only after the hard timeout: the old Flatpak
wrapper could outlive the observed command long enough to attempt database
writes while scratch cleanup removed its world. They do not describe an emerge
failure, but they expose a harness teardown defect. The replacement worker uses
Flatpak's `--die-with-parent` boundary before scratch cleanup; clean successful
shutdown remains mandatory.

The approved release approximation retains every input row but divides the
real-engine order proof into two coherent pairs: ten feature rows and all 32
native rows. The native pair deliberately keeps the contiguous 25-cell event
grid together with all seven adjacent stratum/ore census slices. Four engines
run concurrently on distinct ports with one emerge thread each, and a final
deterministic receipt requires the two pairs to cover 42 unique IDs plus one
identical checkout, Seed `0`, engine and production manifest. Within-shard
later-request mutation remains covered; feature-to-native cross-shard mutation
is the explicitly accepted residual risk. Observed timings project the native
pair at approximately 101--106 minutes and the feature pair at 24--26 minutes,
below the two-hour operational target. Per the user's post-timeout direction,
that target no longer kills a nearly complete run: the replacement uses a
10,770-second probe timeout, a three-hour host safety stop and a 10,801-second
periodic-liquid boundary.
