# WP40 Simple Map R6 Review

**Status:** accepted 2026-08-31. The still-disabled surface/resource
implementation, complete 32-seed evidence fleet, canonical artifact and
LuaJIT/PUC 5.1 parity KAT passed independent review. R7 is next after WP33
registers every visible cultural source against R6's frozen slot API.

**Reviewed candidate HEAD:**
`fb577ea2ab33e6ed1cb2c7adf8f7ab22ceed65de`

**Accepted R6 contract / assignment SHA-256:**
`814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f`

The exact `git status --porcelain=v1` snapshot captured after the final
candidate commit and successful artifact promotion, but before this
review/status closeout was added, was:

```text
?? docs/research/wp40-simple-map-r6-artifact.tsv
?? docs/research/wp40-simple-map-r6-run-receipt.tsv
```

Its SHA-256 was
`2881e46aa6d45f1f9c49152f875c31b24c83bfdbb060f736e27ed4eb4cc151e4`.
This review record and the mechanical status closeout were added only after
the final acceptance verdict.

## Reviewed candidate

R6 preserves the accepted R2 horizontal, R3 vertical, R4 geography/policy
and R5 planner/adapter authorities. It adds:

- the frozen surface-content, shore/bed, decoration, cultural-opportunity,
  resource-density and representative-seed catalogs;
- production-owned P7 surface and decoration planning, invisible P9 cultural
  reservations and exact-host P8 resource settlement;
- whole-footprint validation, exact exclusion precedence, immutable
  24-apex-socket authority and one consolidated replay-checked VoxelManip
  transaction;
- the frozen private session API with no callback, global publication or
  writer activation; and
- the seven-worker 32-seed population, complete semantic ledger validation,
  production KAT and byte-identical LuaJIT/PUC 5.1 micro-KAT.

The accepted R6 payload remains deliberately disabled. It registers no
mapgen callback and writes no world. WP33 must register all visible cultural
sources against the exact centred 5 by 5 by 9 reservation API before R7 may
activate the consolidated writer.

## Pilot and canonical evidence

The seed-one pilot and targeted reference produced the same population
SHA-256,
`67975eaef16041ba84b8fffa366354bc6bc137b54d3447faa3112caec751f270`.
The pilot's measured projection was explicitly approved before the fleet:

- approved projection SHA-256:
  `9541fa35b201fd1205904c3aa5f0e8c5d231fa1563b1103992c090863702e97f`;
- static-gate receipt SHA-256:
  `e73d350c3e1b2d6821aba86bb1ab557f0d3abcf9dee2a9a7530b8dfba1981875`;
- pilot/reference wall time: 539.88 / 2,781.94 seconds;
- projected fleet wall time: 18,895.80 seconds; and
- projected artifact population/ceiling: 824,386 data rows / 93,223,759
  bytes.

The approved seven-worker fleet covered the exact contiguous seed ranges
1-5, 6-10, 11-15, 16-20, 21-25, 26-30 and 31-32. Its fragment SHA-256 values
were, in worker order:

1. `72c726080e711012488edf65b3df76657a052623905a0efd5295b9e416246b9e`
2. `229b0caa82510b16f448737ec2c937ba396146aedecdefa86e5a66ee47ebc05d`
3. `aeda00ba2e145a116c26dbe1731edb1eade45224a36369425bb5e3679b971353`
4. `748acaea07f95c3d1a5cfa8941f54666bbeab14d830a5a1244f8451a47d62fcd`
5. `15940c6f14803fdeaaa7cc9033d89ca475e258e43c2281b648a85a057bea01f6`
6. `748cc87e71ee84479e571abdb8b684017ca10cfb946909453b8c66ce8d3a51a5`
7. `4820251c8b7f4387a2ebeb50b35cc5dd2e3de3a467e2dff3c802b5582fb0c6a4`

The slowest worker completed in 17,406.05 seconds. Every worker ran under
LuaJIT with the repository-wide seven-process cap and separate immutable
inputs and scratch paths.

The canonical promoted evidence is:

- artifact body/file SHA-256:
  `1d64aa332c061d3ea3fe07b4185e6ff4aa3a42509d0bdd10792dafae3027a278` /
  `bb3e9674b768f7ef14fc0a703d0dc97022e9767d0c532b48cd5f1c0c741257b4`;
- artifact population: 824,386 data rows, 824,388 physical lines and
  92,812,301 bytes;
- durable run-receipt SHA-256:
  `e49490bcabae4360faad6777b99c22f560628f95a012d46aadf6bf2331498eba`;
- global fragment SHA-256 / population:
  `be29bdfb4b898c17b0f7a011a706d4e9729a38b3921507d56529e2ad9be3e94e`
  / 514 rows;
- production-KAT SHA-256:
  `fba8e798a16e856d4091f87015c622b6c53e49aa22fca3f4b7d1296cec76d1cc`;
- byte-identical LuaJIT and PUC 5.1 micro-KAT SHA-256:
  `a25a715e6d31cb664e481e9e29f70501436e00a25eef90d3f213cf5e013a698c`;
