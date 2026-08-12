# TODO — PvP death and XP loss

Opened 2026-08-12 while integrating the geographic PvP contract. This file
owns one question only: **does a death conclusively caused by hostile-player
PvP skip the ordinary current-level XP loss?**

## Context

The shipped `grug_xp` behavior applies one universal penalty: death removes
25% of the XP progress within the current level, never de-levels the character
and does not remove inventory. The decided PvE target retains that penalty.
WP41 will provide one authoritative PvP transaction and can classify a PvP
death without individual combat paths guessing from the current zone or a
stale tag. WP9 must not author quest rewards or penalties around an assumed
answer before this question is decided.

## Options

- **(a) Keep the shipped universal loss.** A PvP death and a PvE death both
  remove 25% of current-level progress. This is mechanically simple but adds a
  leveling penalty to participation in mandatory contested quest routes.
- **(b) Exempt confirmed PvP deaths.** A death attributed by the WP41 PvP seam
  to an eligible hostile player applies no XP loss; PvE, environment and
  unclassified deaths retain the ordinary 25% loss. This requires an exact
  attribution boundary and must not infer an exemption merely from standing
  in contested territory or carrying a PvP tag.

## Recommendation

Choose **(b)**. Mandatory level-31+ contested routes already impose travel,
combat and opposition costs; preserving the leveling penalty for PvE while
removing it only for authoritatively attributed PvP deaths encourages players
to participate without creating a zone-based death exploit.

**Decision:** _open_ — blocks WP9's final quest/death consequences. The
implementation seam itself belongs to WP41.

*Lands in*: `docs/design/progression.md` §3 and the WP9/WP41 handoff in
`BACKLOG.md`.
