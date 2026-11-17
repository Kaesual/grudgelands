# DD2 — Design documents, combat and character, against the code (verified)

- Finder model: claude-opus-5-5
- Verifier model: claude-opus-5-5
- Files read in full: 7 of 9 design files (combat_stats.md, progression.md, pvp.md, skill_trees.md, character_visuals.md, accounts.md, scout.md); skimmed: classes.md (§1, §2, §3 rage ledger, §6 read; the kit tables were left to C2), ability_targeting.md (links and open-question scan only, kits already matched by C2); not reached: none. Code read for the checks: `grug_core/combat.lua` (formulas, threat, central hp modifier, absorb), `status.lua`, `environment_damage.lua`, `grug_classes` (stats, scout, init, talents, all four `talent_graph_<class>.lua`), `grug_xp/init.lua`, `grug_pvp` (rules, init, view), `grug_mobs` (levels, env_damage, telegraph, aggro, pvp_garrison, spawn_policy, run_velocity/reach of every family), `grug_visuals` (looks, compose, apply, poses, head_look), `grug_accounts` (flow, model, page, init), `grug_achievements/catalog.lua`, `grug_alchemy/recipes.lua`, `grug_food`, `charge.lua`, mana regen in `grug_abilities/init.lua`.
- Summary: The numeric core is in very good shape. Every formula and anchor I recomputed matches: pools, HP/mana anchors, B(L), spell base, level scalar, level malus, K(L) and the 70 % cap, crit/dodge, fall/lava/drown/void shares, mob tiers and the king/General HP (32,436 / 28,203), the whole 180-cell XP table of progression.md (computed independently: all equal), the kill-XP and gathering examples, every one of the 109 talent nodes (id, type, ranks, gate, requires, effects, text) plus the count table, the six races' look options and statures, the pose and emote frame ranges, the head-look constants, the PvP timers and the account constants. The defects are stale prose: combat_stats.md still says the Charge stun is 1.5 s (code and classes.md: 0.75 s), states a "every melee mob ≥ 4.6 / every reach 3 m" rule that the mob roster no longer follows (and the Lava Seep breaks it with no documented exception, filed as a bug), and gives a mandatory 25–30 s TTD band that only holds at `grug_mob_damage_scale` 1.0 while the default is 1.5. pvp.md gives the wrong PvP quest level, scout.md carries open questions and dead line-number citations against the layer rule, and two small dead-code remnants of the old talent trees remain in the stat and mana accessors.
- Verification note: static reading at `4cb49044e`; each Low finding checked with one search or one read of the cited sentence.

