# Round 79 — Website accounts, phase 1: the Account page, linking, account rewards

Planned with the user on 2026-11-14 and 2026-11-15. The long-term model, every ruling
and the later phases: [accounts-concept.md](accounts-concept.md). Routing (user's
standing rule): one coordinator, lanes as subagents of the session model, independent
review of every lane with game logic. Version **0.79.0**, expected **compatible**: no
map reset, no change to existing saved data; one new mod with its own mod storage and
two new player-meta keys (`grug_accounts:character_id`, written at join, and
`grug_accounts:seen`).

Round 77, the keep-claims map reset, was discarded by the user on 2026-11-15; its
number is not reused.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a
  ruling until the user says so; a coordinator default is marked as such.
- Name functions rather than line numbers.

## Why

Players should be able to link their characters to an account on the realm's
website, so that rewards an administrator grants an account reach every character
of it. The first reward is the Supporter Cloak. The link is the foundation for
everything later (concept §4): rewards for every website user, account bans,
characters created through a bridge command, deletion, and the shared Claim Stone.
So this round puts weight on getting the identities and the data flow right, and
ships only one visible thing: a new inventory page.

## 1. Lanes and order

Start state: main at the last account planning commit (0.78.0, no game change). Integration
branch `round79` in `.claude/worktrees/round79`; every lane branches from it.

| Lane | Goal (§4) | Wave | Merge order | Review |
|---|---|---|---|---|
| ACC | New mod `grug_accounts` (the list, bindings, character id, reward catalogue, the link flow); `grug_bridge` speaks it, including `account.set_password`; the protocol amendment; the fake bridge's accounts mode | 1 | 1 | independent |
| PAGE | The Account page; the Supporter Cloak as an account reward in `grug_achievements` | 2 (after ACC merged) | 2 | independent; screenshots to the user before the merge |
| D | Design doc, mod map, module guide, help text, completion, GUI checklist | after every merge | — | coordinator |

PAGE waits for ACC because the page is a view of ACC's API. The API is fixed here
(§3.3), so PAGE's brief can be written before ACC finishes.

**The website's part** (code creation, the password check and direct binding, the
admin's reward page, the list, the link answers, the random password) is built on the
platform by its own agent, from the contract
[web-accounts.md](../technical/web-accounts.md) (§3.2 here) that the user hands over.
This round tests against the fake bridge; the end-to-end test on the rehearsal realm
follows once the platform side is ready.

## 2. User rulings

From [accounts-concept.md](accounts-concept.md) §2, the ones this round builds:

1. **Accounts are optional and on top** (2026-11-15). A character without an account
   plays exactly as today; linking only adds. No new rule for anyone: multiboxing
   stays allowed, no session takeover.
2. **Linking by code** (2026-11-15): the website creates the code, the player enters
   it on the in-game Account page; only an online character can be linked this way
   (ruling 16 adds the password path on the website).
3. **The code** (2026-11-15): 10 characters, upper-case letters and digits without
   `0`, `O`, `I`, `1`.
4. **The Account page** (2026-11-15) names the linked website account and lists the
   account's rewards.
5. **Rewards are account-bound** (2026-11-15), available to every character of the
   account, granted **manually per account by the administrator on the website**.
   The first is the Supporter Cloak.
6. **At most 10 characters per account** (2026-11-14), a rule of the website.
7. **The online rows carry the account id** (2026-11-14).
8. **The account name is never shown to other players** (2026-11-14).
9. **Claim Stones, deletion and bans do not change in this round** (2026-11-15).
   The in-game password change stays allowed for linked characters.
10. **A code is valid for 10 minutes** (2026-11-15).
11. **Only an administrator unlinks**, on the website; deleting an account unlinks its
    characters, which stay (2026-11-15). Both are list changes, so the game only has
    to handle a binding that disappears.
12. **No grace period after linking** (2026-11-15).
13. **No address setting** (2026-11-15): only one website links characters.
14. **The page tells the player that linking takes a few seconds** and that they
    should wait (2026-11-15).
