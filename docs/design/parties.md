# Parties

Decided 2026-09-21; Round 14 user Go.


### Confirmed by the user

- Maximum ten members, **always the same faction**. This is not a temporary
  V1 limitation; enemy factions cannot form a party.
- A party is created only when an invitation is accepted and there are two
  members. There are no persistent one-person parties.
- When membership falls to one, dissolve the party automatically. Offline
  players are still members and count toward both minimum and maximum size.
- Offline membership is indefinite, including across server restarts. Offline
  leaders keep leadership indefinitely; disconnects never elect a new leader.
- Only the leader invites and kicks while a party exists. Ungrouped players
  can invite to form one. Everyone may leave voluntarily.
- A Group tab manages invitations, accept/decline, leave and leader actions.
- Each player can disable incoming invitations. Rate limit is one invitation
  per second **per sender**. No ten-per-minute limiter or additional rate tiers.
- A saved per-player HUD switch defaults on. Ungrouped means hidden. Display
  names and HP bars; offline rows display offline status, not fake live HP.
  No mana/rage bars in this round.
- No XP multiplier, passive nearby-party credit, loot mode, automatic quest
  sharing or party-owned mob tag is introduced. Existing participation governs
  XP and quest credit independently of party identity.

### Invitation model

An invitation refers to its **inviter**, not to a provisional group id. On
acceptance, validate both current factions, recipient eligibility/preferences,
current membership, inviter authority and available capacity again:

1. If the inviter is ungrouped, create a new two-person party.
2. If the inviter currently leads a party, join that party if space remains.
3. If the inviter is now an ordinary party member, refuse the stale invitation.

Therefore: A invites B and C; B accepts (A+B exists); B leaves (dissolve);
C accepts the still-valid invitation (new A+C party). No special orphan-party
state or generation history is necessary. The UI identifies the inviter and
shows current group context before acceptance; invites do not reserve slots.

Accepted defaults:

- One pending invitation per inviter/recipient pair; duplicate sends are a
  no-op and cannot create duplicate notifications.
- Invitations are short-lived (120 seconds), session-only, and require an
  online inviter/recipient to send/accept. No offline mailbox; leaving the
  server expires that player's invitations but **never** their membership.
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

## Round 15 presentation

The party HUD sits at screen middle-left, vertically centred for the current
row count, with edge padding. Saved visibility and offline rows remain as above.
The atlas shows online member positions and headings in its current view; this
does not introduce any shared XP, quest or teleport authority.

## Online invitation roster

The Group tab offers a scrollable, name-sorted list of online players in the
viewer's faction, excluding the viewer. Each row retains the exact player name
as its action identity. Invitation opt-out and existing party membership are
shown as status; the unchanged invitation API decides whether an invite is
allowed at submission time. Losing the selected player clears selection rather
than choosing another player. Entering the page or pressing Refresh rebuilds
the list; no background roster polling is required. Names need not be typed.

## Party health colors

Round 17: a saved personal Group-tab dropdown chooses **All green** (default,
existing life-bar color) or **By class**. Class colors are Warrior brown, Mage
blue, Priest white and Scout olive-green, with dark backing for readability.
Only the viewer's HUD changes. Offline rows remain labelled offline with no
fabricated live HP. The existing HUD visibility preference is independent.
Settings changes and health/class transitions update changed HUD fields only.
