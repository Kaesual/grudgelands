# WP13: first Hearthpine settlement increment

Status: implementation in progress, 2026-09-13. Non-trivial package.

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

Pending implementation and independent review. Record final commits, evidence,
implementing/reviewing models, Critical/High findings, fix rounds and observed
elapsed wall time here before merge. WP13 remains in progress after delivery.
