# DD2 — Design documents, combat and character, against the code

- Finder model: claude-opus-5-5
- Files read in full: 7 of 9 design files (combat_stats.md, progression.md, pvp.md, skill_trees.md, character_visuals.md, accounts.md, scout.md); skimmed: classes.md (§1, §2, §3 rage ledger, §6 read; the kit tables were left to C2), ability_targeting.md (links and open-question scan only, kits already matched by C2); not reached: none. Code read for the checks: `grug_core/combat.lua` (formulas, threat, central hp modifier, absorb), `status.lua`, `environment_damage.lua`, `grug_classes` (stats, scout, init, talents, all four `talent_graph_<class>.lua`), `grug_xp/init.lua`, `grug_pvp` (rules, init, view), `grug_mobs` (levels, env_damage, telegraph, aggro, pvp_garrison, spawn_policy, run_velocity/reach of every family), `grug_visuals` (looks, compose, apply, poses, head_look), `grug_accounts` (flow, model, page, init), `grug_achievements/catalog.lua`, `grug_alchemy/recipes.lua`, `grug_food`, `charge.lua`, mana regen in `grug_abilities/init.lua`.
- Summary: The numeric core is in very good shape. Every formula and anchor I recomputed matches: pools, HP/mana anchors, B(L), spell base, level scalar, level malus, K(L) and the 70 % cap, crit/dodge, fall/lava/drown/void shares, mob tiers and the king/General HP (32,436 / 28,203), the whole 180-cell XP table of progression.md (computed independently: all equal), the kill-XP and gathering examples, every one of the 109 talent nodes (id, type, ranks, gate, requires, effects, text) plus the count table, the six races' look options and statures, the pose and emote frame ranges, the head-look constants, the PvP timers and the account constants. The defects are stale prose: combat_stats.md still says the Charge stun is 1.5 s (code and classes.md: 0.75 s), states a "every melee mob ≥ 4.6 / every reach 3 m" rule that the mob roster no longer follows (and the Lava Seep breaks it with no documented exception, filed as a bug), and gives a mandatory 25–30 s TTD band that only holds at `grug_mob_damage_scale` 1.0 while the default is 1.5. pvp.md gives the wrong PvP quest level, scout.md carries open questions and dead line-number citations against the layer rule, and two small dead-code remnants of the old talent trees remain in the stat and mana accessors.

Values checked per document (each a number, list entry or rule compared with code):
- combat_stats.md: about 190 (anchors table 20, mob table 20, TTK formula inputs, §2 formulas 25, environment shares 14, mob tiers 18, speeds of 70 family definitions, reaches of 14 non-3 definitions, threat 8, telegraph 6, aggro/shot/dogshoot 6, food/potion/elixir 34, mana regen 4, nametag/frame 4, PvP 8, combat state 3, depth/pulse 6).
- progression.md: about 205 (the 180-cell per-level table, 14 band cells, 11 kill-XP examples, 5 gathering examples and the three ratios, point rule, gates, respec rule, level-up refill).
- skill_trees.md: about 900 node fields (109 nodes × id/type/ranks/gate/requires/effects/text), 8 tree totals, the 9-column count table, 7 windows, gate rows, POINTS_MAX, movement clamp and stance, absorb rules, respec prices, rage ruling 25.
- pvp.md: about 35 (flag timers, depth line, refusal text, death message, logout mark values, status ids, banner and frame texts, `/pvpstate` privilege, garrison levels and respawn ranges, quest level).
- character_visuals.md: about 75 (30 look-option counts, 6 statures and window, 7 pose clips ×2 ranges, 5 emote ranges, pose holds and gaps, head-look 5 constants, 21+1 achievements with tiers, inventory camera).
- accounts.md: about 20 (code length and alphabet, normalization, 30 s / 2 min / 5 in 10 min, reward columns and 18 cap, 32-hex id, 64-char name, every quoted player text).
- classes.md (sections above): about 25 (resource table, cast counts at L1/L60 for 5/6/8/10 %, rage ledger and its derived 13 swings / 20 s / 4th-5th-3rd swing, crit exclusions).
- scout.md: about 15 (L60 Dex/crit/dodge, bow curve 8/13/19/24, Sprint 15 %/300 s/+50 %/10 s, Sidestep +15/3 s, Loose cadence).
- ability_targeting.md: links only.
- Links: every relative link and every `#anchor` of all nine files resolves (24 anchors checked).

