-- Class abilities (docs/design/classes.md): hotbar items with cooldowns,
-- mana/rage resources with HUD line, kit granting on class pick. Resources
-- and cooldowns are runtime state (not persisted): mana is full on
-- join/respawn, rage starts at 0.

wob_abilities = {}

wob_abilities.registered = {} -- ability id -> def
wob_abilities.by_class = {} -- class id -> ordered list of defs
local item_defs = {} -- item name -> ability def

local mana = {} -- player name -> current mana (fractional)
local rage = {} -- player name -> current rage (fractional)
local cooldowns = {} -- player name -> {ability id -> expiry (us time)}
local gcd_expiry = {} -- player name -> expiry (us time) of the global cooldown
local targets = {} -- player name -> {enemy = rec, ally = rec}; rec = {obj, expiry}
local resource_huds = {} -- player name -> hud id
local flash_huds = {} -- player name -> {id = hud id, token = n}

-- Global cooldown across all abilities of a class (classes.md core
-- principles): turns button mashing into a rotation. Deliberately NOT
-- displayed via item wear — 1 s of wear flicker on every kit item would
-- multiply inventory re-sends for zero information (AGENTS performance
-- rules); try_cast just gates silently.
wob_abilities.GCD = 1.0

-- Soft target lock (classes.md core principles): the last punched/pointed
-- enemy or ally stays the implicit target this long; abilities fall back
-- to it when pointed_thing has no valid target.
wob_abilities.TARGET_LOCK = 8

local function resource_of(player)
	local def = wob_classes.get_class_def(player)
	return def and def.resource or nil
end

--
-- Resource API
--

function wob_abilities.get_mana(player)
	return math.floor(mana[player:get_player_name()] or 0)
end

function wob_abilities.get_rage(player)
	return math.floor(rage[player:get_player_name()] or 0)
end

local hud_update -- forward

function wob_abilities.add_rage(player, amount)
	if resource_of(player) ~= "rage" then
		return
	end
	local name = player:get_player_name()
	rage[name] = math.max(0, math.min(100, (rage[name] or 0) + amount))
	hud_update(player)
end

local function refill_mana(player)
	mana[player:get_player_name()] = wob_classes.get_max_mana(player)
end

-- cost = {mana = n} or {rage = n}; returns false if not affordable.
local function spend(player, cost)
	local name = player:get_player_name()
	if cost.mana then
		if (mana[name] or 0) < cost.mana then
			return false
		end
		mana[name] = mana[name] - cost.mana
	end
	if cost.rage then
		if (rage[name] or 0) < cost.rage then
			return false
		end
		rage[name] = rage[name] - cost.rage
	end
	hud_update(player)
	return true
end

local function affordable(player, cost)
	local name = player:get_player_name()
	return (not cost.mana or (mana[name] or 0) >= cost.mana)
		and (not cost.rage or (rage[name] or 0) >= cost.rage)
end

--
-- Soft target lock. Enemy and ally are separate slots — a Priest who
-- Smites a mob must not lose their heal target over it. The kits
-- re-validate faction/range/LOS on every use; this only stores identity
-- and freshness.
--

function wob_abilities.set_target(player, obj, ally)
	local name = player:get_player_name()
	targets[name] = targets[name] or {}
	targets[name][ally and "ally" or "enemy"] = {
		obj = obj,
		expiry = core.get_us_time() + wob_abilities.TARGET_LOCK * 1e6,
	}
end

-- Locked enemy (ally = false) or ally (ally = true) — nil when no lock,
-- expired, or the object is gone (mob died/unloaded, player left;
-- invalid ObjectRefs return nil from get_pos).
function wob_abilities.get_target(player, ally)
	local name = player:get_player_name()
	local slot = ally and "ally" or "enemy"
	local rec = targets[name] and targets[name][slot]
	if not rec then
		return nil
	end
	if core.get_us_time() > rec.expiry or not rec.obj:get_pos() then
		targets[name][slot] = nil
		return nil
	end
	return rec.obj
end

-- Effective targeting range of an ability for this player (elf passive:
-- +5 m on everything, world.md §7). The granted item's meta `range`
-- override (sync_kit) keeps pointed_thing in step with this.
function wob_abilities.get_range(player, def)
	return (def.range or 4)
		+ (wob_classes.get_race_perk(player, "ability_range_bonus") or 0)
end

--
-- HUD: resource line above the XP line (mana blue / rage red) and a
-- short-lived error flash top center ("Not enough mana", "No target", ...).
--

