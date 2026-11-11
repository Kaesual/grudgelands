# Round 76 — Clans, party chat and clan chat

Planned with the user on 2026-11-11 after player requests for a clan feature. Routing
(user's standing rule): one coordinator, lanes as subagents of the session model,
independent review of every lane with game logic. Version **0.76.0**, expected
**compatible**: no map reset, no change to saved party data; clans add one new
mod-storage key and one new player-meta key.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a
  ruling until the user says so; a coordinator default is marked as such.
- Name functions rather than line numbers.

## Why

Players keep asking for clans. Today they keep a permanent party of ten as one. That
collides with Expeditions, which take three or four players
(`grug_expeditions/catalogue.lua` `max_players`): the party is the unit for content, and
a long-lived social group has nowhere else to live. A clan is that second, purely social
group. Parties stay exactly as they are and stay free for Expeditions, capital raids and
other temporary groups.

## 1. Lanes and order

Start state: main `64d585f4` (0.75.4). Integration branch `round76` in `.claude/worktrees/round76`;
every lane branches from it.

| Lane | Goal (§4) | Wave | Merge order | Review |
|---|---|---|---|---|
| CLAN | The clan state, rules and API in a new mod `grug_clans`; `/c` clan chat with presence lines; `/p` party chat | 1 | 1 | independent |
| SOCIAL | The Social tab in four cards: party, clan, online players (party and clan buttons, clan mark), PvP | 2 (after CLAN merged) | 2 | independent; screenshots to the user before the merge |
| D | Design doc, mod map, help text, completion, GUI checklist | after every merge | — | coordinator |

SOCIAL waits for CLAN because the clan card is a view of CLAN's API; the API contract is
fixed here (§3.2), so SOCIAL's brief can be written before CLAN finishes.

## 2. User rulings (2026-11-11)

1. **Clans are a second kind of party, without a HUD and without any effect in the
   game.** Purely social: no XP, loot, quest, map, Expedition or PvP effect, no bank, no
   shared building rights. A player may be in one clan and one party at the same time;
   the two are independent, and a party may hold players of different clans.
2. **No name, no tag, no founding cost.** A clan is as anonymous as a party.
3. **A clan forms like a party:** a player without a clan invites another player without
   a clan; when the invitation is accepted, the clan exists with two members and the
   inviter as its leader. There is no one-member clan: when the second-to-last member
   goes, the clan dissolves.
4. **Same faction only**, like parties.
5. **Limits:** party 10 (unchanged), clan 100.
6. **Roles:** **Leader** (exactly one), **Captain** (any number), **Member**.
   - Only the leader makes members captains and captains members again.
   - Leader and captains invite. Members do not.
   - Captains kick members only, never another captain or the leader. The leader kicks
     anyone.
   - Captains cannot promote or demote anyone.
7. **Social tab:** a clan section like the party section. Online clan members are always
   listed first. The PvP card moves below the Online Players list (which scrolls), so
   the page holds four cards.
8. **Online Players list:** two invite buttons per row, **Party** and **Clan**; clan
   mates get a small mark.
9. **Chat:** `/p <text>` party chat in blue, `/c <text>` clan chat in green. Both are
   free (no mod and no Luanti built-in registers them). Every member may write. There is
   **no clan or party mute.** Both need `shout` like public chat; every player holds it
   by default (Luanti `default_privs`), so this only matters for a player whose `shout`
   an admin revoked.
10. **Presence lines:** when a clan member logs in or out, the online clan members see
    it in clan chat.

### 2.1 The user's choices during the round (2026-11-11)

On SOCIAL's screenshots and two mockups (the second, v2, at the same artifact URL):

11. **The Online Players order stays** (faction, favourites, name). Ruling 7's "online
    clan members first" is the clan card; the clan mark shows clan mates in the list.
12. **Wordings stay:** "5 min ago" (not "5 min"), "new clan" for an inviter without a
    clan, "Member" spelled out in the role column.
13. **One row style** for the party, clan and player lists (clear columns, the own row
    tinted, a click on a party or clan row selects it); the left cards narrower (8.6),
    the right wider (10.8).
14. **The clan list has Online and Offline tabs and pages of seven** (one list of 100
    members made the page about 30 KB too large); the party list shows six rows and
    scrolls from seven.
15. **The party's HP column becomes the clan's status column** ("Online" / "Offline"):
    the page is not re-sent on HP changes, so the number was a stale snapshot; the
    Party HUD keeps live health.
16. **Party invitations in the row style** of the clan invitations (class, race,
    inviter, party size, level, seconds left).
17. **Selection hints** under the clan list as in the mockup, and **no "(you)"** in the
    party and clan rows (Online Players keeps it).
18. No merge of SOCIAL without the user's explicit go after the screenshots (given).

## 3. Shared conventions

### 3.1 Rules not covered by a ruling (coordinator defaults, the user may overrule)

- **Succession:** when the leader leaves, is removed by a faction change, or the clan
  otherwise loses its leader, the first captain in join order leads; without a captain,
  the first member in join order. Offline leaders keep leadership indefinitely, as in a
  party.
- **Make leader:** the leader may hand leadership to any member; the old leader becomes
  a captain.
- **Demotion clears sent invitations:** a captain made member loses the invitations it
  sent (as a party leader does on transfer).
- **Kicking offline members is allowed** (clearing out inactive members needs it).
- **Invitations:** same mechanics as party invitations: only online targets, two minutes
  to answer, one per second per sender, at most ten pending clan invitations per
  recipient, accept re-checks every condition, a clan member holds none. A **separate
  "Clan invitations" switch** (player meta), default on; the party switch stays as it is.
- **No HUD for clan invitations.** The party's invitation box stays party-only; a clan
  invitation is announced with one chat line and answered on the Social tab.
- **Faction change** removes the player from the clan, as from the party.
- **Membership lines in clan chat:** joined, left, kicked, promoted, demoted, new leader
  and "the clan has been dissolved" go to the online clan members as clan chat lines.
- **Chat format:** `[Party] Name: text` in `#6fb6ff`, `[Clan] Name: text` in `#7ee081`;
  presence `[Clan] Name came online.` / `[Clan] Name went offline.` in the same green.
  The sender sees its own line. Without a party or clan, or without text, the command
  answers with one plain line. Each message is written to the server log at `action`
  level, like Luanti's `/msg`. No history, no message to offline members.
- **Last online:** each clan member's last logout time is stored with the membership
  (needed for the offline order, §4 SOCIAL).

### 3.2 The clan API (`grug_clans`, CLAN owns it, SOCIAL reads it)

The shape follows `grug_parties`, so SOCIAL can mirror the party card:

- `view(player)` → nil or `{id, leader, faction, members = {{name, role, online,
  level, class, last_online}}}`, `role` one of `"leader"`, `"captain"`, `"member"`.
- `in_clan(player)`, `same_clan(a, b)`, `role_of(name)`.
- `pending(player)`, `invitations_enabled(player)`, `set_invitations_enabled(player, on)`.
- `can_invite(inviter, recipient)`, `invite`, `accept`, `decline`, `leave`, `kick`,
  `promote`, `demote`, `transfer_leader` — each returns `ok, message`; the permission
  rules of §2.6 live only here, the UI asks `can_*` and never decides.
- `can_kick(viewer, target)`, `can_promote(viewer, target)`, `can_demote(viewer, target)`,
  `can_transfer(viewer, target)` for the buttons.
- `register_on_change(callback(names, reason))` like the party's, so the Social tab
  re-sends through its existing limiter.

### 3.3 Shared files

- `grug_parties/init.lua`: CLAN adds `/p` there (the party's own chat). Nothing else in
  the party logic changes.
- `grug_parties/ui.lua`: SOCIAL only.
- `grug_pvp/page.lua`: the card already takes its position from the caller's container;
  SOCIAL changes it only if the card must shrink.
- `grug_inventory/help.lua`, `docs/technical/mod-map.md`, `docs/design/`: D only.
- `game.conf`, the upgrade declaration, `CHANGELOG.md`: root.

## 4. Lane goals

### CLAN

A new mod `mods/PLAYER/grug_clans` (state, rules, invitations, chat, presence) with the
API of §3.2, persisted in its own mod storage like `grug_parties` (one serialized table,
validated at load, membership derived). It depends on `grug_factions`, `grug_xp`,
`grug_classes` and `grug_parties` (for `is_online`); `grug_parties` must not depend on
it. Rulings §2.2–§2.6, §2.9, §2.10 and the defaults of §3.1 hold. `/p` goes into
`grug_parties`, `/c` into `grug_clans`. A focused portable fixture covers forming,
the 100 limit, every role permission in both directions, succession, dissolving at one
member, faction change, invitation expiry and the switch, offline kick, persistence
across a reload, and the chat recipients and colours.

### SOCIAL

The Social tab (`grug_parties/ui.lua`) in four cards on the 20 × 13.5 page:

- **Left top, Party:** unchanged content, shorter (a party has at most ten rows).
- **Left bottom, Clan:** heading `Clan (n/100) · k online` and the "Clan invitations"
  switch. With a clan: a member table (class icon, name, role, level, `Online` or
  "last online" age), online members first, then by most recent logout; the buttons the
  API allows for the selected row (Leave, Kick, Make captain / Make member, Make leader).
  Without a clan: the pending clan invitations with Accept and Decline, or one line
  explaining the Clan button.
- **Right top, Online Players:** the existing list, shorter (it scrolls). Per row a small
  green clan mark for clan mates, and two narrow buttons **Party** and **Clan** in place
  of Invite, each shown only when the API allows it.
- **Right bottom, PvP:** the existing section at the same size, moved from the left.

The existing refresh rules (one send per 2 s, none while the scrollbar is dragged) cover
clan changes too. The clan mark is a small 16 px texture in the simple icon style; the
lane draws it and the user judges it in the GUI test. Screenshots of the four cards
(with and without party and clan, as leader, captain and member) go to the user before
the merge. The user's preview before the round (HTML mockup, private artifact):
https://claude.ai/code/artifact/17614e5a-0f81-48e3-93da-01c3de4d6b23

### D

`docs/design/clans.md` (the rulings and defaults of §2 and §3.1), a `grug_clans` row in
the mod map and the `grug_parties` row updated, the Social tab paragraph in
`grug_inventory/help.lua` (clans, `/p`, `/c`), completion notes and the GUI checklist
below.

## 5. Rules

[Round workflow](../process/round-workflow.md), [AGENTS.md](../../AGENTS.md), Lua 5.1.
Focused fixtures per lane; the full fixture suite runs once at the round end, by the
coordinator. Maximum eight Lua processes across all agents. No sync to Luanti and no push
by any lane.

## 6. Verification and GUI checklist

Code: changed-file Lua check, the CLAN fixture, the existing party, Social tab and PvP
fixtures, the full suite at the round end, upgrade declaration self-test, headless boot.

User GUI test (desktop and web), with at least three accounts of one faction and one of
the other:

1. A invites B to a clan with **Clan**; B accepts on the Social tab; both see the clan
   card, A as leader. No HUD element appears.
2. A party between A and C (not in the clan) works as before; A is in both.
3. A makes B captain; B invites C; C joins. B cannot kick, promote or demote A or
   another captain; B kicks a member; A kicks B.
4. A leaves: the first captain (else the first member) leads. With two members, one
   leaves: the clan is gone for both.
5. A player of the other faction never shows a **Clan** button and cannot be invited.
6. The clan card opens on **Online (n)**: leader, captains, members, each by name.
   **Offline (n)** lists by most recent logout with "5 min ago" / "3 h ago" / "2 d
   ago". With more than seven, pages "‹ p / P ›"; an arrow at the end is dimmed and
   does nothing; a tab or page change clears the selection. Try it with 30+ members.
7. Clan mates carry the green mark in Online Players (tooltip "Your clan"); judge
   whether it reads as a clan sign at 16 px. **Party** and **Clan** fit in their
   buttons at the smallest and largest text size.
8. `/p` and `/c` reach exactly the online party and clan members, in blue and green,
   with `[Party]` / `[Clan]`; without a party or clan the command explains why.
9. A clan member logging in or out shows `[Clan] … came online.` / `… went offline.`.
10. The "Clan invitations" switch off: clan invitations are refused, party invitations
    still arrive.
11. The PvP card works from its new place (flag button, countdown, statistics).
12. A server restart keeps clans, roles and last-online times.
13. **Four cards:** party and clan left, Online Players and PvP right; nothing
    clipped or overlapping at the smallest and largest text size, on desktop and
    web.
14. **Long names:** a 20-character name (with "(you)" on the own row) in Online
    Players, and in the party and clan name columns, does not run into the class
    icon or the role column, at the largest text size too.
15. **One row style:** alternating rows, the own row tinted, a click anywhere on a
    party or clan row selects it (stronger tint and a frame); no "(you)" in party
    and clan rows.
16. **Party rows:** the last column is "Online" (green) or "Offline", no HP; the
    Party HUD still shows live health. Six rows visible, the list scrolls from
    seven.
17. **Party invitations** (without a party) are rows: inviter, party size, level,
    seconds left; a click selects one; Accept and Decline act on the selected one.
    An inviter without a party shows "1/10" (the clan card says "new clan"): judge
    whether that reads right. The Expedition warning still shows beside Accept.
18. **Clan invitations** (without a clan) in the same rows with "23/100" or "new
    clan"; the invitation arrives as one chat line, with no HUD box. The seconds
    count down only when the page is re-sent (as for parties).
19. **The party's messages** (Party button, Accept, Leave, Kick, Make leader) show
    in the Online Players heading row, readable beside the count: the lane's
    deviation from the mockup (the party box has no free line).
20. **Clan hints** under the list: "Click a member to select them.", "Selected:
    you.", "Members can only leave." (as member), "Captains cannot act on the leader
    or other captains." (as captain), "Selected: <name>."; a button's "Success: …"
    or "Refused: …" holds the line until the next row click, tab or page change.
21. **Buttons per role** on the selected row: leader sees Make captain or Make
    member, Make leader and Kick; a captain Kick on members only; a member only
    Leave. Each action shows its message in the clan card.
22. **Refresh:** while the tab is open, another player's login, a role change or a
    kick updates the card and the Online Players buttons within about 2 s; the
    scroll positions (party, invitations, Online Players) and the selected clan
    member (while on the shown page) survive it. A click right after the list
    moved acts on the highlighted row.
23. **Offline clan rows** show the class icon but no race icon (clans store no
    race): judge whether that is fine.
24. `/c` with `shout` revoked gives the builtin refusal; `/p` and `/c` lines appear
    in the server log.

## Completion (2026-11-11)

Both lanes are merged into `round76` at `16a93af3`; this lane D runs on it. **Nothing is
on main and nothing is pushed:** `round76` lands on main as one squash commit (0.76.0,
tag `round-76`) after the round-end full run and the user's go. CLAN and SOCIAL had an
independent review each; SOCIAL also two delta reviews of its fix rounds.

Round-end full run: 345 passed, 1 failed on `16a93af3` (CLAN + SOCIAL); the failure,
`r451_kf`, was a fixture stub (the shared `r44_ts` harness lacked `grug_classes.get_race`)
and a pin on the old member table, fixed in `0d85b01c`; that fixture with 11 related ones
12/0, and `r451_kf` + `r44_pp` 2/0 on the merged tree after lane D. After main (0.75.5) was
merged in (`b32ef5e4`, release files only): 347 passed, 0 failed.

**0.76.0 is compatible:** no step, no map reset, no new world. Both lane reports say
compatible and lane D's reading agrees: a new mod with its own storage key, no change to
world generation, the party storage untouched (`/p` reads it). A 0.75.4 world has no
`clans` key, which reads as no clans. Saved state, all new: mod storage `grug_clans` /
`clans` (one serialized table), `grug_clans` / `clans_unreadable` (only when `clans`
cannot be read) and player meta `grug_clans:invites_off`. Everything else (invitations,
the card's tab, page and selection, the notices) is session state.
`check_upgrade.py --base 64d585f4` (0.75.4) passes; `check_fresh_server.py` passes.

### Lanes

`round76`'s first-parent merges from the plan `352b6f3c` (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| CLAN | `151cfe6d` (`35a84fbd`) | `grug_clans` (state, rules, invitations, `/c`, presence and membership lines); `/p` in `grug_parties` | MERGE (5 backlog notes) |
| SOCIAL | `16a93af3` (`aaf498dd`; first build `cd6199a2`, fix 1 `80745cf3` / `6f5551bd`, fix 2 `aaf498dd`) | The Social tab in four cards, the clan card with tabs and pages, one row style, the clan mark | MERGE (2 Low), delta 1 MERGE (4 Low), delta 2 MERGE (2 nits) |
| D | this branch, `r76-d` | `clans.md`, parties.md, mod map, module guide, help text, release 0.76.0, this completion, BACKLOG | coordinator |

### What shipped, with numbers

Fixture numbers on the fixture's fake engine.

- **CLAN:** `mods/PLAYER/grug_clans/init.lua` (568 lines) and `/p` (22 lines in
  `grug_parties/init.lua`). `r76_clan`: 561 checks, 0.05 s; a mutation pass on a scratch
  copy caught all 5 seeded bugs. `r67_social` (the only fixture loading the real party
  `init.lua`) needed one stub line. Smoke boot through the queue: no line names
  `grug_clans`.
- **SOCIAL:** `grug_parties/ui.lua` (four cards, `row_list`, `column_heads`,
  `member_cells`, the `clan_section` seam, `social_resend_all`), `grug_clans/social.lua`
  (325 lines), the 16 px mark `grug_clans_mark.png` (drawn by `tools/r76_social/clan_mark.py`),
  `grug_pvp/page.lua` (card width 10.8 and its two columns). `r76_social`: 181 → 280 → 301
  checks over the three builds; `r67_social` 114, `r44_pp` 186, `r26_status_icons` 420,
  `r31_p2` 107 (each updated with a one-line reason where it pinned the old tab).
  Three capture runs (one per build: 6, 7 and 7 shots in
  `~/projects/grudgelands-orchestration/r76/social-shots/`, `v2/`, `v3/`).
- **Formspec bytes** of the Social tab, 0.75.4 → 0.76.0: `r67_social` with 1 / 10 / 50
  players listed 1998 / 6749 / 27988 → 1905 / 7236 / 29831 (the Clan button and its
  tooltip per row); `r44_pp` out of a party 6445 → 7346 (invitation rows instead of the
  textlist), in a party of 3 6773 → 7666. Leader of a 100-member clan with about 80
  online: 56358 with the whole member table (first build) → 55040 with tabs and pages
  (Online tab; Offline tab 54238 at fix 1); the clan card is about 3.9 KB of that.
- **The dependency seam:** `grug_parties` cannot read `grug_clans` (an optional
  dependency on a mod that depends on it is a cycle the engine refuses,
  `src/content/mod_configuration.cpp`), so `grug_clans/social.lua` installs
  `grug_parties.clan_section` (card, field handler, mark, Clan button check), as
  `grug_pvp` installs `pvp_section`; `ui.lua` draws a stand-in without it. The
  `r76_social` fixture checks that `grug_parties`' `mod.conf` never names `grug_clans`.
- **Performance:** no globalstep and no per-tick work. Clan invitation expiry is one
  `core.after` per invitation; clan changes re-send through the existing 2 s limiter
  (membership, role, presence and the switch every Social viewer, level, class and
  invitations only the named players).

### The user's decisions during the round

§2.1 (rulings 11–18, 2026-11-11): the Online order kept, the wordings kept, one row style
and new card widths, clan tabs and pages, the party status column instead of HP, party
invitations as rows, the selection hints and no "(you)" in party and clan rows.

### Coordinator defaults the lanes built

All of §3.1 as written: succession by join order (first captain, else first member);
Make leader turns the old leader into a captain, **who keeps the invitations it sent**;
sent invitations go on demote, leave, kick, faction change and logout; offline kicks
allowed; invitations with the party's mechanics and a separate switch; no HUD for clan
invitations (one chat line); faction change removes (checked at login too); membership
and presence lines and the chat format and colours; `action`-level log lines
("Clan chat from N to clan ID: text", the party's alike); `last_online` stamped at
logout, login, joining and shutdown. Rules in [clans.md](../design/clans.md).

### Deviations

- **The party's messages show in the Online Players heading row** (fix round 1): the
  mockup left the party box no free line, and most party messages answer that list's
  Party button. The alternative is a five-row party list with a notice line under it.
  GUI item 19.
- **Offline clan rows have no race icon:** party and clan store no race. Storing it with
  the class would be one field, compatible. GUI item 23.
- **The clan heading is "Clan (n/100)"** without the plan's "· k online": the Online and
  Offline tabs carry the counts.
- A party invitation from a player without a party reads "1/10" where the clan card says
  "new clan" (delta review 2 nit). GUI item 17.

### Open for the user

- The GUI test (§6, 24 items, desktop and web), the clan mark's look among them.
- Backlog notes from the reports and reviews: [BACKLOG](../../BACKLOG.md#round-76--clans-party-chat-and-clan-chat-gui-acceptance-pending).

## 0.76.1 follow-up

**Ruling (the user, 2026-11-11):** players can be invited to a party directly from the
clan list: a small **Party** button in the row of each online clan member, at the right
end of the row, shown only when a party invitation is allowed
(`grug_parties.can_invite(viewer, name)`), exactly like the Party button in Online Players
(same label, size and look). No selection needed. The bottom button bar stays as it is.

Built on branch `r761-party` (one lane, PARTY, with its own release lines): the button
in `grug_clans/social.lua`, drawn after the row's invisible pick through `row_list`'s new
`list.over` (the engine hands a click to the last element drawn at that point,
`irr/include/IGUIElement.h` `getElementFromPoint`), so a click on it invites and never
selects; its message shows in the clan card's line. The level and status columns of the
party and clan rows moved left (5.05 → 4.95, 5.95 → 5.7) so the button never covers
"Online". No new refresh: every change that moves the button already re-sends the page.
**Compatible:** nothing new is saved.

GUI checklist (desktop and web):

1. As a party leader (or without a party), the clan card's **Online** tab shows **Party**
   at the right end of each member's row that can be invited, the same button as in
   Online Players; none on the own row, on party mates, on members in another party or
   with party invitations off, and none on the **Offline** tab.
2. A click on **Party** sends the invitation ("Success: Invitation sent." under the clan
   list) and does **not** select the row; a click elsewhere on the row still selects it.
   The button goes while the invitation is pending and comes back after a decline or
   the expiry.
3. As a party member who does not lead, or with a full party (10), no row has the
   button; it appears within about 2 s when the party changes.
4. At the smallest and largest text size, "Online" and the button do not touch, the
   button stays inside the row, and the party card's columns still line up with the
   clan card's. The narrower role column still keeps "Captain" clear of "Lv", and in
   the invitation rows "new clan" and "23/100" clear of "Lv" (review note).

Checks: lane fixtures `r76_social` (404), `r44_pp`, `r67_social`; independent review MERGE;
full run on the merged `round76.1` 347 passed, 0 failed. From now on a small follow-up like
this one ends with the targeted fixture selection instead of the full run (user, 2026-11-11;
[round workflow](../process/round-workflow.md) §3).
