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

18. **A list change never removes a home at once** (the user, 2026-11-22; from STONE's
    review). The game learns of an unlink or a deleted account only through the website's
    list, so one faulty list (a malformed account row, an empty list, a restored backup)
    would end account claims with their stone and fuel for good. An account claim that
    loses its last member **through a list change** therefore stays, ownerless, and is
    treated like any claim whose owner stopped fuelling (the user, 2026-11-22, from
    GUARD's review): a list change never removes it, fuelled or empty; it protects while
    its fuel lasts and then becomes the empty stone, which anyone with a pick may dig as
    today; a character of that account and faction that is linked again may join it and
    refuel it. This narrows
    ruling 13 to the paths the game is told directly: a character deleted by command and
    the last member's own choice end the claim as before.
19. **The pictures** (the user, 2026-11-22): the Claim Stone becomes the artist's design
    "Under One Roof"; the Account page is accepted as built (no line for "no rewards");
    the preview's line gets a dark box and stays left of the minimap; the home-name icon
    is the shipped cottage (`grug_map_home.png`), not a new one; STONE's pictures are
    accepted. ROADS builds the fading cut (ruling 17 holds: the route is not touched).
20. **The stone in the game** (the user, 2026-11-22, on the in-game pictures): accepted
    as built (a house of half a node's height that turns its door to the placer). The
    map's marker stays the shipped claim icon. **Only the fuelled stone gives light,
    level 8**; an empty stone and a draft give none.
21. **The road cut as built** (the user, 2026-11-22): the cut fades to the natural ground
    at the side zone's edge, and its face rises at most a quarter of the squared distance
    from the road's edge above the old slope, so a deep cut gets no ledge beside the road
    (the lane's own bound, confirmed). What it leaves, a rock face as steep as the
    hillside, waits for the road-planning rework (ruling 17).

### 2.3 Coordinator defaults on smaller points (the user may overrule)

- Smaller defaults: an admin's faction change of a member counts as leaving; the default
  name is stored at placement, and the admin reset of an account claim's name uses the
  first member; a name may equal a place's or another home's; `/claim_remove <member>`
  removes the account claim; NAMES may change `grug_core/flash.lua` so the protection hint
  carries the icon.

### 2.4 During the round

Rulings 13–17 came with the user's go at the start, rulings 18–21 during the round
(all 2026-11-22, §2.2).

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
    16 px textures, the draft stays half-transparent *(corrected at the round's end: the
    earlier text said the flat `STONE_TEXTURE` stays for icons and the minimap; the map and
    the minimap draw their own claim icon `grug_map_claim.png`, ruling 20, and
    `STONE_TEXTURE` is the fuelled stone's front tile, which only names the stone in the
    claim's waypoint row)*; the house icon of NAMES comes from the same Astra run (by
    ruling 19 the shipped cottage instead). If ART
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

## Completion (2026-11-22)

Eleven lanes in three waves, each independently reviewed or, for display-only fix deltas,
checked by the coordinator: CONTRACT (the coordinator, Opus review), BASE, PREVIEW, STONE,
PACK, NAMES, ACCOUNT, ROADS (Opus each), ART (GPT-6.2 Astra's design and art, Opus wiring),
and two lanes added during the round, GUARD (ruling 18) and FORMFIX (the stone form at GUI
scaling 1.5), then lane D. Release **0.86.0**, a **map reset** (the twenty-first;
`tools/web_data/upgrade.json`, no step, `map_reset_pass` stays 0.50.0), because ROADS
changes world generation; every other lane is compatible with a 0.85.0 world. Production
(0.83.0) goes to 0.86.0 in one step with one map reset, which covers 0.85.0's (ruling 5).
Merge order into `round86`: CONTRACT, BASE, ACCOUNT, PACK, STONE, PREVIEW, NAMES, GUARD,
ART, FORMFIX, ROADS, then lane D.

**Saved keys** (the upgrade contract's map-reset table has a line for each):
`grug_housing` `claim:<id>` stays v3, with `kind` (`account` for an account claim, whose
owner is `account:<account id>:<faction>`) and `name` (the home's name, written at
placement) in use; `player:<name>` gains the member state `v2|member|<owner text>`, kept at
a map reset (ruling 14); an account claim's belongings are stored under
`recovered:account:<id>:<faction>:<seq>:<n>[.<k>]` and `packed:account:…`, which the
player-key pattern cannot read; `grug_home` `claim_lost:<name>` is written per member, with
the new events `left`, `unlinked` and `faction`; `grug_accounts`' stored `list` gains
`default_rewards` (the game reports `accounts_version` 0 until a list was stored under the
capability `rewards.defaults`); the item meta `ref` of a packed container moves with a
joining member's belongings; new item and node names `grug_housing:account_stone`,
`_empty` and `_draft`; the six stone nodes are node boxes with `paramtype2 = "4dir"`.

**What shipped:**

- **CONTRACT:** the amendment to [web-accounts.md](../technical/web-accounts.md) (§5, §5.1,
  §5.2, §8, §9 step 8): `default_rewards` inside the `sync` response's `accounts` object,
  only for a realm reporting `rewards.defaults`; display only; an empty list, `null` and a
  missing field alike; unknown ids kept but not shown; the first four known ids in the
  order sent; the resend after the upgrade (the game reports 0 and then applies the next
  list whatever its version). Sent to the website through the user.
- **BASE:** the seams the parallel lanes built on, with no change a player sees: one owner
  question `is_owner(claim, name)` (9 direct owner comparisons in 7 files moved; the
  review's 35 places in 13 files were mostly record lookups, notices and logs, each listed
  as moved or deliberately left), `account_owner_of`, `home_name`, the stone item and node
  sets `STONE_ITEMS`/`STONE_KINDS`, the rename slot in the stone form, `create(…, kind)`
  with `placement_name`, the belongings seam `recovered.holder`/`move_to_account`, and
  Help's "Housing" heading ([module guide](../technical/modules/player-systems.md#housing)
  "Seams"). Twelve fixtures green, one pin rewritten where the owner comparison it pinned
  had moved.
- **PREVIEW:** the placement preview by map chunk (the known defect of 0.85.0): the minimap
  in claim mode draws every chunk that placement refuses for the chunk's own sake in red, a
  faint grid, the claims' frames and the player's chunk in green; a line left of the
  minimap on a dark box (58 % of the "Now playing" grey, after two fix rounds) names the
  reason for the chunk the player stands in; the quota's red per chunk; a failed mask shows
  every chunk red. One pure function (`grug_housing/preview.lua`) answers both the preview
  and placement's chunk steps, which the fixture `tools/r86_preview` compares on 13 × 13
  chunks for both factions at the start, after placements, at full quota and after a
  removal. The per-column overlay baked into the map base is gone (about 26 KB less
  download, no 5 MB overlay decode on the client). Cost, `bench_claim.lua` with a
  worst-case stand-in mask: packets per second unchanged, bytes in claim mode about doubled
  (328 → 702 bytes/s walking, 1027 → 2158 flying; texture string 168 → 911 characters on
  average), per-step time within the noise; on the production seed 554–768 characters.
  The item text, the Steward, the draft form and Help describe the chunk rule. Five
  capture boots on the production seed.
- **STONE:** the account Claim Stone (concept §3.1 rulings 1–10, plan rulings 10, 13, 14,
  16): the Steward's two columns, one account claim per account and faction, members with
  full owner rights, drafts per member with exclusive activation, joining with no item,
  leaving only at the Steward and never as the last member, the reconcile against the
  website's list at load, at every list change, at a join, at the Steward and before
  placing or activating, a faction change by an admin as leaving, notices to every member,
  "Set as home" per member. New `grug_housing/account.lua`; fixture `tools/r86_stone` (the
  state table, 165 checks after fix round 1, 200 after GUARD). Three capture boots.
- **GUARD** (ruling 18): an account claim whose last member goes through the website's
  list stands ownerless (derived from the records, nothing stored), fuelled or empty, as
  any unfuelled claim: it protects while its fuel lasts, nobody can refuel it, then it is
  the empty stone any pick digs; a relinked character of that account and faction joins
  it and may refuel it, and hears of it at its login when it could join; no binding is
  checked while the game holds no list at all (`grug_accounts.held_version`). The paths
  the game is told directly (a deletion, an admin's faction change, a pick-up,
  `/claim_remove`) end it at once.
- **PACK:** the belongings of an account claim: the key forms above; a joining member's
  own belongings move to the account's, one way, contents and the carried item's `ref`
  with them, at the join and at every login of a member with entries of its own (the
  map-reset pass packs an account stone's draft under its placer); every member's
  Belongings tab shows and takes from the account's, a take by one redraws the others'; a
  deletion takes only the character's own keys; the map-reset pass packs an account
  claim's containers under its owner text and refuses, before any write, a claim whose
  owner is neither form. v2 and personal v3 output byte-identical
  (`tools/r85_reset/diff_v2.py`, 7 runs), `test_pack.py` 38 OK, the trixie container test
  OK. Fixture `tools/r86_pack`.
- **NAMES:** home names for every claim (concept ruling 11, plan rulings 8, 9, 12, 15): the
  default "<character>'s Home" stored at placement, the rename row on the stone form
  (1–24 ASCII letters, digits, space, apostrophe, hyphen; checked again on storing), the
  name with the house icon in the banner, the line under the minimap, the Map tab's line
  and the protection hint ("<home name> – protected"), "Your Home" gone, an account
  claim's default from its first member by name and never its owner text,
  `/claim_name_reset <player> | here`. The icon is the shipped cottage
  `grug_map_home.png` (ruling 19), placed beside the HUD text from a width estimated with
  the client font's glyph widths (`grug_core.hud_layout`); icon 1.2 em with a 0.4 em gap,
  a banner wider than 0.6 of the window drawn smaller. Fixture
  `tools/r86_names` (109 checks after fix round 1). Three capture boots.
- **ACCOUNT:** the Account page "The Charter" (ruling 3, the mock-up of Round 84): the
  framed panel with the crest and "Every linked account gets" with up to four rewards of
  the website's `default_rewards` (`DEFAULTS_SHOWN`), the three steps with "Create
  Character" (one constant, `grug_accounts.CODE_BUTTON`), the code field, the offer page,
  the linked page with "Your rewards" (up to 18 fit, the catalogue has 8); the capability
  `rewards.defaults`; a change of the defaults redraws every open page; the fake bridge
  `tools/r691_bridge` plays the field. Help's website-account paragraph no longer says
  every account gets Cheer (ruling 4). Fixture `tools/r86_account` (126 checks). Two capture boots.
- **ART:** the Claim Stone's new look, the artist's design "Under One Roof" (ruling 19,
  picked from three drafts): a small house in a node box (`grug_housing/stone_art.lua`),
  one terracotta gable with a chimney for the personal stone, two slate gables for the
  account stone, shuttered windows when empty, the draft pale and half-transparent; the
  door turns toward the placer (`4dir`); one selection box around the house; only the
  fuelled stone gives light, level 8 (ruling 20; before 4, the draft 2); the map's marker
  stays the claim icon. Fixture `tools/r86_art` (382 checks); three capture boots.
- **FORMFIX:** at GUI scaling 1.5 on 1600 × 900 the fuel panel scrolled and "Home name" ran
  under the icon (the client shrinks the form's units, not its fonts); the panel's texts
  now use `grug_core.ui.text_scale`. Two capture boots; display only, checked by the
  coordinator.
- **ROADS:** road cuts fade to the natural ground (rulings 7, 17, 21). The census of the
  304 fleet seeds under the old rule: 301 seeds with cut walls, 2,331 walls (1,257 of 10
  nodes or more, 249 of 30 or more, the highest 134), production's seed four (33, 18, 11,
  10). Built: the cut meets the ground at the side zone's edge (a cut is never deeper
  than its distance to that edge, `CUT_FADE = 1`, except where the lift bound is lower:
  the face rises at most 0.25 e² above the old slope, `CUT_FADE_LIFT`, e the distance
  from the road's edge), so a deep cut keeps no ledge beside the road; on the 48-seed
  sample the largest step beside the road is 6, and where the lift bound binds the face
  rises up to about 0.5 e + 2 per node (12–13 per node 12–14 nodes out on
  5664044364126834037). The seed fleet
  fails a seed whose cut adds more than 2 to the step at a side zone's edge (`road_cut`,
  capitals' protected cities exempt) and reports `road_face` (report only). Production:
  of 3,432,875 columns 682 rise, by up to 32, none goes down, 663 of them within 48 nodes
  of the four walls; no point of interest, village, camp, leader or quest place moved, the
  claim mask identical (366 / 373); five spawn cells change their mean height (up to 2.5),
  26 decorations move up with the ground and 3 new ones stand on the uncovered face. The
  sampler's walk +1–5 %. Seed fleet `full`: **304 of 304 seeds on the final rule**
  (38 min 7 s; `road_cut` 2 on 301 seeds, 1 on 3); nothing under world generation changed
  after it. Two engine boots (production, before and after). Fixture `tools/r86_roads`.
- **Lane D:** version, changelog, upgrade declaration and its history entry, the contract's
  map-reset table, this section, STATUS, README, ROADMAP and BACKLOG lines, the concept's
  Part B and preview marked as built, and the texts the lanes left stale (the account
  draft's node, a member's travel home and waypoint, the contract's shared-stone lines,
  the Account page's Check code, the minimap layer order, §3.2's sentence on
  `STONE_TEXTURE`).

**Reviews:** plan review APPROVE AFTER FIXES (four High, five Medium, worked in). CONTRACT
MERGE AFTER FIXES (F1 the resend loop, F2 the reported version apart from the held one,
F3–F5 wording; fixed in the text). BASE MERGE AFTER FIXES (four seam shapes: the rename
row's height, the rename hook, `create`'s kind with the default-name function,
`move_to_account`'s owner text; fix round 1 checked by the coordinator: identical output).
ACCOUNT MERGE (one Low, the clipped status line; fixed, display only, checked by the
coordinator). PACK MERGE AFTER FIXES (Critical: a join could reuse the number of a carried
packed item's content row and overwrite it; fix round 1, delta review MERGE). STONE MERGE
(no exploit found; Low: the minimap frames after a join, a silent faction change, a
member's old permission entry, owner-text leaks in texts, the fuel lines' overlap; fix
round 1, delta review MERGE). PREVIEW MERGE (L1 the probe's receipts, L2 the taken line's
wording; fix rounds 1 and 2, display and text only, checked by the coordinator). NAMES
MERGE (Low 1 an unchanged default refused, Low 2 a literal "<" in Help; fix rounds 1 and 2,
delta review MERGE). GUARD MERGE AFTER FIXES (Medium: an empty account claim was still
removed at once by a faulty list; fix round 1, delta review MERGE AFTER ONE SMALL FIX, the
login notice only when the join is allowed, applied as written). ART MERGE (the selection
box, two stale texts; fix round 1 checked by the coordinator). FORMFIX: display only,
checked by the coordinator on its pictures. ROADS MERGE (three Low: the edge-only check,
the docs overstating the bank, the exemption's reach; fix round 1, no world-generation
change).

**The user's choices during the round:** the four open questions answered at the start
(rulings 13–15: the claim ends when the last member unlinks or the account is deleted, its
belongings staying the account's; membership survives a map reset; "Your Home" is gone);
only one account stone can be activated, drafts per member (ruling 16); ROADS changes only
the cut's cross-section, never the route (ruling 17); a list change never removes a home,
an ownerless account claim behaves as any unfuelled claim (ruling 18, with the
coordinator's empty-stone reading confirmed); the pictures: "Under One Roof", the Account
page as built without a "no rewards" line, the preview's line on a dark box left of the
minimap, the shipped cottage as the home icon, STONE's pictures (ruling 19); the stone in
the game as built, the map's marker unchanged, light 8 only when fuelled (ruling 20); the
fading cut with the lift bound 0.25 e² (ruling 21); the go on every UI lane's pictures,
FORMFIX's "as it is" included.

**Deviations from the plan:**

- Two lanes not in §1: GUARD (ruling 18, from STONE's review) and FORMFIX (the fuel panel at
  GUI scaling 1.5, seen in ART's pictures).
- ART was built by Astra (design, textures, `stone_art.lua`) and wired by an Opus step after
  STONE's merge; Astra's own home-name icon was dropped for the shipped cottage (ruling 19).
- The account stone's colour (ruling 10) comes from ART's two designs; STONE's interim tint
  was replaced.
- ROADS built the fade plus a lift bound of its own (pure fade left steps of up to 54 beside
  deep cuts), confirmed as ruling 21; the seed fleet `full` ran three times, twice on rules
  later superseded (the pure fade stopped, a linear bound failed 7 seeds).
- Engine boots above the briefs' numbers: STONE 3 (stated 1), NAMES 3 (1 planned),
  ACCOUNT 2 (1), PREVIEW 5 over three rounds; each extra boot retook pictures after a
  visible defect or a fix round.
- PACK's join hook moves a member's own entries at every login, beyond its brief (the pass
  packs an account stone's draft under its placer); kept.
- §3.2's sentence that the flat `STONE_TEXTURE` stays for icons and the minimap was wrong
  when written (the map already drew its own claim icon `grug_map_claim.png`); corrected
  in place.

**Round-end gates** (on `round86`, 2026-11-22): the full `tools/run_fixtures.sh` once after
lane D: 393 passed, 1 failed (`r25_claim_core`: a check of Round 85 still expected a new
claim's name to be empty; NAMES stores the default "<character>'s Home" at placement, so
the check was brought in line and the fixture rerun alone: PASS). Seed fleet `full`: 304 of
304 on ROADS' final rule, not repeated, since nothing under `mods/MAPGEN`, `mods/WORLD` or
`mods/ENTITIES/grug_mobs` changed after that run. `check_fresh_server` PASS; `check_upgrade`
PASS (0.86.0, map reset declared; compared with `origin/main` at 0.83.0);
`r28_design/validate.py --game` 0 errors, 18 warnings; `r29_e4/income.py --check` PASS; the
building templates' gate PASS (286 templates, 0 errors); the bat mesh `--check` PASS; the
migration tool's tests in the `debian:trixie` container PASS (38 tests, 2 skipped); a
headless boot on the production seed PASS.

**Human tests (offers):** two linked characters of one account choose the account stone,
both place it, one activates it (the other's draft vanishes), the other fuels it and sets
it as home; a third character with a personal stone tries to open a chest there; rename a
home and walk in and out with a second character, at your own GUI scaling, and dig in
someone else's active claim; hold the stone across chunk edges near a road, a camp and a
capital ring, at a full quota, and place a stone in a free chunk and on its edge; place both
stones from all four sides, walk onto the roof, travel home to it, look at it at night
fuelled and empty; open the Account page unlinked and linked on the rehearsal realm with
the website's list set, empty and changed while the page is open, and press Open website;
on a fresh world of production's seed stand on the road at −1276, −884 (looking
south-west) and at −2039, −293 (looking north), where a 20–38-node wall stood; on the
rehearsal realm after a reset, two members open the account stone's Belongings and one
takes.

## Carry-overs

Each line names where it came from. The first four are wanted work and have BACKLOG lines.

**Wanted work:**

- **Road faces on steep hillsides** (ROADS, rulings 17 and 21): the cut now meets the
  ground at the side zone's edge, but on steep hills its outer part is a rock face as
  steep as the hill or, beside deep cuts, steeper: up to about 0.5 e + 2 per node where
  the lift bound binds (12–13 per node 12–14 nodes out on 5664044364126834037). On the
  48-seed sample the largest step beside the road is 6; `road_face` on single seeds is 4
  (production), 3 (5664044364126834037) and 5 (6410640627505506314). The 1:1 soil foot of
  a deep cut can steepen to 3–6 per node. Only another route gives a bank
  there: the user's road-planning rework, in which a local change stays local (working
  number from the census: keep nature within about 43 nodes above the road at 24 nodes from
  its edge; at the edge nature stands a median 52 above the road). `road_face` on the fleet
  line is report-only; the engine before/after road pictures were taken from different view
  angles.
- **The housing concept's Part C**, the soft map reset that keeps homes
  ([concept](housing-rework-concept.md) §4), when the first one is needed.
- **For the website** (CONTRACT, ACCOUNT): the amendment in
  [web-accounts.md](../technical/web-accounts.md) (`default_rewards`, `rewards.defaults`);
  the website must send the field for the Account page's strip to show (the user forwards
  the note `r86/website-message.md`); the end-to-end account test on the rehearsal realm
  stays open.
- **`box[]` colours without alpha** are drawn at alpha 140 (an engine default, found by
  ACCOUNT in its first capture): the Account page writes `ff` itself; the other pages and
  `UI.input_background` (the half-transparent code and name fields) were not touched.

**Notes:**

- **FORMFIX:** at GUI scaling 1.5 on 1600 × 900 the stone form's fuel panel text is smaller
  than the rest of the form (a 25 % larger variant computed to fit, not built); 1920 × 1080
  was not captured; "Interact" and "Everything" are tight.
- **NAMES / PREVIEW:** two tables of the HUD font's glyph widths (PREVIEW's
  `minimap_view.lua` `V.text_width`, NAMES' `grug_core.hud_layout.GLYPH_EM`) could become
  one; both assume the default font. The Map tab's icon and the minimap line's icon at
  scale 1 are small; very long names at a large GUI may meet the quest box (not seen).
- **PREVIEW:** claim mode's bytes per second about double (reported, not gated); red over
  water turns purple, the free chunk's green fill is faint on light map colours; the old
  probe `grug_probe_r502_cmap` still checks the removed overlay.
- **PACK:** the content rows of an account's packed items carried by a member who is then
  deleted stay behind (`forget` cannot tell they are carried; a small leak); an account's
  entries outlive a deleted account (ruling 13 keeps them).
- **ACCOUNT / CONTRACT:** a website list sent with version 0 would keep housing's binding
  checks off (`held_version()` 0 reads as "no list held"). At 1920 × 1080 the page's text is
  relatively smaller than in the mock-up; the inventory window and the code field are
  half-transparent.
- **STONE / GUARD:** an offline placer whose draft was removed by another member's
  activation learns it only from the Character page; an offline last member learns that
  the claim stands ownerless only from its home's fallback at its next login.
- **BASE:** Help's heading "Riding, home and death" keeps its word "home" (respawn).
- **ACCOUNT:** Help's quickbar line (`grug_inventory/help.lua`, Basics) still says "Cheer
  with a website account", which reads as every account's; Cheer is an account reward
  (`emote:cheer`) the website grants. A game text for a later lane.
- **ART:** the hand shows the large extruded flat picture.
