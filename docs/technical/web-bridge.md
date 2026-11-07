# Web bridge protocol, version 1

The wire contract between the hosting platform's bridge and the game's mod
`grug_bridge` (0.69.1): the platform's website administers a running realm
through it, with the online list, kick, name bans, public chat, admin mail and
fixed admin actions. The platform's repository keeps the design and the reasons;
this file holds what both sides must agree on, as the game implements it. A
change goes through the user, because the website side builds on it. The
[amendments](#amendments-2026-11-07) name what this copy adds to the first
version. How the mod is built: [module guide](module-guide.md#web-bridge).

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
- All times are Unix seconds. All text is UTF-8.
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
- `resync`: the mod sends the named state again. The only value is `"mail"`.
- `banlist` is present only when the mod's version differs, and is the complete list.

## Events

Each event has `seq`, `time` and `type`. `seq` starts at 1 per boot and increases by
one. The mod resends unacknowledged events in order, at most 100 per request and
fewer when the request would pass 256 KiB (a ticket with a reported letter runs to
tens of KiB). The bridge ignores a `(boot, seq)` it has already stored. The queue
holds 1000 events; beyond that the oldest are dropped and counted.

| Type | Fields | Sent when |
| --- | --- | --- |
| `chat` | `name`, `text` | public chat line, at most 500 characters |
| `mail.ticket` | `ticket` | a ticket was added or changed |
| `mail.ticket_removed` | `id` | a ticket was deleted or expired |
| `mail.broadcast` | `broadcast` | an announcement was added |
| `mail.broadcast_removed` | `id` | an announcement was deleted or expired |
| `mail.snapshot_end` | `ticket_ids`, `broadcast_ids` | a `resync` finished |

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

- Chat and kick text from the website is untrusted: the mod removes colour escapes
  and control characters, and a line break becomes a space. An empty `text` is
  `invalid_args`; an empty `reason` is no reason.
- `mail.*`: an empty or over-long `subject` (60 characters) or `body` (4000) is
  `invalid_args`, never cut. `grug_mail.send_system` would cut, so the mod checks
  first, as the Admin Mail tab does. A closed ticket is `refused`, a gone one
  `unknown_target`.
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

The contract check before the mod was built, accepted by the user. What this copy
adds to the platform's first version:

- `faction` is `accord` or `throng`; the first example named a heraldry.
- When a result is forgotten, and that the bridge takes results by `id`.
- The bridge answers every new `boot` and a rising `dropped_events` with a `resync`.
- Events per request are bound by bytes too.
- An expired ticket or announcement is reported as removed, at a read.
- The refusals: a character in creation, the items no grant hands out, an empty
  subject or body, a privilege the server's admin keeps.
- A ban disconnects through `core.disconnect_player`, and a kick reads `Kicked: `.
