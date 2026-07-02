# mobs_redo Briefing

- MIT License (TenPlus1, 2025) — forkable/embeddable. Some bundled textures CC BY-SA 3.0/CC0 (attribution needed if shipped).
- API-only mod (`mobs`); content in separate mods. init.lua loads api.lua, crafts.lua, mount.lua, spawner.lua.
- `mobs:register_mob(name, def)` at api.lua:3161. Key params: type (animal/monster/npc), hp_min/hp_max, armor (100=normal, LOWER=tankier), damage, reach, punch_interval, walk/run_velocity, view_range, drops, attack_type, visual/mesh/textures/animation, immune_to, follow, sounds, passive, runaway, pathfinding.
- Global `mob_difficulty` conf multiplier scales hp_max+damage.
- Spawning: `mobs:spawn(def)` (api.lua:3700) — nodes, neighbors, interval (30s), chance (higher=rarer), min/max_light, min/max_height, active_object_count, day_toggle, on_spawn, on_map_load. NOT biome-native; gate via nodes/height or `mobs:spawn_abm_check(pos,node,name)` (api.lua:3479, return true to BLOCK spawn) — natural place for faction-territory spawn gating.
- `mobs:add_mob(pos, def)` force-places specific mob — ideal for scripted merchant/quest NPCs.
- Attack types: dogfight, shoot (needs arrow via mobs:register_arrow), dogshoot, explode.
- Target selection: `general_attack()` api.lua:1679 — closest w/ line of sight; filters: attack_players, attack_animals/monsters/npcs, specific_attack (whitelist, supports group:), attack_ignore, group_attack, owner_loyal. `is_peaceful_player` check at api.lua:1697-1703 is template for "skip this player" logic.
- NPC/trading: `on_rightclick(self, clicker)` first-class def field → open formspec for trade/quests. type="npc" + passive=true. Taming/ownership built-in (self.owner, nametag).
- Drops: `{name=, chance=, min=, max=}`, chance N = 1-in-N; `drops` may be a FUNCTION drops(pos) → dynamic/level-scaled loot. on_die/on_death(self,killer) hooks for quest kill-credit.
- Faction-awareness: EASY — do_custom(self,dtime) every tick (stop_attack if same faction), on_spawn to tag self.faction, or (cleanest, since MIT) patch general_attack api.lua:1699-1706 with faction condition.
- Difficulty tiers: vary hp_max/armor/damage/view_range/group_attack + spawn chance/aoc per tier.
- Limits: mob_active_limit, mob_nospawn_range (12), count_mobs per-area.
- Full API docs in api.txt (register 35-284, hooks 338-389, spawn 504-565, drops 204-214).