15. **Per realm, rewards everywhere** (2026-11-15): bindings, codes, the list and
    the 10-character limit per realm; accounts and rewards global (contract §3
    item 1).
16. **Direct binding by password** (2026-11-15, concept ruling 26): the website binds
    characters itself after checking a stored or once-typed password against the
    auth entry (contract §6a); the game only receives the list. The code path stays.
17. **grudgelands.com** (2026-11-15) is live no later than 0.79.0 in production;
    the page names `grudgelands.com/play`.
18. **The website sets a linked character's password** (2026-11-15, concept ruling
    29): the command `account.set_password` with a finished SRP entry, capability
    `accounts.password`, online or offline (contract §6b).

## 3. Shared conventions

### 3.1 Rules not covered by a ruling (coordinator defaults, the user may overrule)

- **Character id:** 32 lower-case hex digits, made at the character's first join
  after 0.79.0 (also during character creation) and stored in player meta
  `grug_accounts:character_id`; never changed or rewritten. It goes into the
  module guide's table of player-meta keys read by external tools.
- **Id index:** `grug_accounts` keeps name → character id in its own mod storage.
  Player meta of an offline character cannot be read, so the index is what lets the
  character-id rule hold for offline names (later: account bans at prejoin, the
  shared Claim Stone, account chests). Three states per name, as in the contract
  (web-accounts.md §2):
  - **No entry:** a binding for the name counts; a character joining without an id
    adopts the binding's id if there is one, else gets a new id.
  - **Id X:** a binding counts only with id X; a character joining without an id
    takes X (meta and index are saved by separate timers, so a crash can lose one).
  - **Tombstone:** written only by a future deletion, never a plain clear; no
    binding counts and nothing is adopted. Phase 1 writes none but reads the state.
  - At a join where meta and index disagree, the meta wins and the index is
    rewritten, with a log line.
- **A binding counts** only when its name and its character id match by these rules
  (online: the character's meta; offline: the index). A mismatch is ignored and
  logged once per boot.
- **The game never writes a binding.** It applies the website's list; a binding that
  disappears (an administrator unlinked it) simply returns the page to "not linked"
  and the rewards go with it.
- **The list is kept** in `grug_accounts`' mod storage and applied at load, so
  rewards hold while the bridge is down and across restarts. The engine writes mod
  storage only at intervals: after a crash the stored version may be older, and the
  bridge then sends the list again because the versions differ.
- **Any list whose version differs is applied**, a lower one too (a restored website
  backup), and its version is stored even when malformed rows were dropped; otherwise
  the website would resend it forever.
- **Linked or not comes from the list only.** The page shows "linked" exactly when
  `account_of(name)` is set; the flow's `linked` state is only the one-off success
  line. An open request in `confirming` ends as linked as soon as an applied list
  holds a counting binding for the character, even if the `linked` answer is lost.
  A `linked` answer whose binding is not in the applied list keeps waiting until the
  30 s timeout.
- **Online rows follow a binding change:** an applied list that changes an online
  character's binding marks the online list changed, so `account_id` reaches the
  website with the next request.
- **Rewards are read live** and never copied into player meta. A worn reward cloak
  that the account loses falls back to none. The character-bound Supporter
  achievement and its cloak stay exactly as they are.
- **Notices** (ACC, kind-agnostic): when a character gains or loses an account reward
  (at a list change while online, or at the next join), the feed says "Your account
  gives you: Supporter Cloak." / "Your account no longer gives you: Supporter
  Cloak." once. What the character last saw (its account id and reward set) is player
  meta `grug_accounts:seen`.
- **Binding notices** (ACC, contract §6a item 6): a binding that appears gives "This
  character is now linked to the website account <name>." unless the character's
  own code request ended as linked (that shows its success line instead); one that
  disappears gives "This character is no longer linked to a website account." Both
  are compared with `grug_accounts:seen`, so a change made while the character was
  offline or in creation is reported at the next join or after creation. The
  account name always comes from the list, also in a success line of a request that
  a direct binding ended.
- **During character creation** a binding from the list is stored and counts, but
  the creation is not disturbed: reward and binding notices and the cloak refresh
  wait until the creation is finished (`grug_classes.register_on_arrival`).
- **A binding that appears for a character with an open request** ends it: in
  `confirming` as linked, otherwise with `account.link_cancel` (contract §5.3).
- **Code input:** upper case is applied, spaces and hyphens are removed; anything
  that is not 10 symbols of the alphabet is refused on the page at once, without a
  request.
- **Timeouts:** a request without an answer for 30 s ends with "The website did not
  answer. Please try again later."; an offer not confirmed within 2 minutes lapses.
  Both send `account.link_cancel`.
- **Attempts:** at most 5 link requests per character per 10 minutes (session state,
  so a relog resets it; the website limits on its own and never relies on this).
- **Character creation:** a character still being created cannot link; the page says
  so.
- **Page visibility:** the Account tab shows only while `grug_bridge` is active **and**
  the game holds a list (`accounts_version` > 0). The website sends a first list,
  empty if need be, as soon as it supports accounts (contract §3), so a release that
  ships before the platform side shows no tab that cannot work. Without the bridge,
  the stored list still grants its rewards.
- **Website address:** the page names `grudgelands.com/play` once, from one constant
  in `grug_accounts` (rulings 13 and 17). No setting.
- **Website text** (account names) is cleaned like every other website text: no
  escapes or control characters, at most 64 characters.
- **Logs:** a code or a password entry is never written to the server log. Requests,
  confirmations, bindings and password changes are logged at `action` level with name
  and account id.

### 3.2 The contract with the website

[web-accounts.md](../technical/web-accounts.md) is the contract (draft, agreed with
the user on 2026-11-15) and the website agent's brief. In short: the new capability
`accounts`, the request's `accounts_version` and `reward_catalog`, the online rows'
`character_id` and `account_id`, the response's complete `accounts` list (applied
before the commands), the events `account.link_request`, `account.link_confirm`,
`account.link_cancel` and the command `account.link_answer` with its refusal
reasons, the direct binding by password (§6a, website only), and the command
`account.set_password` with its capability `accounts.password` (§6b). Protocol 1
stays.