## Findings

### DD2-01 | Medium | bug | The Lava Seep chases at 3.4, below the decided 4.6 melee band, with no documented exception

- **Where:** `mods/ENTITIES/grug_mobs/lava_flan.lua:4-8` against `docs/design/combat_stats.md:555-564`
- **What:** combat_stats.md §3 decides that "every melee attacker has `run_velocity` at least 4.6 against the player's 4.0" and lists the exceptions (ranged 4.0, harmless critters 3.4, Bog Ooze 2.6, Kraken). The Lava Seep (`grug_mobs:lava_flan`) is `type = "monster"`, `attack_type = "dogfight"`, `attack_players = true`, yet `run_velocity = 3.4`, so a walking player outruns it. No design file names it as an exception (biomes_mobs.md lists it only as "Aggressive", l.719; world_zones.md l.1211-1212 and expeditions.md l.576/596 use it as a melee pack mob).
- **Evidence:** `lava_flan.lua:7` `attack_type = "dogfight", attack_players = true, group_attack = true,`; `:8` `reach = 3, pathfinding = 1, walk_velocity = 1, run_velocity = 3.4,`. Added 2026-09-19 (`7ab846cce`, Round 9), three days after the 4.6 band was ruled.
- **Proposal:** raise `run_velocity` to 4.6 like every other aggressive melee family (it keeps `walk_velocity = 1`, under `CALM_WALK_MAX`), or, if the slow seep is wanted, name it beside the Bog Ooze as the second deliberate slow tank in combat_stats.md §3. Expedition packs ("3 Lava Seeps") would feel the change; the user decides.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** medium (the slowness may be intended but is undocumented)

### DD2-02 | Medium | docs | combat_stats.md says Charge stuns for 1.5 s; the code and classes.md say 0.75 s

- **Where:** `docs/design/combat_stats.md:1599-1601`; code `mods/PLAYER/grug_abilities/charge.lua:44-46,173,178`; `docs/design/classes.md:782`
- **What:** §7 "Control and threat expiry" states "Charge stun lasts 1.5 seconds on accepted hits". Round 53 (`890abbfb6`) halved it: `local RAGE, STUN, HALT_AFTER = 15, 0.75, 2` with the comment "classes.md §3, the Charge row; round53-plan.md §4 WARRIOR: a 0.75 s stun", and classes.md's Charge row says "a 0.75 s stun". The doc side is wrong.
- **Evidence:** `charge.lua:173` `grug_core.set_stun(target, STUN)`, `:178` `grug_mobs.stun(ent, STUN)`.
- **Proposal:** change combat_stats.md l.1599 to 0.75 s (and keep "Halt runs 2 s longer" where it already lives).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-03 | Medium | docs | The mandatory 25–30 s "raw TTD" band and the 27 s pressure fit hold only at damage scale 1.0, not at the default 1.5

