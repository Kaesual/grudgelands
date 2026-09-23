# Round 19 lane B — Character, Talents and Skills report

Date: 2026-09-23

## Result

Lane B implements the approved interface clarification without changing any
stat, entitlement, inventory or respec rule.

- Character now presents maximum HP, maximum mana or rage, one armor rating,
  same-level reduction, effective Crit, effective Dodge and money. The former
  pool/armor derivation block and its duplicate armor summary are gone.
- Help retains the general pool and attribute formulas and now owns the cap and
  armor-rating explanations. Its assembled text remains formspec-escaped.
- Talents no longer presents Crit, Dodge or Armor. The freed header space moves
  the tree upward and enlarges the wrapped description area.
- One click on an available talent buys exactly one rank. The callback binds a
  fixed registered field to the submitting player's current class and visible
  tree, then delegates points, rank, tier and prerequisite validation to
  `grug_classes.spend_talent`. Repeated deliberate clicks buy one further rank;
  denied, stale, foreign-class and hidden-tree requests buy none. Existing
  respec confirmation and payment remain unchanged.
- Skills shows the short instruction above the catalog. Every assembled visible
  text value in the touched page is escaped; the raw semicolon-bearing textarea
  that previously serialized as six fields was removed. Ability and mount
  catalog construction, one-copy checks, entitlement and drag recovery are
  unchanged.

## Bounded evidence

`tools/r19_ui/fixture.lua` returns a canonical string from a repository path.
It loads the real talent registry, real Talents page and real receive-fields
callback. It proves first-click and repeated one-rank purchases, authoritative
gate refusal, and rejection of a forged fixed field for a talent outside the
visible tree. It also loads the real Character, Help and Skills page builders.

The fixture parses generated formspec elements with escape-aware delimiter
handling. Semicolon-bearing Help prose, a semicolon-bearing selected talent
description and semicolon-bearing passive Skills text each remain one textarea
text field; every touched textarea serializes with exactly five fields. This
checks the serialized structure rather than the presence of an escaped source
literal. The same generated Skills form is parsed for element geometry and
proves that the purchased-mount row ends before the passive-talents heading.

LuaJIT development result:

```text
character=concise-totals
skills=textarea-fields-5
talents=first-click+authority
```

Plain Lua 5.1 parsing passes for all three changed production files and the new
fixture. `SETGLOBAL` inspection finds no global writes in those files. All five
required source sweeps were run across `mods/*/grug_*` and `tools/r19_ui`; their
matches are pre-existing comments, literal data delimiters and the historical
WP40 manifest, with no forbidden construct in this lane's changed files. No PUC
runtime was run in this implementation lane; root owns the one final frozen-byte
PUC/LuaJIT micro-KAT pair.

## Limits and GUI check

The server-side fixture cannot certify client font wrapping or physical layout.
The user GUI pass should open Character, Help, both talent trees and Skills at a
normal and a smaller window size; verify that all concise Character totals fit,
tree controls and the description remain separated, one click buys one rank,
respec still asks for confirmation, and the Skills hint appears without an
invalid-textarea log entry. Drag one ability and one purchased mount out of and
back into Skills to cover the unchanged recovery interaction.

The historical `tools/wp11/talent_ui_kat.lua` encodes the superseded two-click
purchase and Talents stat-header contract, so it now reports expected failures.
The lane-specific fixture replaces those assertions for Round 19 rather than
rewriting evidence outside this lane's owned tool directory.
