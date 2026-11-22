# Round 86 — The account Claim Stone, home names, the claim preview, the Account page (0.86.0)

**Status: started on 2026-11-22 with the user's go** (after the plan review and the
user's answers, rulings 7–17). Version **0.86.0**, a
**map reset** (the lane ROADS changes world generation), which costs nothing: no world runs
0.85.0, and production (0.83.0) is upgraded once, to 0.86.0, with the map reset 0.85.0
already declares.

The round finishes what Round 85 started, as **one round of parallel lanes** (the user,
2026-11-22): the placement preview that Round 85 moved out (ruling 23 there), the housing
concept's Part B ([housing-rework-concept.md](housing-rework-concept.md) §3: the account
Claim Stone and home names) and the Account page "The Charter" with the website's list of
rewards every linked account gets. After it production is upgraded.

Preparation that exists: the concept's Part B rulings (§3.1, the user, 2026-11-21); the
claim record v3 with the empty fields `kind` and `name`, the mask's and the registry's
interface (Round 85 [Completion](round85-plan.md#completion-2026-11-22)); the Account page
mock-up "The Charter" (`tools/r84_account_mock/`, the user's pick,
[Round 84 plan](round84-plan.md)); the agreement with the website of 2026-11-22 on the
reward list (§3.3 below).

Not in this round: the soft map reset (concept Part C); account-bound chests or doors
(concept ruling 10); an account ban.

An independent Opus review of this plan (2026-11-22, verdict APPROVE AFTER FIXES: four
High, five Medium; orchestration `r86/reports/plan-review.md`, with the facts table, the 35
owner comparisons and the shared-file table the briefs take over) was checked by the
coordinator (the account id's characters, the list version rule, the clans' missing names
and the road's cut numbers against the code) and worked in. Its findings about the code are
starting points: every lane re-checks its own facts first.

Routing (as in Round 85, to be confirmed at the start): this session coordinates, Opus
implements and reviews, GPT-6.2 Astra only for art.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a ruling
  until the user says so; a coordinator default is marked as such.

## 1. Lanes and order

| Wave | Lane | What | Model | Needs |
|---|---|---|---|---|
| 0 | CONTRACT | The amendment to `docs/technical/web-accounts.md`: `default_rewards` and the capability `rewards.defaults` (docs only, by the coordinator, reviewed; goes to the website before it builds) | coordinator + Opus review | the user's go on this plan |
| 0 | BASE | The seams the parallel lanes build on, with no change a player sees: one owner function used by every place that compares a claim's owner with a player (about 35 places in 13 files), the name accessor, the set of stone items, the rename slot in the stone form, the Help heading for housing | Opus (STONE's implementer) | §3.2 settled in the brief |
| 1 | PREVIEW | With the Claim Stone in hand the minimap shows the chunk grid (allowed, forbidden, the player's chunk), the quota's red per chunk and why a chunk is forbidden; the stone's texts and Help describe the chunk rule | Opus | — |
| 1 | STONE | The account Claim Stone: the choice at the Housing Steward, one account claim per account and faction, members with owner rights, joining, leaving, belongings, losing the link | Opus | BASE |
| 1 | PACK | Belongings of an account claim: the packed containers' key for an account, a joining member's belongings moving over, the map-reset pass (`tools/migration`) reading v3 claims of both kinds | Opus | BASE |
| 1 | NAMES | Home names for every claim: rename, the default, where the name shows, the house icon, the admin reset | Opus (Astra: the icon) | BASE |
| 1 | ACCOUNT | The Account page "The Charter": the page before and after linking, the reward strip from `default_rewards`, the hint to click "Create Character" | Opus | CONTRACT |
| 1 | ROADS | Road cuts on steep hills end in a slope, not a wall; the fleet sees road cut walls | Opus | — |
| 1 | ART | The Claim Stone's new look: a block that reads as "home", in two variants (personal, account) told apart at a glance | GPT-6.2 Astra (Opus review) | — |
| 2 | D | Version, changelog, status, design documents, Completion | Opus | all above |

BASE is small and merges first (reviewed like any lane); CONTRACT, ROADS and ART do not
wait for it. All lanes of wave 1 then start together. The user sees pictures before a merge of PREVIEW (the
minimap in five situations, the stone form, Help), STONE (the Steward's choice, the stone
form of an account claim), NAMES (the rename field, the name with the house icon in the
three places) and ACCOUNT (the page unlinked, with a code, linked); ROADS shows before and
after profiles of the three known seeds; ART shows its drafts before anything is built
into the game.

## 2. Rulings

### 2.1 Carried over

1. Part B's eleven rulings (concept §3.1, the user, 2026-11-21) are this round's rules for
   STONE and NAMES, as written there.
2. The preview and texts (Round 85 plan §4 CLAIMUI, rulings 6 and 14–16 there): the preview
   never shows a chunk as allowed that placement refuses for the chunk's own sake.
3. The Account page takes the mock-up "The Charter"; the page adds the hint that the player
   must click "Create Character" on the website to generate the code (the user, 2026-11-21).
4. Which rewards every linked account gets is the owner's setting on the website; the game
   only displays what the website sends, also to an unlinked character (the user,
   2026-11-21).
5. 0.85.0 is not deployed on its own; production is upgraded after this round (the user,
   2026-11-22).
6. Standing rules: only the user pushes; a UI lane merges, even into the round branch, only
   after the user's go on its pictures; a fix delta with game logic gets an independent
   delta review; fixtures only targeted per lane, the full run once at the round's end.

### 2.2 New (the user, 2026-11-22)

7. **Road cut walls are fixed in this round** (the lane ROADS), while a map reset is still
   free. Round 85 carried over that a road's cut slope ends 24 nodes from the road, so on
   steep hills the cut ends in a wall of 10–31 nodes. The stop rule is ruling 17.
8. **A home's name:** letters, digits, space, apostrophe and hyphen, 1–24 characters, no
   leading or trailing space. (No word filter exists in the game: clans have no names. None
   is built; the admin reset of ruling 11 of the concept is the remedy. Coordinator
   default: "letters" are ASCII letters.)
9. **The protection hint** shows the home's name with the house icon instead of the owner;
   the owner's name stands on the stone's form.
10. **The account stone is its own item**, "Account Claim Stone", told apart from the
    personal stone at a glance by its colour.
11. **The Claim Stone gets a new look** (the lane ART, Astra): today's stone looks dull; it
    becomes a block that looks like "home". Both variants (personal, account) come from this
    rework.
12. **An account claim's default name** is "<character>'s Home" with the character that
    placed the stone, as for a personal claim; any member may rename it.
13. **The last member unlinks, or the account is deleted** (the user, 2026-11-22): the
    claim ends as `/claim_remove` does; its belongings stay stored for the account and
    faction and are there again when a character of that account joins a new account claim.
14. **Membership across a map reset** (the user, 2026-11-22): it survives; members get a
    stone at the Steward as today.
15. **"Your Home" is gone** (the user, 2026-11-22): the owner too reads the home's name
    with the icon.

16. **Only one account stone can be activated** (the user, 2026-11-22; concept ruling 5
    as written). Every member may place its account stone as a draft; the draft belongs to
    the character that placed it, protects nothing and crumbles after five minutes as
    every draft does. Activation makes it the account claim, so there are never two
    account claims of one account and faction. At the activation every other draft of
    that account and faction is removed at once (its block is loaded for that, as for an
    expired draft), and an account stone still in a member's inventory vanishes when they
    try to place it, with a line that the home already stands.
17. **ROADS changes only the cut's cross-section** (the user, 2026-11-22): its reach and
    its shape (terraces), never the route's planning. The user is preparing a separate
    rework of how roads are planned (local changes staying local); a wall that only a
    different route could remove is reported and waits for that rework.

### 2.3 Coordinator defaults on smaller points (the user may overrule)

- Smaller defaults: an admin's faction change of a member counts as leaving; the default
  name is stored at placement, and the admin reset of an account claim's name uses the
  first member; a name may equal a place's or another home's; `/claim_remove <member>`
  removes the account claim; NAMES may change `grug_core/flash.lua` so the protection hint
  carries the icon.

### 2.4 During the round

(empty)

## 3. Shared conventions

### 3.1 Coordinator defaults (the user may overrule)

- **The account claim's owner never looks like a player name.** Account ids and player
  names use the same characters (`grug_accounts/model.lua`), so the claim record's owner
  field of an account claim is a text no name can be: `account:<account id>:<faction>`,
  with `kind = account`. A place that still compares it with a player name then fails
  closed. Belongings of an account claim get their own key form (today's keys parse only
  player names).
- **Membership is stored per character** (the player record's state names the account
  claim), never as a list in the claim that can go stale. The housing code gets no event
  that names the old account when a character is unlinked or deleted or an account is
  deleted (the binding is forgotten first), so the member's record holds what is needed,
  and housing reconciles members against the bindings at load and when the list changes.
- **Rights are asked through one function** ("is this character an owner of this claim");
  BASE moves every comparison to it before the other lanes start.
- An account's binding is read from the game's stored copy of the website's list
  (`grug_accounts`), offline characters included; no new request to the website.
- Numbers and layouts on the pages are rough targets; no gate is built around them.

### 3.2 Settled before the lanes start (by the coordinator, in the briefs)

- The owner text and the `kind` values, the member state and what it stores, the account
  belongings' key form (above), written into BASE's brief and every later brief.
- **File ownership by function, not by file** (the review's §2b lists every shared file:
  `grug_housing/api.lua`, `manager.lua` (the Steward's dialogue), `interface.lua`,
  `admin.lua`, `interaction.lua`, `stone.lua`, `stone_form.lua`, `registry.lua`,
  `recovered.lua`, `packed.lua`, `tools/migration/pack.py`, `grug_home/claim_home.lua`,
  `grug_map` (the claim mode, the location line and window), `grug_core/flash.lua`,
  `grug_inventory/help.lua`, `docs/design/housing.md`, `world_map.md`, and the fixtures
  that pin texts: `r25_interfaces`, `r25_interaction`, `r502_home`, `r691_bridge`):
  - BASE: the owner function and its callers, the name accessor (`name_of`, returning the
    default), the stone item set, an empty rename slot in the stone form, the housing
    heading in Help.
  - STONE: ownership and membership, the Steward's dialogue, the stone form's logic and
    layout, the admin commands' behaviour for account claims.
  - PACK: `packed.lua`, `recovered.lua`, `tools/migration/`; nothing else.
  - NAMES: `set_name`, the rename row in BASE's slot, every place a name shows (the
    location line, the banner, the Map tab, the protection hint in `flash.lua`), the admin
    reset.
  - PREVIEW: `grug_map`'s claim mode and the texts about the chunk rule and the quota (item
    text, the stone form's explanatory texts, its Help paragraph).
  - ART: the stone's art files and the node's drawing, after STONE's merge. Technical rules
    for Astra: the six node names stay, everything fits inside one node (the arrival cube),
    16 px textures, the flat `STONE_TEXTURE` stays for icons and the minimap, the draft
    stays half-transparent; the house icon of NAMES comes from the same Astra run. If ART
    is not accepted in time, the round ships the tinted stone and ART follows as 0.86.x.
- Merge order: BASE; then STONE, PACK, NAMES, PREVIEW, ACCOUNT, ART, ROADS; the round
  branch is merged into each later lane before its review where a shared file changed.

### 3.3 The website's reward list (agreed on 2026-11-22)

`default_rewards`, a list of reward ids, inside the `accounts` object of the `sync`
response, sent only to realms that report the capability `rewards.defaults`. An empty list
means no strip; the list is sorted by id; the game skips ids it does not know; it is display
only and grants nothing. The game ignores a list whose version it already has
(`grug_accounts/model.lua`) and today drops fields it does not know, so the amendment also
says how the list arrives the first time after the game's upgrade and after the owner
changes the setting (a change of the defaults raises the list's version; the game asks for
a resend when it newly reports the capability). The label of the website's button
("Create Character") comes from the website, not from the game's documents. CONTRACT writes this into `docs/technical/web-accounts.md` (§8 and
the protocol sections) before the website builds it.

### 3.4 Release

0.86.0, **map reset** (ROADS): "0.86.0" is added to `map_reset` only if ROADS merges. The claims lanes on their
own would be compatible with 0.85.0 (a new state in the player record and the two record
fields in use); STONE's report still says exactly which saved keys change. Production's path from 0.83.0 is one map reset; the pass must still read
0.83.0's v2 claims (Round 85's RESET) and, new, v3 claims of both kinds (PACK). A change
under `tools/migration/` runs every declared step's test in the `debian:trixie` container
(round workflow §3).

## 4. Lane goals

### CONTRACT

The contract text for `default_rewards` and `rewards.defaults` as §3.3, with what the game
does on a missing field, an unknown id, an empty list and a website that does not know the
capability; the test steps of §9 extended. Docs only; the final text goes to the website
through the user.

### BASE

No player sees a difference. Every place that compares a claim's owner with a player name
asks one function instead; a claim's name is read through one accessor that returns the
default; the stone items are one set every reader uses; the stone form has a slot for the
rename row; Help has a housing heading. The fixtures that pin today's behaviour stay green
unchanged. The report lists every place moved (the review counted 35 in 13 files) and every
place deliberately left.

### PREVIEW

With the Claim Stone in hand the minimap shows, per map chunk, whether a stone can be
placed there, and marks the chunk the player stands in; the quota's red is per chunk and
follows every placement and removal; the player can tell why the chunk they stand in is
forbidden before wasting a placement; a failed mask shows nothing allowed and says so. The
item text, the stone form's texts and Help describe the chunk claim, the rules and the
quota in the player's words. What the preview shows as allowed is never refused for the
chunk's own sake. With STONE in the round: the preview is the same for both kinds of stone.
(The lane brief written for Round 85 is the starting material.)

### STONE

Concept §3.1 rulings 1–10: at the Housing Steward every character from level 20 chooses a
personal or the account Claim Stone, with an explanation of both and, without an account,
where to get one; one account claim per account and faction; only a character without an
active stone may choose; every member has full owner rights, same-account characters with a
personal stone have none; joining a standing claim gives no item, before it stands every
joining member gets a stone and only one can be activated (ruling 16); leaving only at the Steward and
never as the last member; a joining character's packed belongings move to the account
claim's, one way; an unlinked character falls back to "personal, no stone", a deleted
account ends its claims, and a claim with no owner left ends. Travel stays "Set as home"
per character. No exploit by joining and leaving (items, a second claim, a free stone, the
quota). The states a player can reach are listed in the report as a table, each with what
the player sees.

### PACK

An account claim's belongings: where the packed containers of an account claim are stored
(a key no player name can collide with), a joining member's personal belongings moving
into the account's (one way, concept ruling 7), the Belongings tab showing them to every
member, what stays when the claim ends (ruling 13), and the map-reset pass packing an account
claim's containers for the account. Nothing is lost or duplicated by joining, leaving,
unlinking or a reset; the report shows each path.

### NAMES

Concept §3.1 ruling 11: the owner (for an account claim: any member) renames the home, at
most 24 characters by ruling 8; the default name; the name with a house icon in the
line under the minimap, the entry banner and the Map tab's location line; an admin command
resets a name. A name can never be mistaken for a place of the world and never breaks a
form or a HUD line (formspec and colour escapes, width).

### ACCOUNT

The inventory's Account page as "The Charter": before linking, what an account gives (the
reward strip from the website's list, each reward with its name and icon from the game's
catalogue), the address, the steps including "Create Character", and the code field; after
linking, the account and its rewards with a hint how to use each. The capability is
reported; a realm whose website sends no list shows no strip and nothing else changes. The
fake bridge (`tools/r691_bridge`) plays the new field.

