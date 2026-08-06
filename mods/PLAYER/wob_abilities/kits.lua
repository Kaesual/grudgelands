-- The MVP class kits (docs/design/classes.md §3–§5). Numbers live in the
-- design doc — change them there first.

--
-- Targeting helpers. The ability item's `range` limits pointed_thing, so
-- cast functions can rely on it.
--

local function mob_ent(obj)
	if obj:is_player() then
		return nil
	end
	local ent = obj:get_luaentity()
	return (ent and ent._cmi_is_mob) and ent or nil
end

-- Attackable target from pointed_thing: any mob not of the own faction, or
-- a hostile player (friendly fire stays blocked by wob_factions anyway).
local function enemy_target(user, pointed)
	if not pointed or pointed.type ~= "object" or not pointed.ref then
		return nil
	end
	local obj = pointed.ref
	if obj:is_player() then
		return wob_factions.hostile(user, obj) and obj or nil
	end
	local ent = mob_ent(obj)
	if not ent then
		return nil
	end
	if ent._wob_faction and
			ent._wob_faction == wob_factions.get_faction(user) then
		return nil
	end
	return obj
end

-- Friendly target for heals: pointed ally player, otherwise self.
local function heal_target(user, pointed)
	if pointed and pointed.type == "object" and pointed.ref
			and pointed.ref:is_player()
			and wob_factions.same_faction(user, pointed.ref) then
		return pointed.ref
	end
	return user
end

--
-- Particle helpers (existing textures only; own effects are Phase 3).
--

local function beam(user, target, texture)
	local from = user:get_pos()
	from.y = from.y + (user:get_properties().eye_height or 1.5)
	local to = vector.offset(target:get_pos(), 0, 1, 0)
	local dist = vector.distance(from, to)
	local steps = math.max(2, math.floor(dist * 2))
	local dir = vector.direction(from, to)
	for i = 1, steps do
		core.add_particle({
			pos = vector.add(from, vector.multiply(dir, i * dist / steps)),
			velocity = vector.new(0, 0, 0),
			expirationtime = 0.25,
			size = 2.5,
			texture = texture,
			glow = 12,
		})
	end
end

local function burst(pos, texture, amount)
	core.add_particlespawner({
		amount = amount or 12,
		time = 0.2,
		pos = vector.offset(pos, 0, 0.5, 0),
		radius = 0.5,
		vel = {min = vector.new(-2, 0, -2), max = vector.new(2, 3, 2)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 1.5, max = 3},
		texture = texture,
		glow = 10,
	})
end

--
-- Root effects (Frost Nova). Mobs: zero out walk/run velocity and restore
-- after the duration; re-rooting refreshes the timer. Players (PvP): a
-- physics override. MVP caveat (documented in classes.md): the override
-- would clobber other speed modifiers — fine while none exist.
--

local function root_mob(ent, duration)
	local obj = ent.object
	if not ent._wob_root then
		ent._wob_root = {walk = ent.walk_velocity, run = ent.run_velocity}
		ent.walk_velocity = 0
		ent.run_velocity = 0
	end
	local expiry = core.get_us_time() + duration * 1e6
	ent._wob_root_until = expiry
	local v = obj:get_velocity()
	if v then
		obj:set_velocity(vector.new(0, v.y, 0))
	end
	core.after(duration, function()
		if ent._wob_root and ent._wob_root_until == expiry
				and obj:get_pos() then
			ent.walk_velocity = ent._wob_root.walk
			ent.run_velocity = ent._wob_root.run
			ent._wob_root = nil
		end
	end)
end

local player_roots = {} -- player name -> expiry (us time)

local function root_player(target, duration)
	local name = target:get_player_name()
	local expiry = core.get_us_time() + duration * 1e6
	player_roots[name] = expiry
	target:set_physics_override({speed = 0.1, jump = 0.3})
	core.after(duration, function()
		local p = core.get_player_by_name(name)
		if p and player_roots[name] == expiry then
			p:set_physics_override({speed = 1, jump = 1})
			player_roots[name] = nil
		end
	end)
end

core.register_on_leaveplayer(function(player)
	player_roots[player:get_player_name()] = nil
end)

--
-- Warrior (rage; all abilities count as tank abilities: threat ×3)
--

