# WP40 Simple Map R5 Review

**Status:** accepted 2026-08-29. The pure typed planner, consolidated map
adapter, disabled construction seam and canonical exhaustive artifact passed
independent review. R6 is next. R5 remains disabled and does not register a
Luanti callback or materialize a world.

**Reviewed candidate HEAD:**
`6e66cb30f0a17a8a4257c0f0d66ab0ef12e33b09`

**Accepted R4 parent authority:**
`948689138c15c291544fe10927683da4183bfd8e`

**Immutable input-manifest SHA-256:**
`8eaef1d05557655552d845f4a281bf65d0066ceda562eb7736b995c3c174237a`

The exact `git status --porcelain` snapshot captured after the final candidate
commits and successful artifact promotion, but before this review/status
closeout was added, was:

```text
?? docs/research/wp40-simple-map-r5-artifact.tsv
```

Its SHA-256 was
`810f8a73529f214a71c4e2ac07777e9bae6584e36e70d573371da566d21e351b`.
The reviewed contract file SHA-256 was
`30d4c267986e43f3f6abeec7cd27abc0f4d44565a0439f5df26f567f849a8fda`.
This review record and the mechanical status closeout were added only after
the final clean verdict.

## Reviewed candidate

R5 preserves the accepted R2 horizontal, R3 vertical and R4 geography/policy
authorities. It adds:

- one construction-owned typed Planner with the closed P2-P6 operation
  relation, independent priority/conflict resolution, authored-floor checks,
  owner-slice clipping and immutable plan provenance;
- one consolidated Adapter transaction over retained VoxelManip buffers,
  preserving native caves, liquids, ores, strata and deep dungeons while
  applying exact content, Param2, lighting and liquid-dirty rules;
- the authenticated native heightmap/context seam and exact mapgen-owner
  bounds;
- a private disabled R5 construction API with no callback, global publication
  or production activation; and
- an independent Validator oracle, canonical artifact toolchain and bounded
  LuaJIT/PUC micro-KAT.

The final correction also binds a source-derived named-causeway roster. For
each named causeway interface, the complete seed-zero scan records footprint,
eligible and resolved-culvert counts. Eligibility is a subset of the
footprint, resolved count must equal eligible count, and a zero-eligible
footprint is valid. Derived causeways with a nil functional interface remain
outside this named roster and cannot contribute a resolved culvert.

The separate process commit
`275450945d7680948f8c27bd4ea888e5a17c3216` records two execution lessons in
`docs/process/claude-cli-review.md`: Claude reviews remain attached to a
tracked foreground command-runner session, and long acceptance runners first
perform a real write probe in the exact promotion directory under the same
permission profile. That process document is outside the R5 input manifest
and changes no R5 evidence byte.

## Canonical runtime evidence

The authoritative Full and Final invocations ran on the same immutable
manifest. The Full invocation used LuaJIT only. The Final invocation completed
two independent seven-shard LuaJIT fleets before starting exactly one LuaJIT
and exactly one repository PUC 5.1 micro-KAT process. The two micro outputs
were byte-identical. The Final invocation then merged both canonical artifacts,
rechecked the manifest and promoted the result with a same-directory atomic
rename as its literal last operation.

- Canonical artifact body/file SHA-256:
  `a0e7241dabf71833c490d574cbbf4702cdd2c63289277bcc3f49255039a78e1b` /
  `0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0`.
- Validation receipt SHA-256:
  `612b7596dd0d1aeeb75761c81717a13b7d98f84517a1f24555bdbe2a1c21b1ad`.
- Seed-zero shard SHA-256:
  `98a16cdc08172064fefe146bd925212a10cebfaeb9b644203931d875064b27c7`.
- Historical R4 shard SHA-256:
  `738f4cc2ab5886ff1480bc95c9965687f950a6ec59666f126620d01fa728cbf9`.
- LuaJIT/PUC micro-KAT body/file SHA-256:
  `762d01815fc77e8e6226c2166ae1170718ff28f0a32b4e0c97b217ef551a8003` /
  `b5cd7307e10e1a641ca65e8464286a262125d013ecf438431fe3d077412ea80d`.
