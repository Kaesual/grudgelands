# Round 14 quest and party UI working record

Status: implementation candidate; integrated review and final conformance are pending.

## Implemented boundary

- The inventory has `Quests` and `Group` pages using the shared 10.4 × 11.1
  sfinv geometry. Both keep all content above y=7 and retain the standard
  inventory below y=7.2.
- Quests shows the 20-slot journal, selectable detail, live objectives and
  rewards, ready-to-return state, three-entry tracking, a persisted HUD switch,
  and a two-step abandon action. Kill objectives derive explicit target names
  from registered entity descriptions even when authored prose is generic.
- Group shows invite preferences, pending accept/decline actions, current
  membership including offline state, and leader kick/transfer plus voluntary
  leave. Submitted names and selected rows are presentation state only; every
  action passes the authenticated PlayerRef to party core for revalidation.
- Shared HUD anchors place up to three tracked quest blocks at the upper left
  and the ten-member party list below its reserved quest area. Existing
  top-centre target and top-right status displays remain untouched. HUD packets
  are compare-before-write; party HP and live item readiness sample at 0.5 s.
  Inventory callbacks provide immediate quest readiness refresh, while the
  bounded fallback covers builtin pickup paths.

## Remaining integration gates

Root owns independent review, integrated static gates, the final compact
PUC/LuaJIT parity fixture, native boot and GUI runtime testing. Runtime should
exercise a full 20-quest journal, three longest tracked objective blocks and a
ten-member party at representative HUD scaling, plus invite expiry, offline
rows, leadership actions, item pickup readiness and reconnect persistence.

## Coordinator corrections before independent UI review

The party HUD now uses real image HP bars from the shared bar texture/palette,
not ASCII text bars. Its first row starts at y=260 with 30-pixel spacing, leaving
a conservative gap below the quest tracker. Hidden/absent parties remove rows;
unchanged health sends no packet. Quest blocks reserve one title line and two
objective lines, with progress counts first so long target names cannot hide
the count. Full text remains in the journal.

Pending invitation highlights now follow the selected inviter, reconcile an
expired selection, and resolve list clicks against rendered names. Previously
the displayed first-row highlight could disagree with the actual action target.
The expanded production UI fixture passes 17 checks, including graphical HP
changes, unchanged-packet suppression and selection reconciliation.
`journal()` also skips holdings scans when no quests are active; this one-line
core optimization is subsequent to the core review and needs UI review coverage.