- finalizer/combine/final-validation log SHA-256:
  `18ac311455d06596c78d65eb06e9ee0960519d14a7b05adbc57728c1a3873384`,
  `b461b9b24f460af179748c8ddef0a7b2f9253776da50a01495d91ba93d07dbab`
  and `c1fa4b957aa49246f8d4c089c72cc3714efac755b9c5022b07e261da02ecfbee`.

The artifact contains each of the 28 closed row families at its exact
population, all 20 mandatory gates exactly once and passing, the complete
32-seed surface/resource/cultural/decoration ledgers, practical access
witnesses, fixed housing projection and exact 24-socket apex binding.

## Failed first fleet and correction

An earlier full fleet reached global finalization and failed with an apex
socket reported absent. The socket and hard authority were present; the
validator had incorrectly required the representative first-match exclusion
ID to be the active apex ID even when a higher-priority anchor or route
exclusion represented the same column. That run's scratch was lost under the
old cleanup behavior and therefore could not be promoted or accepted.

The correction separated representative exclusion classification from the
exact R4 hard-foundation authority, bound all 24 sockets directly, added an
early finalizer preflight, retained scratch on future failures and added both
hard-plus-route and route-only exclusion-precedence micro witnesses. The
corrected bytes required and received a fresh pilot, a fresh explicit
projection approval and the complete fleet recorded above.

A focused Claude Opus review of that correction returned **ACCEPT FIX**, with
0 Critical / 0 High / 0 Medium / 1 Low. The Low requested the route-only
negative control subsequently added before the final pilot and fleet.

- Focused-review prompt SHA-256:
  `95285b22ade478529e0319bdb61c4f42cc49ed3991f492aae1253a6f107a2a5d`.
- Focused-review JSONL SHA-256:
  `e88d51b197422137f1d818e09a7216df41d4bb6650e9feb252fd18973e1e950c`.

## Independent final acceptance review

A fresh Claude Opus context at `xhigh` effort reviewed the exact candidate,
contract, promoted artifact, durable receipt, implementation and evidence
toolchain through the repository's read-only review profile. Claude Code was
version `2.1.228`; the foreground process exited zero with empty stderr and a
final `type="result"`. The verdict was **ACCEPT**, with 0 Critical / 0 High /
0 Medium / 2 Low.

- Prompt SHA-256:
  `fc335fa18e1243a60e9a94f51361b62913af57323ede463b78b17a89547a3a64`.
- JSONL SHA-256:
  `18561b41e6a06be7572ae8decabf8251e804bcd27791a29c9267fdc02977bf1e`.
- CLI-version capture SHA-256:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`.
- Captured `claude --help` SHA-256:
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
- Empty stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The review independently confirmed the disabled/no-writer state, exact
R2-R5 projection, P7/P8/P9 semantics, exclusion and apex authority,
transaction and allocator bounds, engine-exact rotation, seven-worker fleet,
closed artifact arithmetic and LuaJIT/PUC parity.

The two accepted Low findings are retained as explicit follow-up constraints:

1. The candidate-discovery halo is available through planner metrics and
   indirectly evidenced by the 49-cell production KAT, but is not printed as
   its own canonical artifact identity rows.
2. The static-gate script's automatic source selection omits
   `seed_corpus.lua` and `counting_allocator.lua` from parse, `SETGLOBAL` and
   syntax sweeps. The reviewer directly audited the current bytes and found no
   Lua 5.1 defect; the allocator is also executed by the PUC KAT, while the
   seed corpus received direct source inspection.

Neither finding changes an R6 runtime result or blocks acceptance. They are
not repaired in the receipt-bound candidate after promotion: changing the
artifact schema or static-gate script would invalidate the approved static
receipt and immutable evidence chain. The next evidence-schema/static-gate
revision that touches these files must add explicit halo rows and include both
non-`r6*` production files in the full Lua gate set before producing fresh
evidence.

## Calibration record

- Classification: non-trivial deterministic map-generation implementation,
  32-seed evidence fleet and acceptance update.
- Implementing/coordinating model: GPT-5.6 Sol with specialized internal
  implementation and audit lanes.
- Reviewing model: Claude Opus at `xhigh` effort in fresh read-only contexts.
- Focused correction-review severity counts: 0 Critical / 0 High / 0 Medium /
  1 Low.
- Final complete-review severity counts: 0 Critical / 0 High / 0 Medium / 2
  Low.
- Post-review blocking fix rounds: 0.
- Observed package elapsed wall time: `unknown` (multi-session package).
- Accepted pilot wall time: 539.88 seconds.
- Accepted targeted-reference wall time: 2,781.94 seconds.
- Accepted fleet's slowest worker wall time: 17,406.05 seconds.

R6 is an accepted, private surface/resource and evidence payload. It remains
deliberately disabled and materializes no terrain, water, structures or
content. R7 is the next WP40 delivery stage after WP33 supplies the mandatory
cultural-source registrations.