- **Where:** `docs/design/combat_stats.md:832-854` and `:1603-1613`; code `mods/CORE/grug_core/combat.lua:179-192,1590-1600`, `mods/ENTITIES/grug_mobs/levels.lua:127-141`, `settingtypes.txt:108`
- **What:** "Same-level TTK check" says `mob_pressure_scale` makes one mob hit `max(1, floor(P(L)/27))` and makes raw normal-mob TTD 25–30 s a mandatory band, with a table of 23–33 s values. But the pressure scale divides by the unscaled curve `2 + 0.3L + 0.005L²`, while the mob's actual damage is that curve ×`grug_mob_damage_scale` (default 1.5, `levels.lua:140`). The player therefore takes about 1.5 × P/27 per second: raw TTD ≈ 18 s for the neutral pool (Warrior ≈ 22, casters ≈ 14), outside the band. The "Global non-player damage scale" section says the setting multiplies all mob damage but never says that the TTK section's numbers are at 1.0. `tools/r36_r/numbers.py:13-15` models "the pressure fit at the default grug_mob_damage_scale 1.5", so the code intent is ×1.5; the doc table is the stale side.
- **Evidence:** `combat.lua:189-191` `fitted_hit = math.max(1, math.floor(grug_core.base_pool(level) / 27)); return (fitted_hit - 0.000001) / mob_damage` with `mob_damage` unscaled; `combat.lua:1597-1599` multiplies the incoming (already ×1.5) hp_change by it; `levels.lua:140` `grug_mobs.scale_attack_damage(round1(...))`.
- **Proposal:** state in the TTK section that the bands and the table are at scale 1.0 and give the default-1.5 TTD (or rebase the band to the default); fix the `combat.lua:179` comment ("fitted to 27 seconds") the same way. No code change unless the user wants 27 s at the default.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium

### DD2-04 | Low | docs | combat_stats.md §3 speed rule and its exception list are stale

- **Where:** `docs/design/combat_stats.md:555-564`
- **What:** "every melee attacker has run_velocity at least 4.6 … including retaliating passive prey"; only the Bandit Archer and "two Skeleton ranged families" stay at 4.0. Code: Frog (aggressive, dogfight) 3.4 (`frog.lua:37`), Tortoise (retaliates) 2 (`tortoise.lua:35`), Shore Crab (retaliates) 3.4 (`shore_crab.lua:29`), and at 4.0 also the Bog Witch (`bog_witch.lua:36`), the Poacher (`zero_asset_variants.lua:47`) and the Frost Stray (`zero_asset_variants.lua:84`). biomes_mobs.md documents the frog and tortoise speeds (l.1871-1872, Round 51), so combat_stats.md is the stale side (the Lava Seep is DD2-01).
- **Evidence:** the `run_velocity` lines quoted; biomes_mobs.md l.1871 "slow (walk 0.5, run 2)", l.1872 "hops (run 3.4)".
- **Proposal:** list the amphibians and shore crabs as named exceptions and widen the 4.0 list to "every ranged family (Bandit Archer, Poacher, Skeleton Archer and Raider, Frost Stray, Bog Witch)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-05 | Low | docs | "every ordinary explicit mob reach is 3 m" is no longer true

- **Where:** `docs/design/combat_stats.md:577-579`
- **What:** The doc names only the Kraken (4) and villagers (0) as exceptions. Code has reach 2 on the Frog, Tortoise, Stingray, Glowwing, Ember Wisp, the night-family wisp and three zero-asset variants, reach 4 on the Abyssal Shark and 6 on the dragons.
- **Evidence:** `rg 'reach *= *[0-9.]+' mods/ENTITIES/grug_mobs` minus `reach = 3`: `frog.lua:29`, `tortoise.lua:29`, `stingray.lua:28`, `glowwing.lua:9`, `ember_wisp.lua:17`, `night_families.lua:147`, `zero_asset_variants.lua:233,280,339` (2), `shark.lua:124` (4), `boss_dragons.lua:1170` (6).
- **Proposal:** reword to "3 m for ordinary ground melee mobs; small fliers and amphibians 2 m, the large swimmers 4 m, dragons 6 m" (or point to the per-family table in biomes_mobs.md).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-06 | Low | docs | pvp.md says PvP quests start at level 40; progression.md, quests.md and the data say 41

