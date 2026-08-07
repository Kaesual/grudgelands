-- The MVP class kits (docs/design/classes.md §3–§5). Numbers live in the
-- design doc — change them there first.

--
-- Targeting helpers. The ability item's `range` limits pointed_thing, so
-- cast functions can rely on it for the pointed path; the soft-target-lock
-- fallback re-checks range explicitly (grug_abilities.get_range).
--

local function mob_ent(obj)
	if obj:is_player() then
		return nil
	end
	local ent = obj:get_luaentity()
	return (ent and ent._cmi_is_mob) and ent or nil
end

-- Is obj a valid enemy for user right now? (mob not of the own faction /
-- hostile living player)
local function valid_enemy(user, obj)
	if obj:is_player() then
		return grug_factions.hostile(user, obj) and obj:get_hp() > 0
	end
	local ent = mob_ent(obj)
	if not ent or (ent.health or 0) <= 0 then
		return false
	end
	return not (ent._grug_faction and
		ent._grug_faction == grug_factions.get_faction(user))
end

local function valid_ally(user, obj)
	return obj:is_player() and obj ~= user
		and grug_factions.same_faction(user, obj)
		and obj:get_hp() > 0
end

local function in_lock_range(user, obj, def)
	return vector.distance(user:get_pos(), obj:get_pos())
		<= grug_abilities.get_range(user, def)
end

-- Eye-to-body line of sight — the pointed path gets this for free from
-- the engine raycast; the lock fallback must check it itself, otherwise
-- ranged abilities could be spammed through walls at a locked target.
local function lock_los(user, obj)
	local eye = user:get_pos()
	eye.y = eye.y + (user:get_properties().eye_height or 1.5)
	return core.line_of_sight(eye, vector.offset(obj:get_pos(), 0, 1, 0))
end

-- Attackable target: the pointed object if valid (locks it), otherwise the
-- soft-locked enemy target if still valid, in range and in line of sight.
local function enemy_target(user, pointed, def)
	if pointed and pointed.type == "object" and pointed.ref
			and valid_enemy(user, pointed.ref) then
		grug_abilities.set_target(user, pointed.ref, false)
		return pointed.ref
	end
	local obj = grug_abilities.get_target(user, false)
	if obj and valid_enemy(user, obj)
			and in_lock_range(user, obj, def) and lock_los(user, obj) then
		grug_abilities.set_target(user, obj, false) -- refresh the lock
		return obj
	end
	return nil
end

-- Friendly target for heals: pointed ally (locks it), otherwise the
-- soft-locked ally if still valid and in range — this is what makes
-- healing moving allies workable — otherwise self. Deliberately no LOS
-- check on the fallback: healing the ally who just kited around a tree
-- is the point of the lock.
local function heal_target(user, pointed, def)
	if pointed and pointed.type == "object" and pointed.ref
			and valid_ally(user, pointed.ref) then
		grug_abilities.set_target(user, pointed.ref, true)
		return pointed.ref
	end
	local obj = grug_abilities.get_target(user, true)
	if obj and valid_ally(user, obj)
			and in_lock_range(user, obj, def) then
		grug_abilities.set_target(user, obj, true) -- refresh the lock
		return obj
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
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.5, 0, -0.5),
			max = vector.offset(pos, 0.5, 1, 0.5)},
		vel = {min = vector.new(-2, 0, -2), max = vector.new(2, 3, 2)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 1.5, max = 3},
		texture = texture,
		glow = 10,
	})
end

--
-- Root/slow effects (Frost Nova, Hamstring). Mobs: grug_mobs.root/slow —
-- restore runs as a reload-safe countdown inside the mob's do_custom (a
-- core.after timer here once persisted permanently-immobile mobs into the
-- world file). Players (PvP): a staged physics override — stages run in
-- sequence (e.g. root, then slow), a newer effect replaces the running one
-- via the token, and physics overrides reset on rejoin so a relog inside
-- the window cannot stick. MVP caveat: the override clobbers other speed
-- modifiers — fine while none exist.
--

local speed_fx = {} -- player name -> {speed = n, expiry = us} of the active stage