Values checked per document (finder's counts, not re-counted):
- combat_stats.md: about 190; progression.md: about 205; skill_trees.md: about 900 node fields; pvp.md: about 35; character_visuals.md: about 75; accounts.md: about 20; classes.md (sections above): about 25; scout.md: about 15; ability_targeting.md: links only.
- Links: every relative link and every `#anchor` of all nine files resolves (24 anchors checked).

## Findings

### DD2-01 | Medium | bug | The Lava Seep chases at 3.4, below the decided 4.6 melee band, with no documented exception

- **Verdict:** CONFIRMED — the rule's wording is unconditional ("every melee attacker has `run_velocity` **at least 4.6** against the player's 4.0, including retaliating passive prey …", `combat_stats.md:555-564`, exceptions: Bandit Archer and two Skeleton ranged families 4.0, harmless critters 3.4, Bog Ooze 2.6, Kraken); `lava_flan.lua:4-8` is `type = "monster"`, `attack_type = "dogfight"`, `attack_players = true`, `run_velocity = 3.4`, and nothing in `grug_mobs` raises it (registration only scales `_grug_speed_base` for slows/evade, `init.lua:418-533`). No design file names it: `rg -i "seep|flan" docs/design` hits only biomes_mobs.md's "Aggressive" list, world_zones.md and expeditions.md (melee pack). The code side is wrong against the rule as written (rule committed `4e1bbcc96`, 2026-09-17; the seep added `7ab846cce`, 2026-09-19).
- **Where:** `mods/ENTITIES/grug_mobs/lava_flan.lua:4-8` against `docs/design/combat_stats.md:555-564`
- **What:** A walking player outruns the Lava Seep, an aggressive deep melee pack mob, contrary to the decided band; no exception documents it.
- **Evidence:** `lava_flan.lua:7` `attack_type = "dogfight", attack_players = true, group_attack = true,`; `:8` `reach = 3, pathfinding = 1, walk_velocity = 1, run_velocity = 3.4,`.
- **Proposal:** raise `run_velocity` to 4.6 like every other aggressive melee family (it keeps `walk_velocity = 1`, under `CALM_WALK_MAX`), or, if the slow seep is wanted, name it beside the Bog Ooze in combat_stats.md §3. Expedition packs ("3 Lava Seeps") would feel the change; the user decides.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** medium (the slowness may be intended but is undocumented)

### DD2-02 | Medium | docs | combat_stats.md says Charge stuns for 1.5 s; the code and classes.md say 0.75 s

- **Verdict:** CONFIRMED — `combat_stats.md:1599-1600` "Charge stun lasts 1.5 seconds on accepted hits"; `charge.lua:46` `local RAGE, STUN, HALT_AFTER = 15, 0.75, 2`, used at `:173` (`grug_core.set_stun`) and `:178` (`grug_mobs.stun`); classes.md's Charge row (`:782`) says "a 0.75 s stun". The document is the wrong side.
- **Where:** `docs/design/combat_stats.md:1599-1601`; code `mods/PLAYER/grug_abilities/charge.lua:44-46,173,178`; `docs/design/classes.md:782`
- **What:** §7 "Control and threat expiry" still carries the pre-Round-53 value.
- **Evidence:** `charge.lua:173` `grug_core.set_stun(target, STUN)`, `:178` `grug_mobs.stun(ent, STUN)`.
- **Proposal:** change combat_stats.md l.1599 to 0.75 s.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-03 | Medium | docs | The mandatory 25–30 s "raw TTD" band and the 27 s pressure fit hold only at damage scale 1.0, not at the default 1.5

- **Verdict:** CONFIRMED — the band's wording ("raw normal-mob TTD **25–30 s**", mandatory, KAT ±10 %, table 23–33 s, `combat_stats.md:839-850`) carries no scale condition; the setting defaults to 1.5 (`settingtypes.txt:108`, `combat_stats.md:1605-1606`, `levels.lua:127`). `mob_pressure_scale` (`combat.lua:182-192`) divides by the unscaled curve `2 + 0.3L + 0.005L²`, while the stored mob damage is that curve ×1.5 (`levels.lua:132-141`), and `combat.lua:1596-1598` multiplies the already-scaled hit, so the player takes ≈ 1.5 × `floor(P/27)` per second: raw TTD ≈ 18 s neutral (table values ÷ 1.5: Warrior ≈ 22, Mage ≈ 17). History agrees: the band was written 2026-09-17 (`654bd26fe`), the scale added 2026-09-22 (`4cc9d126f`). The document is the stale side unless the user wants 27 s at the default.
- **Where:** `docs/design/combat_stats.md:832-854` and `:1603-1613`; code `mods/CORE/grug_core/combat.lua:179-192,1588-1600`, `mods/ENTITIES/grug_mobs/levels.lua:127-141`, `settingtypes.txt:108`
- **What:** The TTK section's pressure fit and TTD band are stated as if they were the live game; at the shipped default the raw TTD is about two thirds of the band, and the "Global non-player damage scale" section never says the TTK numbers are at 1.0. `tools/r36_r/numbers.py:13-15,63,74-75` models "the pressure fit at the default `grug_mob_damage_scale` 1.5", so the ×1.5 intake is the working model.
- **Evidence:** `combat.lua:189-191` `fitted_hit = math.max(1, math.floor(grug_core.base_pool(level) / 27)); return (fitted_hit - 0.000001) / mob_damage` with `mob_damage` unscaled; `levels.lua:140` `grug_mobs.scale_attack_damage(round1(...))`.
- **Proposal:** state in the TTK section that the bands and the table are at scale 1.0 and give the default-1.5 TTD (or rebase the band to the default); fix the `combat.lua:179` and `:1588-1590` comments ("fitted to 27 seconds") the same way. No code change unless the user wants 27 s at the default (then the fit divides by the scaled curve, a balance change).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-04 | Low | docs | combat_stats.md §3 speed rule and its exception list are stale

- **Verdict:** CONFIRMED — `frog.lua:27,30,37` monster, dogfight, `run_velocity = 3.4`; the 4.0 roster in code (`zero_asset_variants.lua:47,84`, `bog_witch.lua`) is wider than the rule's exception list, which already names the Poacher and Frost Stray only in the following "Roaming pace" bullet.
- **Where:** `docs/design/combat_stats.md:555-564`
- **What:** "every melee attacker has run_velocity at least 4.6 … including retaliating passive prey"; code: Frog 3.4, Tortoise 2, Shore Crab 3.4, and at 4.0 also the Bog Witch, the Poacher and the Frost Stray. biomes_mobs.md documents the frog and tortoise speeds (l.1871-1872), so combat_stats.md is the stale side (the Lava Seep is DD2-01).
- **Evidence:** the `run_velocity` lines quoted.
- **Proposal:** list the amphibians and shore crabs as named exceptions and widen the 4.0 list to every ranged family.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-05 | Low | docs | "every ordinary explicit mob reach is 3 m" is no longer true

- **Verdict:** CONFIRMED — `rg 'reach *= *[0-9.]+' mods/ENTITIES/grug_mobs` minus 3 lists exactly the cited reach-2 families, shark 4, kraken 4, dragons 6, villagers 0.
- **Where:** `docs/design/combat_stats.md:577-579`
- **What:** The doc names only the Kraken (4) and villagers (0) as exceptions. Code has reach 2 on the Frog, Tortoise, Stingray, Glowwing, Ember Wisp, the night-family wisp and three zero-asset variants, reach 4 on the Abyssal Shark and 6 on the dragons.
- **Evidence:** `frog.lua:29`, `tortoise.lua:29`, `stingray.lua:28`, `glowwing.lua:9`, `ember_wisp.lua:17`, `night_families.lua:147`, `zero_asset_variants.lua:233,280,339`, `shark.lua:124`, `boss_dragons.lua:1170`.
- **Proposal:** reword to "3 m for ordinary ground melee mobs; small fliers and amphibians 2 m, the large swimmers 4 m, dragons 6 m" (or point to biomes_mobs.md).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-06 | Low | docs | pvp.md says PvP quests start at level 40; progression.md, quests.md and the data say 41

- **Verdict:** CONFIRMED — `pvp.md:280` "**PvP quests start at level 40**" against `progression.md:163` "start at level 41, open from 39" and the same sentence's own "level-41 entry and supply quests".
- **Where:** `docs/design/pvp.md:280-282` against `docs/design/progression.md:163`, `docs/design/quests.md:1155,1228,1240`
- **What:** pvp.md is wrong and contradicts itself in one sentence.
- **Evidence:** the quoted lines.
- **Proposal:** "PvP quests start at level 41 and open at 39 (acceptance at quest level − 2)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-07 | Low | docs | combat_stats.md §6 sentence on high-level mobs reads as denying §2's level malus

- **Verdict:** CORRECTED — the sentence (`combat_stats.md:1549-1551`) is about *mob* damage ("no extra damage modifier for high-level mobs — mob damage already scales via the level formulas"), which stays true; it does not strictly contradict §2's malus on *player* damage against higher-level mobs (`combat.lua:143-150`). It is ambiguous rather than wrong.
- **Where:** `docs/design/combat_stats.md:1549-1551` against `:121-125`; code `mods/CORE/grug_core/combat.lua:143-150,163-178`
- **What:** A reader can take "no extra damage modifier for high-level mobs" to exclude the Round 70 malus.
- **Proposal:** "No skull tier and no extra damage bonus for high-level mobs; the only level modifier is §2's malus on player damage against higher-level mobs."
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-08 | Low | docs | scout.md carries open questions, proposals and pending tasks in a design file

- **Verdict:** CONFIRMED — `scout.md:101-104` (task sentence), `:313` and `:324` (§6.3 "needs a rule", "Rule needed before any mob speed changes"), `:549`, `:564`, `:597` ("needs a rule"), `:581` ("Recommendation").
- **Where:** `docs/design/scout.md:101-104`, `:313-326`, `:435-476`, `:549-610`
- **What:** AGENTS.md "Documentation layers": `docs/design/` holds decided design, no open questions. The open parts belong in a `TODO-*.md` or BACKLOG.
- **Evidence:** the quoted headings and lines; `docs/design/skill_trees.md:969-973`.
- **Proposal:** move §6.3 and the open parts of §8 to a `TODO-scout-stealth.md` or a BACKLOG row and leave a one-line pointer; delete the §2 l.101-104 sentence.
- **Effort:** M · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-09 | Low | docs | scout.md cites line numbers and texts that no longer exist

- **Verdict:** CONFIRMED — `rg -n -i 'kiting IS' docs/design` hits only `scout.md:315`; the other citations were not re-read.
- **Where:** `docs/design/scout.md:36,40,56,171,192,315,577,599,607,609`
- **What:** skill_trees.md §0 forbids line citations; scout.md still has them and they have drifted (combat_stats.md, inventory_equipment.md, classes.md quotes, skill_trees.md "§7, task 9").
- **Evidence:** the rg above.
- **Proposal:** replace each with a section reference or drop it.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-10 | Low | docs | character_visuals.md gives Hold Ground an "8 s buff"; it lasts 5 s

- **Verdict:** CONFIRMED — `character_visuals.md:576` "not the whole 8 s buff"; `kits_warrior.lua:199` `duration = 5`; classes.md Hold Ground row "for 5 s".
- **Where:** `docs/design/character_visuals.md:575-577`; code `mods/PLAYER/grug_abilities/kits_warrior.lua:199,208`
- **What:** The 1.0 s guard hold is right; the 8 s is the old Hold Ground.
- **Proposal:** "not the whole 5 s shield".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-11 | Low | docs | The achievement table in character_visuals.md §5b misses the Miner's Guild series

- **Verdict:** CONFIRMED — `catalog.lua:151` has the `miners_guild_1` cloak; `rg -i miner docs/design/character_visuals.md` finds nothing.
- **Where:** `docs/design/character_visuals.md:426-448`; code `mods/PLAYER/grug_achievements/catalog.lua:295-299`
- **What:** §5b reads as the complete set but lacks `miners_guild` (tiers 3/6/10, three cloaks).
- **Proposal:** add the row with a pointer to miners_guild.md §6.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-12 | Low | docs | classes.md §1 says PvP hits keep combat 5 s; PvP contact keeps it 10 s

- **Verdict:** CONFIRMED — `classes.md:151-152` "a PvP/other hit within the last 5 s"; `combat.lua:442` `grug_core.PVP_COMBAT_TIMEOUT = 10`.
- **Where:** `docs/design/classes.md:151-152`; code `mods/CORE/grug_core/combat.lua:441-442`, `mods/PLAYER/grug_pvp/init.lua:162-163,180`
- **What:** classes.md defers to combat_stats as owner but restates the number wrongly.
- **Proposal:** "…or another hit within the last 5 s (10 s after PvP contact)", or just link.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-13 | Low | docs | skill_trees.md §6 sends the reader to a BACKLOG section that does not exist

- **Verdict:** CONFIRMED — `rg -i 'round 53 carry' BACKLOG.md`: no hit; `skill_trees.md:964` labels a round53-plan.md link "BACKLOG".
- **Where:** `docs/design/skill_trees.md:962-966`
- **What:** The link labelled BACKLOG points into round53-plan.md; BACKLOG.md has no "Round 53 carry-overs" section.
- **Proposal:** label the link "the Round 53 plan's carry-overs" or point at the BACKLOG rows that replaced them.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD2-14 | Low | dead | `combat_mana_regen_add` (the retired Cold Focus) is still read by the mana regeneration

- **Verdict:** CONFIRMED — `rg -n combat_mana_regen_add mods` → only `grug_abilities/init.lua:158`.
- **Where:** `mods/PLAYER/grug_abilities/init.lua:147-161`
- **What:** No talent node produces the key since Round 53; the branch and its Cold Focus comment are dead (bonus always 0).
- **Proposal:** drop the bonus read, return `combat_rate + trinket`, fix the comment. Output identical.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

### DD2-15 | Low | dead | Stat accessors read three talent keys and one status key nothing can produce

- **Verdict:** CONFIRMED — `rg -n 'crit_cap_override|crit_chance_add_window|dodge_chance_window' mods` → only `grug_classes/stats.lua:146,153,162`; `status.lua:22-28` `MODIFIER_KEYS` has no `dodge_percent`.
- **Where:** `mods/PLAYER/grug_classes/stats.lua:140-168`
- **What:** `get_crit_chance_raw`, `get_dodge_chance_raw` and `get_crit_chance` read keys no talent graph or status can produce.
- **Proposal:** remove the four terms and the `math.max(30, …)`, make the crit cap a plain 0.30; keep `absorb_modifier(player, "dodge_percent")` (live). Output identical.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** compatible
- **Confidence:** high

## Backlog notes

- combat_stats.md:673-676 "takes the registered ranged roster from 4 of 43 to 5 of 44" is a Round-era count in present tense; the roster has grown far past 44.
- combat_stats.md:3 "last revised 2026-09-18" while the file carries rulings up to 2026-11-16 (Round 80); the header date is misleading.
- accounts.md:9 and character_visuals.md:177,183,212: mild discussion-tone in decided files.
- classes.md §1 l.151 and combat_stats.md §5 both define "in combat"; combat_stats owns it, so classes.md could just link instead of restating.
- `grug_classes.get_scout_dodge_cap()` (`grug_classes/scout.lua:51-53`) is a constant-30 function called with a player argument it ignores; it only exists for the retired Untouchable cap.

## Good to know

- Recomputed and equal to code (finder): P(L) anchors and class HP, spell base examples, 1H weapon 25/27/29 at ilvl 60/65/70, malus 0.85/0.75/0.50/0.25, K(L), crit and dodge, Scout and Warrior L60 values, mob HP/damage/XP table, king 32,436 and General 28,203 HP, all 60 rows of progression.md's level table, the band table and KE column, every kill-XP and gathering example, mana cast counts at L1/L60, the rage ledger arithmetic.
- skill_trees.md §2 tables are a faithful copy of the four `talent_graph_<class>.lua` files; the §2.9 counts are right.
- pvp.md and `grug_pvp/rules.lua` agree on every timer, the depth line −501, the logout mark values, the refusal text, the death message and the status ids.
- accounts.md agrees with `grug_accounts` on every constant and every quoted player text.
- Not checked: the enchant-ceiling percentages in combat_stats.md l.115-119, the nav/A* numbers of §4 beyond the named constants, and the knockback fit test.

## Refuted

(none)
