# Parties

Decided 2026-09-21; Round 14 user Go. Clans, the second and purely social
kind of group (Round 76), have their own rules: [clans.md](clans.md).


### Confirmed by the user

- Maximum ten members, **always the same faction**. This is not a temporary
  V1 limitation; enemy factions cannot form a party.
- A party is created only when an invitation is accepted and there are two
  members. There are no persistent one-person parties.
- When membership falls to one, dissolve the party automatically. Offline
  players are still members and count toward both minimum and maximum size.
- Offline membership is indefinite, including across server restarts. Offline
  leaders keep leadership indefinitely; disconnects never elect a new leader.
- Only the leader invites and kicks while a party exists. Players without a
  party can invite to form one. Everyone may leave voluntarily.
- A Party tab manages invitations, accept/decline, leave and leader actions
  (since Round 44 the top section of the Party & PvP tab, with the PvP
  section and no inventory; since Round 67 the **Social** tab, below;
  [pvp.md](pvp.md) §5).
- Each player can disable incoming invitations. Rate limit is one invitation
  per second **per sender**. No ten-per-minute limiter or additional rate tiers.
- A saved per-player HUD switch defaults on. Without a party it is hidden.
  Display names and HP bars; offline rows display offline status, not fake
  live HP. No mana/rage bars in this round.
- No XP multiplier, passive nearby-party credit, loot mode, automatic quest
  sharing or party-owned mob tag is introduced. Existing participation governs
  XP and quest credit independently of party identity.

### Invitation model

An invitation refers to its **inviter**, not to a provisional party id. On
acceptance, validate both current factions, recipient eligibility/preferences,
current membership, inviter authority and available capacity again:

1. If the inviter is in no party, create a new two-person party.
2. If the inviter currently leads a party, join that party if space remains.
3. If the inviter is now an ordinary party member, refuse the stale invitation.

Therefore: A invites B and C; B accepts (A+B exists); B leaves (dissolve);
C accepts the still-valid invitation (new A+C party). No special orphan-party
state or generation history is necessary. The UI identifies the inviter and
shows current party context before acceptance; invites do not reserve slots.

Accepted defaults:

- One pending invitation per inviter/recipient pair; duplicate sends are a
  no-op and cannot create duplicate notifications.
- Invitations are short-lived (120 seconds), session-only, and require an
  online inviter/recipient to send/accept. A player in a party cannot be
  invited and holds no invitations: when a party forms, the pending
  invitations of both the joining player and the inviter are cleared, and
  so are the ones the joining player had sent (a member cannot invite);
  the inviter, who leads, keeps the ones it sent. A leader who hands the
  lead over loses the invitations it sent the same way (Round 67). Invitations never go through the
  mail ([mail.md](mail.md)); leaving the server expires that player's
  invitations but **never** their membership.
- Limit pending incoming invitations to ten so many different senders cannot
  grow the queue indefinitely. This is a storage cap, not another rate timer.
- Turning invites off removes pending incoming invitations as well.
- Store canonical membership/leader in mod storage and treat lookup indexes
  as derived. No two authoritative copies of party state.
- Explicit leadership transfer is allowed. If a leader voluntarily leaves while
  at least two members remain, the earliest-joined remaining member becomes
  leader, regardless of online status. This is one deterministic leave rule,
  without a mandatory successor-selection dialog. Logout never triggers it.
  Leaving a two-member party dissolves it instead.
- No automatic party cleanup for inactivity, region change, death or logout.
- Party HUD rows need not support click-to-target for V1. Do not broaden the
  current spell ally/targeting rules merely because parties now exist.

## HUD and atlas presentation

The party HUD sits at screen middle-left, vertically centred for the current
row count, with edge padding. Saved visibility and offline rows remain as above.

**Invitation box** (Round 67 ruling 2): while a player without a party holds
invitations, a box with the party icon stands at the party HUD's place:
"<name> has invited you to join their party.", "Open Social to answer
(N s)" with the seconds left, and "+N more" when other invitations wait. It
shows the newest invitation, whatever the Party HUD switch says, and goes
when the invitation is accepted, declined or expires. There is no chat
command to answer; the chat line at the invitation names the Social tab.
While the player owns an Expedition alone, the box and the Social tab beside
Accept add one line: "Accepting ends your Expedition." (Round 71), or, while
the run is unfinished, "Accepting ends your Expedition and gives you the
Deserter's Mark." (Round 72.1, [expeditions](expeditions.md) §3).
The atlas shows online member positions and headings in its current view; this
does not introduce any shared XP, quest or teleport authority.

## The Social tab

Round 67 (rulings 1–8) renamed the Party & PvP tab **Social** and rebuilt
it; Round 76 (rulings 7 and 8) made it four cards: left (8.6 wide), from
the top, the settings row (Invitations, Party HUD, Health colors), **one
party box** and the **clan card**; right (10.8 wide) the **Online Players**
list (it scrolls) and the PvP section below it ([pvp.md](pvp.md) §5). The
party, clan and player lists share one row style: alternating row
backgrounds, icons, fixed columns, the own row tinted; in the party and
clan lists a click anywhere on a row selects it (stronger tint and a frame).