ACC builds the game side exactly to it. A lane that finds it must change stops and
reports: the change goes through the user, because the website builds on it. ACC adds
the capability and the new rows to `web-bridge.md` with a pointer to the contract.

### 3.3 The account API (`grug_accounts`, ACC owns it, PAGE and later phases read it)

- `enabled()` → bool: the bridge is active and a list was received (§3.1).
- `character_id(player)` → string.
- `account_of(name)` → nil or `{id, name}`: the counting binding (§3.1), for an
  offline name too, checked against the id index.
- `can_link(player)` → ok, reason: refuses a character in creation, one already
  linked, one without an id, or one over the attempt limit; the page shows the reason.
- `has_reward(name, reward_id)` → bool; `rewards_of(name)` → list of
  `{id, kind, name}` the catalogue knows, catalogue order.
- `register_reward(id, def)` at load time, `def = {kind, name, icon, hint,
  description?}` (`icon` a texture for the page row, `hint` the one line where to use
  it); `catalog()` → list. Only `id`, `kind` and `name` go to the website.
- `register_on_change(callback(names))`: the names whose binding or rewards changed
  (online or not), after a list was applied.
- The link flow, per online player:
  - `link_state(player)` → `{state, account_name?, message?, expires_at?}`, where
    `state` is `idle`, `checking`, `offer`, `confirming`, `linked` (the one-off
    success line, §3.1) or `refused`. Which answer is valid in which state is the
    contract's table (§5.4); anything else gets `invalid_args` and the request stays
    open; an answer for no open request gets `refused`
  - `request_link(player, text)` → ok, message; while a request is open it cancels
    that one first (`account.link_cancel`, contract §5.3)
  - `confirm_link(player)` and `cancel_link(player)` → ok, message
  - `register_on_link_state(callback(player))` so the page re-renders
- The bridge side: `attach(push_event)`, `apply_list(list)` → ok, `link_answer(args)`
  → code, message, `catalog_rows()`, `accounts_version()`. The bridge calls only
  these. The rules live in `grug_accounts`, in pure files a portable fixture loads.