local function hud_state(player)
	local res = resource_of(player)
	if res == "mana" then
		return ("Mana %d / %d"):format(wob_abilities.get_mana(player),
			wob_classes.get_max_mana(player)), 0x4a9bd8
	elseif res == "rage" then
		return ("Rage %d / 100"):format(wob_abilities.get_rage(player)), 0xc41e3a
	end
	return "", 0xffffff
end

hud_update = function(player)
	local id = resource_huds[player:get_player_name()]
	if not id then
		return
	end
	local text, color = hud_state(player)
	player:hud_change(id, "text", text)
	player:hud_change(id, "number", color)
end

function wob_abilities.flash(player, msg)
	local name = player:get_player_name()
	local rec = flash_huds[name]
	if not rec then
		return
	end
	rec.token = rec.token + 1
	local token = rec.token
	player:hud_change(rec.id, "text", msg)
	core.after(1.5, function()
		local p = core.get_player_by_name(name)
		local r = flash_huds[name]
		if p and r and r.token == token then
			p:hud_change(r.id, "text", "")
		end
	end)
end

--
-- Ability registration & item. One tool per ability; the item's `range`
-- doubles as the targeting range (pointed_thing works up to it), the wear
-- bar displays the running cooldown.
--

function wob_abilities.register_ability(def)
	assert(def.id and def.class and def.cast and def.cooldown,
		"incomplete ability definition")
	def.cost = def.cost or {}
	wob_abilities.registered[def.id] = def
	wob_abilities.by_class[def.class] = wob_abilities.by_class[def.class] or {}
	table.insert(wob_abilities.by_class[def.class], def)

	local class_def = wob_classes.registered_classes[def.class]
	local cost_line = def.cost.mana and (def.cost.mana .. " mana")
		or def.cost.rage and (def.cost.rage .. " rage") or "free"
	local cd_line = def.cooldown > 0 and (def.cooldown .. " s cooldown")
		or "no cooldown"
	local itemname = "wob_abilities:" .. def.id
	item_defs[itemname] = def

	core.register_tool(itemname, {
		description = def.name .. " (" .. class_def.name .. ")\n" ..
			cost_line .. ", " .. cd_line .. "\n" ..
			def.description,
		inventory_image = "wob_abilities_orb.png^[multiply:" .. def.color,
		wield_image = "wob_abilities_orb.png^[multiply:" .. def.color,
		range = def.range or 4,
		stack_max = 1,
		groups = {wob_ability = 1, not_in_creative_inventory = 1},
		on_drop = function(itemstack)
			return itemstack -- ability items cannot be dropped
		end,
		on_use = function(itemstack, user, pointed_thing)
			wob_abilities.try_cast(user, def, pointed_thing)
			return nil
		end,
	})
end

-- Cooldown display via item wear. Inventory writes re-send the whole
-- player inventory to the client, so this path is deliberately stingy:
-- slot indices are cached (no full-list scan per tick) and the wear bar is
-- quantized to WEAR_STEPS — a write happens only when the visible step
-- changes, not every tick.
local WEAR_STEPS = 12

local slot_cache = {} -- player name -> {ability id -> main list index}
local wear_steps = {} -- player name -> {ability id -> last written step}

local function set_item_wear(player, ability_id, wear)
	local inv = player:get_inventory()
	local itemname = "wob_abilities:" .. ability_id
	local name = player:get_player_name()
	slot_cache[name] = slot_cache[name] or {}
	local idx = slot_cache[name][ability_id]
	if idx then
		local stack = inv:get_stack("main", idx)
		if stack:get_name() == itemname then
			stack:set_wear(wear)
			inv:set_stack("main", idx, stack)
			return
		end
		slot_cache[name][ability_id] = nil
	end
	local list = inv:get_list("main") or {}
	for i, stack in ipairs(list) do
		if stack:get_name() == itemname then
			slot_cache[name][ability_id] = i
			stack:set_wear(wear)
			inv:set_stack("main", i, stack)
			return
		end
	end
end

-- Ability items live in the main inventory only — stashing one in a bag
-- would hide its cooldown and used to confuse the kit sync. NB other
-- allow callbacks OR-combine (see wob_inventory): return nil when
-- unconcerned, a number swallows later callbacks.
core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" and info.to_list ~= "main" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		if item_defs[stack:get_name()] then
			return 0
		end
	end
end)

