-- Function-style isolated KAT for the Round 9 core trinket consumers.

return function(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"r9 trinkets KAT requires an absolute repository root")
	local globals = {"core", "grug_core", "grug_classes", "grug_abilities",
		"grug_gear", "grug_trinkets"}
	local saved = {}
	for index = 1, #globals do
		local name = globals[index]
		saved[index] = {name = name, present = rawget(_G, name) ~= nil,
			value = rawget(_G, name)}
	end
	local old_time = os.time

	local function restore()
		os.time = old_time
		for index = 1, #saved do
			local row = saved[index]
			if row.present then rawset(_G, row.name, row.value)
			else rawset(_G, row.name, nil) end
		end
	end

	local function run()
		local failures = {}
		local function check(value, message)
			if not value then failures[#failures + 1] = message end
		end
		local function close(left, right)
			return math.abs(left - right) < 0.000001
		end
		local function source(path)
			local file = assert(io.open(repo .. "/" .. path, "rb"))
			local bytes = file:read("*a")
			assert(file:close())
			return bytes
		end
		local function production_chunk(path, first_token, last_token, suffix)
			local bytes = source(path)
			local first = assert(bytes:find(first_token, 1, true), first_token)
			local last = assert(bytes:find(last_token, first + #first_token, true),
				last_token)
			return bytes:sub(first, last - 1) .. (suffix or "")
		end
		local function execute(bytes, environment)
			setmetatable(environment, {__index = _G})
			local chunk = assert(loadstring(bytes))
			setfenv(chunk, environment)
			return chunk()
		end

		local Stack = {}
		Stack.__index = Stack
		local function stack(name)
			return setmetatable({name = name or "", count = name and 1 or 0}, Stack)
		end
		function Stack:is_empty() return self.name == "" end
		function Stack:get_name() return self.name end
		function Stack:take_item(amount)
			self.count = math.max(0, self.count - (amount or 1))
			if self.count == 0 then self.name = "" end
			return self
		end

		local equipment_callback
		local leave_callback
		local now = 1000
		os.time = function() return now end
		rawset(_G, "core", {
			registered_items = {},
			register_craftitem = function(name, definition)
				core.registered_items[name] = definition
			end,
			colorize = function(_, text) return text end,
			register_on_leaveplayer = function(callback) leave_callback = callback end,
		})
		rawset(_G, "grug_core", {
			register_on_equipment_change = function(callback)
				equipment_callback = callback
			end,
		})
		local rage, mana, absorbs = {}, {}, {}
		rawset(_G, "grug_abilities", {
			add_rage = function(player, amount)
				local name = player:get_player_name()
				rage[name] = math.min(100, (rage[name] or 0) + amount)
			end,
			restore_mana = function(player, amount)
				local name = player:get_player_name()
				mana[name] = math.min(player.max_mana,
					(mana[name] or player.mana or 0) + amount)
			end,
		})
		rawset(_G, "grug_classes", {
			get_max_hp = function(player) return player.max_hp end,
			get_max_mana = function(player) return player.max_mana end,
			get_class_def = function(player) return {resource = player.resource} end,
		})
		grug_core.set_absorb = function(player, amount, duration)
			absorbs[#absorbs + 1] = {player = player:get_player_name(),
				amount = amount, duration = duration}
		end
		grug_core.get_equipped_weapon = function() return stack("kat:weapon") end
		rawset(_G, "grug_gear", {})
		dofile(repo .. "/mods/ITEMS/grug_gear/trinkets.lua")
		dofile(repo .. "/mods/PLAYER/grug_trinkets/init.lua")
		check(type(equipment_callback) == "function",
			"equipment-change cache callback was not registered")
		check(type(leave_callback) == "function",
			"leave cleanup callback was not registered")

		local Meta = {}
		Meta.__index = Meta
		function Meta:get_string(key) return self.values[key] or "" end
		function Meta:set_string(key, value) self.values[key] = value end
		local function player(name, resource)
			local result = {name = name, slots = {}, hp = 100, max_hp = 200,
				mana = 100, max_mana = 500, resource = resource or "rage",
				meta = setmetatable({values = {}}, Meta), reads = 0}
			result.inventory = {get_stack = function(_, listname)
				result.reads = result.reads + 1
				return stack(result.slots[listname])
			end}
			function result:get_player_name() return self.name end
			function result:is_player() return true end
			function result:get_inventory() return self.inventory end
			function result:get_meta() return self.meta end
			function result:get_hp() return self.hp end
			function result:set_hp(value) self.hp = value end
			function result:get_properties() return {hp_max = self.max_hp} end
			return result
		end
		local function equip(target, first, second)
			target.slots.grug_trinket1 = first
			target.slots.grug_trinket2 = second
			equipment_callback(target, nil)
		end
		local function custom(name, identity, kind, value, stacking, cap,
				cooldown, extra_rage)
			core.registered_items[name] = {
				_grug_trinket_identity = identity,
				_grug_trinket_kind = kind,
				_grug_trinket_value = value,
				_grug_trinket_stacking = stacking,
				_grug_trinket_cap = cap,
				_grug_trinket_cooldown = cooldown,
				_grug_trinket_rage = extra_rage,
			}
			return name
		end

		local subject = player("subject", "rage")
		local mana_other = custom("kat:manawell_other", "manawell_other",
			"mana_regen", 0.75, "additive", 1)
		equip(subject, "grug_gear:manawell_t6", mana_other)
		check(close(grug_core.trinket_mana_regen(subject), 1),
			"Manawell did not add and cap at 1 Mana/s")
		local mana_environment = {
			grug_abilities = {},
			grug_core = {
				get_player_level = function() return 10 end,
				trinket_mana_regen = grug_core.trinket_mana_regen,
			},
			grug_classes = {
				get_max_mana = function() return 500 end,
				get_race_perk = function() return 1 end,
				get_talent_bonus = function() return 0 end,
			},
		}
		execute(production_chunk("mods/PLAYER/grug_abilities/init.lua",
			"function grug_abilities.mana_regen_rate",
			"\nfunction grug_abilities.mana_cost"), mana_environment)
		check(close(mana_environment.grug_abilities.mana_regen_rate(
			subject, false), 3.5),
			"production Mana-regeneration seam did not add cached Manawell")
		local reads = subject.reads
		grug_core.trinket_mana_regen(subject)
		grug_core.trinket_mana_regen(subject)
		check(subject.reads == reads,
			"Manawell hot-path read equipment after cache rebuild")
		equip(subject, "grug_gear:manawell_t6", "grug_gear:manawell_t6")
		check(close(grug_core.trinket_mana_regen(subject), 0.5),
			"same trinket identity applied twice across both slots")

		equip(subject, "grug_gear:manawell_t6", "grug_gear:mercy_seal_t6")
		check(close(grug_core.trinket_mana_regen(subject), 0.5) and
			close(grug_core.trinket_outgoing_heal(subject, 100), 106),
			"different Manawell and Mercy kinds did not coexist")
		local mercy_other = custom("kat:mercy_other", "mercy_other",
			"outgoing_healing", 8, "additive", 12)
		equip(subject, "grug_gear:mercy_seal_t6", mercy_other)
		check(close(grug_core.trinket_outgoing_heal(subject, 100), 112),
			"Mercy Seal did not add and cap at 12%")
		local heal_environment = {
			grug_core = {
				scale_player_value = function(_, amount) return amount end,
				get_crit_chance = function() return 0 end,
				add_heal_threat = function() end,
				trinket_outgoing_heal = grug_core.trinket_outgoing_heal,
			},
			effective_heal_callbacks = {},
			crit_particles = function() end,
		}
		execute(production_chunk("mods/CORE/grug_core/combat.lua",
			"function grug_core.heal_player",
			"\n--\n-- Absorb shields"), heal_environment)
		local heal_target = player("heal_target", "mana")
		heal_target.hp = 50
		local healed = heal_environment.grug_core.heal_player(subject,
			heal_target, 100, {no_crit = true})
		check(healed == 112 and heal_target.hp == 162,
			"production outgoing-heal seam did not apply Mercy before settlement")

		local beat_other = custom("kat:beat_other", "beat_other",
			"battlebeat_rage", 3, "additive", 4)
		equip(subject, "grug_gear:battlebeat_t6", beat_other)
		grug_core.trinket_weapon_hit(subject)
		check(close(rage.subject, 4),
			"Battlebeat did not add fractional Rage and cap at 4 per hit")
		grug_core.get_equipped_weapon = function() return nil end
		grug_core.trinket_weapon_hit(subject)
		check(close(rage.subject, 4),
			"Battlebeat fired without an equipped weapon")
		grug_core.get_equipped_weapon = function() return stack("kat:weapon") end
		-- Execute the real authoritative settlement. At the Rage cap a proc must
		-- pay its cost before both the base swing Rage and Battlebeat settle.
		equip(subject, "grug_gear:battlebeat_t6", nil)
		rage.subject = 100
		local swing_finish
		local swing_environment = {
			grug_core = {
				register_native_melee_handler = function(_, finish)
					swing_finish = finish
				end,
				combat_debug_due = function() return false end,
				combat_debug_log = function() end,
				trinket_weapon_hit = grug_core.trinket_weapon_hit,
				add_threat = function() end,
			},
			grug_abilities = {
				add_rage = grug_abilities.add_rage,
				reset_charge = function() end,
			},
			spend = function(player_object, cost)
				local name = player_object:get_player_name()
				if (rage[name] or 0) < (cost.rage or 0) then return false end
				rage[name] = rage[name] - (cost.rage or 0)
				return true
			end,
			swing_rage = function() return 8 end,
			core = {log = function() end},
		}
		execute(production_chunk("mods/PLAYER/grug_abilities/init.lua",
			"local function finish_authoritative_swing",
			"\nlocal function debug_target_name"), swing_environment)
		check(type(swing_finish) == "function",
			"production authoritative-swing finish did not register")
		if swing_finish then
			swing_finish({player = subject,
				proc = {id = "mighty_blow", cost = {rage = 25}}},
				{landed = true, grant_rage = true})
		end
		check(rage.subject == 85,
			"production proc settlement credited Battlebeat before its Rage cost")

		local light_other = custom("kat:light_other", "light_other",
			"last_light_absorb", 8, "highest", nil, 120)
		equip(subject, "grug_gear:last_light_t3", light_other)
		local post_hit_callback
		execute(production_chunk("mods/CORE/grug_core/combat.lua",
			"core.register_on_player_hpchange(function(player, hp_change, reason)\n" ..
				"\tif grug_core.trinket_after_hit",
			"\nend, false)", "\nend, false)"), {
			core = {register_on_player_hpchange = function(callback)
				post_hit_callback = callback
			end},
			grug_core = {trinket_after_hit = grug_core.trinket_after_hit},
		})
		check(type(post_hit_callback) == "function",
			"production post-hit callback did not register")
		subject.hp = 60
		post_hit_callback(subject, -20, {type = "punch"})
		check(#absorbs == 1 and absorbs[1].amount == 16 and
			absorbs[1].duration == 120,
			"Last Light did not use highest 8% value and 120 s lifetime")
		post_hit_callback(subject, -1, {type = "punch"})
		check(#absorbs == 1, "Last Light ignored its shared cooldown")
		now = now + 121
		subject.hp = 20
		post_hit_callback(subject, -20, {type = "punch"})
		check(#absorbs == 1, "Last Light saved a lethal hit")
		subject.hp = 60
		post_hit_callback(subject, -20, {type = "punch"})
		check(#absorbs == 2, "Last Light did not become ready after 120 s")

		local reclaim_other = custom("kat:reclaim_other", "reclaim_other",
			"reclaimer", 4, "highest", nil, 10, 6)
		equip(subject, "grug_gear:reclaimers_mark_t3", reclaim_other)
		subject.hp = 100
		rage.subject = 0
		grug_core.trinket_xp_kill(subject)
		check(subject.hp == 108 and rage.subject == 6,
			"Reclaimer Warrior restore did not use highest HP/Rage row")
		grug_core.trinket_xp_kill(subject)
		check(subject.hp == 108 and rage.subject == 6,
			"Reclaimer ignored its shared 10 s cooldown")
		local dead = player("dead", "rage")
		dead.hp = 0
		equip(dead, "grug_gear:reclaimers_mark_t6", nil)
		local kill_environment = {
			grug_mobs = {
				kill_xp = function() return 100 end,
				cleanup_xp_participants = function() end,
			},
			grug_xp = {
				get_level = function() return 10 end,
				add_xp = function() end,
			},
			grug_factions = {same_faction = function() return false end},
			grug_core = {trinket_xp_kill = grug_core.trinket_xp_kill},
			core = {
				get_player_by_name = function(name)
					return name == "dead" and dead or nil
				end,
				chat_send_player = function() end,
				colorize = function(_, text) return text end,
			},
			within_xp_range = function() return true end,
		}
		execute(production_chunk("mods/ENTITIES/grug_mobs/init.lua",
			"function grug_mobs.award_kill_xp",
			"\n-- Kill-loot hooks"), kill_environment)
		kill_environment.grug_mobs.award_kill_xp({
			_grug_level = 20,
			temp = {grug_xp_participants = {dead = true}},
			object = {get_pos = function() return {x = 0, y = 0, z = 0} end},
		})
		check(dead.hp == 0 and (rage.dead or 0) == 0 and
			next(dead.meta.values) == nil,
			"production kill-XP seam let Reclaimer revive a dead participant")
		local caster = player("caster", "mana")
		equip(caster, "grug_gear:reclaimers_mark_t6", nil)
		grug_core.trinket_xp_kill(caster)
		check(caster.hp == 108 and mana.caster == 120,
			"Reclaimer caster restore did not apply 4% HP/Mana")

		local loop_other = custom("kat:loop_other", "loop_other",
			"potion_amount", 20, "additive", 30)
		equip(subject, "grug_gear:apothecary_loop_t6", loop_other)
		check(close(grug_core.trinket_instant_potion(subject, 100), 130),
			"Apothecary Loop did not add and cap at 30%")
		local potion_heal
		local potion_mana
		local potion_environment = {
			grug_alchemy = {POTION_PERCENT = 30},
			grug_core = {
				trinket_instant_potion = grug_core.trinket_instant_potion,
				can_use_item_level = function() return true end,
				heal_player = function(_, _, amount) potion_heal = amount end,
			},
			grug_classes = {
				get_max_hp = function(player_object) return player_object.max_hp end,
				get_max_mana = function(player_object) return player_object.max_mana end,
			},
			grug_abilities = {
				restore_mana = function(_, amount) potion_mana = amount end,
			},
			grug_traders = {
				potion_cooldown_left = function() return 0 end,
				start_potion_cooldown = function() end,
			},
			core = {chat_send_player = function() end},
		}
		local production_potion_use = execute(production_chunk(
			"mods/ITEMS/grug_alchemy/effects.lua",
			"local function consume", "\nlocal function utility_use",
			"\nreturn potion_use"), potion_environment)
		production_potion_use("health", 60)(stack("kat:health_potion"), subject)
		production_potion_use("mana", 60)(stack("kat:mana_potion"), subject)
		check(potion_heal == 78 and potion_mana == 195,
			"production instant-potion seam did not apply Apothecary's 30% cap")

		equip(subject, nil, nil)
		local rage_before = rage.subject
		grug_core.trinket_weapon_hit(subject)
		check(grug_core.trinket_mana_regen(subject) == 0 and
			grug_core.trinket_outgoing_heal(subject, 100) == 100 and
			grug_core.trinket_instant_potion(subject, 100) == 100 and
			rage.subject == rage_before,
			"an unequipped trinket special remained active")

		local gear_source = source("mods/ITEMS/grug_gear/trinkets.lua")
		check(not gear_source:find("inert until the trinket effects lane", 1, true),
			"trinket tooltip still marks specials inert")

		leave_callback(subject)
		if #failures > 0 then error(table.concat(failures, "; "), 0) end
		return table.concat({
			"r9_trinkets\tmanawell=1.00/s\tbattlebeat=4/hit\tmercy=12%",
			"r9_trinkets\tlast_light=8%@120s\treclaimer=4%+6@10s\tapothecary=30%",
			"r9_trinkets\tcache_reads=event_only\tduplicate_identity=once\tunequipped=off",
			"r9_trinkets_result\tfailures=0",
			"PASS",
		}, "\n") .. "\n"
	end

	local ok, result = pcall(run)
	restore()
	if not ok then error(result, 0) end
	return result
end
