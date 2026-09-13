# WP40 quality and fresh-server review record

Date: 2026-09-13. Baseline `0d06276`; implementation branch
`wp40-mapgen-quality`. Every scope below is non-trivial. Reviews were performed
in independent contexts which did not implement their reviewed scope.

| Scope | Implementation | Independent review | Result |
|---|---|---|---|
| Surface selector `2db4714`, resource optimization `037fd98` | Coordinator / `quality_resources` | `tree_gap_diagnosis` | ACCEPT; 0 findings |
| Material/camp cleanup `562136b` | `quality_resources` | `tree_gap_diagnosis` | ACCEPT; 0 findings |
| Height/road revision `bfd73ab` | `quality_geometry_plan` | `tree_gap_diagnosis` | ACCEPT; 0 findings |
| Cave revision `2557f75` | `tree_gap_diagnosis` | `quality_geometry_plan` | ACCEPT; no code findings; engine tube evidence verified |
| Vendor cleanup and final net ore removal | Coordinator / `tree_gap_diagnosis` | `quality_resources` | ACCEPT after 3 Medium and 3 Low fixes |
| Profile and final-pair harnesses, including plain-5.1 surface fixture | Coordinator | `quality_resources` | ACCEPT after focused corrections below |

The configured delegation/review route was GPT-5.6 Sol. The retained agent
messages inconsistently self-labeled underlying models as GPT-6 Codex/Astra;
those self-descriptions are not used to infer a different configured route.
The coordinator was Codex. Cross-model Opus review was unavailable in this
session (organization HTTP 403); independent-context Sol review was used.
Observed elapsed delivery time is `unknown`; all reviews reported zero
Critical and zero High findings. Material, surface/resource, geometry and cave
code had zero fix rounds. Vendor/ore had one review cycle with the fixes below;
the harness received three focused corrections and one final fixture repair.

## Findings resolved before merge

- Remove references to the deleted ore loader from active R7/R8 micro-input
  rosters and the T2 tool loaders; align the compact populations to 73 modules
  and 107/110 input files. Historical acceptance receipts remain unchanged.
- Preserve the current `_nametag` through the administrative mob reset tool,
  then exercise reset, serialization and reactivation in the vendor fixture.
- Remove unused offline-player API wrappers and the old plural
  `attacks_monsters` definition spelling. Current initialized-player APIs and
  the singular definition field remain exercised.
- Remove the orphan depleted-vein image, generator entry and media-license
  row; update the vendored patch inventory and removed API documentation.
  A reviewer's colon-only marker count was withdrawn: all `GRUG PATCH` forms
  total 39 in the final `mobs/api.lua`.
- Make the selected cave corpus an explicit absolute-path profile input,
  copied into the disposable probe and bound in both harness and snapshot
  hashes. The default corpus remains unchanged.
- Query only requested-owner nodes in the small persistence digest. Samples
  outside that owner use explicit sentinels; the stronger complete-owner
  content/param2/light digest is unchanged.
- The final parity runner starts exactly two fixture interpreter processes,
  logs versions from inside them, hashes binaries, checks dependencies and
  nonempty inputs, binds required sentinels and all additional catalog
  design/research/reference inputs, and checks unchanged hashes afterward.
- The first PUC run exposed an FFI-only MTS reader in the surface test setup.
  The corrected fixture reads only actual uncompressed MTS dimensions and
  name tables, which are the only template data its catalog setup consumes.
  Independent Python/zlib inspection verified that every declared name index
  is used in all 15 relevant schematics. This is a test-only repair; no game
  byte changed. It earns one replacement final PUC/LuaJIT pair.

Reviewers inspected source, mandatory Lua-5.1/static checks, actual vendored
recipe registrations and current runtime callers. They did not duplicate the
final PUC runtime. Both evidence conditions are satisfied: the final pair has identical
8,828-byte outputs with SHA-256
`c577859417107480fdbdab8d3fec25fafa5e486a1775df05030a21a4f0cb63dd`
and 1,753 unchanged inputs; the real engine verifies all 416 cave air voxels
on cold generation and disk reload, with full 5,120,000-voxel parity.
The harness/vendor reviewer independently inspected both receipts and issued
**unconditional ACCEPT**, with 0 Critical / 0 High / 0 Medium / 0 Low open
findings. See [the completion report](wp40-mapgen-quality.md) for full hashes
and the retained evidence. These are source and headless-runtime approvals;
the user's GUI visual acceptance remains open.