`grug_accounts` depends on `grug_core` (the feed, the UI helpers), `grug_classes` and
`grug_factions` (the creation check), `sfinv` and `grug_inventory` (the page, which
lives in `grug_accounts/page.lua`). `grug_bridge` and `grug_achievements` depend on
it; `grug_inventory` must not, so there is no cycle. Without the bridge the mod loads,
keeps its stored list and sends nothing.

### 3.4 Shared files

- `grug_bridge/link.lua`, `init.lua`, `commands.lua`: ACC only.
- `grug_accounts/page.lua`: PAGE (written in wave 2 into ACC's mod; ACC leaves the
  file out and the `dofile` line in place).
- `grug_inventory/navigation.lua`: PAGE adds the one `captions` row for the tab,
  nothing else. The tab's place follows the registration order.
- `grug_achievements/` (catalog flag, the account cloak source, refresh on change):
  PAGE only.
- `tools/r691_bridge/` (portable test, scenario, fake bridge): ACC only.
- `docs/technical/web-bridge.md`: ACC (the amendment section and the tables).
- `docs/technical/module-guide.md`, `mod-map.md`, `grug_inventory/help.lua`,
  `docs/design/`: D only.
- `game.conf`, the upgrade declaration, `CHANGELOG.md`: root.

## 4. Lane goals

### ACC

- **The mod:** a new mod `mods/PLAYER/grug_accounts` with the API of §3.3 and the
  defaults of §3.1.
  - The model and the link state machine live in pure files, with every engine
    call injected, as `grug_bridge/link.lua` and `grug_housing/registry.lua` do.
  - The list is validated, persisted and indexed (name → binding, account →
    rewards) at load and on every apply. Account names, from the list and from
    `account_name`, are cleaned and cut to 64 characters.
  - Timeouts and the attempt limit run on injected clocks.
  - The id index, the id adoption, the notices and `grug_accounts:seen` (§3.1) are
    ACC's.
- **The bridge:** `grug_bridge` reports the capability, the catalogue (§3.2: once
  per boot until acknowledged, like the online list's flight bookkeeping) and
  `accounts_version`. It applies `accounts` before the commands, pushes the three
  events and runs `account.link_answer`, and answers `resync: ["reward_catalog"]` by
  sending the catalogue again (today `resync` handles only `"mail"`). The online
  rows get `character_id` and `account_id`.
- **`account.set_password`** (contract §6b), capability `accounts.password`:
  - it checks the entry's form by decoding and re-encoding both base64 parts (the
    text must come back unchanged; the verifier 1 to 256 bytes), as `valid_entry`
    in `tools/web_accounts/luanti_password.py` does
  - it checks the auth entry with `core.get_auth_handler().get_auth(name)` before
    writing and never writes when it is missing (`set_player_password` would create
    a login; `core.player_exists` looks at the player database, not the auth table)
  - it checks the counting binding for `account_id`
  - it writes the entry with `core.set_player_password`
  - an online character gets the feed line
  - the log line never holds the entry
  - its results are those of the contract
- **The contract docs:** the game side follows
  [web-accounts.md](../technical/web-accounts.md) exactly; `web-bridge.md` gets a dated
  amendment pointing to it and the new rows in its tables (capability, request and
  response fields, the `resync` value `"reward_catalog"`, events, command).
- **The fake bridge:** `tools/r691_bridge/fake_bridge.py` gets an accounts mode for
  the GUI test. It holds one or two test accounts, prints a fresh code on demand and
  answers requests by the contract (§3.2), including every refusal, the 10-minute
  validity and the reservation, with an optional delay so the waiting states can be
  seen. Options for the test: a shorter code validity (to reach `expired_code`), a
  lower account limit (`account_full`), a binding seeded on the website side that the
  game does not hold yet (`already_linked`). It takes stdin
  commands: `code <account>`, `grant <account> <reward>`, `revoke …`,
  `unlink <name>`, `rename <account> <name>`, `delete <account>`, and
  `bind <name> <account>` for a direct binding as the website makes it after a
  password check (contract §6a), and `setpw <name> <password>`, which sends
  `account.set_password` with an entry from `tools/web_accounts/luanti_password.py`
  `make_entry`. Usage goes in its docstring.
