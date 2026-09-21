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