function wob_abilities.try_cast(user, def, pointed_thing)
	if user:get_hp() <= 0 then
		return
	end
	if wob_classes.get_class(user) ~= def.class then
		wob_abilities.flash(user, "You are no " ..
			wob_classes.registered_classes[def.class].name .. ".")
		return
	end
	local name = user:get_player_name()
	local now = core.get_us_time()
	-- Global cooldown: silent gate (mashing during the GCD is normal, a
	-- flash per blocked click would be pure noise).
	if gcd_expiry[name] and now < gcd_expiry[name] then
		return
	end
	cooldowns[name] = cooldowns[name] or {}
	local expiry = cooldowns[name][def.id]
	if expiry and now < expiry then
		wob_abilities.flash(user, def.name .. " is not ready.")
		return
	end
	if not affordable(user, def.cost) then
		wob_abilities.flash(user,
			"Not enough " .. (def.cost.mana and "mana" or "rage") .. ".")
		return
	end
	-- A false return means "no valid cast" (e.g. no target): no cost, no
	-- cooldown, no GCD. def is passed through for the target-lock helpers
	-- (range checks).
	local ok, err = def.cast(user, pointed_thing, def)
	if not ok then
		wob_abilities.flash(user, err or "Invalid target.")
		return
	end
	spend(user, def.cost)
	gcd_expiry[name] = core.get_us_time() + wob_abilities.GCD * 1e6
	if def.cooldown > 0 then
		cooldowns[name][def.id] = core.get_us_time() + def.cooldown * 1e6
		wear_steps[name] = wear_steps[name] or {}
		wear_steps[name][def.id] = WEAR_STEPS
		set_item_wear(user, def.id, 65534)
	end
end

--
-- Kit granting: exactly one item per class ability, foreign class items are
-- purged, wear resets with the (runtime) cooldowns. Runs on join and on
-- class pick/switch. Talent-gated abilities (def.talent_gated, e.g. Renew)
-- stay registered but are NOT part of the base kit — WP11's talent system
-- will grant them. The elf range passive lands here as a per-stack meta
-- `range` override (engine 5.9+: overrides the pointing range), so
-- pointed_thing reaches as far as wob_abilities.get_range allows.
--

local function sync_kit(player)
	local class = wob_classes.get_class(player)
	local name = player:get_player_name()
	cooldowns[name] = {}
	gcd_expiry[name] = nil
	wear_steps[name] = {}
	slot_cache[name] = {}
	local range_bonus = wob_classes.get_race_perk(player, "ability_range_bonus") or 0
	local inv = player:get_inventory()
	local have = {}
	for listname, list in pairs(inv:get_lists()) do
		for i, stack in ipairs(list) do
			local def = item_defs[stack:get_name()]
			if def then
				-- Only granted items in "main" count as present:
				-- foreign-class items, talent-gated items (not granted
				-- yet), duplicates and strays in other lists (bags from
				-- old saves) are removed; own-class strays re-granted
				-- into main below.
				if def.class ~= class or def.talent_gated or
						listname ~= "main" or have[stack:get_name()] then
					inv:set_stack(listname, i, ItemStack(""))
				else
					have[stack:get_name()] = true
					local changed = false
					if stack:get_wear() ~= 0 then
						stack:set_wear(0)
						changed = true
					end
					local meta = stack:get_meta()
					local desired = range_bonus > 0
						and (def.range or 4) + range_bonus or 0
					if meta:get_float("range") ~= desired then
						if desired > 0 then
							meta:set_float("range", desired)
						else
							meta:set_string("range", "") -- remove override
						end
						changed = true
					end
					if changed then
						inv:set_stack(listname, i, stack)
					end
				end
			end
		end
	end
	for _, def in ipairs(wob_abilities.by_class[class] or {}) do
		local itemname = "wob_abilities:" .. def.id
		if not def.talent_gated and not have[itemname] then
			local stack = ItemStack(itemname)
			if range_bonus > 0 then
				stack:get_meta():set_float("range",
					(def.range or 4) + range_bonus)
			end
			inv:add_item("main", stack)
		end
	end
end