- Full-run log SHA-256:
  `03789bc80acd13a02732b4e8015f7d3ab344216e3ee0e1772f6e4dd95b2043d2`.
- Final-run log SHA-256:
  `35dfc0752e8c1119edefc12af9f06ffd95f13a2cce792a386c5ef99aa516939b`.
- Full wall time and process population: 2,908 seconds; 15 LuaJIT and zero
  PUC processes.
- Final wall time and process population: 10,793 seconds; 28 LuaJIT and
  exactly one PUC process.
- LuaJIT executable/version SHA-256:
  `4fd1f5075a6cb15c933f5abaf7ad4b203c8926ab27261c334b41c9bc5e40a1a6` /
  `ce09c19b108c7705b7fbd06a0a868314fed85741c95d960d6ea832d89a13dfce`.
- PUC 5.1 executable/version SHA-256:
  `a1a427f38260513b64158630bc2b7d2fccfa31b48129efbfbcc60e02e4960a4f` /
  `2ff0cbffc9aa8f445c637928eb5be5b92e36b64b491c5e060592ac7e187f73c8`.

The Full run reports 3,970.79 LuaJIT user seconds and 1,755,264 KiB peak
RSS. The Final run reports 8,149.71 LuaJIT user seconds, 5,141.61 PUC user
seconds and peak RSS values of 2,398,280 KiB and 3,261,336 KiB respectively.
Those host/resource values are deliberately unbound evidence; they do not
enter the canonical artifact.

## Causeway correction reviews

The first complete acceptance review of candidate `86b91c7` returned
**REJECT**, 0 Critical / 0 High / 1 Medium / 0 Low. It found that the original
Contract required every named causeway to have at least one culvert while the
Validator exposed only aggregate culvert evidence.

- Prompt SHA-256:
  `a38b03753a509184a8ab4ba43936165e3db1b83664c0b8911c375ee317735d60`.
- JSONL SHA-256:
  `00d620b4ed736f8d4a0c39c381519afc239476bceb51fa445077478b0ab0a66f`.
- Extracted verdict SHA-256:
  `939bd3b017b8affb75e838ff5e575254f9a35b8de4c4e18e768fad0385608be4`.

The first focused correction review returned **NO-START**, 0 Critical / 1
High / 0 Medium / 0 Low: accepted source geometry makes the complete
505-column `gravesalt_causeway_north` footprint legitimately zero-eligible.

- Prompt SHA-256:
  `dcfb67dc1a37283fb6032f01054a173937b199a37e81ca9949f994b78430a50b`.
- JSONL SHA-256:
  `961fef6e413050167c1e58c6fed129fa7d07ab88196554f467464c1017a30c5b`.
- Extracted verdict SHA-256:
  `e4b4c62492f3a87798f05c583a007fbf4c76c7c9ba3ae93ac8197f1addd61287`.

The amended correction review then returned **NO-START**, 1 Critical / 0 High
/ 0 Medium / 1 Low because its first census also included thousands of
derived nil-interface causeways and because the subset rule was not explicit.
Those findings produced the final source-faithful Contract and Validator
semantics described above.

- Prompt SHA-256:
  `91d5aa447be6489f03181f733b3b82071ec18f3c54d1979b6a51d1d1496435ee`.
- JSONL SHA-256:
  `57e6ab6dce0912d23303835a2278725ea6667b590d3d2d796cb1d6ab10c67fe3`.
- Extracted verdict SHA-256:
  `bda9ea423d8aaebc90cc80209c4a664967e111be6e6ac3d23842b5fe666a7f1c`.

A fresh focused Claude Opus context at `xhigh` effort reviewed the final
correction through the repository's read-only `Read,Grep,Glob` profile. It
exited zero with empty stderr and returned **START**, with 0 Critical / 0 High
/ 0 Medium / 0 Low.

- Prompt SHA-256:
  `55f3b66259d246b4c8296d7e66b825c2a7c110632aa3a635d2432757337a4640`.
- JSONL SHA-256:
  `b219c8c6bd461efb001bf0da3554f92625f4d22edc5fa6ac5dad0408238644f5`.
