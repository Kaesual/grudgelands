# WP40 Simple Map V1e R2 Review

**Status:** accepted 2026-08-27. Independent implementation review is clean,
the user explicitly approved the final V1e SVG, and the accepting commit makes
V1e the sole live R2 authority.

**Reviewed semantic base:**
`773387a54cdf0000e6245cfd4fc2a543df78ebc4`

**Reviewed HEAD:**
`ff9d0711fc640e6f9550069f81db8be8b58c1807`

The process-only commit at reviewed HEAD was independently accepted in a
separate review and was excluded from this implementation verdict. The V1e
review combined the committed V1e delta through
`78c5ff8937498a82dae0ccbb5ae0cbc5fc49d987` with the 39-file reviewed byte
manifest: that committed V1e delta plus the 31 uncommitted paths in the final
status snapshot below, captured before this record was added:

```text
 M BACKLOG.md
 M README.md
 M docs/design/world.md
 M docs/design/world_zones.md
 M docs/research/wp40-engineering-brief.md
 M docs/research/wp40-simple-map-r2-artifact.tsv
 M docs/research/wp40-simple-map-r3-contract.md
 M docs/research/wp40-simple-map-rebase-plan.md
 M docs/research/wp40-simple-map-v1e-baseline-diagnosis.tsv
 M mods/MAPGEN/grug_mapgen/wp40/height.lua
 M mods/MAPGEN/grug_mapgen/wp40/simple_map.lua
 M mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua
 M tools/wp40/README.md
 M tools/wp40/render_simple_map_svg.lua
 M tools/wp40/run_simple_map.sh
 M tools/wp40/run_simple_map_r2.sh
 M tools/wp40/simple_map_r2_metadata.lua
 M tools/wp40/simple_map_r2_test.lua
 M tools/wp40/simple_map_r2_water.lua
 M tools/wp40/simple_map_r3_validate.lua
 M tools/wp40/simple_map_v1e_baseline_diagnosis.lua
?? docs/research/wp40-simple-map-v1e-preview.svg
?? docs/research/wp40-simple-map-v1e-r3-preflight.tsv
?? tools/wp40/run_simple_map_r3.sh
?? tools/wp40/simple_map_r2_contacts.lua
?? tools/wp40/simple_map_r3_artifact.lua
?? tools/wp40/simple_map_r3_common.lua
?? tools/wp40/simple_map_r3_kat.lua
?? tools/wp40/simple_map_r3_offline.lua
?? tools/wp40/simple_map_r3_selftest.lua
?? tools/wp40/simple_map_v1e_r3_preflight.lua
```

Its complete status SHA-256 was
`50a74ed40fcbb3a5ee12c73a1c9d07e6153ef5188658b1cd1b41baccf8d7e6b4`.

## Independent review

