# Website accounts — the contract between the game and the website (phase 1)

**Status: draft, agreed with the user on 2026-11-15**, for game version 0.79.0
([round79-plan.md](../planning/round79-plan.md)). It extends the
[web bridge protocol](web-bridge.md) (protocol 1); everything there still holds. Once
0.79.0 ships, this file is the contract for accounts, and a change goes through the
user, as for the bridge. The model and the later phases:
[accounts-concept.md](../planning/accounts-concept.md).

**Amended 2026-11-16** (game 0.80.0, [round80-plan.md](../planning/round80-plan.md)):
dated notes in §5.4 (the website's narrower answers), §6a item 4 (the confirmed rate
limits) and §8 (what phase 2 is). Nothing else changed.

Written for the agent that builds the website and bridge side. It names what the
website must do, what it sends, what it receives and how the game behaves.

## 1. What phase 1 is

- A player who has an account on the website can **link** characters to it, in one
  of two ways:
  - **By code** (§4, §6): the website creates a link code, the player enters it on
    the in-game Account page and confirms.
  - **By password** (§6a): the website checks the character's password against the
    realm's auth entry and binds the character itself. The password is either one the
    website already stores for the web client, or one the player types once on the
    website. Neither a code nor a bridge round trip is involved.
- An administrator grants **rewards** to an account on the website. Every character
  linked to that account has them. The first reward is the Supporter Cloak.
- Accounts are **optional**. A character without an account plays exactly as before,
  and linking never takes anything away.

- The website can **set a linked character's password** in the game (§6b), for the
  "new random password" of the auto mode.