-- stages: list of {speed = n, jump = n, time = seconds}; restores to 1/1
-- after the last stage. A new effect replaces the running one UNLESS the
-- currently active stage is stronger (lower speed) — a Hamstring must not
-- lift an ally's Frost Nova root. Chain ownership is tracked by record
-- identity (not a counter), so orphaned core.after chains from before a
-- relog can never hijack a later effect.
local function apply_player_speed_stages(target, stages)
	local name = target:get_player_name()
	local active = speed_fx[name]
	if active and core.get_us_time() < active.expiry
			and active.speed < stages[1].speed then
		return -- a stronger snare stage is running; keep it
	end
	local rec = {}
	speed_fx[name] = rec
	local run
	run = function(i)
		local p = core.get_player_by_name(name)
		if not p or speed_fx[name] ~= rec then
			return -- left, or a newer effect took over
		end
		local stage = stages[i]
		if not stage then
			p:set_physics_override({speed = 1, jump = 1})
			speed_fx[name] = nil
			return
		end
		rec.speed = stage.speed
		rec.expiry = core.get_us_time() + stage.time * 1e6
		p:set_physics_override({speed = stage.speed, jump = stage.jump or 1})
		core.after(stage.time, function()
			run(i + 1)
		end)
	end
	run(1)
end

-- NB physics overrides are not persisted: a relog inside the window
-- clears the root/slow. Accepted MVP caveat — reconnecting takes longer
-- than any current effect (max 7 s), so it is no practical escape.
core.register_on_leaveplayer(function(player)
	speed_fx[player:get_player_name()] = nil
end)

--
-- Warrior (rage; all abilities count as tank abilities: threat ×3)
--

grug_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
	description = "Dash to an enemy up to 12 m away, dealing 3 damage\n" ..
		"and generating 15 rage.",
	color = "#e8c85a",
	cost = {},
	cooldown = 10,
	range = 12,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		local tpos = target:get_pos()
		local dir = vector.direction(tpos, user:get_pos())
		local dest = vector.add(tpos, vector.multiply(dir, 1.3))
		dest.y = tpos.y
		user:set_pos(dest)
		grug_abilities.add_rage(user, 15)
		grug_core.deal_ability_damage(user, target, 3, {threat_mult = 3})
		burst(tpos, "default_item_smoke.png", 8)
		return true
	end,
})

-- The rage dump (kit tuning 2026-08-06): no own cooldown — at +12 rage
-- per auto-hit a cooldown left the Warrior permanently rage-capped.
grug_abilities.register_ability({
	id = "mighty_blow",
	class = "warrior",
	name = "Mighty Blow",
	description = "A heavy melee hit: 150% weapon damage plus your\n" ..
		"melee bonus. Uses the best weapon you carry.",
	color = "#c84a32",
	cost = {rage = 25},
	cooldown = 0,
	range = 4,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
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
			+ grug_classes.get_melee_bonus(user)
		-- Position BEFORE the damage: a lethal punch invalidates mob refs.
		local tpos = target:get_pos()
		grug_core.deal_ability_damage(user, target, amount, {threat_mult = 3})
		burst(tpos, "mobs_blood.png", 6)
		return true
	end,
})

-- The control tool (kit tuning 2026-08-06): in an engine where mobs
-- outrun players, the snare is the Warrior's identity.
grug_abilities.register_ability({
	id = "hamstring",
	class = "warrior",
	name = "Hamstring",
	description = "Cripples the enemy: 2 damage and 50% slow for 5 s.",
	color = "#a8324e",
	cost = {rage = 10},
	cooldown = 6,
	range = 4,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		-- Capture BEFORE the damage: a lethal punch removes a mob without a
		-- die animation synchronously, invalidating the ObjectRef.
		local ent = mob_ent(target)
		local tpos = target:get_pos()
		-- Damage first: a dodged Hamstring (player targets) must not snare.
		local dealt = grug_core.deal_ability_damage(user, target, 2,
			{threat_mult = 3})
		if dealt > 0 then
			if ent then
				grug_mobs.slow(ent, 5, 0.5) -- harmless no-op on a removed mob
			elseif target:get_hp() > 0 then
				apply_player_speed_stages(target, {{speed = 0.5, time = 5}})
			end
			burst(tpos, "mobs_blood.png", 4)
		end
		return true
	end,
})

grug_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
	description = "Forces the target mob to attack you.",
	color = "#e07b39",
	cost = {},
	cooldown = 8,
	range = 8,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		local ent = mob_ent(target)
		if not ent or not ent.attack_type then
			return false, "Cannot be taunted."
		end
		ent:do_attack(user, true)
		-- Threat part (combat_stats.md §4): sets the taunter to top×1.1 and
		-- suppresses hysteresis target switches for 3 s.
		grug_core.taunt(ent, user)
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#e07b39", 6)
		return true
	end,
})

--
-- Mage (mana)
--

-- Bread-and-butter nuke (kit tuning 2026-08-06): pays with mana instead
-- of a cooldown — 5 mana against a 240+ pool was free.
grug_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	description = "Hurls fire at an enemy up to 20 m away:\n" ..
		"6 + spell power damage.",
	color = "#ff8833",
	cost = {mana = 8},
	cooldown = 0,
	range = 20,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		beam(user, target, "mobs_fire_particle.png")
		burst(target:get_pos(), "mobs_fire_particle.png")
		grug_core.deal_ability_damage(user, target,
			6 + grug_classes.get_spell_power_bonus(user))
		return true
	end,
})

