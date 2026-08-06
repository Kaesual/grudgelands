# TODO — Guilds as ownership layer (housing, mining rights, guild bank)

Raised 2026-08-06. Proposal (user): territory ownership runs through
**guilds** — a guild manager NPC per faction capital; even a solo player
founds a guild; the guild then holds property (guild bank + housing +
mining rights). Multiple players can pool housing and mining.

**NOTE — this flips a documented decision**: ROADMAP lists "No guild
system" under "Deliberately NOT planned", and `world.md` §5 says "one
plot per player", owner-only build rights (§2 R5). If adopted, both must
be rewritten (ownership: player → guild). The original rationale ("Luanti
is not MMORPG enough") stays respected by keeping guilds strictly an
**ownership + roles + bank** layer: no guild levels, perks, wars or
progression.

## 1. Decided direction (user proposal)

- Guild manager NPC per faction capital; founding open to solo players.
- Guild property: **guild bank**, **housing plot(s)**, **mining rights**.
- Fixed role set, not custom: **Owner** (admin, only role that assigns
  roles), **Admiral** (moderator), **Member**. (Names are placeholders —
  English flavor naming later.)

## 2. Proposals on top (to decide)

- **Founding fee** in gold (early gold sink; also anti-spam).
- **Housing**: the frontier model of `world.md` §5 transfers 1:1, owner
  becomes the guild — one plot per **guild**, paid expansion stays the
  gold sink, all members build/dig on the plot. Open: do larger guilds
  get bigger base plots, or is expansion purely paid? (Recommendation:
  purely paid — keeps it simple and the sink honest.)
- **Mining rights**: guilds can **claim/rent ore-rich mining zones**
  (the outpost mining zones of `world.md` §4) — recurring gold upkeep
  (another sink); non-members cannot dig there (plugs into the central
  `is_protected` override). Open: claim mechanics (first-come + upkeep
  vs. auction), number of claims per guild.
- **Guild bank**: chest-like shared inventory at the guild manager
  (capital only). Permissions: Member = deposit only, Admiral =
  withdraw, Owner = manage. (Keeps roles meaningful with zero config.)
- **Guild chat** (`/g …`): cheap, high value — include in the MVP of the
  guild WP.
- Membership: one guild per player; leaving forfeits access, property
  stays with the guild. Owner leaving requires transfer (or guild
  dissolution → property released?). Open: dissolution rules.

## 3. Open questions

- Adopt the flip at all? (Recommendation: yes, scoped as above.)
- Claim mechanics + upkeep numbers (needs the gold curve, economy.md).
- Dissolution/inactivity: does an abandoned guild's plot/claim ever
  expire? (Recommendation: upkeep lapse frees mining claims; housing
  stays — it's paid for.)
- Storage tech: guild data is cross-player → `core.get_mod_storage()`
  (mod storage), not player meta. Roles in the guild record.

**Decision:** _pending_

## WP mapping (once decided)

New WP16 "Guilds" (registry, manager NPC, roles, bank, /g chat) —
depends on WP7 (gold). Housing WP and mining claims build on it;
`is_protected` in wob_core gets the guild-plot/claim hooks.