- **Where:** `docs/design/pvp.md:280-282` against `docs/design/progression.md:163`, `docs/design/quests.md:1155,1228,1240`
- **What:** pvp.md §7 "PvP quests start at level 40 (progression.md §4); since Round 65 the level-41 entry and supply quests open at 39". progression.md §4 (the file it cites) says "start at level 41, open from 39"; the quest data agrees (`elandor_ashenward_march.front.quests.json:123,145` `"level": 41`). pvp.md is wrong and contradicts itself in one sentence.
- **Evidence:** the quoted lines.
- **Proposal:** "PvP quests start at level 41 and open at 39 (acceptance at quest level − 2)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-07 | Low | docs | combat_stats.md §6 denies a high-level damage modifier that §2 decides

- **Where:** `docs/design/combat_stats.md:1549-1551` against `:121-125`; code `mods/CORE/grug_core/combat.lua:143-150,163-178`
- **What:** §6 says "No skull tier and no extra damage modifier for high-level mobs — mob damage already scales via the level formulas". Since Round 70 §2 decides the higher-mob-level damage malus `max(0.25, 1 − 0.05×gap)` on player damage, and `scale_player_damage` applies it. The §6 sentence is stale.
- **Evidence:** `combat.lua:149` `return math.max(0.25, 1 - 0.05 * gap)`.
- **Proposal:** "No skull tier; the only level modifier is §2's damage malus against higher-level mobs."
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-08 | Low | docs | scout.md carries open questions, proposals and pending tasks in a design file

- **Where:** `docs/design/scout.md:101-104`, `:313-326` (§6.3 "needs a rule"), `:435-476` (§8.1.4 "proposed"), `:549-610` (§8.2.4, §8.2.5, §8.2.7 "needs a rule", "Recommendation")
- **What:** AGENTS.md "Documentation layers" item 1: `docs/design/` holds decided design, "no open questions, no discussion". scout.md §6.3 ends "Rule needed before any mob speed changes", §2 says three decided files "need one sentence each — skill_trees.md §7 task 1 carries that, and it is not this lane's to write" (skill_trees.md §7 is now "Tasks (closed)", archived), and the deferred stealth chapter §8 holds two unanswered questions and a recommendation. The stealth research may stay, but its open questions belong in a `TODO-*.md` or BACKLOG.
- **Evidence:** the quoted headings and lines; `docs/design/skill_trees.md:969-973`.
- **Proposal:** move §6.3 and the open parts of §8 (8.1.4, 8.2.4, 8.2.5, 8.2.7) to a `TODO-scout-stealth.md` or a BACKLOG row and leave a one-line pointer; delete the §2 l.101-104 sentence (its task is closed).
- **Effort:** M · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-09 | Low | docs | scout.md cites line numbers and texts that no longer exist

- **Where:** `docs/design/scout.md:36,40,56,171,192,315,577,599,607,609`
- **What:** skill_trees.md §0 forbids line citations; scout.md still has them and they have drifted: `combat_stats.md:40-41` (the growth now sits at l.37-39), `combat_stats.md:249-252` "gives the bow gravity and draw time" (removed in Round 53; l.249 is environmental damage), `combat_stats.md:274-275` "a voluntary hostile action tags" (the tag rule was removed in Round 31; l.274 is drowning), `:331-348`, `:174-179`, `:154-161` (now shore height, armor and resolution text), `inventory_equipment.md:184-193` (now the ghost-icon rule, not armour classes), `classes.md:439-441` quoting "kiting IS the Mage fantasy" (the sentence exists nowhere in docs/design any more), `skill_trees.md` "§7, task 9" (archived).
- **Evidence:** `rg -n -i 'kiting IS' docs/design` hits only scout.md:315; `sed -n 182,195p docs/design/inventory_equipment.md`.
- **Proposal:** replace each with a section reference (§2 "Player formulas", inventory_equipment.md §2, etc.) or drop it; the §4.1 historical ballistic block can say "removed in Round 53" instead of citing.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-10 | Low | docs | character_visuals.md gives Hold Ground an "8 s buff"; it lasts 5 s

