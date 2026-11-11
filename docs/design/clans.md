# Clans

Decided 2026-11-11 (the user's rulings, Round 76); implemented in Round 76
(`grug_clans`). Provenance: [Round 76 plan](../planning/round76-plan.md) §2
(rulings) and §3.1 (coordinator defaults, built as written below; the user
may overrule them). Parties stay as they are ([parties.md](parties.md)).

## Rulings (the user, 2026-11-11)

1. **A clan is a second kind of party, without a HUD and without any effect
   in the game.** Purely social: no XP, loot, quest, map, Expedition or PvP
   effect, no bank, no shared building rights. A player may be in one clan
   and one party at the same time; the two are independent, and a party may
   hold players of different clans. Parties stay the unit for content
   (Expeditions, raids); a clan is the long-lived social group.
2. **No name, no tag, no founding cost.** A clan is as anonymous as a party.
3. **A clan forms like a party:** a player without a clan invites another
   player without a clan; when the invitation is accepted the clan exists
   with two members and the inviter as its leader. There is no one-member
   clan: when the second-to-last member goes, the clan dissolves.
4. **Same faction only.**
5. **At most 100 members** (a party stays at 10).
6. **Roles:** **Leader** (exactly one), **Captain** (any number), **Member**.

   | Action | Leader | Captain | Member |
   |---|---|---|---|
   | Invite | yes | yes | no |
   | Kick a member | yes | yes | no |
   | Kick a captain | yes | no | no |
   | Make captain / Make member | yes | no | no |
   | Make leader | yes | no | no |
   | Leave | yes | yes | yes |

7. **Social tab:** a clan card like the party box; online clan members are
   listed first. The PvP card moved below the Online Players list, so the
   page holds four cards.
8. **Online Players:** two invite buttons per row, **Party** and **Clan**;
   clan mates carry a small mark.
9. **Chat:** `/c <text>` clan chat in green (and `/p` party chat in blue,
   [parties.md](parties.md#party-chat)). Every member may write; there is no
   clan mute. Both need `shout`, like public chat; every player holds it by
   default, so this matters only for a player whose `shout` an admin revoked.
10. **Presence lines:** a clan member's login and logout show in clan chat.

The user's choices during the round (2026-11-11), on the screenshots:
the Online Players order stays (faction, favourites, name; the mark shows
clan mates, ruling 7 reads as the clan card); the wordings "5 min ago",
"new clan" and "Member" stay; the party, clan and player lists share one
row style; the clan list has Online and Offline tabs with pages of seven
(a 100-member clan in one list made the page about 30 KB larger).

## Membership

- **Succession:** when the leader leaves, is kicked or changes faction, the
  first captain in join order leads; without a captain, the first member in
  join order. Offline leaders keep the lead indefinitely, as in a party;
  logout never moves it.
- **Make leader:** the leader may hand the lead to any member; the old
  leader becomes a captain.
- **Kicking offline members** is allowed (inactive members can be cleared
  out); every rule counts offline members like online ones.
- **Faction change** removes the player from the clan, as from a party; the
  check also runs at login.
- **Offline rows:** the last known level and class are stored with the
  membership, and **`last_online`**, the time of the member's last logout.
  It is stamped at logout, at login, when the member joins the clan and at
  server shutdown (before the engine kicks the players), so after a crash an
  offline row shows the last login instead. Online rows read level and class
  live.

## Invitations

Same mechanics as party invitations ([parties.md](parties.md#invitation-model)),
bound to the inviter: only online players, **120 s** to answer, **one per
second per sender**, at most **ten pending** clan invitations per recipient,
one per inviter and recipient (a repeat is a no-op), and the accept checks
every condition again (faction, room, the inviter's role, the recipient's
switch). Accepting an invitation from a player without a clan founds a new
clan, also after the inviter's earlier clan dissolved.

- A clan member holds no clan invitations. When a player joins, its held
  invitations go, and so do the ones it sent (a member cannot invite); when
  a clan forms, the inviter's held invitations go too.
- **Sent invitations are cleared** when the sender is made member, leaves,
  is kicked, changes faction or logs out. A leader who hands over the lead
  becomes a captain and keeps them, since a captain may invite.
- **The "Clan invitations" switch** (per player, default on) is separate
  from the party's; turning it off refuses new clan invitations and drops
  the held ones. Party invitations are not affected.
- **No HUD:** the party's invitation box stays party-only. A clan invitation
  is announced with one plain chat line, "<name> has invited you to join
  their clan. Open the Social tab to answer.", and answered on the Social
  tab. A decline is not announced to the inviter (party parity).
- Each invitation expires by its own timer (no globalstep); a read treats an
  expired one as gone.

## Clan chat and lines

- **`/c <text>`** sends `[Clan] Name: text` in green (`#7ee081`) to the
  online members, the sender included. No history, nothing reaches offline
  members. Each message goes to the server log at `action` level, like
  Luanti's `/msg`: `Clan chat from <name> to clan <id>: <text>`. Without a
  clan the command answers "You are not in a clan.", without text "Write a
  message after /c."
- **Presence lines**, to the other online members: `[Clan] Name came
  online.` and `[Clan] Name went offline.`
- **Membership lines**, in the same green to the online members, the
  leaving player included: "X joined the clan.", "X left the clan.", "X was
  removed from the clan by Y.", "X left the clan (changed faction).", "X is
  now a captain.", "X is now a member.", "X now leads the clan." (a hand-over
  or a succession) and "The clan has been dissolved." (to the last two).

## The clan card (Social tab)

The Social tab's layout, row style and refresh rules are in
[parties.md](parties.md#the-social-tab). The clan card is the left bottom
card (`grug_clans/social.lua`, installed as `grug_parties.clan_section`):

- **Heading** "Clan (n/100)" and the **Clan invitations** switch.
- **With a clan:** two tabs, **Online (n)** (the default) and **Offline
  (n)**, and **pages of seven** rows with "‹ p / P ›" (an arrow at the end is
  dimmed and does nothing). Only the shown page is sent. Columns: class and
  race icons (race only for online members: clans store none), name, role
  (Leader, Captain, Member), level, and **STATUS** "Online" on the Online
  tab or **LAST ONLINE** "5 min ago", "3 h ago", "2 d ago" on the Offline
  tab. Order: online members by role (leader, captains, members), then by
  name; offline members by most recent logout. The own row is tinted, not
  marked "(you)".
- **Party button (0.76.1, the user's ruling 2026-11-11):** each online
  row but the own ends in the Online Players **Party** button (same label,
  size, look and tooltip), shown only when `grug_parties.can_invite` allows
  the party invitation now: not on party mates, members in another party,
  players with party invitations off or already invited by the viewer, and
  on no row while the viewer's party is full or led by someone else.
  Offline rows never have one. The button lies above the row's pick, so a
  click on it invites and does not select the row; its message ("Success:
  Invitation sent." or the refusal) shows in the line under the list. The
  level and status columns of the party and clan rows moved left (4.95 and
  5.7) to give it room beside "Online".
- **Selection and buttons:** a click anywhere on a row selects it. **Leave**
  always; for the selected row the buttons the clan API allows: **Make
  captain** or **Make member**, **Make leader** and **Kick**. A tab or page
  change, or a refresh that moves the selected member off the shown page,
  clears the selection.
- **The line under the list** shows the last button's message ("Success:
  …" or "Refused: …") until the next row click, tab or page change, else a
  hint: "Click a member to select them.", "Selected: you.", "Members can
  only leave.", "Captains cannot act on the leader or other captains." or
  "Selected: <name>.".
- **Without a clan:** "N Pending Clan Invitations" and the invitations in
  the same rows (class, race, inviter, the inviter's clan size "23/100" or
  "new clan", level, seconds left "97 s"; the seconds update with the next
  send of the page), a click selects one, **Accept** and **Decline**; with
  none, "You are not in a clan." and a hint to invite with the Clan button.
- **Online Players:** a small green **clan mark** (tooltip "Your clan")
  after the faction icon of each clan mate, and the **Clan** button
  (tooltip "Invite to your clan") on a row only when the clan API allows the
  invitation now.
- Tab, page and selection are session state.

## Saved state

- Mod storage `grug_clans`, key `clans`: one serialized table, `{next_id,
  clans = {[id] = {faction, members = {{name, role, level, class,
  last_online}, ...}}}}`, members in join order (succession reads it). The
  name index is derived at load. At load an invalid or duplicate member is
  dropped, a clan with fewer than two members goes, a second leader becomes
  a captain and a clan without one gets its successor; each repair logs a
  warning (and is saved with the next change).
- Mod storage `grug_clans`, key `clans_unreadable`: written only when
  `clans` cannot be read; the store then starts empty and an error is logged.
- Player meta `grug_clans:invites_off`: 1 when the Clan invitations switch
  is off; 0 or absent means on.
- Invitations, the rate limit and the card's tab, page and selection are
  session state.

The API the Social tab reads and the mod's seams: [mod map](../technical/mod-map.md)
and [module guide](../technical/module-guide.md).