- Extracted verdict SHA-256:
  `3ca5ad2c3fa888fff83c8c17f942f75633b3b67a985d13683175bb22528a4d63`.

## Independent final acceptance review

A new Claude Opus context at `xhigh` effort reviewed the complete final
candidate, both official logs and the promoted artifact through the same
read-only profile. Shell, writes, delegation, MCP, browser and network tools
were unavailable. Claude Code was version `2.1.228`; the process exited zero
with empty stderr and returned **ACCEPT**, with 0 Critical / 0 High / 0 Medium
/ 0 Low.

- Prompt SHA-256:
  `a325df01c43cab1c44378210a758c95cf5cea3ab46cef248bb936aefd5d6a6e5`.
- JSONL SHA-256:
  `a687526b1e2c5bcd60983d198517c78370f54208c2adfc829a5535e153527b3b`.
- Extracted verdict SHA-256:
  `ae1a6bbf2b7444905ae34e0c908c58c7e3f036ca0d7bddc31dfd12731603f30c`.
- CLI-version capture SHA-256:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`.
- Captured `claude --help` SHA-256:
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
- Empty stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The review independently confirmed the cycle-free R2/R3/R4 lineage, every
Contract section, the closed operation relation, complete analytic scan,
bounded materialized-plan corpus, native preservation, Adapter transaction,
allocator and API closure, disabled state, causeway census, artifact
arithmetic, exact interpreter population and atomic final promotion.

## Authority closeout review

A fresh Claude Opus context at `xhigh` effort reviewed this durable record,
the promoted artifact, the official logs, the mechanical status closeout and
the amended Claude execution procedure. It exited zero with empty stderr and
returned **REJECT**, with 0 Critical / 0 High / 1 Medium / 2 Low findings.

- Prompt SHA-256:
  `6133125d9e7c194901de9201b7852ff5216f13943a9fbe78557a30e8d2a81c3b`.
- JSONL SHA-256:
  `65e50d27db571227b219a39cb9043d067ec702ed4ff601e2ccb1dd6ccd5dd531`.
- Extracted verdict SHA-256:
  `e0eacc3cdb62c39dd9d63a69a0eca68c64d417e466c32819d1e3e17c9c4192c4`.
- CLI-version capture SHA-256:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`.
- Captured `claude --help` SHA-256:
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
- Empty stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

All three findings are dispositioned without changing an accepted R5 runtime
byte. The Medium found that the engineering brief is an artifact-bound B+
input and therefore may not receive a post-acceptance status edit. Its exact
accepted bytes were restored; the unbound rebase plan and this review now
state explicitly that its header remains the pre-acceptance status while the
technical brief stays authoritative. One Low found missing immutable handles
for two successful focused review processes; the prompt, JSONL and extracted
verdict hashes are now recorded above. The other Low found that the Claude
procedure's example hard-coded the main checkout even though the reviews ran
in this worktree; it now requires the exact absolute reviewed worktree and its
foreground wrapper remains consistent with the process rule. Project policy
requires focused rereview only for Critical or High fixes, so these mechanical
Medium/Low corrections do not trigger another Claude invocation or any Lua
rerun.

## Calibration record

- Classification: non-trivial deterministic map-generation implementation,
  exhaustive evidence and acceptance update.
- Implementing/coordinating model: GPT-5.6 Sol with specialized internal
  implementation and audit lanes.
- Reviewing model: Claude Opus at `xhigh` effort in fresh read-only contexts.
- First complete-review severity counts: 0 Critical / 0 High / 1 Medium / 0
  Low.
- Final complete-review severity counts: 0 Critical / 0 High / 0 Medium / 0
  Low.
- Post-complete-review correction rounds: 3.
- Authority-closeout severity counts: 0 Critical / 0 High / 1 Medium / 2 Low.
- Authority-closeout fix rounds: 1.
- Observed package elapsed wall time: `unknown` (multi-session package).
- Canonical Full runner wall time: 2,908 seconds.
- Canonical Final runner wall time: 10,793 seconds.

R5 is an accepted, private planner/adapter payload. It remains deliberately
disabled, registers no mapgen callback and does not materialize terrain,
water, structures or content. R6 is the next delivery stage.
