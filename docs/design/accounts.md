# Website accounts

Decided 2026-11-14 and 2026-11-15 (the user's rulings); phase 1 implemented in
Round 79, version 0.79.0 (`grug_accounts`, the bridge side in `grug_bridge`,
the account cloak in `grug_achievements`). Provenance:
[Round 79 plan](../planning/round79-plan.md) §2 (rulings), §3.1 (coordinator
defaults, built as written below; the user may overrule them) and its
completion. The long-term model and the later phases:
[accounts-concept.md](../planning/accounts-concept.md). The protocol with the
website (fields, events, answers, refusal reasons, the password check):
[web-accounts.md](../technical/web-accounts.md), the contract the website
builds on; it is not repeated here.

## Rulings

1. **Accounts are optional and on top.** A character without an account plays
   exactly as before; linking only adds. Multiboxing stays allowed; there is no
   session takeover.
2. **The website is the source of truth** for accounts, bindings and rewards.
   The game keeps the website's list and never writes a binding itself.
3. **Linking** works two ways: **by code** (the website creates a code, the
   player enters it on the in-game Account page and confirms; only an online
   character) and **by password** on the website (the website checks the
   character's password and binds it itself; the game only receives the list).
4. **A link code** has 10 characters, upper-case letters and digits without
   `0`, `O`, `I` and `1`, and is valid for 10 minutes.
5. **At most 10 characters per account** per realm, a rule of the website.
   Bindings, codes and the list are per realm; accounts and rewards are global.
6. **Only an administrator unlinks**, on the website. Deleting an account
   unlinks its characters; they stay and play on.
7. **Rewards are account-bound:** granted by the administrator per account on
   the website, available to every character of the account. The first is the
   **Supporter Cloak**.
8. **The account name is never shown to other players:** only on the
   account's own characters' Account page and feed lines.
9. **The website can set a linked character's password** (online or offline).
   The in-game password change stays allowed for linked characters.
10. **Unchanged in phase 1:** Claim Stones, character deletion and bans. No
    grace period after linking, no address setting.
11. **The website's address** shown in the game is `grudgelands.com/play`.

The user's choices during Round 79 (2026-11-15), on the screenshots:

- A character still in **character creation** sees only one line on the
  Account page ("Finish creating your character first. You can link it
  afterwards."), no code field and no Link button.
- A **re-granted** account cloak is worn again: the character's cloak choice
  is kept when the account loses the cloak, so a later grant puts it back on.
- **The tab's place** follows the inventory's registration order (after
  Admin Mail, before Creative) and stays there.

## For a player

- **The Account tab** (title "Website Account", caption "Account") shows only
  on a realm whose website supports accounts: the bridge is active and the
  game has received the website's first list. It appears at the inventory
  window's next build after that list. Without it nothing changes.
- **Not linked:** the page says what an account gives ("Rewards on your
  website account reach all your characters."), how to link (sign in on
  `grudgelands.com/play`, link there with the character's name and password,
  or create a code there and enter it here), the code field and **Link**.
  Lower case, spaces and the hyphen are accepted; a code that is not 10
  symbols of the alphabet is refused at once, without asking the website.
- **Waiting:** after Link and after the confirmation the page says that the
  website is being asked, that this can take a few seconds and that the player
  should wait. The buttons are shown inert; the page changes by itself when
  the answer arrives. Without an answer for 30 s: "The website did not
  answer. Please try again later."
- **The offer:** "Link <character> to the website account <name>?", the
  warning "Only link to your own account. Only an administrator can undo a
  link.", a green **Link** and a red **Cancel**. An offer not confirmed within
  2 minutes lapses; logging out cancels it.
- **Refusals** each have their own line (unknown, expired or used code, an
  account with 10 characters, a character already linked, too many attempts).
  At most 5 link requests per character in 10 minutes (reset by a relog; the
  website limits on its own as well).
- **Linked:** "Linked to the website account <name>." and the account's
  rewards as rows (icon, name, kind and where to use it), or "Your account has
  no rewards yet."
- **Notices** in the message feed, each once: "This character is now linked
  to the website account <name>." (a binding by password, or one made while
  the character was offline), "This character is no longer linked to a website
  account.", "Your account gives you: Supporter Cloak." and "Your account no
  longer gives you: Supporter Cloak.". A change made while the character was
  offline or in character creation is reported at the next join or after
  "Create character". A link by code shows its own success line instead of
  the "now linked" line.
- **The Supporter Cloak** as an account reward appears in the Character
  page's cloak picker of every linked character while the account holds it.
  When the account loses it, a worn one falls back to no cloak. The
  character-bound Supporter achievement (granted with `/achievement`) and its
  cloak stay exactly as they are; a character may own the cloak both ways, and
  revoking the achievement keeps the cloak while the account still gives it.
- **A password set on the website** applies from the next login; an online
  character reads "Your password was changed on the website. It applies from
  your next login." and plays on.

## For an administrator

- **On the website:** create codes, grant and remove rewards per account (from
  the catalogue the game reports), unlink a character, rename or delete an
  account, set a linked character's password. Every change reaches the game as
  a new list; the game applies any list whose version differs.
- **In the game** there is nothing to set up beyond the
  [bridge's settings](../technical/web-bridge.md#settings). Without the bridge
  the mod loads, keeps its stored list, still grants its rewards and shows no
  tab.
- **The server log** shows link requests, confirmations, bindings and password
  changes with the character's name and the account id, never a code or a
  password entry.
- **Testing without the website:** `tools/r691_bridge/fake_bridge.py
  --accounts` plays the website's part (usage in its docstring).

## Defaults (coordinator, Round 79 plan §3.1)

- **Character id:** every character gets 32 lower-case hex digits at its first
  join with 0.79.0 (also during character creation), never changed. A
  binding counts only for the character id it names; the game keeps its own
  index of name to id, so this also holds for offline characters. The index's
  three states and the adoption of a binding's id are the contract's (§2).
- **The list** is stored by the game and applied at load, so rewards hold
  while the bridge is down and across restarts. A lower version is applied
  too (a restored website backup); malformed rows are dropped and logged.
- **Linked or not** comes from the list only. A binding that appears for a
  character with an open request ends that request.
- **Rewards are read live** and never copied into the character's data.
- **During character creation** a binding counts, but notices and the cloak
  wait until the creation is finished; the character cannot link by code.
- **Account names** from the website are cleaned like every website text and
  cut to 64 characters.
- **Online rows** carry the character id, and the account id for a linked
  character; a binding change resends them.

## Later phases

Phase 2 (a cloak and an emote for every website user), more Supporter content,
account bans, characters created through a bridge command, character deletion
and the shared Claim Stone are the
[concept's](../planning/accounts-concept.md) §4–§5; each comes with its own
amendment to the [contract](../technical/web-accounts.md#10-outlook-later-amendments).
