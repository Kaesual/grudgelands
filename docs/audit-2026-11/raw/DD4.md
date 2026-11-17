# DD4 — Design documents, player systems, against the code

- Finder model: claude-opus-5-5
- Files read in full: 11 of 11 design files (docs/design/quests.md, expeditions.md, housing.md, home_travel.md, mail.md, parties.md, clans.md, mounts.md, boats.md, sound.md, README.md); code read against them: grug_home (all), grug_housing (api, registry header and constants, manager, interface strings, interaction), grug_mail (model, letters, quest, texts), grug_parties (init, hud constants), grug_clans (init), grug_mounts (catalog, state, items, shipwright, entity header), grug_expeditions (catalogue, loot, traps constants, entry, the four templates' trap/ambush/encounter/particle lines), grug_quests (registry, state, use, validate constants; all 48 quest files counted), grug_sounds (header, helper defaults), grug_ambience (data.lua, rules constants), grug_mobs (voices, boss HP scales, kraken speeds); skimmed: quest JSON texts (sampled by id), mounts.md §1 stable/display prose, sound.md §2 conventions (no code to check against); not reached: none
- Summary: The player-system design documents are in good shape against the code: of roughly 420 values, counts and rules checked, almost all match exactly (quest totals 393/48, group quests 22, every Expedition box/grid/timer/trap/loot/mob roster number, housing fuel arithmetic and timers, mail limits and postage, party and clan limits, mount speeds and prices, sound and ambience numbers). The most valuable item is a three-way drift on where the Expedition Registrar stands: the 0.75.3 move to the great hall door was written into expeditions.md and settlements.md, but two player-facing texts in the code (the "no Expedition" notice and the level-20 letter) and mail.md §8 still send players to the waystone plaza. The rest are stale paragraphs: map markers in housing.md that are now icons ("H", "+"), a mounts.md paragraph that still treats ranged attackers and bows as future Phase-2 work, and a mounts.md §5 research/licence section that names mobs_redo as the mount base and recommends an item-based mount pattern the design itself retired. A few leftover "this round"/"may overrule" phrasings remain in parties.md and clans.md. No dead links or anchors; README lists every design file exactly once. No older word for "Expedition" remains in the package's docs or code.

## Findings

### DD4-01 | Medium | bug | Two player texts still send players to the Registrar at the "waystone plaza"; it moved to the great hall door in 0.75.3

- **Where:** `mods/PLAYER/grug_expeditions/entry.lua:10-11`, `mods/PLAYER/grug_mail/texts.lua:44`; the decided design `docs/design/expeditions.md:123` (§3), `docs/design/settlements.md:762-767`
- **What:** expeditions.md §3 places the Expedition Registrar "outdoors a few steps from a capital's great hall door", and settlements.md records that it stood at the waystone-plaza approach only until 0.75.3. The code puts it there (the six `expedition_registrar` sockets in `mods/MAPGEN/grug_mapgen/wp13/<capital>.lua`, e.g. `highcourt.lua:693-695`: "a few nodes outside the … king's hall … door"). But two player-facing texts still name the plaza: the Expeditions-tab/entry notice "The Expedition Registrar at a capital's waystone plaza opens one." and the level-20 Registrar letter "Come to the waystone plaza in {capital} and ask for me". A player who follows them looks in the wrong place. The code is the wrong side here.
- **Evidence:** `entry.lua:10-11` `local NOTHING = "You have no Expedition to enter. The Expedition Registrar at a capital's " .. "waystone plaza opens one."`; `texts.lua:44` `"... Come to the waystone plaza in {capital} "`; `git log -S'great hall door' -- docs/design/expeditions.md` → `23f0f1b4e Round 75.3 (0.75.3): the Expedition Registrar at the great hall door`; texts.lua was last touched by `9cdb4328a Round 73.1 … the Registrar at the plaza`.
- **Proposal:** Reword both strings to the great hall ("…at the great hall of your capital", with the capital's own hall name if wanted: king's hall, warlord hall, mausoleum, as in settlements.md). The letter's flag and send rule stay as they are, so a letter already delivered keeps its old text. That is acceptable: mail is text only.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### DD4-02 | Low | docs | mail.md §8 says the Registrar's letter sends players to the waystone plaza; contradicts expeditions.md §3

- **Where:** `docs/design/mail.md:224-226`; against `docs/design/expeditions.md:123`
- **What:** mail.md describes the Registrar's letter as one that "sends the player to the waystone plaza of their race's capital (the guild house before 0.73.1)". Since 0.75.3 the Registrar stands at the great hall door (expeditions.md §3, settlements.md "Public Expedition Registrar"). The two design files contradict each other, and mail.md documents the stale letter text of DD4-01. mail.md is wrong.
- **Evidence:** mail.md:225-226 "it sends the player to the waystone plaza of their race's capital (the guild house before 0.73.1)"; expeditions.md:123 "at the **Expedition Registrar**, outdoors a few steps from a capital's great hall door".
- **Proposal:** Change it to "to the Registrar at the great hall of their race's capital (the waystone plaza before 0.75.3, the guild house before 0.73.1)" once DD4-01 is fixed.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-03 | Low | docs | mounts.md §3.2 still treats ranged attackers, bows and a ranged class as future Phase-2 work

- **Where:** `docs/design/mounts.md:446-455`
- **What:** The paragraph "And it stops being a formality once ranged attackers exist" says that "today a rider mostly has to walk into a melee swing", that "bows are fully catalogued as a Phase-2 enabler (`items_crafting.md` §9)" and that "a ranged/stealth class direction is deferred Phase-2 work (`classes.md` §6)". The Scout, a bow class with homing arrows, shipped in Round 11 (scout.md; items_crafting.md §9 now opens "Its consumer is delivered in Round 11"), and classes.md §6 no longer lists a ranged class as deferred, only Scout stealth (scout.md §8). The same mounts.md section already counts on the Scout's Sprint (line 437). The doc is stale; the rule itself (damage dismounts) is unchanged.
- **Evidence:** mounts.md:448-451; items_crafting.md:1818-1820 "**Its consumer is delivered in Round 11**: the Scout's base kit opens with a bow shot"; classes.md:985-1003 (§6 lists cast times, shield abilities, auras, Scout poison/stealth, PvP DR; no ranged class); `mods/PLAYER/grug_abilities/scout.lua` registers the Scout kit.
- **Proposal:** Rewrite the paragraph in the present tense: ranged mobs (`dogshoot`) and Scout players can bring a rider down at range, which is the counterplay to permanent mount speed. Drop the Phase-2 references.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-04 | Low | docs | mounts.md §5 is a research and licence note that names mobs_redo as the mount base and recommends a retired item pattern

- **Where:** `docs/design/mounts.md:636-675` (§5 "Reference implementations & licences"), also `:273-276` (§3 "Dismounting")
- **What:** §5 says "**mobs_redo is the base**: `mount.lua` is already vendored and loaded…", lists its `mobs.attach/detach/drive/fly` helpers as the land/flying split, and recommends Lord-of-the-Test's "craftitem whose `on_place` spawns the mount entity" as "the acquisition half we need". `grug_mounts` uses none of that: its controller is its own entity (`entity.lua`, `player:set_attach` at `:445`, `:834`, its own gravity, jump and step code), with no call to `mobs.attach`, `mobs.detach`, `mobs.drive` or `mobs.fly`. Since Round 44 no mount item exists at all (§3: "Nothing hands out a mount item"). This is option and reference discussion left in a decided-design file, which AGENTS.md "Documentation layers" puts outside `docs/design/`, and part of it is now wrong. The doc is wrong.
- **Evidence:** `rg -n 'mobs\.(attach|detach|drive|fly)' mods/PLAYER/grug_mounts` → no hits; mounts.md:649-650 "**mobs_redo is the base**"; mounts.md:661-666 the LotT craftitem pattern; mounts.md:159-160 (§3) "Nothing hands out a mount item".
- **Proposal:** Remove §5, or move it to `docs/research/` or the archive. If the licence verdicts are still wanted, keep one line in the technical module guide. In §3 "Dismounting", keep the rule (a free neighbouring node) and drop the "pattern of the vendored mount.lua" pointer.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-05 | Low | docs | housing.md says the map marks a claim home with "H"; it is the home icon, and home_travel.md says so

- **Where:** `docs/design/housing.md:407-408` (§8); against `docs/design/home_travel.md:105-107` and `mods/PLAYER/grug_map/providers.lua:150-155`, `markers.lua:45-50`
- **What:** housing.md §8: "the map marks a claim home with 'H'". The provider emits `kind="home"` for a claim home, and `markers.texture` draws `grug_map_home.png` for that kind (the window uses the same texture, `window.lua:255`). home_travel.md correctly says "the home icon at the stone … without a label since Round 44". The two design files contradict each other; housing.md is stale.
- **Evidence:** providers.lua:151-154 `{id=selected.id, label="Your Claim Stone", … kind="home", personal=true, …}`; markers.lua:48-49 `return "grug_map_" .. marker.kind .. ".png"`.
- **Proposal:** "the map marks a claim home with the home icon at the stone (home_travel.md)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-06 | Low | docs | housing.md says the Housing Steward has a "+" map marker; it has its own steward icon

- **Where:** `docs/design/housing.md:371-372` (§7.2)
- **What:** "The map shows it with a '+' marker." The provider gives the Steward `texture = "grug_map_housing_steward.png"`, `kind = "steward"`; that icon has its own mask in `icon_masks.lua:1533` and is not a plus sign. The sentence dates from Round 25 (commit c27051c6c). The doc is stale.
- **Evidence:** `mods/PLAYER/grug_map/providers.lua:81-83` `elseif socket.role == "housing_manager" then label, texture = "Housing Steward", "grug_map_housing_steward.png"; kind = "steward"`.
- **Proposal:** "The map shows it with the Steward icon (world_map.md)."
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-07 | Low | docs | clans.md marks its rules as coordinator defaults the user "may overrule"

- **Where:** `docs/design/clans.md:4-6`
- **What:** "§3.1 (coordinator defaults, built as written below; the user may overrule them)". In a decided-design file, this leaves the status of every rule below open. AGENTS.md "Documentation layers" allows only settled decisions in `docs/design/`. Other files record confirmation (expeditions.md:18-22: "The user confirmed on 2026-11-08 that these stay"). Either the user confirmed the clan defaults, or they belong in a TODO file.
- **Evidence:** clans.md:4-6, quoted above.
- **Proposal:** Record the confirmation (date) or move the unconfirmed defaults out. Drop "the user may overrule them".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium

### DD4-08 | Low | docs | parties.md keeps round-scoped and lane wording ("in this round", "for V1 … do not broaden")

- **Where:** `docs/design/parties.md:7`, `:25`, `:45`, `:69-70`
- **What:** The file still carries the Round 14 decision log's structure and voice: the headings "Confirmed by the user" and "Accepted defaults" (quests.md retired exactly these names, see its "Former section names" table), "No mana/rage bars in this round." (line 25), and an instruction to implementers, "Party HUD rows need not support click-to-target for V1. Do not broaden the current spell ally/targeting rules merely because parties now exist." (lines 69-70). The rules are true of the code (no mana bars in `hud.lua`, no click-to-target), but the wording reads as a work order and a round note rather than a rule.
- **Evidence:** parties.md lines cited; `mods/PLAYER/grug_parties/hud.lua` draws health bars only.
- **Proposal:** Restate as rules ("The party HUD shows health only, no mana or rage bars"; "Party HUD rows are not click targets"), and rename the two headings by topic.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-09 | Low | docs | mounts.md §1 keeps lane ownership notes (CAP/GAME) in the stable rule

- **Where:** `docs/design/mounts.md:40-47`
- **What:** "CAP authors separate bounded movement/rest regions for all four sockets. … GAME owns throttled movement and persistence; CAP owns the roof, enclosure and socket geometry." CAP and GAME are lane names from a past work plan, not game rules. The decided rule (displays move inside bounded regions, have no AI and cannot be ridden) is already stated around them.
- **Evidence:** mounts.md:40, 44-45.
- **Proposal:** Drop the lane sentences and keep the display rules.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Values checked per document

- **README.md:** 37 rows against 37 design files (every file listed once, no dead entry), 6 supporting-record links and the AGENTS.md anchor: all resolve.
- **quests.md (about 70):** 393 quests and 48 files (counted per-quest `"level"` and `"line"` fields: 393 each); 22 "Party:" quests and their levels (2 Expedition quests at 20/40, 6 at 39, 2 at 50, 12 at 59–60, matching the list); acceptance level − 2 (`registry.lua:28`); 20 active (`state.lua:373`); 10 tracked (`state.lua:5`); silver "!" two levels (`SOON_LEVELS`); 2–4 choices (`MAX_CHOICES`); copper formula and P = 25/65/160/400/1000/2500 (`registry.lua:244-249`); reward XP `weight × (25 + 5L)`, so mailbox_visit = 30 XP at L1 (`grug_xp` `mob_xp`, `quest.lua:23`); use hold 1–15 s, 5-node reach, 48-node reach via `LEADER_RANGE`, 6-node column search, 10 s retry (`use.lua:46-70`); at most two givers per hub and two lines per giver (`validate.lua:27-28`); `EXPEDITION_TARGETS` flintback 20 / auditor_nemm 40 / duewarden 60; band 11–20 "13 quests per zone" (own + homed variants, all six zones 13); Expedition quests weight 4, level 20/40/60, line `guild`, no `story` flag; story_throng_04 requires and its 3 s hold at `socket:nhal_veyr/miners_guild/miners_guild_public_register`; main line 17 Accord / 14 Throng tagged steps and 15 story steps of 41+ in the two base files. Content prose per band was sampled, not proved for every quest.
- **expeditions.md (about 110):** the three rows (levels, max players), tier table (ore and gem per tier), entry level rule, RESERVE 600 s, closing 30 s, closed 10 s, Deserter 120 s, 100 slots, box 128×64×128 at y −112…−49, grid 10×10, pitch 320, origin and last corner (x 11071, z 1391), the no-spawn rectangle (x 7744–11391, z −1936–1711), 4 blocks per step, respawn lock 10 s; traps 45 %, 0.6, r 2, 1.5 s, rearm 10 s, 8 nodes/s, 32-node range (`traps.lua:51-57`); per template, floor-trap groups and counts (Second Shift 2/4, 1/2, 1/2, 2/4; Last Mint 3×2/4), wall traps, ambush candidates (2 each, one armed); every pack's roster (Seam 12 spiders + 3 elite golems; Shift 12 raiders, 2 miners, 3 elite miners, 3 ambush miners; Mint 11 Seeps, 5 Wisps, 2 elite Seeps, 1 Sentinel, 3 ambush Seeps); critters per template; particle budgets 122 and 200 (summed); boss HP scales 8/14/14 (`golem.lua:267`, `skeleton_raider.lua`, `land_guard.lua:41`); Nemm's mark every 12 s; all three chest tables row by row (`loot.lua:30-75`, incl. Drilled Bone = `marching_bone`).
- **housing.md (about 45):** radius 50 (101×101), min y −100, lump 26 160 s, Anthracite ×1.5, cap 99 lumps, draft 300 s, 5 lumps activation and its fuel order, pick-up lock 43 200 s, issue level 20, zone band 11–30 and capital exclusion, settlement margin 16, dig times 60…10 s, orphan radius 16, storage format v2, the Steward's dialog lines, all seven Character-page status strings, the protection hint, the deep-water refusal, map markers (DD4-05, DD4-06).
- **home_travel.md (about 20):** twelve locations (6 starts + 6 capitals), racial default binding, own-faction binding, cooldown 1800 s charged only on landing, combat and return-guard refusals in order, respawn without cooldown, the innkeeper four-side arrival order, claim arrival cell checks, start-pocket fallback, emerge timeout 30 s, the `/home` refusals, claim-home fallback messages and the map-reset clearing.
- **mail.md (about 30):** every `model.lua` constant (50 letters, 50 sent, 5 tickets, 8 rows, subject 60, body 4000, draft 10 000, quote 500, note 200, 4 stacks, 30 days, 5c + 30c, "Server Admin", topics, report reasons); window reach 6, label reach 16; level letters 15/20/20 with their usefulness rules; the starter quest's turn-in line, 25c and once-only grant (DD4-02).
- **parties.md (about 18):** 10 members, 120 s invitations, one per second per sender, 10 pending, duplicate no-op, the invitation chat line, party size labels "/10", health colours (four classes, all-green, backing), `/p` colour, `shout`, `action` log.
- **clans.md (about 20):** 100 members, 10 pending, 120 s, 1 s rate, `/c` colour `#7ee081`, both refusal texts, the nine membership/presence lines word for word, the succession order (first captain, else first member), dissolve at one member, invites_off meta key.
- **mounts.md (about 40):** four tiers' levels, modes, speeds and vertical speeds; prices 110/700/12 900/73 800 c; reverse 35 %; gravity 19.62 and jump 9.3; flight ceiling 600; warning band 40; combat window 5 s; Sprint +50 % 10 s cd 300 s; Swiftness +10 % 5 s; meta keys; the retired items still registered as described; restore wait 5 s.
- **boats.md (about 15):** tiers 5/6, speeds 4/8, prices as Apprentice/Journeyman, `water_tier`, response 1.5, landing radius 2, reverse 35 %, Kraken 10 nodes/s in deep ocean (5 elsewhere) and view 40, Shipwright socket role.
- **sound.md (about 55):** helper defaults (distance 16, interval 0.1, stop fade 0.1), the five direct `core.sound_play` sites by file, the 22 voice families in order, the retired `cast_frost_ward` still shipped and hooked; ambience: 8 slots × 0.25 s, layer curves (surface −15/+10/+60, wind 30→100 at 50 %, peak y 215 at 25 % within 4, cave 4→16 at 40 %, deep −500 ± 2), level step 3 %, floor 1 %, three passes, two-pass hysteresis, crossfade 3 s, cave grid 5×3×5 (75 reads) with min depth 4, sea grid 4 within 16 and full share 0.5, calls 90–240 s, thunder 40–56, animals 24–40 at surface ≥ 0.5, emitter box ±12/±5/±12, fire 10, furnace 60 % of fire, water 14, limit 2; music pause 5, push lead 60, timeout 120, retry 30, fade 3; capital margin 8; Master of the Feast in no rotation. The approval gate itself was not checked (fixture's job).

## Backlog notes

- `docs/design/settlements.md:745` (outside this package) still says the Registrar "now uses the dedicated core socket beside the waystone plaza approach", while the same file at :762-767 has the great hall door. This is the same drift as DD4-01/02 and belongs to whoever owns settlements.md.
- `docs/design/expeditions.md:30-34` heads its first table "Most players inside" but writes "3 at every level" for one row and a bare "4" for the others. Taste only.
- `docs/design/mounts.md:102-104` "Persistent highest-tier metadata is the ownership authority": the code keeps one highest tier per mode (`grug_mounts:land_tier`, `flight_tier`, `water_tier`, `state.lua:5-7`), so "per mode" would be more exact.
- `docs/design/mounts.md:160-163` and `mods/PLAYER/grug_mounts/items.lua:1-8`: the six retired mount items stay registered "until the 0.44.0 migration step removes them", 36 releases later. Doc and code agree; whether the shim can go is a dead-code question for a code lane.
- `docs/design/sound.md:171-172`: the retired Glacial Ward's cue `cast_frost_ward` "still ships, a hook without a call site" (`grug_sounds/init.lua:68,184`, the `.ogg` present). The doc is accurate; the file and the spec are a dead-asset candidate for a code lane.

## Good to know

- The quest, Expedition, housing, mail, party and clan numbers are all held in one constant table each (`grug_quests/registry.lua`/`state.lua`, `grug_expeditions/catalogue.lua`/`loot.lua`/`traps.lua`, `grug_housing/registry.lua`, `grug_mail/model.lua`, `grug_parties/init.lua`, `grug_clans/init.lua:20`, `grug_mounts/catalog.lua`, `grug_ambience/data.lua`), so a re-check later is quick.
- The Expedition templates (`templates/*.exp`) are text with a binary tail; `rg -a '^(trap|ambush|encounter|particles)'` lists the authored rows, which match expeditions.md §13–§15 row for row.
- All markdown links and anchors in the 11 files resolve (checked with a slug script), and every "§n" cross-reference sampled (36) points at an existing heading.
- No "dungeon"/"instance"/"raid group" wording for Expeditions remains in the package's docs or in grug_expeditions, grug_quests, grug_parties or grug_mail. `grug_mobs:dungeon_master` and "dungeon stone" are an unrelated mob and node.
