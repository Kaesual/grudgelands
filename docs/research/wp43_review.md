# WP43 Independent Review Record

Status: **CLEAN**. No open findings remain.

## Reviewed revisions

- Base: `607a96bef016053caff5d2c9a7897f5b7c02fa2a`
- Implementation and completion-documentation head initially reviewed:
  `85f0ae83ea382edb0a1732522e612c81a619aa8a`
- Final reviewed code head after the last review fix:
  `c3a32ed655082e11a62531c6b444d4418ea620e2`

The reviewer did not participate in implementation. The review covered the
complete branch diff, every changed production and test file, the completion
documentation, the WP43 request and implementation brief, the workflow and Lua
5.1 contracts, the WP25/WP43 backlog records, and the authoritative material,
world and zone design sections.

The principal lenses were natural target-y depth versus resource harvest tier;
protection and refusal ordering; exact under-tier destruction, wear, drop and
settlement behavior; renewable-node handling; removal of `leveldiff` authority;
pick capability preservation; canonical namespaces and saved-world aliases;
recipe retirement; visible derivatives; registry and consumer consistency;
startup auditing; Lua 5.1, callback, reentrancy and error-restoration behavior;
test fidelity; documentation accuracy; and WP26/WP29/WP40/WP44 scope boundaries.

## Findings and resolution

The initial full review found **0 Critical, 2 High, 5 Medium and 1 Low**:

1. **High — over-broad natural-node classification.** Treating
   `is_ground_content` as natural terrain also captured saplings and
   decorations, applying mining depth rules to non-ground content.
2. **High — prematurely craftable Steel pick.** The surviving
   `default:pick_steel` recipe resolved through the migrated historical Steel
   ingot to canonical Iron Bars, making the verification pick craftable across
   the WP29 boundary.
3. **Medium — visible legacy storage derivatives.** Steel-named sign, ladder,
   stair and slab registrations and outputs remained reachable instead of
   resolving to canonical Iron or canonical material derivatives.
4. **Medium — incomplete failure feedback.** Depth/no-pick and shatter paths
   did not yet implement the shared resource/tier messages, rate limit, sound
   and particle contract completely.
5. **Medium — lost combat-use capability.** Rebuilt pick capabilities did not
   preserve the effective `punch_attack_uses` values produced for the vendored
   tools by Luanti's registration preprocessing.
6. **Medium — impure mining decision.** The public decision helper recorded a
   protection violation, so inspection had a side effect and an actual refusal
   could record the same violation twice.
7. **Medium — regression-harness blind spots.** Tests did not prove several
   runtime-derived capabilities, recipe/alias outcomes, derivative callbacks,
   natural-taxonomy exclusions, feedback details and refusal side effects.
8. **Low — implementation-brief EOF hygiene.** A redundant trailing blank line
   remained at the end of the brief.

Commit `a90360367810b856cf1963c90b296b6bdbac7e0f` fixed all eight findings and
expanded the integration and source-audit coverage. Focused re-review found one
remaining **Medium** issue: the bare-hand/no-pick message always claimed T1,
including at y = -2000 where the required depth tier is T6. Commit
`dc1902397856394c0d50a80fdcdb1b968c898f5c` changed the message to use the
structured `depth_required_tier` and added the deep no-pick regression; its
targeted re-review was clean.

The final full-branch review through `85f0ae83ea382edb0a1732522e612c81a619aa8a`
found one **Low** documentation defect in production source: the depleted-vein
fallback comment still described the retired WP25 node-level/stratum-identity
gate. Commit `c3a32ed655082e11a62531c6b444d4418ea620e2` replaced only that comment
with the correct cosmetic-stratum and target-y explanation. Focused re-review
confirmed that no executable code changed and was clean.

Final disposition: **CLEAN, with no open findings**.

## Verification

The final review gates passed:

- `tools/wp43/run.sh`: WP43 production integration tests and source audit.
- All six WP39 Lua 5.1 regressions: cast/projectile, combat aim, combat debug,
  combat integration, projectile foundation and swing aim.
- `tools/bin/luac51 -p` for every Lua file changed from the reviewed base.
- `bash -n` for both changed WP43 shell scripts.
- The five Lua compatibility grep sweeps, with all matches classified as
  comments or ordinary text delimiters.
- `git diff --check` for the complete reviewed branch and focused fix diffs.
- Local Markdown-link audit for all changed Markdown files.
- Stale-reference classification for Emberstone, Mese, Grudgesteel,
  `maxlevel`, `leveldiff`, `level_for_tier`, retired tools and legacy
  namespaces.
- Scope audit for recipes, gear, economy and mapgen expansion.
- Clean worktree and all nine reference submodules present at their unchanged
  pinned commits, with no `+`, `-` or `U` status.

WP43 did not implement the WP26 furnace/alloy recipes, the WP29 final gear and
pick catalog, the WP40 regional mapgen geometry, or the WP44 economy rebase.
It published and migrated only the material/depth/harvest contracts and the
consumer changes necessary for those contracts.

No GUI or in-game runtime test was performed by the reviewer. The documented
fresh-world mapgen pass and backed-up WP25-world migration pass remain user
runtime checks.
