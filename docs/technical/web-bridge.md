# Web bridge protocol, version 1

The wire contract between the hosting platform's bridge and the game's mod
`grug_bridge` (0.69.1): the platform's website administers a running realm
through it, with the online list, kick, name bans, public chat, admin mail and
fixed admin actions. The platform's repository keeps the design and the reasons;
this file holds what both sides must agree on, as the game implements it. A
change goes through the user, because the website side builds on it. The
[amendments](#amendments-2026-11-07) name what this copy adds to the first
version. Website accounts (0.79.0) are a separate contract that extends this one:
[web-accounts.md](web-accounts.md); the rows below that it adds are marked
**(accounts)**. How the mod is built: [module guide](module-guide.md#web-bridge).

## Settings

The hosting platform writes these into the server's configuration, never into
the game's `minetest.conf`, which cannot carry a `secure.*` key. The mod reads
them and never writes them.

| Key | Value |
| --- | --- |
| `secure.http_mods` | contains `grug_bridge` |
| `grug_bridge.url` | base URL of the bridge, plain HTTP on an internal network |
| `grug_bridge.token` | 64 lowercase hex characters, unique per world |

The mod is inert unless `core.request_http_api()` returned a table and both
`grug_bridge.*` keys are set: no requests, no hooks. It logs one line naming what
is missing. `request_http_api` only works in the mod's main scope, and the
returned table stays in a local variable.

## The exchange

The mod always initiates. Exactly one request is in flight at any time.

```text
POST {url}/v1/sync
Authorization: Bearer {token}
Content-Type: application/json
```

- The mod sends the next request `next_ms` after the previous one finished. The
  default before the first answer is 2000. `next_ms` lies between 1000 and 30000;
  the mod holds other values to those bounds.
- The request timeout is 5 seconds. After a failed request the mod waits 5, 10, 20,
  40 and then 60 seconds. Results and events stay queued meanwhile.
- `401` means the token is wrong. The mod logs it once and retries every 60 seconds.
- `409` means the bridge does not speak this `protocol`. Same handling as `401`.
- Any other answer than `200` with a readable body of this `protocol` counts as a
  failed request.
- A request body is at most 256 KiB. A response is at most 1 MiB.
- All times are Unix seconds. All text is UTF-8: invalid UTF-8 in an event arrives as
  U+FFFD (a modified client can still put an overlong form or a surrogate
  into a ticket, and a ticket stored before 0.81.0 may hold stray bytes; the
  cleaner drops only a lead byte with the wrong number of continuation bytes).
- Both sides accept `null` wherever an empty array is expected, because
  `core.write_json` writes an empty Lua table as `null`.

### Request

```json
{
  "protocol": 1,
  "boot": "5f0c1e7a9b3d4c21",
  "game_version": "0.69.1",
  "capabilities": ["online", "kick", "banlist", "chat", "mail",
                   "action.give_money", "action.give_xp", "action.give_item",
                   "action.grant_priv", "action.revoke_priv"],
  "banlist_version": 12,
  "dropped_events": 0,
  "results": [
    {"id": "65f0a1b2c3d4e5f6a7b8c9d0", "status": "done", "code": "ok", "message": ""}
  ],
  "events": [
    {"seq": 41, "time": 1794096000, "type": "chat", "name": "Rowan", "text": "hello"}
  ],
  "online": [
    {"name": "Rowan", "level": 12, "class": "priest", "race": "human",
     "faction": "accord", "joined_at": 1794095000, "address": "203.0.113.7"}
  ]
}
```

- `boot` is random and made once at mod load. A new value tells the bridge the
  server restarted. The bridge answers a new `boot` with `resync: ["mail"]`: the mod
  sends only what changes while it runs.
- `banlist_version` is the version the mod holds, `0` if it never received one.
- `dropped_events` counts events lost since this boot began. The bridge asks for a
  `resync` when it rises.
- `results` are forgotten once a `200` answers the request that carried them. A
  lost response therefore repeats them, and the bridge takes a result once by its
  `id`.
- `online` is the complete list. It is sent in the first request of a boot, after a
  join, a leave, a level change or a character's arrival, and at least every 30
  seconds. An absent key means unchanged.
- `class` is `warrior`, `mage`, `priest` or `scout`, `race` is `human`, `dwarf`,
  `elf`, `orc`, `troll` or `undead`, `faction` is `accord` or `throng`. All three
  are absent for a character still being created.
- `address` is what `core.get_player_information` reports. The bridge discards it
  for browser players, whose address is the proxy's.
- **(accounts)** `capabilities` adds `accounts` and `accounts.password`.
  `accounts_version` is the account list version the mod holds, `0` before the
  first, in every request. `reward_catalog` lists the rewards the game can give
  (`id`, `kind`, `name`): in the first request of a boot and in every request until
  a `200` answered one that carried it. Online rows add `character_id` and, only
  while the character has a binding that counts, `account_id`; a list that changes
  an online character's binding sends the online list again
  ([web-accounts.md](web-accounts.md) §5.1).

### Response

```json
{
  "protocol": 1,
  "next_ms": 2000,
  "ack_seq": 41,
  "resync": ["mail"],
  "commands": [
    {"id": "65f0a1b2c3d4e5f6a7b8c9d1", "type": "kick",
     "args": {"name": "Rowan", "reason": "Please read the rules."},
     "expires_at": 1794096120}
  ],
  "banlist": {
    "version": 13,
    "entries": [{"name": "Griefer", "expires_at": 1794700000},
                {"name": "Griefer2", "expires_at": null}]
  }
}
```

- `ack_seq`: the mod forgets every event up to and including it.
- `resync`: the mod sends the named state again: `"mail"`, and **(accounts)**
  `"reward_catalog"`, which sends the catalogue again.
- `banlist` is present only when the mod's version differs, and is the complete list.
- **(accounts)** `accounts` is the complete account list, present when its
  `version` differs from the request's `accounts_version`; the mod applies it
  after `banlist` and before the `commands` ([web-accounts.md](web-accounts.md)
  §5.2).

## Events

Each event has `seq`, `time` and `type`. `seq` starts at 1 per boot and increases by
one. The mod resends unacknowledged events in order, at most 100 per request and
fewer when the request would pass 256 KiB (a ticket with a reported letter runs to
tens of KiB). The bridge ignores a `(boot, seq)` it has already stored. The queue
holds 1000 events; beyond that the oldest are dropped and counted, and so is an
event over 128 KiB, which no game text reaches.

| Type | Fields | Sent when |
| --- | --- | --- |
| `chat` | `name`, `text` | public chat line, at most 500 characters |
| `mail.ticket` | `ticket` | a ticket was added or changed |
| `mail.ticket_removed` | `id` | a ticket was deleted or expired |
| `mail.broadcast` | `broadcast` | an announcement was added |
| `mail.broadcast_removed` | `id` | an announcement was deleted or expired |
| `mail.snapshot_end` | `ticket_ids`, `broadcast_ids` | a `resync` finished |
| `account.link_request` **(accounts)** | `request_id`, `name`, `character_id`, `code` | a player entered a well-formed link code ([web-accounts.md](web-accounts.md) §5.3) |
| `account.link_confirm` **(accounts)** | `request_id`, `name`, `character_id` | the player confirmed an offer |
| `account.link_cancel` **(accounts)** | `request_id`, `name` | the player cancelled or left, or the game gave up |

- **Chat** is what other players can read: never a command, so neither `/msg` nor
  `/me`. The hook `core.register_on_chat_message` runs before the engine checks
  `shout`, so the mod checks `shout` itself and ships nothing for a player without
  it. It never returns true, so the game's chat is unchanged. The text arrives
  without colour escapes.
- **`ticket`** is the stored ticket record as `grug_mail.ticket(id)` returns it.
- **`broadcast`** is the stored record from `grug_mail.broadcasts()`.
- **Expiry** happens when a list is read, so an expired entry is reported at that
  read, at the latest at the next `resync`.
- **A `resync`** sends every ticket and broadcast as ordinary events, then
  `mail.snapshot_end`. The bridge removes mirrored rows not listed there.

## Commands

The bridge offers a command only if the capability is reported. It marks a command
`delivered` and binds it to the current `boot`.

**At most once.** The mod keeps a table of command ids it has started, in memory,
for its whole boot, and writes the id there before acting.

- If a command arrives again in the same boot, the mod does not act. It repeats the
  stored result, or reports nothing if the command is still running. This covers a
  lost response.
- The bridge never delivers a command to another boot. A delivered command without a
  result when `boot` changes becomes `unknown`.

The ledger therefore needs no persistence, and it must not rely on any. The engine
writes ModStorage only every `server_map_save_interval`, so a crash can lose a
ledger entry while the effect of the command survives.

A command past `expires_at` is not run; the result is `failed` with code `expired`.

### Result

`{id, status, code, message}`. `status` is `done` or `failed`. `message` is at most
200 characters and is shown to the administrator.

| Code | Meaning |
| --- | --- |
| `ok` | done |
| `not_online` | the target must be online and is not |
| `unknown_target` | no such character, ticket, announcement, item or privilege |
| `invalid_args` | an argument is missing or out of bounds |
| `refused` | the game refused; `message` carries its text |
| `unsupported` | unknown command type |
| `expired` | past `expires_at` |
| `error` | the action raised an error; the server log has the detail |

An exception inside a command is caught, so a bad command cannot take the server
down.

### Types

`admin` is always the acting website account's name, at most 64 characters.

| Type | Capability | Args | Game call |
| --- | --- | --- | --- |
| `kick` | `kick` | `name`, optional `reason` up to 200 characters | `core.kick_player`; the player reads `Kicked: <reason>`, or `Kicked.` |
| `chat.send` | `chat` | `admin`, `text` up to 500 characters | `core.chat_send_all("[Admin]<" .. admin .. "> " .. text)` |
| `mail.answer` | `mail` | `ticket_id`, `admin`, `body` | `grug_mail.answer_ticket` |
| `mail.close` | `mail` | `ticket_id`, `admin` | `grug_mail.close_ticket(id, admin, false)` |
| `mail.delete` | `mail` | `ticket_id`, `admin` | `grug_mail.delete_ticket` |
| `mail.send` | `mail` | `to`, `subject`, `body`, `admin` | `grug_mail.send_system(to, "admin", ...)` |
| `mail.broadcast` | `mail` | `subject`, `body`, `admin` | `grug_mail.send_broadcast` |
| `mail.broadcast_delete` | `mail` | `broadcast_id`, `admin` | `grug_mail.delete_broadcast` |
| `action.give_money` | same | `name`, `copper` 1 to 1000000 | `grug_money.add` |
| `action.give_xp` | same | `name`, `amount` 1 to 1000000 | `grug_xp.add_xp`, no source |
| `action.give_item` | same | `name`, `item`, `count` 1 to the item's stack size | `grug_inventory.give` |
| `action.grant_priv` | same | `name`, `priv` | `core.set_player_privs` |
| `action.revoke_priv` | same | `name`, `priv` | `core.set_player_privs` |
| `account.link_answer` **(accounts)** | `accounts` | `request_id`, `name`, `outcome`, `account_name` or `reason` | `grug_accounts.link_answer` ([web-accounts.md](web-accounts.md) §5.4) |
| `account.set_password` **(accounts)** | `accounts.password` | `name`, `account_id`, `entry` | `core.set_player_password` after the auth entry, the binding and the entry's form are checked ([web-accounts.md](web-accounts.md) §6b) |
| `character.delete` (0.83.0) | `characters.delete` | `name`, optional `character_id`, `admin` | erases the character, online or offline, and answers once it is done ([amendment](#amendment-2026-11-18-characterdelete)) |

- Chat and kick text from the website is untrusted: the mod removes colour escapes
  and control characters, and a line break becomes a space. An empty `text` is
  `invalid_args`; an empty `reason` is no reason.
- `mail.*`: an empty or over-long `subject` (60 characters), `body` (4000) or `to`
  (40) is `invalid_args`, never cut. `grug_mail.send_system` would cut, so the mod
  checks first, as the Admin Mail tab does. `mail.answer` and `mail.close` on a
  closed ticket are `refused`; a ticket that is gone is `unknown_target`.
- `action.*` targets must be online. A grant of money, XP or an item to a character
  still being created is `refused`: creation stores nothing. Offline grants do not
  exist (the user, 2026-11-07).
- `action.give_money` and `action.give_item` show the player a notice in the message
  feed; XP shows there by itself. `message` reports the real outcome: the balance,
  or the XP actually granted, which stops at the top level.
- `action.give_item` takes a bare registered item name, never an item string or an
  alias, and never `air`, `ignore` or `unknown` (`unknown_target`). Skill and mount
  items, which are hotbar bindings, and the empty Bag of Coins are `refused`. It
  checks `grug_inventory.fits` first and fails as `refused`, so an item is never
  half delivered.
- `action.grant_priv` and `action.revoke_priv` accept every registered privilege,
  `server` and `privs` included: the website lets only its owner hand those out
  (the user, 2026-11-07). They run the privilege's grant and revoke callbacks.
  Granting a held or revoking an absent privilege is `ok`; revoking what the
  server's admin always holds is `refused`.

## Bans

The mod stores the last `banlist` in its ModStorage, so a ban holds while the bridge
is down and across a restart.

- `core.register_on_prejoinplayer` refuses a listed name whose `expires_at` is null
  or in the future. Names compare case-insensitively.
- The text is `You are banned from this server.`, with
  ` Ban ends: <YYYY-MM-DD HH:MM> UTC.` added for an expiring ban. A ban's reason
  never reaches the game.
- When a new list arrives, a listed character who is online is disconnected with
  the same text, through `core.disconnect_player`, because `core.kick_player` would
  put `Kicked: ` before it.

The engine's own `/ban` is never used. Every browser player reaches the game from
the proxy's address, so an IP ban would lock out all of them.

## Amendments 2026-11-07

The contract check before the mod was built and its review, accepted by the user.
What this copy adds to or changes in the platform's first version:

- **Values:** `faction` is `accord` or `throng`, where the first example named a
  heraldry; the sets of `class` and `race`.
- **The exchange:** `next_ms` outside its bounds is held to them; what counts as a
  failed request; invalid UTF-8 arrives as U+FFFD; a mod without its settings
  registers no hook at all, stricter than the first version's "no hooks that change
  behaviour".
- **Results and events:** when a result is forgotten and that the bridge takes
  results by `id`; events per request are bound by bytes too; an event over 128 KiB
  is lost and counted; an expired ticket or announcement is reported as removed, at
  a read.
- **The bridge's part:** it answers every new `boot` and a rising `dropped_events`
  with a `resync`.
- **`online`:** "every change" is a join, a leave, a level change or an arrival.
- **Chat:** the event's text arrives without colour escapes, and `/me` counts as a
  command.
- **Commands:** `admin` at most 64 characters, `to` at most 40; website text is
  cleaned of escapes and control characters; the refusals of a character in
  creation, of an alias, an item string and the items no grant hands out, of an
  empty text, subject or body, of a closed ticket and of a privilege the server's
  admin keeps; a held or absent privilege is `ok`; money and item grants show in the
  feed; a privilege's callbacks run; `kick` reads `Kicked: `.
- **Bans:** a ban disconnects through `core.disconnect_player`; the date's format.

## Amendment 2026-11-15: website accounts

Game 0.79.0 (Round 79). The contract is [web-accounts.md](web-accounts.md), agreed with
the user on 2026-11-15; it extends this protocol without changing anything above.
This file lists what it adds, marked **(accounts)**: the capabilities `accounts` and
`accounts.password`, the request's `accounts_version` and `reward_catalog`, the
online rows' `character_id` and `account_id`, the response's `accounts`, the
`resync` value `"reward_catalog"`, the three `account.link_*` events and the
commands `account.link_answer` and `account.set_password`. Protocol stays `1`.

## Amendment 2026-11-18: character.delete

Game 0.83.0 (Round 83). The website erases a character on a player's request
(GDPR Art. 17), online or offline. Protocol stays `1`; everything above holds.

- **Capability** `characters.delete`, at the end of `capabilities`.
- **Type** `character.delete`, args:

  | Arg | Value |
  | --- | --- |
  | `name` | the character's name in the game's spelling (`[A-Za-z0-9_-]`, 1 to 20 characters); another letter case is no such character |
  | `character_id` | optional, 32 lower-case hex digits: the command acts only on a character with exactly this id (an online character's own, else the game's index entry) |
  | `admin` | the acting website account's name, at most 64 characters, for the log line |

  The command must carry `expires_at` (`invalid_args` without it): the website
  sends at most 60 seconds.
- **The answer comes later.** The game checks the command at once and then
  answers when the deletion is done: about 6 seconds offline (one mod-storage
  commit), a second or two more online, plus the next request. Until then a
  repeated delivery gets nothing, as for any running command; afterwards the
  stored result. The result is sent exactly once per boot. A deletion running
  when the server stops is lost unanswered (the website marks it `unknown` at
  the next boot); a retry finishes it or answers `unknown_target`.
- **Codes:**

  | Code | When | `message` |
  | --- | --- | --- |
  | `ok` | deleted; the name's index entry is the tombstone | `<name> (character <id>) deleted by admin <admin>.`, or `<name> (no character id) deleted by admin <admin>.` for a character that never joined since 0.79.0 |
  | `unknown_target` | no such character (no login and no character id in the index; another letter case), or `character_id` does not match. Not after a deletion that stopped after its clears (the tombstone beside the login): the retry finishes it with the `character_id` it carries, which the `ok` line then names | `There is no character called <name>.` / `<name> has another character id.` |
  | `refused` | the server administrator's character (the name in the server setting `name`, any letter case: the engine gives that name every privilege, so a new character of the name would inherit them) | `<name> is the server administrator's character.` |
  | `refused` | a deletion of the name is already running | `<name> is already being deleted.` |
  | `expired` | at arrival: at most `max(10, server_map_save_interval + 4.5)` seconds (10 by default) before `expires_at` | `The command expires too soon for a deletion.` |
  | `expired` | an online character was disconnected but was not gone from the engine before that margin: nothing deleted | `<name> was not deleted: the command expired first.` |
  | `expired` | the clears ran but the removal could not finish before `expires_at` (the character came back between the steps and was not gone again in time, or the server lagged): the login remains, refused at login until a retry finishes it | `<name> was not deleted completely: the command expired first. Send it again.` |
  | `invalid_args` | `name`, `character_id`, `admin` or `expires_at` malformed or missing | `Invalid <field>.` |
  | `error` | a step failed; the server log has the detail. The name stays refused at login while a tombstone stands beside its login; a retry finishes it | `The deletion failed; see the server log.` |

  A character still in character creation counts like any other. Nothing
  destructive runs after `expires_at`.
- **Online:** the game disconnects the character with
  `This character was deleted on the website.` (through `core.disconnect_player`,
  so without `Kicked: `), waits until the engine has saved and dropped the player,
  and only then deletes. While a deletion runs, the name is refused at login (any
  letter case) with the same text.
- **The log line:** exactly one `action` line per deletion, the bridge's
  command line at the answer:
  `[grug_bridge] command <id> (character.delete): ok <name> (character <character id>) deleted by admin <admin>.`
  Nothing else in the deletion logs the name with more detail (the engine logs
  its own leave line for an online character).
- **What goes:** the engine's auth entry (name, password verifier, privileges,
  last login) and player record (meta and inventories); the index entry becomes
  the tombstone, always, and the game's copy of the account list drops the
  character's row at once (the version stays); the character's mailbox (its
  attachments with it), sent copies, messages to the admin and its row in the
  recipient index; its clan and party membership (a leader's lead passes on by the
  group's rule, a group of two dissolves; the other members read `<name> is no
  longer a member.`); every housing claim it owns is released and its Claim Stone
  removed at once (containers and blocks inside stay), its rights in other claims,
  its map-reset belongings; a pending "claim lost" notice; queued achievement
  grants; an Expedition it owns alone ends.
- **What stays:** letters it wrote in other mailboxes, other players' sent copies
  addressed to it and their reports of its letters (the bare name as text; all
  expire after 30 days, and every list is pruned at each server start); admin
  fields naming it if it was an admin (closed tickets, announcements); other
  characters' party favourites; the website's ban list and an engine IP ban; a
  copy of unreadable clan storage kept for an administrator (`clans_unreadable`,
  only after the clan store was corrupt; the user, 2026-11-18); in
  the world, the owner name of locked chests, steel doors and trapdoors and the
  personal furnace slots of public furnaces (a new character of the same name gets
  access to them), crop marks, written books and sign texts; the server log.
  Deleted rows may survive in database free pages until a vacuum.
- **A new character of the name** gets a new character id and adopts nothing:
  no binding counts for it ([web-accounts.md](web-accounts.md) §2).
