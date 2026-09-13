# WP13: first Hearthpine settlement increment

Status: first increment independently reviewed and ready for native GUI
playtest, 2026-09-13.
Non-trivial package. WP13 as a whole remains in progress.

## Authority and scope

The user selected the dwarf start in Hearthpine Vale and an inhabited craft
settlement with a small guardpost. Decided appearance and scope live in
[settlements.md](../design/settlements.md). The fixed identity, envelope,
road and protection contracts remain [world_zones.md](../design/world_zones.md)
§12 and [world.md](../design/world.md) §2 R1. No open design TODO blocks this
architecture-only increment. This starts WP13; it does not complete its
six-race, capital, NPC and camp scope.

## Construction contract

- Use `anchor_001` at x = -1800, z = -2550 and its existing fitted integer
  surface height. Preserve the public spawn at anchor y + 1. Keep a solid
  arrival floor, headroom and a clear route toward the +z road gate at z + 64.
- Author one deterministic blueprint from existing registered stone, pine,
  glass and lighting nodes. Include a workshop, two homes, a timber workyard
  and a modest gate watchpost. No imported media or new vendored dependencies.
- Local blueprint cells are unique and canonically ordered z/y/x, with
  explicit node name and param2. Bounds fit x/z [-63, 63], y [-2, 24].
  Palette names are sorted and bound alongside blueprint semantics in the
  production manifest. Geometry is resolved once during construction.
- Clip cells to each generated owner in all three dimensions. Integrate a
  bounded structure successor into the existing R7 tail, after P9G/anchors
  and before the shared VM commit. No extra `on_generated`, VM setter,
  neighbor writes, deferred placement or load-time regeneration.
- Explicit air cells clear building interiors and essential paths. Preserve
  ground outside authored plots. Feed content, param2, occupancy and intent
  metadata through the existing run, lighting and liquid accounting.
- Fix the existing source's 128-wide hard start footprint to 148, including
  the already-decided ten-node apron. Use the existing protection authority,
  not an additional protection handler. Keep y = -700/-701 precedence.
- Do not use `camp_fire` or `guard_banner` as decorative props: they activate
  existing mob-spawner behavior. No new NPC, quest, profession, storage or
  travel mechanics. No old-world compatibility or migration code.

## Ownership and routing

The coordinator owns scope, docs, independent acceptance tests, integration
and final judgment. Two bounded GPT-5.6 Sol implementation lanes use isolated
worktrees: one owns the pure architectural blueprint; the other owns the
R7 content/manifest/successor/writer integration and protection correction.
Their common interface is the blueprint's schema, canonical cells, bounds,
palette and descriptive landmarks. A fresh independent strong reviewer
reviews the combined increment under the process checklist before main.

## Verification budget and acceptance

Follow [luanti-lua.md](luanti-lua.md)'s interpreter strategy: LuaJIT for
development and engine-backed runs; luac51 parser, SETGLOBAL and all five
static sweeps on changed Lua, explicitly including tools. At most seven
independent Lua processes run concurrently workstation-wide at idle priority.
No intermediate PUC runtime. Frozen final bytes receive one compact PUC/LuaJIT
micro-KAT pair with byte-identical canonical output; reviewers inspect its
evidence instead of rerunning PUC.

Acceptance covers real runtime/authority manifest agreement, exact protected
apron edges and depth precedence, spawn and gate connectivity, building
entrance/interior clearance, unique cells and palette validity, clipped
placement across horizontal and vertical owner boundaries, param2, lighting,
generation order and disk reload. Local headless engine runs use temporary
fresh worlds; the Rehearsal VM is not used. Existing historical WP40 fleets
are not rerun. Final native GUI appearance/walkability remains the user's
focused playtest, followed by the decision whether to extend the style.

Stop and report any conflict with the single writer, public anchor identity,
protection authority or an unapproved functional system. Small reversible
architectural choices inside the selected style need no new user decision.

## Delivery and calibration

Candidate `f9cf215` (base `66f2068`) contains the blueprint, two architectural
corrections, R7 integration and acceptance fixtures. The production code was
implemented by GPT-5.6 Sol in two bounded worktrees; the coordinator authored
scope, acceptance tests and integration documentation. A fresh independent GPT-5.6 Sol reviewer returned **CLEAN / ACCEPT**, with
0 Critical / 0 High / 0 Medium / 0 Low findings and zero review fix rounds.
The Opus route returned HTTP403 `oauth_org_not_allowed` before reviewing any
code; no Opus verdict is claimed. Calibration: implementation GPT-5.6 Sol,
review GPT-5.6 Sol; elapsed wall time `unknown`. WP13 remains in progress
after delivery. The full review record is included with the evidence.

Evidence: [tools/wp13/evidence/20260913-hearthpine/](../../tools/wp13/evidence/20260913-hearthpine/).

- The pure blueprint has 30,593 unique cells, including explicit clearance,
  14 palette entries and 13 supported torches. Five interior destinations,
  including the lookout, pass the conservative walking/one-node stepping
  reachability check; the north route has five clear columns across its width.
- The clipped successor fixture partitions all 30,593 cells exactly once into
  eight owner cubes with both horizontal and vertical boundaries. It also
  verifies an unrelated owner writes nothing. Blueprint identity:
  `e3994155b1e2049bacce3c0bf9007f21b04125f38be5218f6f3d5b2d49072daa`.
- Luanti 5.17 with LuaJIT generated two independent fresh ten-owner corpora
  for seed `531802985935182545`, in forward/reverse order. Each was loaded
  again from disk with **zero generation callbacks**. All authored names and
  param2 values match; nighttime lighting is positive at every torch and
  interior destination. This seed places the start surface at y = 9.
- One explicit test-only administrative edit replaces an arrival-space air
  cell with glass after the cold run and must survive disk reload. That cell
  is excluded from the comparison digest, with its changed value checked
  separately. The other 30,592 cells have the same digest in all four runs:
  `a71d6c71523e6e9ba1d375355da89fdf42af245d270b583b15428cc40d8a2049`.
- Engine queries check all six start aprons at their half-open corner edges
  (-74/+73 inside, -75/+74 outside) and the -700/-701 depth precedence.
- Twenty changed Lua files pass the plain-5.1 parser and have no SETGLOBAL
  instructions. The five source sweeps contain only existing comment/string
  matches. Final frozen micro-KAT: one PUC5.1 and one LuaJIT process, 268 rows
  each, byte-identical SHA-256
  `393e3feaf56afa85b40815b3cea4ca982031b391f30cb3d7fce92df48dd41197`.
  The separate LuaJIT production manifest constructor also passes.

The schematic preview uses symbolic colours, not engine textures. GUI
appearance, movement feel and the decision to extend this style remain the
user's focused playtest. These bounded checks do not discharge WP40's broader
first-public-release resource/order/runtime obligations.

## User runtime test

After reviewed merge and sync, create a fresh world and choose a dwarf.
For the tested seed `531802985935182545`, the arrival position is
`(-1800, 10, -2550)`; other seeds retain x/z and fit their own y. Walk through
the workshop, both houses, workyard and the lookout stairs; follow the main
street out through the guardpost. Inspect the interiors at night, leave and
reload the world, and report appearance or collision issues. Ordinary players
should not be able to dig the settlement or its ten-node apron; an admin with
`protection_bypass` is intentionally exempt. This increment has decorative
furniture and guard architecture, without new NPC or workstation services.