- **The party box** shows the current party ("Current Party (n/10)", the
  member rows under small column heads: class and race icons, name, role
  ("Leader" only), level and status, "Online" or "Offline", as in the clan
  list; live health is the Party HUD's, since this page is not re-sent on
  HP changes; six rows visible, scrolling from seven) with Leave, and Kick
  and Make leader for the leader, or, without a party, the pending
  invitations under their count ("0 Pending Invitations", "1 Pending
  Invitation", …) in the same rows (class, race, inviter, party size,
  level, seconds left; an inviter without a party shows "1/10") with
  Accept and Decline; with none, a hint to invite
  with the Party button. The party and clan rows carry no "(you)" (the own
  row is tinted); Online Players keeps it. The two never show together, and accepting an
  invitation switches the box at once. The box's messages show in the
  Online Players heading row (the box has no free line).
- **The clan card** (Round 76, `grug_clans/social.lua`; rules in
  [clans.md](clans.md)) mirrors it: the
  heading "Clan (n/100)" and the "Clan invitations" switch, two tabs
  "Online (n)" (the default) and "Offline (n)", pages of seven rows with
  "‹ p / P ›", rows with class and race, name, role (Leader, Captain,
  Member), level and "Online" or the age of the last logout ("5 min ago");
  online members by role and name, offline ones by most recent logout.
  Only the shown page is sent. Leave always, and the buttons the clan API
  allows for the selected row (Make captain or Make member, Make leader,
  Kick); a tab or page change, or the selected member leaving the page,
  clears the selection. Each online row but the own ends in the Online
  Players **Party** button (0.76.1), under the same rule; its click invites
  without selecting the row (it lies above the row's pick) and its message
  shows in the clan card's line. The line under the list shows the last button's
  message until the next selection, tab or page change, else a hint:
  "Click a member to select them.", "Selected: you.", "Members can only
  leave.", "Captains cannot act on the leader or other captains." or
  "Selected: <name>.". Without a clan the pending clan invitations in the
  same rows (class, race, inviter, clan size or "new clan", level, seconds
  left) with Accept and Decline, or a hint to invite with the Clan button.
  Tab, page and selection are session state.
- **Online Players** lists every online player of both factions, one
  compact row each: faction, name, class, race and level, faction, class
  and race as icons with the word as tooltip; the viewer's own row is
  marked "(you)". Order: the viewer's faction first, then the other one,
  then players who have not chosen a faction yet; inside each, favourites
  first, then by name (case-insensitive), favourites by name too. It
  scrolls; there is no paging.
- **Row actions** on the right: a **star** that marks the player a
  favourite (any row but the own), and **Party**, shown only when the
  viewer may invite that player now: the viewer is in no party or leads
  one that is not full, and the target is of the viewer's faction, online,
  in no party, accepting invitations and not already invited by the
  viewer. Enemy rows therefore never show it. Beside it **Clan**, shown
  only when the clan API allows the clan invitation (`grug_clans.can_invite`),
  and a small green **clan mark** after the faction icon of every clan
  mate (Round 76). Each button names its player, never a place in the
  list; the invitation API decides again at the click. The same **Party**
  button sits in the clan card's online rows (0.76.1).
- **Favourites** are per character, saved by name in player meta (like the
  recipe favourites); only an online player can be marked.
- **Refresh:** the list follows joins, leaves, faction, class, race and
  level changes, party changes and the invitation switch, and the box
  follows the viewer's invitations. A clan change of membership, role,
  presence or the clan invitation switch re-sends every viewer (their Clan
  buttons and marks may move); other clan changes only the players named. Only players whose current inventory
  page is Social get sends (the server cannot tell whether the window is
  open), at most one every 2 s: changes in one server step make one send,
  a change inside the 2 s goes out when they end. A send waits 0.5 s after
  a scrollbar move, and the scroll position survives a resend. The PvP
  section's countdown goes through the same limit, so it steps by 2 s.

## Party health colors

Round 19: a saved personal dropdown on the Party (& PvP, since Round 67 Social) tab chooses **By class** (default)
or **All green**. Missing preferences use By class; an explicitly saved green
choice remains green. Class colors are Warrior brown, Mage
blue, Priest white and Scout olive-green, with dark backing for readability.
The colors are Warrior `#A66A3F`, Mage `#4A9BD8`, Priest `#F2F2F2` and
Scout `#6B7D32`; all-green remains `#4CAF50`, backing `#141414`.
Only the viewer's HUD changes. Offline rows remain labelled offline with no
fabricated live HP. The existing HUD visibility preference is independent.
Settings changes and health/class transitions update changed HUD fields only.
Since Round 26 each row also shows the member's class icon (Warrior, Mage,
Priest, Scout), in the party HUD and in the Social tab's "Current Party"
table, so the class is clear without knowing the colours. On that tab
an offline member or a member without a class shows a blank instead.

## Level presentation

Member and invitation labels include `[Lv X]`. Online levels are live; an
offline member retains the last known level in the persisted party record.
This does not introduce a separate global offline-player database.

## Party chat

Round 76 (ruling 9): `/p <text>` sends `[Party] Name: text` in blue
(`#6fb6ff`) to the party's online members, the sender included; every
member may write and there is no party mute. It needs `shout` like public
chat (every player holds it by default), is logged at `action` level like
Luanti's `/msg`, keeps no history and reaches no offline member. Without a
party or without text it answers with one plain line. The clan chat `/c`
belongs to the clans ([clans.md](clans.md#clan-chat-and-lines)).
