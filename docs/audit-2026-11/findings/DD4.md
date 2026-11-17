# DD4 — Design documents, player systems, against the code (verified)

- Finder model: claude-opus-5-5
- Verifier model: claude-opus-5-5
- Files read in full: 11 of 11 design files (docs/design/quests.md, expeditions.md, housing.md, home_travel.md, mail.md, parties.md, clans.md, mounts.md, boats.md, sound.md, README.md); code read against them: grug_home (all), grug_housing (api, registry header and constants, manager, interface strings, interaction), grug_mail (model, letters, quest, texts), grug_parties (init, hud constants), grug_clans (init), grug_mounts (catalog, state, items, shipwright, entity header), grug_expeditions (catalogue, loot, traps constants, entry, the four templates' trap/ambush/encounter/particle lines), grug_quests (registry, state, use, validate constants; all 48 quest files counted), grug_sounds (header, helper defaults), grug_ambience (data.lua, rules constants), grug_mobs (voices, boss HP scales, kraken speeds); skimmed: quest JSON texts (sampled by id), mounts.md §1 stable/display prose, sound.md §2 conventions (no code to check against); not reached: none
- Summary: The player-system design documents are in good shape against the code: of roughly 420 values, counts and rules checked, almost all match exactly (quest totals 393/48, group quests 22, every Expedition box/grid/timer/trap/loot/mob roster number, housing fuel arithmetic and timers, mail limits and postage, party and clan limits, mount speeds and prices, sound and ambience numbers). The most valuable item is a three-way drift on where the Expedition Registrar stands: the 0.75.3 move to the great hall door was written into expeditions.md and settlements.md, but two player-facing texts in the code (the "no Expedition" notice and the level-20 letter) and mail.md §8 still send players to the waystone plaza. The rest are stale paragraphs: map markers in housing.md that are now icons ("H", "+"), a mounts.md paragraph that still treats ranged attackers and bows as future Phase-2 work, and a mounts.md §5 research/licence section that names mobs_redo as the mount base and recommends an item-based mount pattern the design itself retired. A few leftover "this round"/"may overrule" phrasings remain in parties.md and clans.md. No dead links or anchors; README lists every design file exactly once. No older word for "Expedition" remains in the package's docs or code.

Verification: all nine findings checked against `main` at `4cb49044e` (8 CONFIRMED, 1 CORRECTED in wording only, 0 REFUTED). The finder's "about 420 values, no mismatch" claim held for ten values the verifier picked (see "Good to know").

## Findings

### DD4-01 | Medium | bug | Two player texts still send players to the Registrar at the "waystone plaza"; it moved to the great hall door in 0.75.3

- **Verdict:** CONFIRMED — Both strings exist as quoted (`entry.lua:10-11`, `texts.lua:42-47`). The Registrar's real position: each of the six capital compositions places the `expedition_registrar` socket "a few nodes outside the … door" of the great hall (`mods/MAPGEN/grug_mapgen/wp13/highcourt.lua:693-695`, `dur_brannoc.lua:654-656`, `nhal_veyr.lua:869-871`, `gor_drazhak.lua:827-829`, `lethariel.lua:804-806`, `kezamba.lua:767-769`), and `CHANGELOG.md:210-215` (0.75.3, 2026-11-10) tells players it "now stands outside, a few steps from the door of the great hall … instead of at the waystone plaza". `rg -i plaza mods` outside mapgen finds only these two strings plus one stale code comment (see Backlog notes). Quest texts only say "Speak to the Expedition Registrar" with no place, so they are fine. A player-visible text pointing to the wrong place is a bug on a less common path; Medium fits.
- **Where:** `mods/PLAYER/grug_expeditions/entry.lua:10-11`, `mods/PLAYER/grug_mail/texts.lua:44`; the decided design `docs/design/expeditions.md:123` (§3), `docs/design/settlements.md:762-767`
- **What:** expeditions.md §3 places the Expedition Registrar "outdoors a few steps from a capital's great hall door", and settlements.md records that it stood at the waystone-plaza approach only until 0.75.3. The code puts it there (the six `expedition_registrar` sockets in `mods/MAPGEN/grug_mapgen/wp13/<capital>.lua`, e.g. `highcourt.lua:693-695`: "a few nodes outside the … king's hall … door"). But two player-facing texts still name the plaza: the Expeditions-tab/entry notice "The Expedition Registrar at a capital's waystone plaza opens one." and the level-20 Registrar letter "Come to the waystone plaza in {capital} and ask for me". A player who follows them looks in the wrong place. The code is the wrong side here.
- **Evidence:** `entry.lua:10-11` `local NOTHING = "You have no Expedition to enter. The Expedition Registrar at a capital's " .. "waystone plaza opens one."`; `texts.lua:44` `"sends small parties to open them again. Come to the waystone plaza in {capital} "`; `CHANGELOG.md:210` "## 0.75.3 — the Registrar at the great hall (2026-11-10)"; `git log -S'great hall door' -- docs/design/expeditions.md` → `23f0f1b4e Round 75.3 (0.75.3): the Expedition Registrar at the great hall door`; texts.lua was last touched by `9cdb4328a Round 73.1 … the Registrar at the plaza`.
- **Proposal:** Reword both strings to the great hall ("…at the great hall of your capital", with the capital's own hall name if wanted: king's hall, warlord hall, mausoleum, as in settlements.md). The letter's flag and send rule stay as they are, so a letter already delivered keeps its old text. That is acceptable: mail is text only. Fix the comment at `grug_core/settlement_sockets.lua:343-344` in the same change.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### DD4-02 | Low | docs | mail.md §8 says the Registrar's letter sends players to the waystone plaza; contradicts expeditions.md §3

- **Verdict:** CONFIRMED — `mail.md:224-226` reads as quoted; expeditions.md:123 and settlements.md:762-767 have the great hall door, and the code (sockets, CHANGELOG 0.75.3) follows expeditions.md. mail.md accurately describes the stale letter text, so it should change together with DD4-01.
- **Where:** `docs/design/mail.md:224-226`; against `docs/design/expeditions.md:123`
- **What:** mail.md describes the Registrar's letter as one that "sends the player to the waystone plaza of their race's capital (the guild house before 0.73.1)". Since 0.75.3 the Registrar stands at the great hall door (expeditions.md §3, settlements.md "Public Expedition Registrar"). The two design files contradict each other, and mail.md documents the stale letter text of DD4-01. mail.md is wrong.
- **Evidence:** mail.md:225-226 "it sends the player to the waystone plaza of their race's capital (the guild house before 0.73.1)"; expeditions.md:123 "at the **Expedition Registrar**, outdoors a few steps from a capital's great hall door".
- **Proposal:** Change it to "to the Registrar at the great hall of their race's capital (the waystone plaza before 0.75.3, the guild house before 0.73.1)" once DD4-01 is fixed.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-03 | Low | docs | mounts.md §3.2 still treats ranged attackers, bows and a ranged class as future Phase-2 work

- **Verdict:** CONFIRMED — `mounts.md:446-455` reads as quoted; `items_crafting.md:1818` says the bow's consumer was delivered in Round 11; `classes.md:985-1003` (§6 "Explicitly deferred") no longer lists a ranged class, only Scout stealth via scout.md §8. The doc is the wrong side.
- **Where:** `docs/design/mounts.md:446-455`
- **What:** The paragraph "And it stops being a formality once ranged attackers exist" says that "today a rider mostly has to walk into a melee swing", that "bows are fully catalogued as a Phase-2 enabler (`items_crafting.md` §9)" and that "a ranged/stealth class direction is deferred Phase-2 work (`classes.md` §6)". The Scout, a bow class with homing arrows, shipped in Round 11 (scout.md; items_crafting.md §9 now opens "Its consumer is delivered in Round 11"), and classes.md §6 no longer lists a ranged class as deferred, only Scout stealth (scout.md §8). The same mounts.md section already counts on the Scout's Sprint (line 437). The doc is stale; the rule itself (damage dismounts) is unchanged.
- **Evidence:** mounts.md:448-451; items_crafting.md:1818-1820 "**Its consumer is delivered in Round 11**: the Scout's base kit opens with a bow shot"; classes.md:985-1003 (§6 lists cast times, shield abilities, auras, Scout poison/stealth, PvP DR; no ranged class); `mods/PLAYER/grug_abilities/scout.lua` registers the Scout kit.
- **Proposal:** Rewrite the paragraph in the present tense: ranged mobs (`dogshoot`) and Scout players can bring a rider down at range, which is the counterplay to permanent mount speed. Drop the Phase-2 references.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-04 | Low | docs | mounts.md §5 is a research and licence note that names mobs_redo as the mount base, which grug_mounts does not use

- **Verdict:** CORRECTED — The core claim holds: `rg 'mobs\.(attach|detach|drive|fly)|mount\.lua' mods/PLAYER/grug_mounts` finds nothing, and `entity.lua:445`, `:834` attach the player to grug_mounts' own controller, so "mobs_redo is the base" (`mounts.md:649`) is wrong. Two nuances the finder overstated: `mods/ENTITIES/mobs/mount.lua` is still vendored (that half of the sentence is true), and the Lord-of-the-Test bullet (`:661-669`) already restricts itself to "only the item-to-entity registration shape" and forbids the consumed-item lifecycle; it is stale (no mount item exists since Round 44, `:159-160`) rather than a recommendation of the retired pattern. Title adjusted accordingly.
- **Where:** `docs/design/mounts.md:636-675` (§5 "Reference implementations & licences"), also `:273-276` (§3 "Dismounting")
- **What:** §5 says "**mobs_redo is the base**: `mount.lua` is already vendored and loaded…", lists its `mobs.attach/detach/drive/fly` helpers as the land/flying split, and calls Lord-of-the-Test's "craftitem whose `on_place` spawns the mount entity" "the acquisition half we need" (with a caveat to reuse only the registration shape). `grug_mounts` uses none of that: its controller is its own entity (`entity.lua`, `player:set_attach` at `:445`, `:834`, its own gravity, jump and step code), with no call to `mobs.attach`, `mobs.detach`, `mobs.drive` or `mobs.fly`. Since Round 44 no mount item exists at all (§3: "Nothing hands out a mount item"). This is option and reference discussion left in a decided-design file, which AGENTS.md "Documentation layers" puts outside `docs/design/`, and part of it is now wrong. The doc is wrong.
- **Evidence:** `rg -n 'mobs\.(attach|detach|drive|fly)' mods/PLAYER/grug_mounts` → no hits; mounts.md:649-650 "**mobs_redo is the base**"; mounts.md:661-669 the LotT craftitem pattern; mounts.md:159-160 (§3) "Nothing hands out a mount item".
- **Proposal:** Remove §5, or move it to `docs/research/` or the archive. If the licence verdicts are still wanted, keep one line in the technical module guide. In §3 "Dismounting", keep the rule (a free neighbouring node) and drop the "pattern of the vendored mount.lua" pointer.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-05 | Low | docs | housing.md says the map marks a claim home with "H"; it is the home icon, and home_travel.md says so

- **Verdict:** CONFIRMED — `housing.md:407-408` says "H"; `providers.lua:150-154` emits `kind="home"` and `markers.lua:48-49` maps it to `grug_map_home.png`; `home_travel.md:105-107` says "the home icon … without a label since Round 44". The code follows home_travel.md; housing.md is stale.
- **Where:** `docs/design/housing.md:407-408` (§8); against `docs/design/home_travel.md:105-107` and `mods/PLAYER/grug_map/providers.lua:150-155`, `markers.lua:45-50`
- **What:** housing.md §8: "the map marks a claim home with 'H'". The provider emits `kind="home"` for a claim home, and `markers.texture` draws `grug_map_home.png` for that kind (the window uses the same texture, `window.lua:255`). home_travel.md correctly says "the home icon at the stone … without a label since Round 44". The two design files contradict each other; housing.md is stale.
- **Evidence:** providers.lua:151-154 `{id=selected.id, label="Your Claim Stone", … kind="home", personal=true, …}`; markers.lua:48-49 `return "grug_map_" .. marker.kind .. ".png"`.
- **Proposal:** "the map marks a claim home with the home icon at the stone (home_travel.md)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-06 | Low | docs | housing.md says the Housing Steward has a "+" map marker; it has its own steward icon

- **Verdict:** CONFIRMED — `housing.md:372` "The map shows it with a '+' marker."; `providers.lua:81-83` gives the Steward `grug_map_housing_steward.png`, `kind = "steward"`. The doc is wrong.
- **Where:** `docs/design/housing.md:371-372` (§7.2)
- **What:** "The map shows it with a '+' marker." The provider gives the Steward `texture = "grug_map_housing_steward.png"`, `kind = "steward"`; that icon has its own mask in `icon_masks.lua:1533` and is not a plus sign. The sentence dates from Round 25 (commit c27051c6c). The doc is stale.
- **Evidence:** `mods/PLAYER/grug_map/providers.lua:81-83` `elseif socket.role == "housing_manager" then label, texture = "Housing Steward", "grug_map_housing_steward.png"; kind = "steward"`.
- **Proposal:** "The map shows it with the Steward icon (world_map.md)."
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-07 | Low | docs | clans.md marks its rules as coordinator defaults the user "may overrule"

- **Verdict:** CONFIRMED — `clans.md:3-6` reads as quoted, and the source, `docs/planning/round76-plan.md:96` ("§3.1 Rules not covered by a ruling (coordinator defaults, the user may overrule)"), records no later confirmation; no confirmation was found in the plan, STATUS.md or BACKLOG.md. Whether the user has confirmed them is for the user to say.
- **Where:** `docs/design/clans.md:4-6`
- **What:** "§3.1 (coordinator defaults, built as written below; the user may overrule them)". In a decided-design file, this leaves the status of every rule below open. AGENTS.md "Documentation layers" allows only settled decisions in `docs/design/`. Other files record confirmation (expeditions.md:18-22: "The user confirmed on 2026-11-08 that these stay"). Either the user confirmed the clan defaults, or they belong in a TODO file.
- **Evidence:** clans.md:4-6, quoted above.
- **Proposal:** Record the confirmation (date) or move the unconfirmed defaults out. Drop "the user may overrule them".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium

### DD4-08 | Low | docs | parties.md keeps round-scoped and lane wording ("in this round", "for V1 … do not broaden")

- **Verdict:** CONFIRMED — `parties.md:7` "### Confirmed by the user", `:25` "No mana/rage bars in this round.", `:45` "Accepted defaults:", `:69-70` the V1 click-to-target instruction, all as quoted.
- **Where:** `docs/design/parties.md:7`, `:25`, `:45`, `:69-70`
- **What:** The file still carries the Round 14 decision log's structure and voice: the headings "Confirmed by the user" and "Accepted defaults" (quests.md retired exactly these names, see its "Former section names" table), "No mana/rage bars in this round." (line 25), and an instruction to implementers, "Party HUD rows need not support click-to-target for V1. Do not broaden the current spell ally/targeting rules merely because parties now exist." (lines 69-70). The rules are true of the code (no mana bars in `hud.lua`, no click-to-target), but the wording reads as a work order and a round note rather than a rule.
- **Evidence:** parties.md lines cited; `mods/PLAYER/grug_parties/hud.lua` draws health bars only.
- **Proposal:** Restate as rules ("The party HUD shows health only, no mana or rage bars"; "Party HUD rows are not click targets"), and rename the two headings by topic.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD4-09 | Low | docs | mounts.md §1 keeps lane ownership notes (CAP/GAME) in the stable rule

- **Verdict:** CONFIRMED — `mounts.md:40` "CAP authors separate bounded movement/rest regions…" and `:44-45` "GAME owns throttled movement and persistence; CAP owns the roof…" read as quoted; the display rules surround them.
- **Where:** `docs/design/mounts.md:40-47`
- **What:** "CAP authors separate bounded movement/rest regions for all four sockets. … GAME owns throttled movement and persistence; CAP owns the roof, enclosure and socket geometry." CAP and GAME are lane names from a past work plan, not game rules. The decided rule (displays move inside bounded regions, have no AI and cannot be ridden) is already stated around them.
- **Evidence:** mounts.md:40, 44-45.
- **Proposal:** Drop the lane sentences and keep the display rules.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Backlog notes

- `docs/design/settlements.md:745` (outside this package) still says the Registrar "now uses the dedicated core socket beside the waystone plaza approach", while the same file at :762-767 has the great hall door. This is the same drift as DD4-01/02 and belongs to whoever owns settlements.md.
- (verifier) `mods/CORE/grug_core/settlement_sockets.lua:343-344`: the code comment "The Expedition Registrar uses a dedicated core socket at the waystone plaza approach" is stale since 0.75.3; same drift as DD4-01.
- (verifier) `mods/MAPGEN/grug_mapgen/wp13/<capital>.lua` (six files, e.g. `highcourt.lua:693`): the Registrar comment reads "a few nodes outside the {'highcourt': \"king's hall\", 'dur_brannoc': …} door", a whole Python dict printed where one hall name was meant. The generator that wrote these compositions interpolated the mapping instead of the capital's entry. Comment only, no behaviour.
- `docs/design/expeditions.md:30-34` heads its first table "Most players inside" but writes "3 at every level" for one row and a bare "4" for the others. Taste only.
- `docs/design/mounts.md:102-104` "Persistent highest-tier metadata is the ownership authority": the code keeps one highest tier per mode (`grug_mounts:land_tier`, `flight_tier`, `water_tier`, `state.lua:5-7`), so "per mode" would be more exact.
- `docs/design/mounts.md:160-163` and `mods/PLAYER/grug_mounts/items.lua:1-8`: the six retired mount items stay registered "until the 0.44.0 migration step removes them", 36 releases later. Doc and code agree; whether the shim can go is a dead-code question for a code lane.
- `docs/design/sound.md:171-172`: the retired Glacial Ward's cue `cast_frost_ward` "still ships, a hook without a call site" (`grug_sounds/init.lua:68,184`, the `.ogg` present). The doc is accurate; the file and the spec are a dead-asset candidate for a code lane.

## Good to know

- Verifier spot-check of the "about 420 values, no mismatch" claim, ten values from eight documents, all matching: (1) mail.md 50 letters and body 4000 → `grug_mail/model.lua:24,32`; (2) parties.md 10 members and 120 s invitations → `grug_parties/init.lua:272,299`; (3) clans.md 100 members, 10 pending, 120 s, colour `#7ee081` → `grug_clans/init.lua:20,22`; (4) housing.md lump 26 160 s → `grug_housing/registry.lua:35`; (5) mounts.md prices 110/700/12 900/73 800 c → `grug_mounts/catalog.lua:13`; (6) mounts.md tier speeds 6.4/8/8/12 → `catalog.lua:31-40`; (7) boats.md speeds 4/8 → `catalog.lua:45,48`; (8) expeditions.md RESERVE 600 s → `grug_expeditions/catalogue.lua:27`; (9) quests.md 20 active / 10 tracked → `grug_quests/state.lua:5,373`; (10) sound.md crossfade 3 s → `grug_ambience/data.lua:49` (the module lives in `mods/CORE/`, not `PLAYER`); plus home_travel.md cooldown 1800 s → `grug_home/travel.lua:1`.
- The quest, Expedition, housing, mail, party and clan numbers are all held in one constant table each (`grug_quests/registry.lua`/`state.lua`, `grug_expeditions/catalogue.lua`/`loot.lua`/`traps.lua`, `grug_housing/registry.lua`, `grug_mail/model.lua`, `grug_parties/init.lua`, `grug_clans/init.lua:20`, `grug_mounts/catalog.lua`, `grug_ambience/data.lua`), so a re-check later is quick.
- The Expedition templates (`templates/*.exp`) are text with a binary tail; `rg -a '^(trap|ambush|encounter|particles)'` lists the authored rows, which match expeditions.md §13–§15 row for row.
- All markdown links and anchors in the 11 files resolve (checked with a slug script), and every "§n" cross-reference sampled (36) points at an existing heading.
- No "dungeon"/"instance"/"raid group" wording for Expeditions remains in the package's docs or in grug_expeditions, grug_quests, grug_parties or grug_mail. `grug_mobs:dungeon_master` and "dungeon stone" are an unrelated mob and node.

## Refuted

(none)