wob_classes.register_on_class_chosen(function(player, class_id)
	sync_kit(player)
	refill_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

--
-- Rage generation (classes.md §1): +12 per melee auto-attack hit dealt
-- (ability punches excluded via wob_core.in_ability_punch), +4 per hit
-- taken (+1 with the orc passive, world.md §7). Charge's +15 lives in the
-- ability itself. Punches also refresh the soft target lock ("last
-- punched enemy or ally").
--

wob_core.register_on_player_hit_mob(function(player, mob_ent, damage)
	if mob_ent.object and (mob_ent.health or 0) > 0 then
		wob_abilities.set_target(player, mob_ent.object, false)
	end
	if not wob_core.in_ability_punch and damage > 0 then
		wob_abilities.add_rage(player, 12)
	end
end)

core.register_on_punchplayer(function(player, hitter)
	if not (hitter and hitter:is_player()) then
		return
	end
	if wob_factions.hostile(hitter, player) then
		wob_abilities.set_target(hitter, player, false)
		if not wob_core.in_ability_punch then
			wob_core.mark_in_combat(hitter)
			wob_abilities.add_rage(hitter, 12)
		end
	elseif wob_factions.same_faction(hitter, player) then
		-- Friendly fire deals no damage (wob_factions), but punching an
		-- ally targets them for heals.
		wob_abilities.set_target(hitter, player, true)
	end
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and reason.type == "punch" then
		wob_abilities.add_rage(player, 4
			+ (wob_classes.get_race_perk(player, "rage_per_hit_taken_bonus") or 0))
	end
end, false)

--
-- Regen / decay / cooldown ticker (0.5 s): mana 2%/s out of combat,
-- 0.5%/s in combat; rage decays 2/s out of combat (combat_stats §5,
-- classes.md §1). Cooldown wear is updated here too.
--

local acc = 0

core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < 0.5 then
		return
	end
	local elapsed = acc
	acc = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local res = resource_of(player)
		if res == "mana" then
			local max = wob_classes.get_max_mana(player)
			local cur = math.min(mana[name] or 0, max)
			-- Troll passive (world.md §7): +50% out-of-combat regen. Today
			-- this multiplier only reaches mana (HP regen does not exist
			-- yet); WP21's HP regen must consume the same perk.
			local rate
			if wob_core.in_combat(player) then
				rate = 0.005
			else
				rate = 0.02
					* (wob_classes.get_race_perk(player, "ooc_regen_mult") or 1)
			end
			local new = math.min(max, cur + max * rate * elapsed)
			if math.floor(new) ~= math.floor(mana[name] or 0) then
				mana[name] = new
				hud_update(player)
			else
				mana[name] = new
			end
		elseif res == "rage" and not wob_core.in_combat(player) then
			local cur = rage[name] or 0
			if cur > 0 then
				local new = math.max(0, cur - 2 * elapsed)
				rage[name] = new
				if math.floor(new) ~= math.floor(cur) then
					hud_update(player)
				end
			end
		end
		-- cooldown wear display (write only when the visible step changes)
		local cds = cooldowns[name]
		if cds then
			local now = core.get_us_time()
			local steps = wear_steps[name] or {}
			wear_steps[name] = steps
			for id, expiry in pairs(cds) do
				local remaining = (expiry - now) / 1e6
				if remaining <= 0 then
					cds[id] = nil
					steps[id] = nil
					set_item_wear(player, id, 0)
				else
					local frac = remaining / wob_abilities.registered[id].cooldown
					local step = math.max(1,
						math.min(WEAR_STEPS, math.ceil(frac * WEAR_STEPS)))
					if step ~= steps[id] then
						steps[id] = step
						set_item_wear(player, id,
							math.floor(step / WEAR_STEPS * 65534))
					end
				end
			end
		end
	end
end)

--
-- Player lifecycle
--

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	resource_huds[name] = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 1},
		offset = {x = 0, y = -135},
		alignment = {x = 0, y = 0},
		number = 0xffffff,
		text = "",
	})
	flash_huds[name] = {token = 0, id = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0.35},
		offset = {x = 0, y = 0},
		alignment = {x = 0, y = 0},
		number = 0xff4444,
		text = "",
	})}
	rage[name] = 0
	refill_mana(player)
	sync_kit(player)
	hud_update(player)
end)

core.register_on_respawnplayer(function(player)
	refill_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	mana[name] = nil
	rage[name] = nil
	cooldowns[name] = nil
	gcd_expiry[name] = nil
	targets[name] = nil
	wear_steps[name] = nil
	slot_cache[name] = nil
	resource_huds[name] = nil
	flash_huds[name] = nil
end)

-- Mana pool grows with Int on level up: clamp/refresh the HUD (no refill).
wob_xp.register_on_level_change(function(player, old_level, new_level)
	hud_update(player)
end)

dofile(core.get_modpath(core.get_current_modname()) .. "/kits.lua")