wob_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
	description = "Dash to an enemy up to 12 m away, dealing 3 damage\n" ..
		"and generating 15 rage.",
	color = "#e8c85a",
	cost = {},
	cooldown = 10,
	range = 12,
	cast = function(user, pointed)
		local target = enemy_target(user, pointed)
		if not target then
			return false, "No target."
		end
		local tpos = target:get_pos()
		local dir = vector.direction(tpos, user:get_pos())
		local dest = vector.add(tpos, vector.multiply(dir, 1.3))
		dest.y = tpos.y
		user:set_pos(dest)
		wob_abilities.add_rage(user, 15)
		wob_core.deal_ability_damage(user, target, 3, {threat_mult = 3})
		burst(tpos, "default_item_smoke.png", 8)
		return true
	end,
})

wob_abilities.register_ability({
	id = "mighty_blow",
	class = "warrior",
	name = "Mighty Blow",
	description = "A heavy melee hit: 150% weapon damage plus your\n" ..
		"melee bonus. Uses the best weapon you carry.",
	color = "#c84a32",
	cost = {rage = 15},
	cooldown = 4,
	range = 4,
	cast = function(user, pointed)
		local target = enemy_target(user, pointed)
		if not target then
			return false, "No target."
		end
		-- The wielded item is this ability, so take the strongest weapon
		-- from the hotbar (list "main", slots 1–8) as the swing.
		local weapon_damage = 1 -- bare hands
		local list = user:get_inventory():get_list("main") or {}
		for i = 1, math.min(8, #list) do
			local caps = list[i]:get_tool_capabilities()
			local dmg = caps.damage_groups and caps.damage_groups.fleshy or 0
			if dmg > weapon_damage then
				weapon_damage = dmg
			end
		end
		local amount = math.floor(weapon_damage * 1.5)
			+ wob_classes.get_melee_bonus(user)
		wob_core.deal_ability_damage(user, target, amount, {threat_mult = 3})
		burst(target:get_pos(), "mobs_blood.png", 6)
		return true
	end,
})

wob_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
	description = "Forces the target mob to attack you.",
	color = "#e07b39",
	cost = {},
	cooldown = 8,
	range = 8,
	cast = function(user, pointed)
		if not pointed or pointed.type ~= "object" or not pointed.ref then
			return false, "No target."
		end
		local ent = mob_ent(pointed.ref)
		if not ent or not ent.attack_type then
			return false, "Cannot be taunted."
		end
		if ent._wob_faction and
				ent._wob_faction == wob_factions.get_faction(user) then
			return false, "Invalid target."
		end
		ent:do_attack(user, true)
		-- Threat part (top×1.1, forced 3 s) lands with WP6's threat table.
		wob_core.add_threat(ent, user, 0)
		burst(pointed.ref:get_pos(), "default_item_smoke.png^[multiply:#e07b39", 6)
		return true
	end,
})

--
-- Mage (mana)
--

wob_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	description = "Hurls fire at an enemy up to 20 m away:\n" ..
		"6 + spell power damage.",
	color = "#ff8833",
	cost = {mana = 5},
	cooldown = 2,
	range = 20,
	cast = function(user, pointed)
		local target = enemy_target(user, pointed)
		if not target then
			return false, "No target."
		end
		beam(user, target, "mobs_fire_particle.png")
		burst(target:get_pos(), "mobs_fire_particle.png")
		wob_core.deal_ability_damage(user, target,
			6 + wob_classes.get_spell_power_bonus(user))
		return true
	end,
})

wob_abilities.register_ability({
	id = "frost_nova",
	class = "mage",
	name = "Frost Nova",
	description = "Roots all enemies within 5 m for 4 s.",
	color = "#66b8ff",
	cost = {mana = 10},
	cooldown = 20,
	range = 4,
	cast = function(user, pointed)
		local pos = user:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 5)) do
			if obj ~= user then
				if obj:is_player() then
					if wob_factions.hostile(user, obj) then
						root_player(obj, 4)
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				else
					local ent = mob_ent(obj)
					if ent and not (ent._wob_faction and
							ent._wob_faction == wob_factions.get_faction(user)) then
						root_mob(ent, 4)
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				end
			end
		end
		burst(pos, "default_item_smoke.png^[multiply:#aaddff", 20)
		wob_core.mark_in_combat(user)
		return true
	end,
})

