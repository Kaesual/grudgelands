# Capital polish implementation

Implemented 2026-11-10, after the user approved the decision gallery and asked to
close the additional gable-wall gaps. All work is in `character-creation`, based
on Round 71; main's concurrent Expedition work was not edited or imported.
**Map reset** is declared under provisional worktree version **0.72.3**.
Before integration, reconcile that patch number with the then-current main and
retain main's newer Expedition behaviour. No merge, push, installation sync or
world reset has been performed. The earlier character-creation implementation
and accepted decision snapshots are preserved.

Open [index.html](index.html) for actual-template captures and actual core maps.
These are captures from the shared web renderer, not native-client screenshots.
Rebuild with `python3 tools/capital_polish_study/implementation/gallery.py`;
this verifies the six image input/output receipts before embedding them. The
registrar maps read the current core export in `registrar/cores.json`.

## Shipped changes

- Six royal halls: lower throne, broad side-wall bays with joined piers, moved
  lamps, removed obstructing seats, ridge lowered half a node. The additional
  gap fix fills 36 gable-end upper slabs per castle with existing roof blocks,
  preserving their top surface: **216 gaps closed**. All points, footprint
  dimensions and roof extents remain. [Castle evidence](castle/README.md).
- Five core gate templates: 14 upper passage-corner stairs each change from
  facedir 1/3 to 21/23. Separate legend entries preserve the ascending stairs
  inside the guard room. Kezamba differs and is unchanged.
  [Gate evidence](gates/README.md).
- Six guild templates plus their authoritative generator: existing thin wooden
  `xdecor_table` nodes replace the high clerk table and detached desk supports.
  Eleven furniture cells change per template; all sockets remain.
  [Table evidence](tables/README.md).
- Six capital compositions: one dedicated inhabited `expedition_registrar` core
  socket each on the existing path at the waystone plaza approach, outside the
  reserved pad including its kerb. Four share (12,1,-12), Lethariel uses
  (28,1,-25), Kezamba (-36,1,-33), all relative to the core anchor. No extra
  building or terrain edits are needed for these positions. The registrar's
  service binding takes these sockets; the guild clerk stays an ordinary
  resident. [Locations](registrar/locations.json).

The normal map-reset contract handles regenerated capitals and NPC state. There
is no online building rewrite or old-socket migration. The historical Round 71
`old_world.sh` clerk-takeover probe is not applicable to this relocation; it stays
as historical evidence, not an acceptance claim for this change.

## All-building furniture follow-up

The user subsequently requested the same table fix across other buildings and
reported two beds through a wall in the Human start town. Implemented in this
same worktree and the same unreleased map-reset declaration:

- **153 additional templates, 575 table-width cells:** replace only explicitly
  paired `table_leg` / `table_top` cells with complete thin tables at the leg
  course. This changes exactly 1150 cells, preserving every point and other
  cell. Raised-floor furniture stays at its own floor height. Active runtime
  table, stall and counter builders use the same existing node. Preserve the
  36 similar-looking camp scaffold pairs and other slab/fence decorations.
  [Inventory, reviews and evidence](all_tables/README.md).
- **Dawnmere Harvest Inn:** both rear bed heads occupied the exterior wall.
  Move both complete beds one node inward and restore the two matching wall
  cells; six cell changes, unchanged points. A scan of 230 complete bed pairs
  in 96 templates finds no malformed pairs and no remaining bed heads on the
  outermost building cells. This geometric scan is not a claim of full visual
  acceptance of every interior. [Bed evidence](beds/README.md).

Follow-up checks: six-start-town fixture **2149 PASS**, six-capital fixture
**3291 PASS**, NPC facing **43 PASS**, runtime table fixture **342 PASS**, complete
`r36_w` decoration fixture **8985 PASS**, and upgrade checker PASS. The full
153-template candidate batch passed the shared validator before atomic writes
(**zero errors, 59 warnings**, including 30 fixed-material warnings for shared
building templates). The original template dimensions and all points remain.
The `r36_w` socket assertion now explicitly expects the six newly authored
Registrar sockets; its historical baseline file is unchanged.