Not part of phase 1, and never to be assumed by the website: account bans,
characters created through a bridge command, shared Claim Stones. Each comes later
as its own amendment (§10). **Character deletion** came with 0.83.0 (Round 83) as
the bridge command `character.delete` ([web-bridge.md](web-bridge.md#amendment-2026-11-18-characterdelete)):
it writes the tombstone below. Names the
website reserves and the web client then creates at its first login are ordinary
characters for the game.

## 2. Terms

| Term | Meaning |
|---|---|
| realm | one game world with its own bridge token (production, the rehearsal realm, a test realm) |
| account | a website account; only website accounts can own characters |
| account id | the account's stable, opaque id: `[A-Za-z0-9_-]`, 1 to 64 characters, never reused and never changed |
| account name | the account's display name, which may change; at most 64 characters; shown only on that account's own characters' Account pages |
| character | a Luanti player on one realm, identified by its name there |
| character id | 32 lower-case hex digits that the game gives every character at its first join with 0.79.0; never changes. Readable in `player_metadata` under `grug_accounts:character_id` |
| binding | character name + character id → account id |
| reward | an id `<kind>:<name>`, lower-case `[a-z0-9_]` (`cloak:supporter`) |

A binding is valid only for the character id it names. The game ignores a binding
whose character id differs from the character's own. That case appears once
characters can be deleted and their names reused. The game keeps its own index of
name → character id, so the rule also holds for characters that are offline. Per
name the index is in one of three states:

| Index entry | A binding for the name counts … | A character joining without an id … |
|---|---|---|
| none (not joined since 0.79.0; later: created through a bridge command) | yes | adopts the binding's id, if there is a binding |
| id X | only with id X | takes X |
| tombstone (written by `character.delete`, always, also where there was no entry; never a plain clear) | never | gets a new id; nothing is adopted |

When the character's meta and the index disagree at a join, the meta wins and the
index is rewritten, with a line in the server log. **One exception** (Round 83): a
tombstone beside an auth entry that has been used (its last login is not the
engine's `-1` of a login never used) is a deletion that stopped before the engine
removed the login (a crash, an error). The game refuses that name at pre-join with
`This character was deleted on the website.` until the website's retry of
`character.delete` finishes it. A new character of the name never meets the rule:
its login is created at its first connection with last login `-1`, and its join
replaces the tombstone. Adoption is the game's recovery
after a lost save, and later the way characters created through a bridge command get
their id.

## 3. The website's duties

The website is the **only source of truth** for accounts, bindings and rewards. The
game keeps a copy (§5.2) and never changes a binding on its own.

1. **Store** accounts (id, name), bindings (realm, name, character id, account id,
   time of linking) and each account's reward ids.
   - **Scope** (the user, 2026-11-15): bindings, codes and the list are **per
     realm**; account ids and rewards are **global**, so a reward reaches the
     account's characters on every realm. A code is created for one realm and links
     only there. The 10-character limit counts per realm.
2. **One binding per character.** Names are unique per realm without regard to
   case (Luanti refuses a second name that differs only in case); store the name
   exactly as the game sent it.
3. **At most 10 characters per account** (on one realm, see 1).
4. **Link codes** (§4).
5. **The list version** (§5.2): raise it on every change to anything in the list,
   whether link, unlink, reward granted or removed, account renamed or account
   deleted. **Send a first list (version 1, empty if need be) as soon as the website
   supports accounts:** the game shows the Account page only once it holds a list,
   so a game release that is live before the website side shows nothing that cannot
   work yet.
6. **Admin pages:**
   - per account: grant and remove rewards, offered from the reward catalogue the
     game reported (§5.1)
   - per character: unlink
   - only administrators unlink; players cannot
7. **Deleting an account** removes the account and its bindings. The characters stay
   in the game as characters without an account. The website never deletes a
   character in phase 1.
8. **Privacy:**
   - The account name and id are never shown to anyone but the account owner and
     administrators. The one place a website name reaches players is the existing
     `admin` field of `chat.send` and the admin mail, which shows the acting
     administrator; send the administrator's chosen label there, as today.
   - No public page may show which characters share an account. Other players must
     not be able to tell which characters belong together.
9. **Never log a link code or a password in plain text**, nor keep a used or
   expired code longer than needed.

## 4. Link codes

- **Alphabet:** the 32 symbols `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`: upper-case
  letters and digits without `0`, `O`, `I` and `1`.
- **Length:** 10 symbols, drawn with a cryptographically secure random generator.
- **Display:** two groups of five, `ABCDE-FGH23`. The game accepts it in any case,
  with or without the hyphen and spaces, and sends it normalized: 10 upper-case
  symbols, no hyphen.
- **Valid for 10 minutes** from its creation. **Single use.**
- **One code per account at a time:** a new code replaces the account's previous
  one.
- **Reservation:** a code that was answered with an `offer` (§6) is reserved for that
  request until it is confirmed, cancelled, or **5 minutes** have passed since the
  offer was sent. That covers the offer's `expires_at` (at most 60 s, §5.4), the
  game's own 2 minutes after the offer arrives and a delayed confirmation event.
  - A confirmation inside the reservation links, even if the 10 minutes ran out
    meanwhile.
  - A confirmation after the reservation lapsed links if the code is still valid,
    unused and not reserved for another request; otherwise it is refused
    (`expired_code` or `used_code`).
  - A second request with a reserved code is refused as `used_code`.
  - **A new code for the account ends every reservation of the old one**; their
    confirmations are refused as `used_code`.
  - On a new `boot`, release every reservation held for a request of an older boot:
    its events can no longer come.
- **Consumed** when the link is made. **At the confirmation, re-check
  `account_full` and `already_linked` atomically with storing the binding**, so two
  confirmations can never pass the limit.
- **Rate limits** on the website: at most 10 requests per character per hour, and a
  global ceiling. The game limits as well (5 per character per 10 minutes, reset by a
  relog, so the website never relies on it) and refuses anything not well-formed
  before it sends a request.

## 5. Protocol additions

New capability **`accounts`**, reported by game 0.79.0 and later. Offer nothing of
this section to a game that does not report it. Protocol stays `1`: every field is
new and optional for the other side.

### 5.1 Request

```json
{
  "protocol": 1,
  "capabilities": ["online", "kick", "banlist", "chat", "mail", "...", "accounts"],
  "accounts_version": 7,
  "reward_catalog": [
    {"id": "cloak:supporter", "kind": "cloak", "name": "Supporter Cloak"}
  ],
  "online": [
    {"name": "Rowan", "level": 12, "class": "priest", "race": "human",
     "faction": "accord", "joined_at": 1794095000, "address": "203.0.113.7",
     "character_id": "9f2c4e1a7b3d5f60a1b2c3d4e5f60718", "account_id": "a_1842"}
  ]
}
```

- **`accounts_version`** is the list version the game holds, `0` before the first
  list. It is sent in every request.
- **`reward_catalog`** lists every reward the running game can give, as `id`, `kind`
  and display `name`. The only `kind` in phase 1 is `cloak`.
  - It comes in the first request of each `boot`, and again in every request until
    a `200` answered one that carried it.
  - Store it per realm and replace it on every arrival. The admin page offers
    exactly these.
  - If the website lost it, answer with `resync: ["reward_catalog"]`; the game then
    sends it again (a new `resync` value beside `"mail"`).
- **Online rows** have `character_id` once the character has one, and `account_id`
  only while the character has a valid binding. An applied list that changes an
  online character's binding makes the game send the online list in its next
  request.

### 5.2 Response: the list

```json
{
  "protocol": 1,
  "accounts": {
    "version": 8,
    "characters": [
      {"name": "Rowan", "character_id": "9f2c4e1a7b3d5f60a1b2c3d4e5f60718",
       "account_id": "a_1842"}
    ],
    "accounts": [
      {"id": "a_1842", "name": "jan", "rewards": ["cloak:supporter"]}
    ]
  }
}
```

- **When to send it:** include `accounts` whenever its `version` differs from the
  request's `accounts_version`. Send it whole: every binding on this realm, and every
  account that owns at least one of them. Accounts without a character on this realm
  stay out; the game would have no use for them.
- **`version`:** a positive integer; raise it on every change. The game applies
  **every list whose version differs from its own, higher or lower** (a restored
  website backup), and stores that version even when it dropped malformed rows.
- **The game keeps the list** in its storage and applies it at every start. Rewards
  therefore hold while the bridge is down. After a server crash the stored version
  may be older than the last one sent, and the version check then sends the list
  again.
- **The game applies `accounts` before the `commands`** of the same response.
- **What the game ignores:**
  - A list without a numeric `version` is ignored whole.
  - A malformed row (bad name, character id or account id) is dropped with a
    warning in the server log.
  - A character row whose `account_id` has no account row is dropped.
  - Two character rows for one name (also differing only in case): both are
    dropped. The website's own rule (§3 item 2) makes this impossible.
  - Two account rows with one `id`: the first is used, the second is dropped with a
    warning in the server log. Account ids are unique on the website, so this
    should not happen either.
  - An account `name` is cleaned (no colour escapes or control characters) and cut
    to 64 characters; it is display text only.
  - Unknown fields anywhere are ignored. Every later amendment that the game must
    enforce (an account ban, for instance) therefore comes with its own capability,
    so the website can tell whether the running game knows it.
  - A reward id the game does not know grants nothing, but stays stored. The website
    may grant a reward before the game version that has it is live.
- **Size:** the response limit is 1 MiB. Warn the administrators once the list
  passes 512 KiB; a delta form would then come as a later amendment.
- Both sides accept `null` where an array is expected, as everywhere in the bridge.

### 5.3 Events from the game

They are ordinary bridge events (`seq`, `time`, `type`), delivered at least once.
Dedupe by `(boot, seq)` as for every event, and process the `account.link_*` events in
`seq` order: a cancel and a confirmation for one request can arrive in the same
request body.

| Type | Fields | Sent when |
|---|---|---|
| `account.link_request` | `request_id`, `name`, `character_id`, `code` | the player sent a well-formed code |
| `account.link_confirm` | `request_id`, `name`, `character_id` | the player confirmed an offer |
| `account.link_cancel` | `request_id`, `name` | the player cancelled, logged out, or the game gave up (30 s without an answer, 2 min without a confirmation) |

- `request_id` is 16 lower-case hex digits, new for every request. The same
  `request_id` runs through request, offer, confirmation and final answer.
- `code` is the normalized code (§4).
- A `link_request` never comes from a character that is still being created, or from
  one that is linked as far as the game knows. A binding that appears in an applied
  list for a character with an open request (a direct binding, §6a) ends that
  request: in `confirming` as linked, otherwise with a `link_cancel`. A character has at most one open
  request; a new one cancels the old one (a `link_cancel` comes first).
- **A cancel after a processed confirmation does not undo the binding** (the
  administrator can unlink). **A confirmation after a cancel** for the same request is
  not bound.

### 5.4 Command to the game: `account.link_answer`

Capability `accounts`. Command delivery, the result format, `expires_at` and
at-most-once are as in the bridge protocol. `expires_at`: **at most 60 s** after
sending.

| Arg | When | Value |
|---|---|---|
| `request_id` | always | the id from the event |
| `name` | always | the character's name from the event |
| `outcome` | always | `offer`, `linked` or `refused` |
| `account_name` | `offer`, `linked` | the account's display name; cleaned and cut to 64 characters like the list's `name` (§5.2) |
| `reason` | `refused` | one of the reasons below |

**Valid answers per game state.** The game holds one open request per character:

| Game state of the request | Valid outcomes | Any other outcome |
|---|---|---|
| `checking` (request sent) | `offer`, `refused` | result `invalid_args`; the request stays open |
| `offer` (shown, waiting for the player) | none | result `invalid_args`; the request stays open |
| `confirming` (confirmation sent) | `linked`, `refused` | result `invalid_args`; the request stays open |
| no open request with this `request_id` | none | result `refused` |

- A `linked` answer whose binding is not in the applied list: result `invalid_args`
  ("binding not in the list"); the request waits for the list until its 30 s end.
- A `linked` answer for a request that the list applied just before it already
  ended as linked (the normal case, §6: list and answer in one response): result
  `ok`. Any further answer with that `request_id` gets `refused`.
- A `name` that is not the request's character is `invalid_args`.
- An unknown `reason` is shown as `other`.
- **The website answers only in reply to an event**, never unprompted. A new code
  ending a reservation, for instance, sends nothing; the refusal comes at the
  confirmation (§4).

**Refusal reasons.** The game has its own text for each, so the website sends no
text a player reads:

| `reason` | When |
|---|---|
| `unknown_code` | no such code |
| `expired_code` | older than 10 minutes and not reserved for this request |
| `used_code` | consumed, replaced by a newer code, or reserved for another request |
| `account_full` | the account already has 10 characters |
| `already_linked` | the character (name or character id) already has a binding |
| `too_many_attempts` | the website's rate limit (§4) |
| `other` | anything else; the game shows a general refusal |

*Note of 2026-11-16: the website's answers are narrower than this table reads*
(its note of 2026-11-15). None needs a change in the game:

- **Some link requests get no answer.** The first request over a character's limit
  (the 11th within an hour) gets `too_many_attempts`; later requests of that
  character in the same hour, and every request once the deployment's ceiling of
  600 link requests per hour is reached, get none. The game's 30 s timeout ends them.
- **A used code comes back as `unknown_code`**, not `used_code`: the website deletes
  a code together with the binding.
- **A confirmation the website never offered gets no answer** (the request was
  refused or not answered). Each confirmation is answered once.
- **A bound name takes the game's spelling** from the request, also when the account
  held the same name in another case. The game compares names ignoring case.

**Results the game reports:**

| Code | Meaning | What the website does |
|---|---|---|
| `ok` | shown to the player | nothing |
| `not_online` | the character left | release the reservation; for a `linked` answer the binding stays |
| `refused` | the game has no open request with this id: it ended or timed out, or a second answer came after it ended | release the reservation; for a `linked` answer the binding stays |
| `invalid_args` | an argument is missing or malformed, or the answer does not fit the request's state (above) | keep the reservation; fix the website |
| `expired`, `error`, `unknown` | the general codes of the bridge protocol | release the reservation; for a `linked` answer the binding stays |

## 6. The link, step by step

```text
Website                                   Game (character Rowan, online)
───────                                   ───────────────────────────────
account owner creates code ABCDE-FGH23
                                          Account page: player enters the code
                       ◄── event account.link_request {request_id R, name, character_id, code}
check the code, the limits, the character
reserve the code for R
command account.link_answer ──►
  {R, name, outcome: offer, account_name}
                                          page: "Link Rowan to the website account jan?"
                                          player presses Link
                       ◄── event account.link_confirm {R, name, character_id}
check the reservation, store the binding,
consume the code, raise the list version
response: accounts (new version)
  + command account.link_answer ──►
  {R, name, outcome: linked, account_name}
                                          applies the list, then the answer:
                                          page: "Linked to the website account jan."
```

- **Ordering of the final answer:** send `linked` only in the same response as the
  list that holds the new binding, or in a later one. The game applies the list
  first (§5.2). The list is what counts: a character whose binding is in the applied
  list is linked even if the `linked` answer is lost.
- **Refusals:** at the request, answer `refused` with the reason. At the
  confirmation, answer `refused` too (for example `used_code`, when the reservation
  lapsed and another request took the code) and do not bind.
- **Cancel:** on `account.link_cancel`, release the reservation. The code is still
  valid if its 10 minutes have not passed.
- **A new `boot`** (server restart) ends every open request in the game. Release the
  reservations of the old boot's requests (§4), so the player can use the same code
  again after the restart.
- **Timing:** the game polls every 2 s by default, so a request, an offer and a
  confirmation take some seconds each. The game tells the player so. Answer within
  the same or the next response where possible: after 30 s without an answer the
  game gives up and sends `account.link_cancel`.

## 6a. Direct binding by password

Agreed with the user on 2026-11-15. For every character whose password the website
stores, and for a character whose password the player types once on the website:

1. **Check the password** against the character's auth entry on that realm, read
   from the auth table. The reference implementation is
   `tools/web_accounts/luanti_password.py` in the game repository. It uses only the
   Python standard library, and its README lists the rules. It comes with 17
   synthetic test vectors whose SRP verifiers were made by the engine's own
   `util/srp.cpp`, and it was checked against entries the engine itself wrote.
   - Use the name **as the auth table stores it**, not as typed: the legacy format
     depends on its case.
   - Compare the password as the UTF-8 bytes typed, without Unicode normalization.
2. **On a match, bind** the character like a link by code: check the one-binding
   rule and the 10-character limit atomically with storing the binding, as at a code
   confirmation (§4), so a password bind and a code confirmation on one account can
   never pass 10 together. Then raise the list version and send the list.
   - **The character id** must already be in `player_metadata`
     (`grug_accounts:character_id`). Bind only an id the database shows. The online
     row's `character_id` is the same value and tells the website when to look, but
     it is not enough on its own. The game's id index and its copy of the list live
     in one mod storage that the engine commits once per interval. A crash right
     after a bind can lose both, and the character would then get a new id that the
     binding no longer matches. Player meta is saved on its own timer (at the latest
     at logout), so on a first join the bind may wait some seconds to minutes.
   - A character that has not joined since 0.79.0 is not bound yet; check again once
     its id is in the database.
3. **A typed password** is not stored; the character stays in manual mode. A stored
   password is checked once for the binding, and again before every web start in auto
   mode. On a mismatch (for instance after an in-game password change) the website
   switches the character to manual mode and asks for the password.
4. **Rate limits for typed passwords**, because the check would otherwise let anyone
   test passwords. *Note of 2026-11-16: confirmed and built by the website on
   2026-11-15 with these numbers:*
   - at most 5 failed checks per character per 15 minutes (per realm and name, the
     name as the auth table stores it, compared ignoring case), and at most 5 per
     account per hour across all realms
   - a global ceiling of 100 failed typed-password checks per hour per deployment;
     once it is reached, every typed-password bind is refused until the hour has
     rolled on
   - one generic refusal text, the same for a wrong password, an unknown name, a
     character without a password and every limit: it never says whether the name
     exists
   - an empty auth entry or an empty typed password never binds
   - the limits are counted in fixed time windows, so around a window boundary up
     to twice a limit can pass
5. **During character creation:** a character that joined through the web client
   and is still creating its character can be bound as soon as its id is in
   `player_metadata` (item 2). The game stores the binding and does not disturb the creation.
   Rewards and the notice below apply once the creation is finished. The website
   needs no signal for that.
6. **Notices in the game:** when a character's binding appears and no code request
   of its own ended as linked, the player reads one feed line: "This character is
   now linked to the website account <name>." When a binding disappears, the line is
   "This character is no longer linked to a website account." The game stores what
   the character last saw, so a binding made while it was offline, or one that
   arrived during character creation, is reported at the next join or after
   "Create character". The account name always comes from the list.

## 6b. Setting a password: `account.set_password`

Agreed with the user on 2026-11-15. It is for the auto mode's recommended option, "a
new, secure random password": the website generates the password, sets it in the
game, and stores it on `ok`.

**Capability:** `accounts.password`, its own, beside `accounts`. Offer the command
only to a realm that reports it.

**Args:**

| Arg | Value |
|---|---|
| `name` | the character's name, as in the binding (§5.2) |
| `account_id` | the account the website acts for |
| `entry` | the complete entry `#1#<salt>#<verifier>` |

**The entry:**

- SRP-6a, SHA-256, the 2048-bit group, the name in lower case (ASCII letters).
- Salt and verifier are base64 **without** `=` padding, as the engine writes
  entries.
- The game accepts only that form:
  - `#1#`, then the salt, `#`, and the verifier
  - each part non-empty, **canonical** base64 without padding: decoding and
    re-encoding gives exactly the text sent. The engine refuses anything else at
    login (`base64_is_valid`: no length of 1 mod 4, a canonical last character), so
    a malformed entry would lock the character out.
  - the verifier 1 to 256 bytes
  - nothing else
- A legacy entry, a plain password or anything malformed is `invalid_args`. The
  reference `valid_entry(entry)` in `tools/web_accounts/luanti_password.py` applies
  exactly this rule.
- **Make the entry** with a fresh 16-byte salt from a cryptographically secure
  source, and never reuse a salt. The reference is `make_entry(name, password)` in
  `tools/web_accounts/luanti_password.py`.

**The game's checks:** the command runs only when the character has an auth entry
(the game never writes one that is missing: that would create a new login) and a
binding that counts by the game's own rules (§2) and names `account_id`. The game writes the entry
with `core.set_player_password` and logs one `action` line without the entry.

**Online or offline:** both are allowed.

- **Offline:** the entry holds from the next login.
- **Online:** the session stays, and the player reads one feed line: "Your password
  was changed on the website. It applies from your next login."
- **One engine quirk until that next login:** the client's own "Change Password"
  dialog authenticates against the entry the server cached at login, so it still
  asks for the old password. A change made there replaces the website's. The
  website's own check before a start in auto mode (§6a item 3) finds that and
  switches to manual mode.

**Results:**

| Code | When | What the website does |
|---|---|---|
| `ok` | the entry is written | make the pending password current |
| `unknown_target` | no auth entry for `name` | drop the pending password |
| `refused` | no counting binding for this account; message "not linked to this account" | drop it |
| `invalid_args` | malformed arguments or entry | drop it; fix the website |
| `expired`, `error`, `unknown` | the general codes of the bridge protocol | drop it; the §6a check settles the real state |

- **Delivery** is at most once, as for every command.
- **`expires_at`** is at most 60 s.
- A character still in character creation counts like any bound one.

## 7. Unlinking and account deletion

Both are list changes only: remove the binding (or the account with all its
bindings), raise the version, send the list. The game then shows the character as
not linked and the account's rewards leave it at once. A worn reward cloak falls
back to none. There is no command for either.

## 8. Rewards

- **Grant and remove** on the admin page, per account, from the catalogue (§5.1).
  Every change raises the list version.
- **The game reads rewards live** from the list. A character gains or loses them on
  the next list, online or at its next login, and gets a short notice in the game.
- **Character-bound rewards stay in the game.** The existing character-bound
  Supporter achievement and its cloak are unaffected; a character may have the cloak
  both ways.
- **Phase 2** (*note of 2026-11-16*, game 0.80.0): the reward every account gets
  automatically is the emote **`emote:cheer`**; there is no cloak for every account.
  The six donor cloaks (`cloak:emberwake`, `cloak:veilstream`, `cloak:pearlwing`,
  `cloak:moonfall`, `cloak:wintercourt`, `cloak:frost_regent`) and the Supporter
  Cloak are granted **manually** per account. All of them arrive through the
  catalogue (§5.1). No new field, event, command or capability.

## 9. Testing

- `tools/r691_bridge/fake_bridge.py` in the game repository gets an accounts mode in
  Round 79. It plays the website's part by this contract and is the reference for the
  game's expectations.
- **End to end on the rehearsal realm**, before the release goes live:
  1. Link a character (with one refusal and one cancel first).
  2. Grant and remove `cloak:supporter`.
  3. Link a second character to the same account.
  4. Bind a character by its stored password and one by a typed password; check the
     notice in the game, and one bound during character creation.
  5. Set a new password with `account.set_password` for an offline and an online
     character, and log in with it.
  6. Unlink one character, then delete a test account.
  7. Restart the server. Bindings and rewards stay, the catalogue arrives again, and
     the list is re-sent after a version mismatch.

## 10. Outlook: later amendments

Not to be built now. Listed so that nothing in the website's data model blocks them.
Each comes with its own capability:

- **Account ban:** a ban field per account in the list. The game refuses every
  character of a banned account at login.
- **Characters created through a bridge command:** a command creates the login and
  the binding at once, and fails atomically when the name is taken. It clears a
  tombstone for the name (§2); the character adopts the binding's id at its first
  join. Later, an option may allow new characters only this way. Not needed for
  names the website reserves today: if someone else registers such a name natively
  first, the stored password does not match, and the website never binds it (§6a).
- **Character deletion:** built in 0.83.0 as `character.delete`
  ([web-bridge.md](web-bridge.md#amendment-2026-11-18-characterdelete)). Instead of
  the `not_offline` answer planned here, the game disconnects an online character
  itself and answers once the deletion is done; it writes the tombstone (§2) and
  drops the deleted character's row from its stored copy of the list at once; the
  website removes the binding.
- **Shared Claim Stone** per account and faction (with a future map reset). The game
  needs bindings of offline characters, which the list already provides.

## 11. Open points

None. The point open on 2026-11-15 morning (characters the website already knows) is
decided: §6a.
