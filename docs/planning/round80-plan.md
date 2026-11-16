# Round 80 — Accounts phase 2 (donor cloaks, Cheer, emote icons) and five fixes

Planned with the user on 2026-11-16. The long-term model: [accounts-concept.md](accounts-concept.md)
(§3.4 rewards, §4 phases); phase 1: [round79-plan.md](round79-plan.md). Routing (user's standing
rule): one coordinator, lanes as subagents of the session model, independent review of every lane
with game logic. Version **0.80.0**, expected **compatible**: no map reset, no new saved data (emote
rewards are read live from the account list, like the cloaks), the player model grows by appended
clips. The round also carries five smaller items the user added the same day: water brakes a fast
fall, instant heals refuse a target at full health, fractional health in party nametags, every
skill states its cost, and a dated contract note on the website's narrower answers.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a ruling until
  the user says so; a coordinator default is marked as such.
- Name functions rather than line numbers.

## Why

Phase 1 made linking work and shipped one account reward. Phase 2 gives linking a reason for every
player (an emote for every website user) and gives donors their own cloaks, which the user grants
per account on the website. Emotes are a growing set now, so the quickbar's emote row becomes a
grid of icon buttons that fits four to a row. The five fixes are small and independent; they run
as their own lanes beside the two account lanes so the round finishes in one wave.

## 1. Lanes and order

Start state: main at the round's planning commit (0.79.0 + this plan). Integration branch
`round80` in `.claude/worktrees/round80`; every lane branches from it.

| Lane | Goal (§4) | Wave | Merge order | Review |
|---|---|---|---|---|
| REWARDS | The six donor cloaks as account rewards (art, catalogue); the Account page holds every reward the catalogue can give | 1 | 1 | independent; screenshots to the user before the merge |
| EMOTE | The Cheer emote (clip, seated twin, the account reward `emote:cheer`, the ownership gate); the quickbar's emotes as icon buttons; the icon tool | 1 | 2 | independent; screenshots to the user before the merge |
| SKILLS | Instant heals refuse a target at full health; every skill text states its cost, a percentage cost with the current mana number | 1 | 3 | independent |
| FIXES | Water brakes a fast fall; party nametags never show fractional health | 1 | 4 | independent |
| D | Contract amendments (§3.2), design docs, mod map, module guide, help text, release 0.80.0, completion, GUI checklist | after every merge | — | coordinator |

All four implementation lanes touch different files (§3.4) and run in parallel in one wave.

## 2. User rulings

From the conversation of 2026-11-16:

1. **Phase 2 is one emote for every website user, no cloak for everyone.** The emote is
   **Cheer** ("Jubeln"); the concept's "a cloak and an emote for every website user" (§4) shrinks
   to the emote. The money-cannon supporter emote is not built now.