The additional `r36_w2` bench heuristic still reports two objects at
Kezamba (11,19,-50)/(43,19,-50). The exact pre-follow-up comparison produces
identical findings (`all_tables/benches-before.log`). Direct template inspection
identifies them as **roof stairs**, not seats: `kezamba_kings_hall.tpl`, local
(6,19,32)/(38,19,32), `role roof_stair channel=roof`, facedir 1/3. This is a known
false positive of that older bench heuristic after the earlier gable repair.
The follow-up changes neither those roof cells nor any bench. This optional
check is recorded as failing; no assertion was suppressed to turn it green.

## Independent reviews

All four implementation packages were independently reviewed: **MERGE, no
blocking findings**. The reviewers checked actual semantic changes against
preserved sources/HEAD and approved proposals, rather than serialization noise.

- [Castles](gates/review-castle.md) — gate agent reviews castle agent.
- [Gate arches](tables/review-gates.md) — table agent reviews gate agent.
- [Guild tables](castle/review-tables.md) — castle agent reviews table agent.
- [Registrar and release documentation](registrar/review.md) — table agent
  reviews coordinator. The small documentation wording suggestions are applied.

## Validation

- Shared template validator: **284 templates, 6 layouts, 6 rosters, zero errors**.
  Its 29 known warnings include existing gate-guard reachability and unused
  templates; the changed arch cells do not affect those standing points.
- Template validator self-test: PASS. Viewer fixture: **56 checks PASS**.
- Actual six-capital geometry/body fixture (`r70_cap`): **3291 checks PASS**,
  including king/dais/door checks, new registrar reachability, facing, proximity,
  other-socket separation and keeping the arrival pad free.
- Registrar UI/service fixture (`r71_ui`): **127 checks PASS**; new service
  binding on all six cores, old clerk stays idle, existing dialog behaviour.
- Guild fixture: **2195 checks PASS**; generator `--check` matches all six outputs.
- Upgrade checker and its self-test: PASS against `origin/main`, including
  the changed-town digest/map-reset requirement.
- Visible-version/docs fixture (`r37_dc`): **974 checks PASS**.
- Every Lua file changed by this task: plain Lua 5.1 parser and all six sweeps
  PASS. The pre-existing test-only `os.exit` in `r70_cap` was replaced with an
  ordinary failing `error`, preserving a nonzero exit and the diagnostic.
- Editor HTTP fixture: **656 checks PASS**. The first sandboxed attempt could
  not bind localhost; the rerun with local socket access passed.
- Final browser gallery: **7 checks PASS**, 1600/760px widths, all 12 images
  decoded, six sections, no horizontal overflow or JavaScript errors. Results
  in `browser-check.json`; screenshots in `gallery-1600.png` / `gallery-760.png`.

Commands and results are retained in the lane reports and `*.log` files. No
extra fleet, native chase simulation or user GUI acceptance is claimed. The
coordinator inspected the closed gable rendering; lane owners/reviewers inspected
actual throne, pillars, gate and table captures.

## Desktop and web GUI checklist

Use a newly generated/reset test world containing this worktree's code:

- [ ] All six royal halls: throne proportions, lamp placement, joined piers,
  broad side bays, closed gable gaps and lowered ridge look correct.
- [ ] Fight/pursue through side bays: kings and guards can enter and leave;
  no exploitable one-node pockets behind piers remain.
- [ ] Core gates: arch corners open into the passage; side stairs still ascend.
- [ ] Other start/capital buildings and outdoor counters: thin tables stand on
  their own floor, including raised floors; benches and scaffolding remain.
- [ ] Dawnmere inn: both rear beds stay indoors and the exterior wall is whole.
- [ ] All six guild houses: thin tables stand on the floor, clerk/Stonewright
  remain visible and every service is reachable.
- [ ] All six capitals: Registrar visible near the waystone approach, free
  arrival pad, correct facing/name/faction, usable Expedition dialog and return.
- [ ] Character creation remains as accepted, including neutral initial Human
  selection; desktop and web window sizes retain the intended layout.

Before integrating, merge only the small registrar binding change into main's
current registrar implementation, keep its newer run/finish/cancel behaviour,
and re-run the corresponding main-era integration checks.

