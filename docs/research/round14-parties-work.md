# Round 14 party core implementation

Status: implemented; awaiting independent review and UI integration.
Author: native GPT-6 Astra. Coordinator: GPT-6 Astra. Independent reviewer:
pending. Review elapsed time and correction rounds: pending. Scope: new
`mods/PLAYER/grug_parties/` core plus `tools/r14_parties/`; no combat, XP or quest
participation changes. Authority: `../design/parties.md`.

## Frozen UI contract

- `view(player_or_name)` returns nil when ungrouped, otherwise a fresh
  `{id,leader,faction,members={{name,online,hp,hp_max},...}}` snapshot in join
  order. Offline rows omit HP fields. IDs are opaque strings.
- `pending(player_or_name)` returns fresh, inviter-name-sorted
  `{inviter,expires_in,party=view(inviter)}` rows. Inviter identity is the action
  key; invitation slots are not reserved. Current group context is presentation.
- `invite(player,target_name)`, `accept(player,inviter_name)`,
  `decline(player,inviter_name)`, `leave(player)`, `kick(player,target_name)` and
  `transfer_leader(player,target_name)` return `boolean, English message`.
  Pass the authenticated current player from engine callbacks, never a name for
  the actor. Targets are exact player names. All authoritative checks repeat at
  transaction time.
- `invitations_enabled(player)`, `set_invitations_enabled(player,boolean)`,
  `hud_enabled(player)` and `set_hud_enabled(player,boolean)` use current player
  metadata. Both preferences default enabled; setters return boolean/message.
- `register_on_change(function(name,reason))` notifies affected players for
  membership, leadership, invitation, preferences and presence. Existing invite
  recipients are notified when their inviter's membership/leadership changes.
  Callbacks run after completed mutations; observers read snapshots. HP changes
  are read live by `view`, so the HUD adapter should sample on its own throttled
  refresh alongside other party rows.

Dependency: `grug_factions`. UI integration adds its explicit dependencies and
UI dofile to init; no file-existence fallback is present. The core owns no forms
or HUD coordinates. Use the shared `grug_core` HUD layout seam.

## State and lifecycle

One serialized mod-storage record owns groups, join order, leader and faction;
the membership index is reconstructed on startup. No player metadata duplicates
membership. Every membership/leadership mutation persists immediately. Groups
remain across disconnects/restarts indefinitely. Removing the leader elects the
earliest remaining member, including offline; one remaining member dissolves
instead. Logout never calls membership removal. Current faction changes remove
a mismatching member through the same succession/dissolution path. Rejoin also
checks persisted membership against the player's current faction.

Invites are inviter-bound in-memory expiry records, cleared on either endpoint
leaving. Duplicate sends produce no new notification. Sending/accepting requires
both endpoints online, matching selected factions, current inviter authority,
an ungrouped recipient with invites enabled, and capacity below ten. Acceptance
has no deferred/yielding work between validation and commit. The one-second
sender limiter survives a quick reconnect and is pruned after its interval;
there is no additional rate tier. One throttled one-second sweep expires invites
and notifies observers. Persistent groups and offline players are not swept.

The engine API contract used is `reference_projects/luanti/doc/lua_api.md`
(get_us_time at line 4635; join/leave callbacks at 6632/6635). The fixture models
leave callbacks while the departing ObjectRef can still resolve: connection
membership is cleared before observers read party views, preventing fake online
rows during that callback.

## Evidence and remaining gates

`tools/r14_parties/evidence/` contains canonical development output (90 checks),
parser/SETGLOBAL/all-five-sweep output and SHA256SUMS. Core declares exactly one
global (`grug_parties`); fixture declares none. Changed tools are included in
all static gates. No PUC runtime was run at this intermediate stage. Root owns
final integrated byte freeze, one compact PUC/LuaJIT parity pair and independent
review. GUI and real server lifecycle remain user-run checks after UI lands.

Runtime plan: two same-faction players invite/accept through Group; inspect HP
and offline status; disable invites; verify duplicate send and expiry; leave a
two-member group; restart while leader is offline and verify membership and
leadership persist. With a third player, reproduce A invites B/C, B joins/leaves,
C accepts, plus leadership transfer and oldest-member succession.