- **Where:** `docs/design/character_visuals.md:575-577`; code `mods/PLAYER/grug_abilities/kits_warrior.lua:199,208`
- **What:** "Hold Ground's guard holds 1.0 s, not the whole 8 s buff". Since Round 53 Hold Ground is a 5 s shield (skill_trees.md B4 "for 5 s"; `duration = 5`). The 1.0 s hold (`poses.lua:33`) is right; the 8 s is the old Hold Ground.
- **Evidence:** `kits_warrior.lua` Hold Ground values `duration = 5`, `add_absorb(user, "hold_ground", v.absorb, v.duration, ...)`.
- **Proposal:** "not the whole 5 s shield".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-11 | Low | docs | The achievement table in character_visuals.md §5b misses the Miner's Guild series

- **Where:** `docs/design/character_visuals.md:426-448`; code `mods/PLAYER/grug_achievements/catalog.lua:295-299`
- **What:** §5b presents "The set" of achievements; the catalogue has one more row, `miners_guild` ("Reach Reputation Rank %d with the Miner's Guild", tiers 3 / 6 / 10, cloaks Lamp Badge Workcloth, Lamp and Pick Workcloth, Lamplight Mantle; Round 58, `0e2c40483`). miners_guild.md owns its rules, but the list here reads as complete.
- **Evidence:** the catalogue lines quoted; the other 21 rows and tiers match exactly.
- **Proposal:** add the row with a pointer to miners_guild.md §6.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-12 | Low | docs | classes.md §1 says PvP hits keep combat 5 s; PvP contact keeps it 10 s

- **Where:** `docs/design/classes.md:151-152`; code `mods/CORE/grug_core/combat.lua:441-442`, `mods/PLAYER/grug_pvp/init.lua:162-163,180`
- **What:** "In combat = engaged with a live mob, or a PvP/other hit within the last 5 s". PvP contact marks both sides for `PVP_COMBAT_TIMEOUT = 10` (combat_stats.md §5 l.1335 and l.1378-1380, pvp.md §3 l.77-79 say 10 s). classes.md defers to combat_stats as owner but restates the number wrongly.
- **Evidence:** `grug_core.mark_in_combat(dealer, grug_core.PVP_COMBAT_TIMEOUT)`.
- **Proposal:** "…or another hit within the last 5 s (10 s after PvP contact)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-13 | Low | docs | skill_trees.md §6 sends the reader to a BACKLOG section that does not exist

- **Where:** `docs/design/skill_trees.md:962-966`
- **What:** "the round's open notes are in [BACKLOG](../planning/round53-plan.md#carry-overs) "Round 53 carry-overs"". The link labelled BACKLOG points into round53-plan.md (anchor resolves, `round53-plan.md:992`), and BACKLOG.md has no "Round 53 carry-overs" section (`rg -i 'round 53 carry' BACKLOG.md`: no hit). The second pointer ("Audit 2026-10 open questions", DP-06) is correct (`BACKLOG.md:466,491`).
- **Evidence:** the rg result above.
- **Proposal:** label the link "the Round 53 plan's carry-overs" or point at the BACKLOG rows that replaced them.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-14 | Low | dead | `combat_mana_regen_add` (the retired Cold Focus) is still read by the mana regeneration

- **Where:** `mods/PLAYER/grug_abilities/init.lua:147-161`
- **What:** `mana_regen_rate` reads the talent key `combat_mana_regen_add` and multiplies the in-combat rate by `1 + 2 * bonus`; its comment still says "Cold Focus raises the in-combat rate by 0.4 of itself per rank (x3 at 5/5, Round 35)". No talent node produces the key since Round 53, and combat_stats.md l.1461-1463 decides that "no talent changes it since Round 53 (the old Cold Focus went with the old trees)". Behaviour is correct (the bonus is always 0) but the branch and comment are dead.
- **Evidence:** `rg -n combat_mana_regen_add mods` → only `grug_abilities/init.lua:158`.
- **Proposal:** drop the bonus read, return `combat_rate + trinket`, fix the comment. Output identical.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### DD2-15 | Low | dead | Stat accessors read three talent keys and one status key nothing can produce

