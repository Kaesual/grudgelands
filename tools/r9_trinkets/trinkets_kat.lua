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
		local function count_token(bytes, token)
			local count, offset = 0, 1
			while true do
				local first = bytes:find(token, offset, true)
				if not first then return count end
				count = count + 1
				offset = first + #token
			end
		end

		local Stack = {}
		Stack.__index = Stack
		local function stack(name)
			return setmetatable({name = name or ""}, Stack)
		end
		function Stack:is_empty() return self.name == "" end
		function Stack:get_name() return self.name end

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
				rage[name] = (rage[name] or 0) + amount
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

		local light_other = custom("kat:light_other", "light_other",
			"last_light_absorb", 8, "highest", nil, 120)
		equip(subject, "grug_gear:last_light_t3", light_other)
		subject.hp = 60
		grug_core.trinket_after_hit(subject, -20, {type = "punch"})
		check(#absorbs == 1 and absorbs[1].amount == 16 and
			absorbs[1].duration == 120,
			"Last Light did not use highest 8% value and 120 s lifetime")
		grug_core.trinket_after_hit(subject, -1, {type = "punch"})
		check(#absorbs == 1, "Last Light ignored its shared cooldown")
		now = now + 121
		subject.hp = 20
		grug_core.trinket_after_hit(subject, -20, {type = "punch"})
		check(#absorbs == 1, "Last Light saved a lethal hit")
		subject.hp = 60
		grug_core.trinket_after_hit(subject, -20, {type = "punch"})
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
		local hooks = {
			{"mods/PLAYER/grug_abilities/init.lua", "trinket_mana_regen(player)"},
			{"mods/PLAYER/grug_abilities/init.lua", "trinket_weapon_hit(context.player)"},
			{"mods/CORE/grug_core/combat.lua", "trinket_outgoing_heal(healer, amount)"},
			{"mods/CORE/grug_core/combat.lua", "trinket_after_hit(player, hp_change, reason)"},
			{"mods/ENTITIES/grug_mobs/init.lua", "trinket_xp_kill(player)"},
			{"mods/ITEMS/grug_alchemy/effects.lua", "trinket_instant_potion(player, amount)"},
		}
		for index = 1, #hooks do
			check(count_token(source(hooks[index][1]), hooks[index][2]) == 1,
				"production seam call differs: " .. hooks[index][2])
		end

		leave_callback(subject)
		check(#failures == 0, table.concat(failures, "; "))
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