### ROADS

A road's cut into a hill ends in a slope a player can read as a bank, not in a wall at the
side zone's edge, on every seed of the fleet (the cut's rock part is already 2 per node: a
steeper slope would be a cliff, so the answer is reach or terracing, not steepness and,
by ruling 17, not the route); the seed fleet reports a road cut wall as it
reports the arena's grade today. Measure first: a census of walls over the fleet's seeds (how many, how
high, where; near the arena's legs and elsewhere), then the smallest change of the side slope's rule that removes
them; the stop rule of ruling 17. Roads on production's seed change as little as the rule allows;
the report says what moved (production's road raster compared before and after), and whether
world generation got slower or placement content moved, since a cut column counts as road
corridor and keeps points of interest, vegetation and spawns off it.

### ART

A Claim Stone that looks like the heart of a home rather than a plain block: one design in
two variants, the personal stone and the account stone, which a player tells apart at a
glance (ruling 10) in the hand, in the inventory and standing in the world; readable at
icon size; its states (a draft, active, expired) still readable if the shipped stone shows
them. Astra gets the goal, every element the stone has today and the technical rules (node
box or mesh limits, texture sizes, the shipped palette), not a list of allowed shapes.
Drafts go to the user as pictures first; only the picked design is built. No new sound.

### D

Version 0.86.0, the upgrade declaration, changelog, status, the design documents the lanes
left, this plan's Completion and Carry-overs, the concept's Part B marked as built.

## 5. Rules

- AGENTS.md and the round workflow apply; the faction names, "Expedition" and the naming
  rule hold in briefs and pages too.
- Fixtures: a lane runs only the fixtures its change touches; the one full run is the
  coordinator's at the round end.
- A fix delta that changes game logic gets an independent delta review.
- PREVIEW, STONE, NAMES, ACCOUNT and ART are merged only after the user's explicit go on
  their pictures; ROADS after the user saw its profiles.
- Engine boots stay few and short; each brief names its lane's number of boots.
- A lane that adds a rule every seed must meet (ROADS) runs the seed fleet `full` before
  its merge, not `quick` (Round 85: the one failing seed was number 115 of the list).

## 6. Verification and human tests

Per lane the gates of round workflow §3 and its own fixtures. STONE: a fixture over the
whole state table (two accounts, two factions, joining, leaving, unlinking, deletion, the
last member, the map-reset pass on an account claim). PACK: every path of the belongings, and the
container run of the migration tests. PREVIEW: the overlay's answer per
chunk equals placement's for every reason and the quota. ACCOUNT: the fake bridge with and
without the field. At the round end the full gates, the seed fleet `full`, and one headless boot.

Assumptions the lanes check first: that the game's stored copy of the website's list
answers "which account does this offline character belong to" at every moment the housing
code asks; that every owner check can go through one function without a per-tick cost; that
the minimap's claim mode can draw per-chunk states within its packet and texture budget.

Human-test proposals (offers): two characters of one account choose the account stone,
one places it, the other fuels it and sets it as home; a third character with a personal
stone tries to open a chest there; rename a home and walk in and out; hold the stone at a
road, in a capital ring and at a full quota; open the Account page unlinked and linked on
the rehearsal realm, with the website's list set and empty.

## 7. Orchestration notes

- **Start state:** main at 0.85.0 (`round-85`); the round branch `round86` holds this plan.
- **Before wave 1:** CONTRACT; §3.2 settled in the briefs; BASE built, reviewed and merged.
- **The website:** CONTRACT's text goes to the kaesual coordinator through the user; the
  game's side is testable without the website (the fake bridge).
- **Process budget:** at most eight Lua processes; ROADS' fleet runs share the queue.
- **Compaction checkpoints:** C0 before the start (after this plan and its review); C1 when
  wave 1's lanes have reported and the pictures are with the user; C2 before D and the
  round-end run.