- **Where:** `mods/PLAYER/grug_classes/stats.lua:140-168`
- **What:** `get_crit_chance_raw` adds `crit_chance_add_window`, `get_dodge_chance_raw` adds `dodge_chance_window` and the status key `dodge_percent`, and `get_crit_chance` honours `crit_cap_override`. No talent graph registers these keys (they are not in `graph.SHARED_KEYS`, and the audit would reject an unknown key), and `status.lua:22-28` `MODIFIER_KEYS` rejects `dodge_percent`, so `status_modifier_sum(player, "dodge_percent")` returns 0 by its first line (`status.lua:89-92`). The comment "Lane X3 owns the time-limited cap overrides and will make those consumers use their raised caps" describes the old trees' windows. Design agrees nothing raises a cap (combat_stats.md l.17-18, l.222; skill_trees.md §2.10).
- **Evidence:** `rg -n 'crit_cap_override|crit_chance_add_window|dodge_chance_window' mods` → only stats.lua; status.lua `MODIFIER_KEYS` has no `dodge_percent`.
- **Proposal:** remove the four terms and the `math.max(30, …)`, make the crit cap a plain 0.30; keep `absorb_modifier(player, "dodge_percent")` (that one is live). Output identical.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

## Backlog notes

- combat_stats.md:673-676 "takes the registered ranged roster from 4 of 43 to 5 of 44" is a Round-era count in present tense; the roster has grown far past 44.
- combat_stats.md:3 "last revised 2026-09-18" while the file carries rulings up to 2026-11-16 (Round 80); the header date is misleading.
- accounts.md:9 "coordinator defaults, built as written below; the user may overrule them" and character_visuals.md:183 "a first version for the user to tune", :212 "a first version, tuned by the user", :177 "a coordinator decision, left as it is": mild discussion-tone in decided files.
- classes.md §1 l.151 and combat_stats.md §5 both define "in combat"; combat_stats owns it, so classes.md could just link instead of restating.
- `grug_classes.get_scout_dodge_cap()` (`grug_classes/scout.lua:51-53`) is a constant-30 function called with a player argument it ignores; it only exists for the retired Untouchable cap.

## Good to know

- Recomputed and equal to code: P(L) anchors and class HP (4 levels × 6 columns), spell base examples (9.5 / 14.5), 1H weapon 25/27/29 at ilvl 60/65/70, malus 0.85/0.75/0.50/0.25, K(L) shown-×10 form 200 + 5L / 85, crit 5 % + 0.05 %×Dex, dodge 0.1 %×Dex, Scout L60 11.4 % crit / 12.8 % dodge, Warrior 8.45 %, mob HP/damage/XP table, king 32,436 and General 28,203 HP, all 60 rows of progression.md's level table (XP to next and cumulative start), the band table and KE column (82/119/148/177/206/235/968), every kill-XP and gathering example, mana cast counts at L1/L60, the rage ledger arithmetic.
- skill_trees.md §2 tables are a faithful copy of the four `talent_graph_<class>.lua` files, field for field; the §2.9 counts (109 nodes, 263 ranks, 21/6/3/71/8) are right.
- pvp.md and `grug_pvp/rules.lua` agree on every timer (60/60/10/15/30 s), the depth line −501, the logout mark values `1`/`wear`, the refusal text, the death message and the status ids.
- accounts.md agrees with `grug_accounts` on every constant and every quoted player text.
- All relative links and all 24 anchors in the nine files resolve.
- Not checked: the enchant-ceiling percentages (+47/57/69 %) in combat_stats.md l.115-119 (item_tiers.md owns them), the nav/A* numbers of §4 beyond the constants named above, and the knockback fit test.