## Coordinator handoff — 2026-11-10

The user may hand `character-creation` to Claude for integration. Implementation
and independent reviews are complete; native interactive desktop/web acceptance
is still open. This is ready for **integration**, not a claim of completed
runtime acceptance or deployment. No push is authorized for an agent.

At handoff, this branch starts at `b0287728` (the Round 72 plan, with Round 71
code). Main has advanced to `709203b0`, **0.73.0**. Preserve main's completed
Round 72/73 work. In particular:

1. Merge with normal project history preservation (`--no-ff`), resolving shared
   files semantically. Do not replace main's files wholesale with this older
   branch's copies. Follow the repository's usual integration gates.
2. **Version/declaration:** the branch's **0.72.3 is provisional and now older
   than main**. Allocate the next version with the coordinator/user, update
   `game.conf` and the latest changelog entry together, and move this branch's
   *unreleased* 0.72.3 map-reset entry to that version. Preserve every released
   reset/migration/new-server entry from main. `check_upgrade.py` must pass
   against the current released baseline after integration. No new migration
   step is needed for this package.
3. **Registrar:** retain main's latest Expedition dialog, run lifecycle,
   finish/cancel behaviour and Round 73 changes. Transfer only this branch's
   dedicated `expedition_registrar` socket binding/comment/export changes and
   the six corresponding capital-core sockets. Adapt the current UI fixture
   to that binding; the guild clerk stays an ordinary idle resident.
4. **Creation:** preserve newer main changes in `grug_classes/init.lua` while
   retaining this branch's extracted window/camera modules, draft behaviour,
   seven installed backgrounds, media provenance and updated test harnesses.
   Main also changed `docs/design/character_visuals.md`; combine the designs.
5. **Documentation:** keep main's Round 72/73 history in CHANGELOG, README and
   STATUS, and its newer Expedition/world rules. Fold in this package's
   creation/building changes and the new upgrade classification. Shared files
   at inspection are also `docs/design/expeditions.md`, `docs/design/world.md`,
   `tools/r71_ui/portable_test.lua`, and `tools/web_data/upgrade.json`.
6. Run the affected Lua/parser, creation, Expedition UI/socket, settlement and
   template/upgrade checks on the integrated code. Prior passing results are
   documented above and in the creation evidence; they do not certify the
   future conflict resolution. The old W2 roof-stair false positives are
   explicitly recorded above and must not be mistaken for new table failures.

Creation implementation, engine probes, accepted browser design and actual
Luanti screenshots: [creation report](../../character_creation_preview/README.md),
[native gallery](../../character_creation_preview/native/index.html).
Building/furniture implementation and GUI checklist: this report and its topic
links. All editable scenes, captures, receipts and test logs live in the worktree.
Historical scratch files recovered from `/tmp` are preserved in
`tools/character_creation_preview/session-backup/`; their manifest records hashes.
They are archival evidence, not current build inputs.

## Integration — 2026-11-10

Integrated into main by the coordinator as **0.73.1** (map reset; the provisional 0.72.3
entry moved there), on top of 0.73.0, squashed on main with tag `round-73.1`. Main's
Round 72/73 Registrar dialog, run lifecycle and finish/cancel stay; only the socket binding
moved. The player-facing texts that sent players to the guild house's registrar (the
Registrar's letter, the "no Expedition" notice, the six Expedition quest texts) now name the
Expedition Registrar or the waystone plaza.

Integration checks on the merged code: the full fixture run on the merge commit had 330 passed and
6 failed; all six were pins of this package or of the integration, not defects. `r56_freeze_towns` and
`r56_freeze_capitals` carry the new digests (towns: only the node list moved, points unchanged);
`r71_l20`, `r72_shift`, `r72_mint` read the approved offers from the planning docs, which now say "the
Expedition Registrar"; `r36_w2` treats a stair with the next stair one up and two along as a stepped
roof, which removes exactly the 28 Kezamba king's hall roof stairs from its seats (the two "benches"
above were two of them) and leaves main's 0.73.0 count unchanged, so the check passes again.
The review's fixture finding (`r721_finish` registers the Registrar's own socket) is fixed; 106 checks.
