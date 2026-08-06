# Guilds — Ownership Layer

Decided spec (2026-08-06). Guilds are strictly an **ownership layer**:
bank, housing, mining claims, fixed roles. Deliberately NO guild levels,
perks, wars or progression — this keeps the original "no guild system"
rationale (Luanti is not MMORPG enough for that) intact.

## 1. Founding & membership

- **Guild manager NPC** in each faction capital; founding is open to
  solo players and costs a **founding fee** in gold (sink + spam guard).
- One guild per player. Leaving forfeits all access; property stays with
  the guild.
- Guilds are faction-bound (members share the founder's faction).

## 2. Roles (fixed set, no custom roles)

| Role | Rights |
|------|--------|
| Owner | everything; only role that assigns roles; must transfer ownership before leaving |
| Admiral | moderator: invite/kick members, withdraw from the bank |
| Member | build/dig on guild property, deposit into the bank |

- Role names are placeholders (flavor naming later).
- **No decay/expiry**: bought property stays bought. Worst case an
  orphaned guild's members clear the minable area and found a new guild,
  or a server admin intervenes (admin command can reassign the owner).

## 3. Property

- **Guild bank**: shared inventory at the guild manager (capital only).
  Deposit: all members; withdraw: Admiral+.
- **Housing area**: one ocean housing area per guild (mechanics:
  `world.md` §5, layout: `TODO-design-housing.md`); all members
  build/dig there.
- **Mining claims**: ore-rich zones (the outpost mining zones of
  `world.md` §4) bought as a **one-time purchase** — the price buys the
  **finite** resources inside: **no ore respawn within claims** (unlike
  the rest of the world, R4). Non-members cannot dig there (enforced via
  the central `is_protected` override in wob_core).
- Purchases (expansions, claims) are made by the Owner from guild funds.

## 4. Communication

- Guild chat `/g <message>` ships with the guild MVP.

## 5. Implementation notes

- Guild records (name, faction, roles, property, bank) in
  `core.get_mod_storage()` — cross-player data, not player meta.
- Plot/claim sizing and pricing are economy parameters
  (items_crafting.md §7): sized so a guild can grow for a
  long time, steps small enough that the maximum is practically never
  reached.
