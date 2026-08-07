# Guilds — Ownership Layer

Decided spec (2026-08-06; housing moved out and the bank respecced
2026-08-07). Guilds are strictly an **ownership and access layer**:
bank, continental mining claims, mutual isle access, fixed roles.
Deliberately NO guild levels, perks, wars or progression — this keeps the
original "no guild system" rationale (Luanti is not MMORPG enough for
that) intact.

**What changed 2026-08-07**: housing is granted per character by the
King (`world.md` §5), not bought by guilds. The guild keeps the bank
(now reachable from members' isles), the continental mining claims, chat
and roles — and loses the "found a solo guild so you may own a house"
crutch, which was never a reason to have a guild.

## 1. Founding & membership

- **Guild manager NPC** in each faction capital; founding is open to
  solo players and costs a **founding fee** in gold (sink + spam guard).
  Since housing left the guild (2026-08-07) a solo guild buys chat,
  a bank and claims — still worth it, no longer mandatory.
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
- **No decay/expiry**: bought property stays bought. Worst case an
  orphaned guild's members clear the minable area and found a new guild,
  or a server admin intervenes (admin command can reassign the owner).

## 3. Property

### 3.1 The guild bank — one account, many terminals

Respecced 2026-08-07. The bank is an **account bound to the guild**, not
a chest standing somewhere: it exists exactly once, and everything that
looks like a chest is a terminal onto it. One member takes something out
and it is gone for everyone, instantly.

- **Contents: 6 tabs × 32 slots** — tabs 1–3 open to every member,
  tabs 4–6 to Admiral+ only. Plus **two purses**: the *member purse*
  (all members deposit and withdraw) and the *officers' purse*
  (Admiral+ and Owner). **Guild purchases come from the officers'
  purse**, so a member cannot drain the treasury by proxy.
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

### 3.2 Continental mining claims

- Ore-rich zones (the outpost mining zones of `world.md` §4) bought as a
  **one-time purchase** — the price buys the **finite** resources
  inside: **no ore respawn within claims** (unlike the rest of the
  world, R4). Non-members cannot dig there (enforced via the central
  `is_protected` override in grug_core).
- These stay **guild** property deliberately, even though housing depth
  is now personal (world.md §5.3): the claim is the *contested,
  dangerous* mining variant out in the open world, and it is what still
  makes a guild worth more than a chat channel.
- Purchases are made by the Owner from the officers' purse.

### 3.3 Housing is no longer guild property

Housing isles belong to characters (`world.md` §5). The guild's role
there is **access**: guild membership grants visitor rights on every
member's isle automatically, and carries the bank terminal.

## 4. Communication

- Guild chat `/g <message>` ships with the guild MVP.

## 5. Implementation notes

- Guild records (name, faction, roles, claims, purses, bank log) in
  `core.get_mod_storage()` — cross-player data, not player meta.
- **The bank is one `core.create_detached_inventory` per guild**, created
  lazily on first access and serialized into mod storage on change; the
  role checks live in its `allow_put`/`allow_take`/`allow_move`
  callbacks. The terminal node holds **no inventory of its own** — it
  only opens a formspec onto the detached inventory. Pleasant
  side-effect: the classic "dig the chest while someone has it open"
  duplication bug cannot occur, because there is nothing in the node to
  duplicate.
- Claim sizing and pricing are economy parameters (items_crafting.md
  §8.4).