wob_abilities.register_ability({
	id = "blink",
	class = "mage",
	name = "Blink",
	description = "Teleport up to 10 m in your look direction\n" ..
		"(blocked by walls).",
	color = "#b06aff",
	cost = {mana = 8},
	cooldown = 15,
	range = 4,
	cast = function(user)
		local eye_height = user:get_properties().eye_height or 1.5
		local from = user:get_pos()
		local eye = vector.offset(from, 0, eye_height, 0)
		local dir = user:get_look_dir()
		local dest_eye = vector.add(eye, vector.multiply(dir, 10))
		local ray = core.raycast(eye, dest_eye, false, false)
		local hit = ray:next()
		if hit and hit.type == "node" then
			dest_eye = vector.subtract(hit.intersection_point,
				vector.multiply(dir, 0.7))
		end
		-- Feet position; back off along the ray until there is room.
		local dest = vector.offset(dest_eye, 0, -eye_height, 0)
		for _ = 1, 12 do
			local feet = core.get_node_or_nil(vector.round(dest))
			local head = core.get_node_or_nil(vector.round(
				vector.offset(dest, 0, 1, 0)))
			local function free(node)
				if not node then
					return false
				end
				local ndef = core.registered_nodes[node.name]
				return ndef and not ndef.walkable
			end
			if free(feet) and free(head) then
				burst(from, "default_item_smoke.png^[multiply:#b06aff", 10)
				user:set_pos(dest)
				burst(dest, "default_item_smoke.png^[multiply:#b06aff", 10)
				return true
			end
			dest = vector.subtract(dest, vector.multiply(dir, 0.75))
			if vector.distance(dest, from) < 0.8 then
				break
			end
		end
		return false, "No room to blink."
	end,
})

--
-- Priest (mana)
--

wob_abilities.register_ability({
	id = "smite",
	class = "priest",
	name = "Smite",
	description = "Smites an enemy up to 20 m away:\n" ..
		"4 + spell power damage.",
	color = "#ffd97a",
	cost = {mana = 4},
	cooldown = 2,
	range = 20,
	cast = function(user, pointed)
		local target = enemy_target(user, pointed)
		if not target then
			return false, "No target."
		end
		beam(user, target, "default_item_smoke.png^[multiply:#ffe9a0")
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0")
		wob_core.deal_ability_damage(user, target,
			4 + wob_classes.get_spell_power_bonus(user))
		return true
	end,
})

wob_abilities.register_ability({
	id = "flash_heal",
	class = "priest",
	name = "Flash Heal",
	description = "Heals the pointed ally (or yourself) for\n" ..
		"8 + 2x spell power.",
	color = "#7ae08a",
	cost = {mana = 8},
	cooldown = 4,
	range = 15,
	cast = function(user, pointed)
		local target = heal_target(user, pointed)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		wob_core.heal_player(user, target,
			8 + 2 * wob_classes.get_spell_power_bonus(user))
		burst(target:get_pos(), "mobs_heart_particle.png", 8)
		return true
	end,
})

-- Active renews: target name -> {ticks, amount, healer}
local renews = {}

wob_abilities.register_ability({
	id = "renew",
	class = "priest",
	name = "Renew",
	description = "Heal over time on the pointed ally (or yourself):\n" ..
		"3 + spell power every 3 s for 12 s.",
	color = "#3fae6a",
	cost = {mana = 6},
	cooldown = 8,
	range = 15,
	cast = function(user, pointed)
		local target = heal_target(user, pointed)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Re-casting refreshes duration and snapshot amount.
		renews[target:get_player_name()] = {
			ticks = 4,
			amount = 3 + wob_classes.get_spell_power_bonus(user),
			healer = user:get_player_name(),
		}
		burst(target:get_pos(), "mobs_heart_particle.png", 5)
		return true
	end,
})

local renew_acc = 0

core.register_globalstep(function(dtime)
	renew_acc = renew_acc + dtime
	if renew_acc < 3 then
		return
	end
	renew_acc = 0
	for name, renew in pairs(renews) do
		local target = core.get_player_by_name(name)
		if not target or target:get_hp() <= 0 then
			renews[name] = nil
		else
			local healer = core.get_player_by_name(renew.healer) or target
			wob_core.heal_player(healer, target, renew.amount)
			burst(target:get_pos(), "mobs_heart_particle.png", 3)
			renew.ticks = renew.ticks - 1
			if renew.ticks <= 0 then
				renews[name] = nil
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	renews[player:get_player_name()] = nil
end)
