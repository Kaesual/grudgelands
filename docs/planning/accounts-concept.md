# Website accounts — concept

Drafted with the user on 2026-11-14 and 2026-11-15. Status: **concept**; phase 1 is
planned in [round79-plan.md](round79-plan.md), phase 2 in
[round80-plan.md](round80-plan.md), their contract with the website is
[web-accounts.md](../technical/web-accounts.md). This file holds the long-term model,
the user's rulings and the order of the phases. Every phase gets its own round
plan; what this file says about a later phase is direction, not a brief.

## How to add to this document

- A new ruling goes to §2 with its date. A **proposal** is not a ruling until the
  user says so; open questions stay in §7 until they are decided.
- Protocol details belong in [web-bridge.md](../technical/web-bridge.md) once a
  phase ships; this file only names what each phase adds.

## 1. The idea

A player may have an account on the realm's website. A character on the server may
be **linked** to one account. An account gives **rewards** (cloaks, later emotes) to
every character linked to it; an administrator grants them per account on the
website.

Accounts are **optional and on top**: a character without an account plays exactly
as today, and linking only ever adds something. Most players use the native Luanti
client and created their character there with their own password; nothing in this
model may push them towards the website or the web client.

## 2. User rulings

### 2026-11-14

1. **Character deletion** (a later phase): a deleted character's name may be
   reused. Its claim ends as on `/claim_remove` (the buildings stay, unprotected);
   locked chests and doors keep the old owner name, and a new character of that
   name may open them (accepted). Mail to the deleted character expires. It is
   about "delete and start over", not about data-protection erasure.
2. **An account ban bans every character of the account.** The login check asks
   whether the character's account is banned.
3. **At most 10 characters per account.**
4. **Linked characters get the same features as characters created on the
   website.**
5. **The bridge's online rows carry the account id.**
6. **Characters still create themselves at their first login** for now. Later it
   must be possible to allow character creation only through the website (a server
   password or a locked creation, via the bridge only). The website already offers
   "copy password" for characters whose password it stores, for logging in with the
   native client.
7. **The account name is never shown to other players.** They see character names
   only and cannot tell which characters belong together.

### 2026-11-15

8. **Linking works the other way round:** the website creates a code, the player
   enters it on the **Account page** in the inventory. Only a character that is
   online can therefore be linked, and no password passes through the website. (For
   the code path; ruling 26 adds linking by password on the website.)
9. **The code:** 10 characters, upper-case letters and digits without the confusable
   `0`, `O`, `I` and `1` (32 symbols).
10. **The Account page** names the linked website account and lists the rewards the
    account owns.
11. **Rewards are account-bound** and available to every character of the account.
    The administrator grants them **manually per account on the website**. The first
    is the **Supporter Cloak**; Supporter emotes follow.
12. **Later, all website users get a cloak and an emote** as a reward, once linking
    works. More Supporter cloaks and emotes come after that. *Narrowed by Round 80
    ruling 1 (2026-11-16): an emote only, Cheer; no cloak for everyone.*
13. **Claim Stones stay as they are** (one per character from level 20). The shared
    claim (§5.5) comes with a later map reset (ruling 25); an in-between version is not worth
    building.
14. **Multiboxing stays allowed.** No session takeover. Linked characters have no
    disadvantage against unlinked ones.
15. **Character deletion comes later**, not in the first phases.
16. **The domain moves from kaesual.com to grudgelands.com** (same server and
    address). Operations, separate from this work.
17. **Deleting an account unlinks its characters**; they stay and play on as
    characters without an account (this replaces the ruling of 2026-11-14 that
    deleted them with the account).
18. **Only an administrator can unlink** a character, on the website. Players
    cannot.
19. **The in-game password change stays allowed for linked characters** (this
    replaces the block planned on 2026-11-14).
20. **No grace period after linking.**
21. **A link code is valid for 10 minutes.**
22. **No address setting:** only one website can link characters, so the game needs
    no configured website address.
23. **The Account page tells the player that linking takes a few seconds** after
    the code is entered, and that they should wait.
24. **Per realm, rewards everywhere:** bindings, codes, the list and the
    10-character limit are per realm; accounts and their rewards are global, so a
    reward reaches the account's characters on every realm.
25. **The keep-claims map reset (Round 77) is discarded.** The next map reset comes
    later, when it is needed; the shared Claim Stone (ruling 13) waits for it.