-- The rotation pivot (kit tuning 2026-08-06): kiting IS the Mage fantasy
-- here — root, make distance, keep nuking, re-nova when it is back up.
grug_abilities.register_ability({
	id = "frost_nova",
	class = "mage",
	name = "Frost Nova",
	description = "Roots all enemies within 5 m for 4 s,\n" ..
		"then slows them by 50% for 3 s.",
	color = "#66b8ff",
	cost = {mana = 10},
	cooldown = 12,
	range = 4,
	cast = function(user)
		local pos = user:get_pos()
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 5)) do
			if obj ~= user then
				if obj:is_player() then
					if grug_factions.hostile(user, obj) then
						apply_player_speed_stages(obj, {
							{speed = 0.1, jump = 0.3, time = 4},
							{speed = 0.5, time = 3},
						})
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				else
					local ent = mob_ent(obj)
					if ent and not (ent._grug_faction and
							ent._grug_faction == grug_factions.get_faction(user)) then
						grug_mobs.root(ent, 4)
						grug_mobs.slow(ent, 3, 0.5) -- queued: starts after the root
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				end
			end
		end
		burst(pos, "default_item_smoke.png^[multiply:#aaddff", 20)
		grug_core.mark_in_combat(user)
		return true
	end,
})

grug_abilities.register_ability({
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

grug_abilities.register_ability({
	id = "smite",
	class = "priest",
	name = "Smite",
	description = "Smites an enemy up to 20 m away:\n" ..
		"4 + spell power damage.",
	color = "#ffd97a",
	cost = {mana = 4},
	cooldown = 2,
	range = 20,
	cast = function(user, pointed, def)
		local target = enemy_target(user, pointed, def)
		if not target then
			return false, "No target."
		end
		beam(user, target, "default_item_smoke.png^[multiply:#ffe9a0")
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0")
		grug_core.deal_ability_damage(user, target,
			4 + grug_classes.get_spell_power_bonus(user))
		return true
	end,
})

grug_abilities.register_ability({
	id = "flash_heal",
	class = "priest",
	name = "Flash Heal",
	description = "Heals the pointed ally (or yourself) for\n" ..
		"8 + 2x spell power.",
	color = "#7ae08a",
	cost = {mana = 8},
	cooldown = 4,
	range = 15,
	cast = function(user, pointed, def)
		local target = heal_target(user, pointed, def)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		grug_core.heal_player(user, target,
			8 + 2 * grug_classes.get_spell_power_bonus(user))
		burst(target:get_pos(), "mobs_heart_particle.png", 8)
		return true
	end,
})

-- Base-kit shield (kit tuning 2026-08-06, replaces Renew): an absorb
-- plays differently from a second heal and makes the Priest useful
-- BEFORE damage lands. The soak itself lives in grug_core's central hp
-- change modifier (grug_core.set_absorb).
grug_abilities.register_ability({
	id = "power_word_shield",
	class = "priest",
	name = "Power Word: Shield",
	description = "Shields the pointed ally (or yourself): absorbs\n" ..
		"8 + 2x spell power damage for 15 s or until consumed.",
	color = "#e8e07a",
	cost = {mana = 8},
	cooldown = 10,
	range = 15,
	cast = function(user, pointed, def)
		local target = heal_target(user, pointed, def)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		grug_core.set_absorb(target,
			8 + 2 * grug_classes.get_spell_power_bonus(user), 15)
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0", 8)
		return true
	end,
})

-- Active renews: target name -> {ticks, amount, healer}
local renews = {}

-- Talent-gated (kit tuning 2026-08-06): stays registered, but sync_kit
-- does not grant it — the Holy tree unlocks it in WP11.
grug_abilities.register_ability({
	id = "renew",
	class = "priest",
	name = "Renew",
	talent_gated = true,
	description = "Heal over time on the pointed ally (or yourself):\n" ..
		"3 + spell power every 3 s for 12 s.\nUnlocked via talents.",
	color = "#3fae6a",
	cost = {mana = 6},
	cooldown = 8,
	range = 15,
	cast = function(user, pointed, def)
		local target = heal_target(user, pointed, def)
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Re-casting refreshes duration and snapshot amount.
		renews[target:get_player_name()] = {
			ticks = 4,
			amount = 3 + grug_classes.get_spell_power_bonus(user),
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
			grug_core.heal_player(healer, target, renew.amount)
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
