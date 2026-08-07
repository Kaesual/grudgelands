# Guilds — Social & Ownership Layer

Decided spec (2026-08-06; housing moved out and the bank respecced
2026-08-07, continental mining claims removed 2026-08-07). A guild is
strictly a **social and access layer**: guild bank, guild chat, fixed
roles, mutual isle access. Deliberately NO guild levels, perks, wars or
progression — this keeps the original "no guild system" rationale
(Luanti is not MMORPG enough for that) intact.

**What changed 2026-08-07**: housing is granted per character by the
King (`world.md` §5), not bought by guilds — the guild loses the "found
a solo guild so you may own a house" crutch, which was never a reason to
have a guild.

**Revised 2026-08-07**: **continental mining claims are removed.**
Mining rights exist only on housing isles, where they are personal,
level-granted and tier-gated (`world.md` §5.3) — a guild owns no ground
anywhere in the world. Territory is a faction property, not a guild one.
That leaves exactly four things a guild is for, and they are worth
naming plainly because they are the whole list:

1. **one shared bank account** (§3.1) — the only shared storage in the
   game,
2. **a private chat channel** (§4),
3. **three fixed roles** with an audited bank (§2, §3.1),
4. **automatic visitor rights on every member's isle** (§3.2).

## 1. Founding & membership

- **Guild manager NPC** in each faction capital; founding is open to
  solo players and costs a **founding fee of 5g** (sink + spam guard —
  `items_crafting.md` §8.4). The fee stays at 5g after the claims
  removal.
- **What 5g buys** (revised 2026-08-07): the four items listed at the
  top of this file — bank, chat, roles, mutual isle access. Nothing
  else. That is a group price by design: five members pool it at 1g
  each, roughly 8–17 hours of endgame income at the 6–12s/hour rate of
  `items_crafting.md` §8 — a shared project, not an impulse buy. It is
  the second of only two big sinks left (`economy.md` §4). A solo guild
  is still legal, but at the full price it buys a private six-tab
  warehouse and an empty chat channel, and is meant to think twice — the
  guild is no longer a prerequisite for anything.
- One guild per player. Leaving forfeits all access; property stays with
  the guild.
- Guilds are faction-bound (members share the founder's faction).

## 2. Roles (fixed set, no custom roles)

| Role | Rights |
|------|--------|
| Owner | everything; only role that assigns roles; spends guild funds; must transfer ownership before leaving |
| Admiral | moderator: invite/kick members, full bank access (all tabs + both purses) |
| Member | bank tabs 1–3 and the member purse (deposit **and** withdraw), visitor access to members' isles |

Revised 2026-08-07: Members may now withdraw from the member half of the
bank. Rationale — a bank nobody but officers can draw from is a
warehouse, not a bank; the guard against abuse is the transaction log
(§3), not a locked door.

- Role names are placeholders (flavor naming later).
- **No decay/expiry**: a guild and its bank persist as they are. Worst
  case the members of an orphaned guild empty the member tabs, leave and
  found a new guild, or a server admin intervenes (admin command can
  reassign the owner).

## 3. Property

A guild owns **exactly one thing: its bank account.** No land, no nodes,
no claims (revised 2026-08-07). Everything else in this section is
access rights on property that belongs to individual characters.

### 3.1 The guild bank — one account, many terminals

Respecced 2026-08-07. The bank is an **account bound to the guild**, not
a chest standing somewhere: it exists exactly once, and everything that
looks like a chest is a terminal onto it. One member takes something out
and it is gone for everyone, instantly.

- **Contents: 6 tabs × 32 slots** — tabs 1–3 open to every member,
  tabs 4–6 to Admiral+ only. Plus **two purses**: the *member purse*
  (all members deposit and withdraw) and the *officers' purse*
  (Admiral+ and Owner), so a member cannot drain the treasury by proxy.
  Revised 2026-08-07: with the claims gone the guild has nothing of its
  own left to buy (§3), so the officers' purse is a **savings and
  payout** account — pooled gold parked out of reach of a single
  member — not a purchase account.
- The Owner gets no private tab — being the only Owner is the privilege.
- **Access points**: the **guild manager NPC** in the faction capital is
  the always-available public door; on top of that every member may
  place **one guild-bank terminal on their own housing isle**
  (`world.md` §5), and any guild member on that isle may use it,
  regardless of the isle's trust list. **Terminals only on housing
  isles** — a bank in the middle of a field would hollow out the capital
  as a meeting place, the same argument that keeps workbenches in towns.
- **Transaction log**: a ring buffer of the last ~50 operations (who,
  what, when) in its own tab. With member-withdrawable tabs this is not
  optional — on any server past a handful of players the alternative to
  a log is an argument.
- Membership and role are checked **when the terminal is opened**, never
  when it is placed: leaving the guild silently deactivates the node and
  no cleanup pass is needed.

### 3.2 Housing is not guild property

Housing isles belong to characters (`world.md` §5). The guild's role
there is **access**: guild membership grants visitor rights on every
member's isle automatically, and carries the bank terminal.

Mining is part of that personal property, never a guild right: what a
character may dig on their own isle is set by the depth steps they
bought and the tool tier they can wield (`world.md` §5.3). A guild
cannot buy, hold or gate a digging area anywhere.

## 4. Communication

- Guild chat `/g <message>` ships with the guild MVP.

## 5. Implementation notes

- Guild records (name, faction, roles, purses, bank log) in
  `core.get_mod_storage()` — cross-player data, not player meta.
- **No area/protection code belongs to guilds** (revised 2026-08-07):
  with the claims gone there is no guild entry in the central
  `grug_core.is_protected` path at all. The only guild-owned check is
  "is this player a member, and in which role", evaluated when a bank
  terminal or the manager NPC is opened.
- **The bank is one `core.create_detached_inventory` per guild**, created
  lazily on first access and serialized into mod storage on change; the
  role checks live in its `allow_put`/`allow_take`/`allow_move`
  callbacks. The terminal node holds **no inventory of its own** — it
  only opens a formspec onto the detached inventory. Pleasant
  side-effect: the classic "dig the chest while someone has it open"
  duplication bug cannot occur, because there is nothing in the node to
  duplicate.
- The founding fee is the guild's only price and is an economy
  parameter (`items_crafting.md` §8.4, `economy.md` §4).