The implementation was reviewed by a fresh Claude Opus context at `xhigh`
effort through the repository's read-only Claude CLI profile. The reviewer did
not implement the package, could use only `Read`, `Grep` and `Glob`, and had no
shell, write, delegation, MCP, browser or network tools. Claude Code version
was `2.1.228`; the captured `claude --help` SHA-256 was
`71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
Both successful invocations exited zero with empty stderr.

The full review was launched 2026-08-26 and completed 2026-08-27. Its immutable
evidence was:

- 39-file manifest SHA-256:
  `52333980c9978573fa05ed30e72ac08029a3ca0e4c291359d548e8b3ec7cd402`;
- reviewed current-byte manifest SHA-256:
  `cfd2ab29f94f7fe7d7f5649450725d7f4fefd6016c8c77f27f0424d98c08fa6a`;
- committed V1e patch SHA-256:
  `f2c5202fb4f5104e0909a85740a80d11d0da289a72da8ec78f52d871724ead87`;
- uncommitted worktree patch SHA-256:
  `3275b33ec12d8bba98b31bf99cf99179adafdf64acb57ec67f8ab7614fbf48c6`;
- bundle-members file SHA-256:
  `c62305c8cb0fcb77cd2e9f6a488a60bbb0af5f25dc22d1c9eedaf6938ef5559a`;
- prompt SHA-256:
  `7c045321240e2a99324d512c1b466b45964b24d94dc590be5dee24549f82fe4e`;
  and
- JSONL SHA-256:
  `90d857fad6c5d136fcd2a32ac8ce2a11732c816b3895001420104d512b9a9335`.

The initial verdict was **REJECTED**, with 0 Critical, 0 High, 1 Medium and
1 Low finding:

1. the live design did not state that Highcourt civic water and its
   contact-face fall are generated before `hard:anchor_008` protects the
   generated result, without a protection exception; and
2. the migration extractor and baseline-diagnosis tool were outside every
   automated Lua 5.1/static gate.

The one fix round added the exact generation/protection ruling to the live
Highcourt design row and added both evidence tools to the current preview
runner's `luac51`, `SETGLOBAL`, five portability/sandbox sweeps and immutable
input manifest. The complete preview runner then passed again with unchanged
KAT and SVG bytes. No R2 or R3 artifact input changed.

The fresh focused rereview completed 2026-08-27. Its immutable evidence was:

- final current-byte manifest SHA-256:
  `65bb72559b12973e002ef0a21137a48bbc0eb1828d85c02edf3eb519289581ae`;
- focused-fix patch SHA-256:
  `98208344b13f87cde1f98df1f1218781307aaddade287ff91056130a1d78796c`;
- bundle-members file SHA-256:
  `6d1e55123cad1c7d3ef562c906903ae21a4fdcf10b3229f5687845c279b8ee56`;
- prompt SHA-256:
  `b7f7062771fe3548dd29c04f49edf88152796cc2a49854c69dbf1e96932e568c`;
  and
- JSONL SHA-256:
  `9da453de7bd8d9345bf9854bd199fa44e4c3aba70d064198693b4ae9f85f812c`.

The rereview verdict was **ACCEPTED**, with 0 Critical, 0 High, 0 Medium and
0 Low findings. It independently verified that both findings were closed,
that all 22 changed Lua files are now covered by one of the three active
simple-map runners, that the artifact chain remained valid and acyclic, and
that the 39-file manifest otherwise remained identical to the reviewed
package.

## Bound evidence

- Anchor migration body/file SHA-256:
  `2001bd4b7af28570f9689e278d321a13adf92c68167c79dddace948fbdfa6859` /
  `1295af991c3896d44089511830f3727a284af98be0510d581ea89afe3f11c1fb`.
- Baseline diagnosis body/file SHA-256:
  `7ab20fd38f05f6ab085a59e94c2e53cd0ff87b0a904eb328799bc22e78829d61` /
  `1c7444c57fd1a95c11f37b46789ae29c21ab6532e1b4ac596675fc3086ec4bed`,
  with exactly 40 witnesses over 14 canonical path pairs.
- Accepted R2 artifact body/file SHA-256:
  `1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b` /
  `ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`.
- Hydrology-contact roster SHA-256:
  `904c548d4679596467ca72e0a0cf86de9248189dee97fcc37321e20700d8e0f7`.
- User-approved SVG file SHA-256 (approved 2026-08-27):
  `5816941d7bb7524a653b7cbe6b471f842be8bdc89db5e18f9fbf2017555e8fdc`.
- Four-seed vertical-preflight body/file SHA-256:
  `de2e1d5a244785a3ca74e737e3848102f8b807d77043b058dc581a9f69d0898e` /
  `f3ccf699df1d67083730ccade57ea829fb8a618a1ee8e93890d41a1548d840e3`.
- Per-seed evidence SHA-256 values in canonical seed order:
  `dffe10e8413e5408aff3221d6e21ec2667ac6ffc6bbb517861e62496a1fced86`,
  `f977bfcdf561adc0faa2207a2892e45a5321aabb91947a464d1f6a6e2ebe80c1`,
  `f38594b3a360c457ad2f0b550397a4a56edd47441c67ef296baa52474e16990e`,
  `7f313fb3f1d9f1c04f35cc51310a12e9a9e3bd90f20883d3d1935ccbb301b5e4`.
- Targeted R3 LuaJIT/PUC KAT digest and merged-file SHA-256:
  `c2fe576c24aed28bb3c416a2405de071b46b24889c713053c3ec99f35d388bca` /
  `2f7810f41d83c482412a2496de35e8071da448b099c40c747551131e48de17ce`.
- Horizontal LuaJIT/PUC KAT digest:
  `cd50b0b18e4535c600051b10991b2a867e654e717901a089e15655848eebb882`.
- The final parallel R3 preflight runner completed in 2,795 seconds, with two
  byte-identical complete four-seed LuaJIT runs and targeted PUC parity.

The user approved the final V1e SVG on 2026-08-27. The accepting commit
promotes the reviewed artifact to the sole live R2 authority; V1d remains
immutable historical evidence at `d337160`. The preflight proves bounded
vertical feasibility only: it does not accept R3 production integration,
planner/materialization work or a Luanti runtime world.

## Authority closeout review

After the user's visual approval, a fresh Claude Opus context at `xhigh`
effort reviewed the authority/status switch only. It used the same read-only
`Read`/`Grep`/`Glob` profile, Claude Code `2.1.228`, and captured help SHA-256
`71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
Before this evidence section was appended, the nine-file closeout byte
manifest had SHA-256
`537d2651440efebbbd9a6a158106e38c34b8fc878ee832868301c9092e20f921`;
the complete status listing had SHA-256
`5ffe2cade9eb1db666eba685017bb5e216e55bded58f7aaa6d56e1a95edf1e9d`.