26. **Direct binding by password** (the user in this session, and as relayed in the
    website's feedback the same day): the website binds a character whose password
    it stores, after checking it once against the realm's auth entry; a player may
    also link on the website by typing a character's password once (not stored). The
    code path stays for players who do not want to type a password into the website.
    Contract [web-accounts.md](../technical/web-accounts.md) §6a.
27. **grudgelands.com** is the website, live no later than 0.79.0 in production; the
    Account page names `grudgelands.com/play`, where codes are created and the
    password link is offered.
28. **No "password changed" event:** the website notices an in-game password change
    at its own check before a web start.
29. **Setting a password from the website comes in phase 1** (0.79.0): the command
    `account.set_password` with a finished SRP entry, for linked characters only,
    online or offline. It serves the auto mode's "new, secure random password"
    (contract §6b).

## 3. The foundation (phase 1)

What every later feature builds on. It must not need to change when they come.

### 3.1 Identities

- **Account id:** opaque string from the website, stable for the account's life
  (`[A-Za-z0-9_-]`, at most 64 characters). The game never derives anything from
  it. The account's **display name** is a separate field that may change.
- **Character name:** the Luanti name, as today.
- **Character id:** new. A random 32-hex-digit id the game gives every character at
  its first join after phase 1 ships, stored in player meta
  (`grug_accounts:character_id`), never changed. It tells two characters of the same
  name apart: once characters can be deleted and names reused, a binding that names
  a character id the current character does not carry is not that character's
  binding. The game sends it with every link event, and it is also readable in
  `player_metadata`. The game keeps its own name → character id index in mod
  storage, because an offline character's meta cannot be read: that is what lets
  later features (bans at login, the shared claim, chests) apply the rule to offline
  characters. The index knows three states per name: no entry (a binding counts and
  its id is adopted at the first join, which is how characters created through a
  bridge command, §5.3, will get theirs), an id (a binding counts only with it), and a
  tombstone that a deletion writes (no binding counts, nothing is adopted).
- **Realm:** the platform runs several worlds (production, rehearsal, tests).
  Bindings, codes and the list are per realm; accounts and rewards are global
  (ruling 24).

### 3.2 The website is the source of truth

The website owns accounts, bindings and rewards. The game holds a **copy**: one
versioned list the bridge sends whenever its version differs from the game's, kept
in mod storage, exactly as the ban list is today. So every check works while the
bridge is down and across restarts, and later features can ask about offline
characters (the shared claim, chests, bans).

The game **never changes a binding itself**: linking ends with the website sending
the new list. Unlinking (an administrator's support action) and account deletion
are list changes too; the game only has to handle a character that loses its
binding.

### 3.3 Linking

1. On the website the account owner creates a code. It is single-use, bound to the
   account, valid for 10 minutes, and a new code replaces the account's previous
   one. It is shown in two groups of five (`ABCDE-FGH23`).
2. On the Account page the player enters it. Case, spaces and hyphens do not matter;
   a code of the wrong length or alphabet is refused at once without a request.
3. The game sends the code with the character's name and id. The website answers
   with an **offer** naming the account, or a refusal with a reason.
4. The page asks for confirmation, naming the account: only link to your own
   account. This guards against a stranger handing a player their code.
5. On confirmation the website binds the character, sends the new list and the
   final answer.

Refusals: unknown code, expired, already used, the account already has 10
characters, the character is already linked, too many attempts.

**Or by password, on the website alone** (ruling 26): the website checks a stored or
once-typed password against the realm's auth entry and binds the character in its
list. The game only sees the new list and tells the player in the feed. The check
needs no game code; the reference is `tools/web_accounts/luanti_password.py`.

### 3.4 Rewards

- A reward is an id of the form `<kind>:<name>` (`cloak:supporter`; phase 2 adds
  `emote:…`). The game keeps the **catalogue**: each mod registers the rewards it
  can give, and the game reports the catalogue to the bridge, so the website's admin
  page offers exactly what the running game knows.
- The list carries each account's reward ids. An id the game does not know is
  ignored, so the website may grant a reward before the game version that has it
  is live.
- A reward is **read live**, never copied into the character: removing it from the
  account removes it from every character at once (a worn cloak falls back to
  none).
- Rewards are not achievements. The existing character-bound Supporter achievement
  stays for those who have it; the cloak picker offers a cloak a character has
  either way.

### 3.5 What the bridge carries (phase 1)

New capability `accounts`. The request adds `accounts_version` and, once per boot,
the reward catalogue; online rows add `character_id` and `account_id`. The response
may carry `accounts`, the complete list. Events `account.link_request`,
`account.link_confirm`, `account.link_cancel`; command `account.link_answer`.
Protocol 1 stays: every addition is optional for the other side. The contract with
the website, exact shapes and the website's duties:
[web-accounts.md](../technical/web-accounts.md).

## 4. Phases

| Phase | Content | When |
|---|---|---|
| 1 | Foundation (§3), the Account page, linking by code and by password on the website, setting a linked character's password from the website, the Supporter Cloak as the first account reward, account id in the online rows | [Round 79](round79-plan.md) |
| 2 | One emote for every website user, Cheer (`emote:cheer`, granted by the website to every account; no cloak for everyone, Round 80 ruling 1); six donor cloaks granted per account; the quickbar's emotes as icon buttons that grow with them; the art | [Round 80](round80-plan.md) |
| 3 | More Supporter emotes and cloaks: content only | later |
| — | Account ban, characters created through a bridge command, character deletion | each as its own phase, order open |
| — | Shared Claim Stone per account and faction, account-bound locked chests and doors | with a later map reset (ruling 25) |

## 5. Later phases — direction

### 5.1 Account ban

The list (§3.2) carries a ban per account (until, or permanent); the existing
prejoin check refuses every character of a banned account, also while the bridge is
down. Name bans stay as they are.

### 5.2 Passwords (phase 1 since ruling 29)

- `core.set_player_password` stores the given string as the password entry unchanged
  (`builtin/game/auth.lua` `set_password`), so the website sends a finished SRP
  entry (`#1#<salt>#<verifier>`, base64 without padding: SRP-6a, SHA-256, the
  2048-bit group, the name in lower case) with `account.set_password` (contract
  §6b). A plain password would end as the weaker legacy SHA1 entry, so the game
  accepts only the SRP form. The entry is never logged.
- The website offers "new random password" and "set manually"; for a native-client
  player this is the first way back from a forgotten password.
- The in-game password change (the client's own "Change Password" dialog) stays
  allowed for linked characters (ruling 19). The website notices it when its stored
  password no longer matches the auth entry (ruling 28) and asks the player again.

### 5.3 Characters created through a bridge command

A bridge command creates the auth entry with a verifier and the binding in one step
and fails atomically when the name is taken (case-insensitively). A later setting
refuses unknown names at prejoin, so creation runs only through the website.

### 5.4 Character deletion

Runs inside the game, never as a database write: several mods (parties, clans, the
claim registry, the mail index) hold their state in memory and would overwrite or
ignore an outside change, wherever the mod storage backend lives. A deletion registry like `grug_core.map_reset` lets each mod clean
its own state (claim, rights in other claims, party, clan, mail, achievement queue,
claim home, a tombstone in the id index, §3.1); then `core.remove_player`, and `core.remove_player_auth` last, which
also drops every privilege. A character that is online is disconnected first and
held out by a game-side marker until the deletion finished; the command answers
`not_offline` until then and the website repeats it. The study of 2026-11-14 lists
every place a character leaves state.

### 5.5 Shared Claim Stone (with a later map reset)

Direction from the user (2026-11-15), to be planned with that reset:

- One Claim Stone per account and faction, shared by all its characters of that
  faction; every one of them has all rights on it (pick up, fuel, permissions) and
  may travel to it from the waystones, level 1 included.
- `claim.owner` stays a character name; the player chooses on the stone which of
  their characters is the owner. (Other players then see a new name on the stone,
  which tells them the two belong together: the form says so.)
- While a stone of the account is placed, no other character of that faction gets
  one from the Housing Steward. An unplaced stone in another character's inventory
  does not block: the Steward hands out a new one, and the older stone leaves its
  holder's inventory at their next login (a generation number on the stone).
- Linking a character that has a placed stone, to an account that already has one
  in that faction, is refused: "You already have an Accord character with a Claim
  Stone on this account. All your Accord characters share one Claim Stone. Pick up
  this character's Claim Stone before adding it to the account." (The 12-hour
  pick-up lock after activation belongs in that text, or the website offers to give
  the stone up.)
- When the owner is deleted, ownership passes to another character of the account
  in that faction (proposal: the one online most recently); with none left, the
  claim ends as on `/claim_remove`.
- Locked chests and doors become account-bound at the same time: new ones store the
  account id beside the owner name, the account decides when it is set, old ones
  take it at their owner's next use. Almost every check runs through
  `default.can_interact_with_node`, plus a few `owner ~= name` comparisons in the
  vendored chests and doors.

## 6. Privacy

- The account's name and id appear only on the character's own Account page and in
  the website's admin views, never in anything another player can see.
- A reward cloak shows that a character is linked, not to which account.
- Online rows carry the account id to the website only.
- The website's public pages never show which characters share an account either.

## 7. Open questions

None at the moment.

Decided on 2026-11-15 (§2, rulings 17–29): account deletion unlinks, only an
administrator unlinks, the in-game password change stays, no grace period, a code
lives 10 minutes, no address setting, bindings per realm with rewards on every realm,
the Round 77 map reset discarded, direct binding by password, setting a password
from the website in phase 1. Phase 1 handles a removed
binding already (§3.2), so unlinking and account deletion need no game change.