2. **Cheer is the variant "V-Jubel" of the preview page, unchanged:** the arms fly up into a V,
   pump twice, the head goes back, the torso leans back a little; 60 frames, 2 s, once (the keys:
   `~/projects/grudgelands-orchestration/cheer-page/build.py`, clip `cheerv`; page
   https://claude.ai/code/artifact/0a7b8eea-3423-4008-8de8-79592b85499e).
3. **The Supporter Cloak** stays what it is: for players who supported the game early with
   feedback, granted manually (per character with `/achievement`, per account on the website).
4. **Donor cloaks** are new and separate: for players who supported the game with money. They
   say "premium", not "money". The user grants them **manually per account** on the website.
5. **The six donor cloaks** (the user's picks on the pick page, 2026-11-16; art by GPT-6 Astra,
   CC0; `~/projects/grudgelands-orchestration/donor-cloak/PICKS.md`):

   | Cloak | Pick (art id) |
   |---|---|
   | Emberwake | `hearthkeeper_1_r1` |
   | Veilstream | `aurora_1_r2` |
   | Pearlwing | `moonsilk_2_r1` |
   | Moonfall | `moonsilk_3_r2` |
   | Wintercourt | `royal_ermine_1_r2` |
   | Frost Regent | `royal_ermine_3_r2` |

6. **Reward cloaks always have wings** (2026-11-16): the wings are one of the marks of the
   "better" cloaks. Every cloak above has its wing texture.
7. **Emotes become icon buttons** in the quickbar (the user's proposal, 2026-11-16): each emote
   has an icon, a still that shows what it does; the tooltip names it. Four to a row, like the
   mounts and the potion belt above. Only the emotes the character has are shown.
8. **The icons are stills rendered from the player model** (2026-11-16), shown to the user on a
   preview page first (https://claude.ai/code/artifact/05a2e143-3a95-48f3-a144-a0985cdb259d,
   framing A upper body or B full figure); if they do not read well, Astra paints them instead.
   The user picked **framing A** (upper body) on 2026-11-16.

From the user's additions of 2026-11-16:

9. **Water brakes a fast fall.** While a player is in water, a high downward speed shrinks until
   only the normal slow sinking remains.
10. **Instant heals refuse a target at full health.** A heal that heals at once and has no
    heal-over-time part is not cast when its target has full health (no mana, no cooldown, a short
    message); from the first missing hit point it casts. Heal-over-time effects are not affected:
    casting them ahead of damage is a valid tactic.
11. **Party health shows whole numbers.** A player reported, rarely and during an Expedition,
    fractional numbers in the health text of party members.
12. **Every skill states its cost clearly.** Where a cost is given as a percentage of the base mana
    pool, the real current mana number (no decimals) stands beside it. The user noticed Priest
    Shield and Mend showing no cost at all.
13. **The website's four narrower answers** (its note of 2026-11-15,
    `~/projects/grudgelands-orchestration/r79/correspondence/kaesual-web-accounts-wave2-notes.md`)
    go into the contract as a dated note.

## 3. Shared conventions

### 3.1 Rules not covered by a ruling (coordinator defaults, the user may overrule)

- **Icon framing:** A (upper body), the user's pick (ruling 8).
- **Cheer on a mount:** a seated twin like Wave (`cheer_sit`, the arms over the saddle pose).
  Dance stays standing only.
- **Who has which emote:** Wave and Dance every character; Cheer a character whose website account
  has `emote:cheer`, read live (`grug_accounts.has_reward`), so it appears and disappears with
  the list like a reward cloak. The server refuses an emote the character does not have
  (`play_emote` answers `"not_owned"`), not only the quickbar.
- **Order in the grid:** Wave, Dance, then reward emotes in catalogue order.
- **A greyed emote** (Dance while riding) shows its dimmed icon, its tooltip says why ("Not while
  riding."), and a click does nothing and keeps the window open (as today).
- **The reward entry:** `emote:cheer`, name "Cheer", the emote's icon, hint "Play it from the
  quickbar (E)." The cloaks: `cloak:<id>` with ids `emberwake`, `veilstream`, `pearlwing`,
  `moonfall`, `wintercourt`, `frost_regent`, names as in §2.5 without "Cloak" (the picker lists
  them by name), hint "Choose it on the Character page." as the Supporter Cloak's.
- **The notice** a character gets when a reward arrives or leaves stays phase 1's (the reward's
  name); nothing new for emotes.
- **The Account page holds every reward** the catalogue can give at the smallest and the largest
  text size: eight today (Supporter Cloak, six donor cloaks, Cheer); the phase-1 backlog row "more
  than about 9 rewards overflow the Account card" is closed by this round, with room for a few
  more (a compact icon grid with tooltips, two columns, or a scroll container: the lane's choice,
  shown in screenshots).

### 3.2 The contract with the website

[web-accounts.md](../technical/web-accounts.md) §8 already says: phase 2 adds an emote for every
website user, the website grants it to every account automatically, and new kinds appear in the
catalogue first; nothing in the contract changes for them. The amendment (lane D, dated
2026-11-16, after the user's go on this plan) only names what phase 2 is:

- The reward every account gets automatically is **`emote:cheer`**; there is no cloak for every
  account (ruling 1).
- The six donor cloaks and the Supporter Cloak are granted **manually** per account.
- No new field, event, command or capability.

A second dated note (ruling 13) records the website's four narrower answers, none of which needs
a game change: a request over the website's limits may get no answer (the game's 30 s timeout ends
it); a used code comes back as `unknown_code`; a confirmation the website never offered gets no
answer; a bound name takes the game's spelling. The draft answer to the website
(`~/projects/grudgelands-orchestration/r79/correspondence/grudgelands-wave2-answer-draft.md`) says
so; the user sends it.

The platform agent gets a short message from the user after the push (the coordinator drafts it):
the pin, `emote:cheer` for every account, the six new cloaks in the catalogue.

### 3.3 The emote API (`grug_visuals`, EMOTE owns it)

`grug_visuals.EMOTE_CLIPS` gains `cheer` (stand and sit). The ownership rule lives with the
quickbar's emote list, not in the model code: one place answers "which emotes does this character
have" (Wave, Dance, and every catalogue emote reward the account gives), used by the quickbar grid
and by the `play_emote` gate. The lane chooses where that function lives (a dependency of
`grug_visuals` on `grug_accounts` is not wanted; `grug_quickbar` may depend on `grug_accounts`)
and names it in its report.

### 3.4 Shared files

| File or folder | Owner |
|---|---|
| `mods/PLAYER/grug_achievements/` (catalogue rows, textures) | REWARDS |
| `mods/PLAYER/grug_accounts/page.lua` | REWARDS |
| `tools/r80_art/` (the picked cloak art, provenance, assemble and check) | REWARDS |
| `tools/r40_an/make_poses.py`, `poses.json`, `tools/r33_c3/gen_cloak_model.py`, the player model | EMOTE |
| `mods/PLAYER/grug_visuals/` (EMOTE_CLIPS, play_emote) | EMOTE |
| `mods/PLAYER/grug_quickbar/` (the grid, icons, the reward registration) | EMOTE |
| `tools/r80_emote/` (icon tool, fixture, capture) | EMOTE |
| `docs/technical/web-accounts.md` | D, after the user's go |
| `mods/PLAYER/grug_abilities/` (heal refusals, cost text), `mods/PLAYER/grug_classes/talent_graph*.lua` | SKILLS |
| `minetest.conf` (the game's), `mods/CORE/grug_core/movement.lua` if the lane takes the override path, `mods/CORE/grug_core/combat.lua` (absorb rounding), `mods/PLAYER/grug_factions/` (the nametag) | FIXES |
| `CHANGELOG.md`, `game.conf`, `tools/web_data/upgrade.json`, `docs/STATUS.md`, design docs, mod map, module guide, `help.lua` | D |

## 4. Lane goals

### REWARDS

1. **The art in the repository:** `tools/r80_art/` in the manner of `tools/r55_art/`: the two
   drops' painters (`~/projects/grudgelands-orchestration/donor-cloak/art/drop-01/src`,
   `drop-02/src`) as delivered, `picks.json` (ruling 5), `assemble.py` that runs the painters in a
   temporary directory and writes the six cloaks and their wings, `--check` exits 1 when the
   shipped textures differ, a README with the licence (CC0 1.0, own work, AI-assisted by GPT-6
   Astra, deterministic Python/Pillow, no image service). Textures
   `grug_achievements_cloak_<id>.png` and `grug_achievements_cloak_<id>_wings.png`.
2. **The catalogue:** six cloak rows with `account = true`, `texture` and `wings`, no achievement
   (they are account rewards only). Each registers `cloak:<id>` as phase 1's Supporter Cloak does;
   the website's catalogue then offers them.
3. **The Account page** holds every reward (§3.1).
4. **Fixtures:** the cloak rows load and validate; an account set with a donor cloak unlocks and
   wears it, losing it falls back to none (the phase-1 cloak cases, extended); the Account page's
   formspec with all eight rewards stays inside the frame at the smallest and largest text size.
   Existing achievement and page fixtures that pin what changes (`r79_page`, the catalogue counts
   in older fixtures): find them by grep, name them.
5. **Engine:** one capture run (the `tools/r79_page` capture method, the fake bridge in accounts
   mode granting all rewards): the Account page with eight rewards at both text sizes, the
   Character page picker, each donor cloak worn (back and three-quarter). Shots to the round's
   orchestration folder. The user sees them before the merge.

### EMOTE

1. **The clip:** Cheer from ruling 2 baked into the player model through `make_poses.py` and
   `gen_cloak_model.py` (the pose spec copied from the preview's `cheerv`, bases `stand` and
   `sit`), appended after the shipped frames; `EMOTE_CLIPS.cheer` with its stand and sit ranges;
   the generator's `--check` holds the model to the spec. Plays once, 2 s; ends like Wave on a
   move, jump, click or mount.
2. **The reward and the gate:** `emote:cheer` registered in the catalogue (§3.1); the ownership
   function (§3.3); `play_emote` refuses an emote the character does not have.
3. **The icons:** `tools/r80_emote/icons.py` renders one still per emote from the shipped model
   with the repository's software renderer (`tools/r55_offhand/render.py`), the method and frames
   of the preview (`~/projects/grudgelands-orchestration/cheer-page/icons.py`; framing per §3.1),
   transparent background, and a dimmed copy; deterministic, `--check`. Textures
   `grug_quickbar_emote_<id>.png` and `_off.png`; the size the quickbar slot needs (at least 64 px).
4. **The quickbar grid:** the emote section becomes image buttons four to a row in the mounts'
   slot size, only the owned emotes, the tooltip the emote's name (or why it is greyed). A click
   plays it and closes the window, as today. The Account page shows Cheer with its icon through
   the catalogue (no change to the page needed; REWARDS owns the page).
5. **Fixtures:** a new `tools/r80_emote/portable_test.lua`: ownership (no account, an account
   without and with `emote:cheer`, the reward removed), the gate in `play_emote`, the quickbar's
   formspec (owned icons only, four to a row, the greyed Dance while riding, tooltips), the clip
   ranges. Existing fixtures that pin the emotes and the quickbar (`r78_emote`, `r39_wm` and
   others found by grep), named.
6. **Engine:** one capture run: the quickbar with Wave and Dance only, with Cheer, while riding,
   at the smallest and largest text size; Cheer playing standing and seated (a few frames); the
   web build: say what could and could not be checked. The user sees the shots before the merge.

### SKILLS

Paths under `mods/PLAYER/grug_abilities/` unless stated. Coordinator's reading at 4f6b20b7, to
re-check (confirmed / changed / refuted in the report).

1. **Instant heals at full health (ruling 10).** Today `grug_core.heal_player` clamps the amount
   to 0 at full health but the skill's `cast` still returns true, so `try_cast` spends the mana,
   starts the cooldown and opens follow-up windows. The existing refusal path is `cast` returning
   `false, msg` (no mana, no cooldown, the red flash).
   - **Heal** (`kits_priest.lua`, target from `support_target`: the ally in the crosshair, else
     yourself): refused when its target has full health.
   - **Hearten** (self plus up to three allies): refused only when every one it would heal has
     full health.
   - Not affected: Mend and Haven (heal over time), Shield (an absorb), Word of Ruin and Retort
     (damage first, a heal as a side effect). Any other class's pure instant heal found by the
     lane follows the same rule (list them).
   - The message: "Target is at full health." (Hearten: "Everyone is at full health.").
2. **Every skill states its cost (ruling 12).** The hotbar and catalogue tooltip
   (`description_prefix`) already reads "9% base mana (N mana)". The talent tree
   (`grug_classes/talent_graph_ui.lua`, `node_text` and `strip_text`) shows only the node's
   description, so Shield, Mend, Haven (Priest) and Broadstroke, Bellow (Warrior) state no cost,
   and the other unlocks state a percentage without the number. Goal: every place that describes
   a skill (tooltip, catalogue, talent node, talent strip, anything else the lane finds) states the
   cost through **one** function: "N% base mana (M mana)" with the player's current M as the cast
   would charge it (integer), "N mana", "N rage", or "free"; node descriptions lose their own
   hand-written cost text so nothing is said twice.
3. **Fixtures:** a new `tools/r80_skills/portable_test.lua` (Heal at full health refused with no
   mana and no cooldown, one missing hit point casts; Hearten all full / one hurt; Mend at full
   health casts; the cost text of every skill of every class in every place, percentage costs
   with the number). Existing ability and talent-tree fixtures that pin these texts, found by
   grep and named.

### FIXES

1. **Water brakes a fast fall (ruling 9).** Research (coordinator, engine 5.18): in liquid the
   client replaces gravity with the liquid sink and brakes toward the target speed, but the brake
   is capped by `movement_liquid_fluidity_smooth` (default 0.5 × BS, about 50 nodes/s², net about
   30 against the sink), so a 30 nodes/s fall needs about 0.8 s and 14 nodes to slow down
   (`src/client/clientenvironment.cpp`, the liquid block of `step`). Normal sinking does not
   depend on it. The game sets none of the liquid settings. Preferred fix: the game's
   `minetest.conf` sets `movement_liquid_fluidity_smooth` (start at 2; the lane measures 2 and 3
   in one headless or capture run and picks the one that stops a fall from about 30 nodes within
   about 2–3 nodes). Alternative if a server setting turns out not to reach the clients as wanted:
   the per-player physics override `liquid_fluidity_smooth`, written only through
   `grug_core/movement.lua` (its single-writer rule) and at join. Not server-side `add_velocity`
   (a round trip late, jitter). Known side effect, to report: horizontal speed into water is
   braked harder too; check swimming and boats feel unchanged. The lane also checks how the
   production stack sets server settings (the game's `minetest.conf` is only a default) and says
   so.
2. **Fractional health in party nametags (ruling 11).** Research: the party HUD formats integers;
   the overhead nametag (`grug_factions/init.lua`, `tag_text`, refreshed from the HP-change logger
   with `get_hp() + hp_change`) does not floor, and `hp_change` becomes fractional when a hit
   breaks an absorb shield (`grug_core/combat.lua`: `add_absorb` stores an unrounded amount, the
   soak sets `hp_change = -remaining`). Fix both ends: absorb amounts and the soak are whole
   numbers, and every health text formats integers. Grep for other health texts built with
   `..` or `%s` and fix them the same way.
3. **Fixtures:** a new `tools/r80_fixes/portable_test.lua` (a shield broken by a hit leaves whole
   numbers in the tag and the absorb; the tag text of fractional input); the setting or override
   present. Existing combat/absorb fixtures that pin the amounts (they may change by rounding),
   found by grep and named. One engine run for the water measurement.

### D

The contract amendments of §3.2 (dated note, nothing else in the contract); the design docs
(`accounts.md`: phase 2; `character_visuals.md`: Cheer; `inventory_equipment.md`: the emote grid);
mod map and module guide (the ownership function, the new textures, the catalogue rows); the
help text (Cheer for linked characters, the icons); release 0.80.0 (`game.conf`,
`tools/web_data/upgrade.json`, CHANGELOG, STATUS, AGENTS pointer); the concept's §4 phase row; the
completion section; the GUI checklist; BACKLOG rows from the reports; `tools/README.md` lines for
`r80_*`.

## 5. Rules

[Round workflow](../process/round-workflow.md), [AGENTS.md](../../AGENTS.md), Lua 5.1. Focused
fixtures per lane; the full fixture suite runs once at the round end, by the coordinator. Maximum
eight Lua processes across all agents. Headless runs only through `tools/luanti_headless.sh` with
`LC_ALL=C`. No sync to Luanti and no push by any lane. The contract binds the platform: a lane that
wants to change it stops and reports. UI lanes merge only on the user's explicit go after the
screenshots.

## 6. Verification and GUI checklist

**Code:** changed-file Lua check, the lanes' fixtures, the model generator's and both art tools'
`--check`, the full suite at the round end, `tools/check_upgrade.py`, `check_fresh_server.py`, a
headless smoke boot.

**User GUI test** (desktop and web; fake bridge in accounts mode, `grant` and `revoke` for the
rewards; D refines this list from the reports):

1. A character without an account: the quickbar shows Wave and Dance as icons, tooltips name them.
2. Grant `emote:cheer`: the notice comes; the quickbar shows Cheer as the third icon after the
   next opening; it plays (arms up in a V, head back), standing and on a mount.
3. Revoke it: Cheer leaves the quickbar; `play_emote` refuses it if called directly.
4. While riding: Dance's icon is dimmed, its tooltip says "Not while riding.", a click does
   nothing; Wave and Cheer play seated.
5. Grant each donor cloak: the Account page lists it with its icon; the Character page offers it;
   worn, it shows with its wings; revoke falls back to no cloak.
6. All eight rewards granted: the Account page shows them all at the smallest and the largest
   text size.
7. Other players see Cheer and the donor cloaks.
8. Jump from about 30 nodes into deep water: the fall stops within a few nodes, then you sink
   slowly as before; swimming, jumping out and boats feel unchanged.
9. Priest at full health: Heal on yourself is refused with the message, no mana spent, no
   cooldown; take one point of damage and it casts. Mend casts at full health. Hearten is refused
   only when the whole group is full.
10. The talent tree and the hotbar tooltips state every skill's cost; percentage costs show the
    mana number, which changes when the mana pool changes.
11. In a party, a priest shields a member who is then hit until the shield breaks: the nametag
    over the member shows whole numbers.

## 7. Orchestration notes

- **Start:** on the user's go, after a compaction and after the user's restructuring of the
  repository's Markdown files (re-read AGENTS.md first; paths in this plan may have moved: fix
  them before writing briefs). REWARDS, EMOTE, SKILLS and FIXES in one wave; D after the merges.
- **Open with the user:** whether trinket enchantments change (below).
- **Trinket enchantments, T5 equals T6** (the user's report, 2026-11-16; research, not a lane):
  not a bug in the code. The enchant value uses `L = min(item level, 10 × tier)`
  (`grug_quality/init.lua`, documented in `docs/design/item_tiers.md`), so on an un-upgraded T6
  item (level 51) a T6 enchant uses L = 51 and a T5 enchant L = 50, which round to the same value;
  T6 pulls ahead only as the item is upgraded towards level 60. The same holds on every slot and
  one tier down (T4 = T5 on a level-41 item). It becomes a lane only if the user wants the rule
  or its wording changed.
- **The platform:** after the push the user sends the platform agent the pin and §3.2's message.
- **Handover:** `~/projects/grudgelands-orchestration/r80/HANDOVER.md`.
- **Inputs outside the repository** (the lanes copy, never move): the cloak drops and picks
  under `~/projects/grudgelands-orchestration/donor-cloak/`, the cheer bake and icon studies
  under `~/projects/grudgelands-orchestration/cheer-page/`.
