# Independent ART integration merge review

**Verdict: CLEAN**

- Merge candidate: `c91f0711ca69df1595d663d9f4bcab856f7045ea`
- First parent: `e73c5494ea7c8e8b476667a9cef2a3be7f1058be`
- ART parent: `dc323374781f2bc27ec60385bb9609b1462bd653`
- Reviewer: native GPT-5.6 Sol, independent non-author review
- Scope: parent parity and the one manual merge resolution; no runtime rerun
- Worktree and `git diff --check`: clean

## Merge verification

The merge introduces the same file set as the reviewed ART parent relative to
its base. The final ART runner, media digest fixture, mount icon fixture and
source manifest are byte-identical to the ART parent:

- `final_micro.lua`: `b56d37e7ec7f92af99b9517510ee54f4935eddb6f0ad468a7c6a21ba5b2cdf8a`
- `art_kat.lua`: `055004ee1931e523070e744f304b123936d5fc9136d407b15a0e2faf91e729f0`
- `mount_icon_kat.lua`: `f926b57bcb13a9224419e4fccf3a179a832c5bef88fd9021c24adcf1a25931df`
- source manifest: `cea7cb8d49aa27c77bdb0d727ecf7ffcf5cf103af48a5afb19d8f5e2a5ad4dc9`

The only recorded conflict, `tools/r9_mounts/mounts_kat.lua`, is resolved
correctly:

- GAME's `options.compact` guard remains around the production-zone fixture
  and the expensive ledger/B3D block.
- ART's twelve unique icon names, file existence, wildcard ledger attribution
  and icon-count assertions live inside that non-compact block.
- The shared `seen` table remains outside the block, so compact execution
  intentionally reports `assets=0`; non-compact execution populates it from
  the eight unique model meshes.
- No icon assertion or B3D read leaked into compact execution.

The automatically merged production seams also preserve both parents:

- `grug_gathering/catalog.lua` changes only Corn/Potato presentation from ART
  while retaining WORLD's schema v2, zone-qualified Rock Salt hosts and
  manifest contract.
- `grug_gear/init.lua` retains EQUIP's registered leather line and uses ART's
  per-tier armor media expression. Weapon media/logic is unchanged.
- `grug_mounts/catalog.lua` retains GAME's T1 speed `6.4`, selection and
  movement geometry while adopting all twelve ART icon bindings.

Root's supplied combined ART micro evidence passed for 72 armor registrations,
17 crops and eight owner-icon cases. The completed non-compact R9 mount
LuaJIT run also passes with `assets=8`, proving the merged guard still reaches
the eight unique model audits and all twelve icon checks. Its log SHA-256 is
`299034116dbeaa017feeb1359ccfd88780a5d2433ede50503fe368effd28bd7f`;
the associated static log hashes to
`f3654b02e1760fa2fc5c5438ea7cfc46e73a82b438a68a572a26f3b202896baa`.
This reviewer inspected those immutable results without rerunning them. CAP's
trainer-vocabulary replacement remains intentionally outside this pre-CAP
atomic merge.

## Non-blocking editorial observation

`mods/ITEMS/grug_gear/init.lua:223-227` still says only metal and cloth ship
and that leather waits for Phase 2, while line 233 now registers leather. This
stale comment already exists in the first parent and is not a merge regression,
but the final documentation/source cleanup should update it to describe the
accepted universal leather base line.