- **Fixtures:**
  - A focused portable fixture covers: list validation and versions, the
    character-id rule with all three index states and the adoption, an unlink,
    unknown reward ids, persistence across a reload, the binding and reward notices
    (also deferred by creation and after an offline change), code normalization,
    every state transition of the link flow including both timeouts, a cancel on leave and the attempt limit, stale and duplicate answers,
    and the change callbacks.
  - The bridge's portable test covers the request fields, the catalogue's
    resend-until-200 and its resync, the order list-then-commands, the command's
    argument checks and the per-state answer table, `account.set_password` (form,
    binding, results), and the events.
  - The engine scenario (`run.sh`) runs one link end to end against the fake
    bridge, and a restart that keeps the binding.

### PAGE

- **The Account page:** an inventory page **Account** (`sfinv.register_page`,
  `is_in_nav` = `grug_accounts.enabled()`), a view of §3.3 that decides nothing
  itself:
  - **Not linked:** two or three lines on what an account gives ("Rewards on your
    account reach all your characters.") and how to link: link on the website with
    the character's password, or create a code on the
    website (the address of §3.1), enter it here. Then a code field, **Link**, and
    the status line (refusal texts, timeout).
  - **Waiting** (ruling 14), after **Link** and after the confirmation: the page says
    plainly that the website is being asked, that this can take a few seconds and
    that the player should wait ("Checking your code with the website. This can take
    a few seconds, please wait."; "Linking your character. This can take a few
    seconds, please wait."). The buttons are disabled meanwhile, and the page changes
    by itself when the answer arrives.
  - **Offer:** "Link <character> to the website account <name>?", the warning "Only
    link to your own account. Only an administrator can undo a link.", **Link**
    (green) and **Cancel** (red), as the 0.72.2 buttons.
  - **Linked:** "Linked to the website account <name>.", and the rewards as rows
    (icon, name, kind, one line where to use it: "Choose it on the Character page.").
    Without rewards: "Your account has no rewards yet."
  - **During character creation:** one line saying the link comes after creation.
  - The page re-renders on `register_on_link_state` and `register_on_change`
    through the existing page refresh. The tab must fit the navigation bar beside
    every existing tab at the smallest and largest text size; if it does not, the
    lane stops and reports before changing the bar.
- **The Supporter Cloak:** the cloak catalogue gets a flag for account rewards (only
  `supporter` this round), and `grug_achievements` registers `cloak:<id>` for each
  flagged cloak.
  - The account's cloaks reach the pure functions in `grug_achievements/core.lua` as
    an injected set: `R.has_cloak` (the selection check, the appearance) **and**
    `R.unlocked` (the picker, `cloak_dropdown`, `choose_cloak_by_name`), which reads
    the stored cloaks directly today and does not call `has_cloak`.
  - Revoking the character-bound Supporter achievement (`R.revoke`, `apply_manual`)
    keeps a worn `supporter` cloak while the account still gives it.
  - On a change, affected online characters get their visuals re-applied and the
    Character page refreshed (the notices of §3.1 are ACC's).
  - The stored appearance follows, so the website's preview shows the cloak.
- **Screenshots** of every page state (desktop; the web build if possible), with a
  64-character account name, go to the user before the merge.

### D

- `docs/design/accounts.md`: what shipped, the defaults of §3.1, and a pointer to the
  concept.
- Mod-map rows for `grug_accounts`, `grug_bridge` and `grug_achievements`.
- The module guide's external player-meta table: `grug_accounts:character_id`.
- An Account paragraph in `grug_inventory/help.lua`.
- The completion notes and the GUI checklist below.

## 5. Rules

[Round workflow](../process/round-workflow.md), [AGENTS.md](../../AGENTS.md), Lua 5.1.
Focused fixtures per lane; the full fixture suite runs once at the round end, by the
coordinator. Maximum eight Lua processes across all agents. Headless runs only through
`tools/luanti_headless.sh`. No sync to Luanti and no push by any lane. The protocol
contract ([web-accounts.md](../technical/web-accounts.md)) binds the platform: a lane
that wants to change it stops and reports; the change goes through the user.

## 6. Verification and GUI checklist

**Code:** changed-file Lua check, the ACC fixture, the bridge's portable test and
engine scenario, the existing achievements and bridge fixtures, the full suite at the
round end, the upgrade declaration's self-test, a headless boot without bridge
settings (the mod inert, no tab).

**User GUI test** (desktop and web), with the fake bridge in accounts mode, two test
accounts and at least three characters:

1. Without the bridge settings: no Account tab; the game plays as before. With the
   bridge but before the fake bridge sent any list: no Account tab either.
2. With the bridge: every character has the Account tab. Not linked, it shows the
   explanation, the website address and the code field.
3. A code of the wrong length or with `0`, `O`, `I` or `1` is refused at once. The
   same code in lower case, with spaces or with the hyphen is accepted.
4. Each refusal the fake bridge can give (unknown, expired, used, account full,
   already linked) shows its own text.
5. After **Link** the page says it is asking the website and that this takes a few
   seconds (try it with the fake bridge's delay); the buttons wait, and the page
   changes by itself. A valid code then shows the confirmation with the account
   name. **Cancel** goes back, and the code still works afterwards. **Link** shows
   the waiting text again, then "Linked to the website account …" and "no rewards
   yet".
6. A character still in character creation cannot link; the page says why.
7. `grant <account> cloak:supporter`: the linked character gets the notice, the
   Supporter Cloak appears in the Character page's picker and can be worn (with its
   wings when the offhand look is on).
8. A second character linked to the same account has the cloak too; a character of
   the other account does not.
9. `revoke`: the worn cloak falls back to none, with the notice, and the picker no
   longer lists it. A character with the old character-bound Supporter achievement
   keeps its cloak through grant and revoke; and with the account reward granted,
   `/achievement revoke <name> supporter` keeps the worn cloak.
10. A restart keeps bindings and rewards. With the fake bridge stopped, rewards stay;
    a link attempt ends after about 30 s with "The website did not answer …".
11. `unlink <name>`: the page returns to "not linked", the account's rewards leave
    that character. `delete <account>`: every character of it is unlinked and plays
    on. `rename <account>`: the linked page shows the new name.
12. A sixth link request within 10 minutes is refused.
13. Logging out with an open offer cancels it, and the fake bridge sees
    `account.link_cancel`.
14. `bind <name> <account>` (a direct binding): the online character reads "This
    character is now linked to the website account …", the page shows it linked;
    `unlink` gives "… no longer linked …". With an open code request, the request
    ends. A character still in character creation is bound without disturbing it;
    its notices come after "Create character".
15. `setpw <name> <password>` for an offline character: the next login takes only
    the new password. For an online character: the feed line "Your password was
    changed on the website …", the session goes on, and the next login takes only
    the new password. For an unlinked character the fake bridge reports `refused`.
16. The fake bridge's online rows show `character_id` for every character and
    `account_id` for linked ones only.
17. The Account tab fits the navigation bar beside every other tab at the smallest and
    largest text size, desktop and web. A 64-character account name does not overflow
    the page.
18. No other player can see the account name anywhere: nametag, Social tab, clan and
    party lists, mail.
19. The server log shows link requests, bindings and password changes with name and
    account id, never a code or an entry.

## 7. Orchestration notes

- **Start:** on the user's go, from main at the last account planning commit. ACC first; PAGE's brief is
  written from §3.3 while ACC runs and starts after ACC's merge.
- **The platform:** the user hands [web-accounts.md](../technical/web-accounts.md) to
  the platform agent; nothing in this round waits for it. Once both sides exist, an
  end-to-end check on the rehearsal realm (contract §9: link by code and by password,
  grant, revoke, set a password, unlink, delete an account, restart) comes before the
  push.
- **Handover:** `~/projects/grudgelands-orchestration/r79/HANDOVER.md`.
- **Decided during the round:** the page's wording and layout from the screenshots
  (the user's iteration style: a first version, the user proposes fixes).