The initial closeout review returned **REJECTED**, with 0 Critical / 0 High /
2 Medium / 3 Low findings. Its prompt/JSONL SHA-256 values were
`dfec6cf2665ce76140b6a8734ffe1f5dcbd513e28fef96f70ec4cfacb499fc11` /
`ff32f88a96cc6396a0a048ac25fda1466ab94d65cf9beb0cce539636e8f7d340`.
The first correction round synchronized ROADMAP and BACKLOG status, documented
the exact R3-preflight mode, marked the old R2 record as superseded and fixed
the reviewed-manifest description. Its fresh rereview confirmed all five
findings closed but returned **REJECTED**, with 0 Critical / 0 High / 1 Medium /
1 Low new wording finding. Its prompt/JSONL SHA-256 values were
`5dfd86dc8dbe07887000a606bdab0643387a5d031de4538483888818f9da053c` /
`15972a28a593b608f51c0d19d21d8aaae30ad9596aa527cbced79020b6fec1b0`.

The second correction round marked the complete 2026-08-25 measurement block
as historical V1d evidence and made `manifest`/`snapshot` terminology exact.
The final fresh rereview returned **ACCEPTED**, with 0 Critical / 0 High /
0 Medium / 0 Low findings. Its prompt/JSONL SHA-256 values were
`e61df7f59720beb936f7ca0a71dbe6c354a4fd56bfa9cc675f1874b9397bc914` /
`7bd20739673e24893c3f3af2112b63f12c3b227adcccd63b7acb6ad9daa718c2`.
All three invocations exited zero with empty stderr. The final verdict confirms
that V1e is the sole live R2 authority, V1d is historical evidence, R3 remains
unaccepted and WP40 remains in progress.

## Calibration record

- Classification: non-trivial (map-source migration, deterministic geometry,
  evidence and authority update).
- Implementing/coordinating model: GPT-5.6 Sol.
- Reviewing model: Claude Opus at `xhigh` effort.
- Initial Critical/High findings: 0/0.
- Initial full severity counts: 0 Critical / 0 High / 1 Medium / 1 Low.
- Implementation-review fix rounds: 1.
- Authority-closeout fix rounds: 2 (3 reviewed correction rounds total).
- Final severity counts: 0 Critical / 0 High / 0 Medium / 0 Low.
- Observed package elapsed wall time: `unknown` (multi-session package); final
  four-seed R3 runner wall time: 2,795 seconds.
