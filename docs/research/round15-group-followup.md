# Round 15 Group roster follow-up

Date: 2026-09-21. Implementation: native Sol. Scope is limited to the Group
page and its bounded development fixture.

The typed invitation field is replaced by a scrollable snapshot of online
players in the viewer's current faction. The viewer is excluded and names are
sorted bytewise for stable presentation. Rows may show `Invites off` and `In
party`; these are hints from the current snapshot, while the existing invite
API remains authoritative for online state, faction, invitation preference,
party membership, leadership, capacity and cooldown at the moment of action.

The selected name is stored alongside the displayed snapshot. A connection,
faction or sort change therefore cannot reinterpret an old row number as a
different player. If a selected player disappears, selection clears instead
of falling through to another row. Page entry, the explicit Refresh button and
completed page actions rebuild the snapshot; there is no background polling. Existing pending
invitations, party management and preference controls remain.

The content switches to `real_coordinates[true]` after the shared SFINV wrapper
has emitted navigation and optional inventory elements. Its controls remain
within real y=0.22..6.73, above the wrapper inventory's legacy y=7.2 boundary
(about real y=8.31 under the 15/13 spacing conversion). Separate label and
control rows remove the prior overlap.

Development evidence:

- The returned fixture function in `tools/r15_ui_followup/group.lua` passes
  under LuaJIT for the sorted roster, self and
  hostile-faction exclusion, status labels, formspec escaping and a stale
  selected player becoming offline without row reinterpretation.
- Plain Lua 5.1 parsing passes for both changed Lua files. `SETGLOBAL` is empty.
- All five Lua compatibility sweeps were inspected. The operator sweep only
  matches the fixture's literal `|` digest separators; the other four have no
  hits.

The final PUC/LuaJIT parity pair remains coordinator-owned. Runtime acceptance
should open Group with several same-faction players, scroll and select a name,
refresh after a login/logout, invite, and confirm pending/member controls and
the inventory below do not overlap.
