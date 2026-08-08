-- Class abilities (docs/design/classes.md): hotbar items with cooldowns,
-- mana/rage resources with HUD line, kit granting on class pick. Resources
-- and cooldowns are runtime state (not persisted): mana is full on
-- join/respawn, rage starts at 0.

grug_abilities = {}

grug_abilities.registered = {} -- ability id -> def
grug_abilities.by_class = {} -- class id -> ordered list of defs
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
grug_abilities.GCD = 1.0

-- Soft target lock (classes.md core principles): the last punched/pointed
-- enemy or ally stays the implicit target this long; abilities fall back
-- to it when pointed_thing has no valid target.
grug_abilities.TARGET_LOCK = 8

local function resource_of(player)
	local def = grug_classes.get_class_def(player)
	return def and def.resource or nil
end

--
-- Resource API
--

function grug_abilities.get_mana(player)
	return math.floor(mana[player:get_player_name()] or 0)
end

function grug_abilities.get_rage(player)
	return math.floor(rage[player:get_player_name()] or 0)
end

local hud_update -- forward

function grug_abilities.add_rage(player, amount)
	if resource_of(player) ~= "rage" then
		return
	end
	local name = player:get_player_name()
	rage[name] = math.max(0, math.min(100, (rage[name] or 0) + amount))
	hud_update(player)
end

local function refill_mana(player)
	mana[player:get_player_name()] = grug_classes.get_max_mana(player)
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

function grug_abilities.set_target(player, obj, ally)
	local name = player:get_player_name()
	targets[name] = targets[name] or {}
	targets[name][ally and "ally" or "enemy"] = {
		obj = obj,
		expiry = core.get_us_time() + grug_abilities.TARGET_LOCK * 1e6,
	}
end

-- Locked enemy (ally = false) or ally (ally = true) — nil when no lock,
-- expired, or the object is gone (mob died/unloaded, player left;
-- invalid ObjectRefs return nil from get_pos).
function grug_abilities.get_target(player, ally)
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
function grug_abilities.get_range(player, def)
	return (def.range or 4)
		+ (grug_classes.get_race_perk(player, "ability_range_bonus") or 0)
end

--
-- HUD: resource line above the XP line (mana blue / rage red) and a
-- short-lived error flash top center ("Not enough mana", "No target", ...).
--

local function hud_state(player)
	local res = resource_of(player)
	if res == "mana" then
		return ("Mana %d / %d"):format(grug_abilities.get_mana(player),
			grug_classes.get_max_mana(player)), 0x4a9bd8
	elseif res == "rage" then
		return ("Rage %d / 100"):format(grug_abilities.get_rage(player)), 0xc41e3a
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

function grug_abilities.flash(player, msg)
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

function grug_abilities.register_ability(def)
	assert(def.id and def.class and def.cast and def.cooldown,
		"incomplete ability definition")
	def.cost = def.cost or {}
	-- Which equipment slot's item this ability wears and (from T4 on) swings
	-- (weapon-slot design C1). "weapon" is the default and every shipped
	-- ability takes it -- deliberately INCLUDING the ones that deal no weapon
	-- damage at all (Blink, Renew, Power Word: Shield): "all skills use the
	-- weapon skin" is the rule, and an exception list would put the orb back on
	-- precisely the abilities whose colour is hardest to remember. "offhand"
	-- exists for WP14's shield abilities and has no user yet -- it is built now
	-- so WP14 does not pay for the same plumbing twice.
	def.slot = def.slot or "weapon"
	assert(def.slot == "weapon" or def.slot == "offhand",
		"ability slot must be \"weapon\" or \"offhand\"")
	grug_abilities.registered[def.id] = def
	grug_abilities.by_class[def.class] = grug_abilities.by_class[def.class] or {}
	table.insert(grug_abilities.by_class[def.class], def)

	local class_def = grug_classes.registered_classes[def.class]
	local cost_line = def.cost.mana and (def.cost.mana .. " mana")
		or def.cost.rage and (def.cost.rage .. " rage") or "free"
	local cd_line = def.cooldown > 0 and (def.cooldown .. " s cooldown")
		or "no cooldown"
	local itemname = "grug_abilities:" .. def.id
	item_defs[itemname] = def

	core.register_tool(itemname, {
		description = def.name .. " (" .. class_def.name .. ")\n" ..
			cost_line .. ", " .. cd_line .. "\n" ..
			def.description,
		inventory_image = "grug_abilities_orb.png^[multiply:" .. def.color,
		wield_image = "grug_abilities_orb.png^[multiply:" .. def.color,
		range = def.range or 4,
		stack_max = 1,
		groups = {grug_ability = 1, not_in_creative_inventory = 1},
		on_drop = function(itemstack)
			return itemstack -- ability items cannot be dropped
		end,
		on_use = function(itemstack, user, pointed_thing)
			grug_abilities.try_cast(user, def, pointed_thing)
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
	local itemname = "grug_abilities:" .. ability_id
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
-- allow callbacks OR-combine (see grug_inventory): return nil when
-- unconcerned, a number swallows later callbacks.
core.register_allow_player_inventory_action(function(player, action, inventory, info)
	if action == "move" and info.to_list ~= "main" then
		local stack = inventory:get_stack(info.from_list, info.from_index)
		if item_defs[stack:get_name()] then
			return 0
		end
	end
end)

function grug_abilities.try_cast(user, def, pointed_thing)
	if user:get_hp() <= 0 then
		return
	end
	if grug_classes.get_class(user) ~= def.class then
		grug_abilities.flash(user, "You are no " ..
			grug_classes.registered_classes[def.class].name .. ".")
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
		grug_abilities.flash(user, def.name .. " is not ready.")
		return
	end
	if not affordable(user, def.cost) then
		grug_abilities.flash(user,
			"Not enough " .. (def.cost.mana and "mana" or "rage") .. ".")
		return
	end
	-- A false return means "no valid cast" (e.g. no target): no cost, no
	-- cooldown, no GCD. def is passed through for the target-lock helpers
	-- (range checks).
	local ok, err = def.cast(user, pointed_thing, def)
	if not ok then
		grug_abilities.flash(user, err or "Invalid target.")
		return
	end
	spend(user, def.cost)
	gcd_expiry[name] = core.get_us_time() + grug_abilities.GCD * 1e6
	if def.cooldown > 0 then
		cooldowns[name][def.id] = core.get_us_time() + def.cooldown * 1e6
		wear_steps[name] = wear_steps[name] or {}
		wear_steps[name][def.id] = WEAR_STEPS
		set_item_wear(user, def.id, 65534)
	end
end

--
-- Ability item skins (weapon-slot design C1-C4). Every ability item wears the
-- item that sits in its slot: a Warrior with a sword equipped holds HIS sword
-- no matter which ability is selected, and swapping the weapon swaps all four
-- icons at once. The mechanism is the per-stack meta override of A1
-- (lua_api.md:2929-2949, src/inventory.cpp:258-295) -- no new item
-- registrations, no new asset, no engine patch.
--
-- C3 (a), the orb backdrop: the hotbar icon is the tinted orb DIMMED, with the
-- weapon art composited on top, so the colour the eye already learned stays a
-- large area. The wield (in-hand) image is the weapon art ALONE -- a glowing
-- disc extruded into a slab in the player's hand is exactly the "round thing"
-- this work removes.
--
-- C2, empty slot: the meta keys are simply NOT written, so the item definition's
-- own tinted orb shows through and a character without a weapon looks exactly
-- like the game did before this. An empty slot makes skills weak, never
-- uncastable.
--

local ORB_TEXTURE = "grug_abilities_orb.png"
-- Alpha of the backdrop, 0..255. Dimmed so the weapon on top stays the thing
-- you read first; the hue still carries the ability identity.
local ORB_BACKDROP_ALPHA = 150

-- The skin token: what a stack has to say about itself so a sync can decide, in
-- ONE string compare, that it is already correct. Load-bearing, not polish --
-- every inventory write re-sends the whole list to the client, which is why the
-- cooldown-wear path above is so stingy and why the GCD is not displayed at all
-- (D2/2). Without it, dragging any item would rewrite four stacks.
--
-- Shape: "<version>|<source image>", or the empty string for "no skin" (which
-- is also what an untouched stack answers, so a weaponless character never
-- writes anything). The source image is in the token rather than just the item
-- NAME because that is what the composed strings actually depend on -- a
-- per-stack image override on the weapon (a WP5 affix) must not read as
-- unchanged. SKIN_VERSION is bumped whenever the composition below changes, or
-- an already-granted stack would keep the old look forever.
local SKIN_VERSION = 1
local SKIN_TOKEN_KEY = "grug_skin"

-- The equipment list behind each ability slot. This is grug_inventory's
-- vocabulary, but grug_abilities deliberately does not depend on that mod --
-- the seam is grug_core's, and `listname` arrives as a plain string. The names
-- are audited against the real slot table at mods_loaded below, because a
-- silent mismatch here would look exactly like "the skin never updates".
local SLOT_OF_LIST = {grug_weapon = "weapon", grug_offhand = "offhand"}

-- Source image of what is in one hand slot, or "" when there is nothing to wear
-- (empty slot, or an item that has no inventory image of its own -- a node
-- item). Mirrors the engine's own resolution order: stack meta wins over the
-- definition (src/inventory.cpp:258-266). `inventory_image` in a DEFINITION may
-- be an item image definition table rather than a string
-- (lua_api.md:10388-10392); the meta override is always a plain name.
local function slot_image(player, slot)
	local stack
	if slot == "offhand" then
		stack = grug_core.get_equipped_offhand(player)
	else
		stack = grug_core.get_equipped_weapon(player)
	end
	if not stack or stack:is_empty() then
		return ""
	end
	local img = stack:get_meta():get_string("inventory_image")
	if img == "" then
		local def = core.registered_items[stack:get_name()]
		img = def and def.inventory_image or ""
		if type(img) == "table" then
			img = img.name or ""
		end
	end
	return img
end

-- THE one place a texture-modifier string is composed (D2/5). These strings are
-- parsed CLIENT-side: a malformed one yields a generateImagePart error and an
-- untextured icon, not a server error, so there is exactly one site to get
-- right and no second one to drift from it.
--
-- Returns inventory_image, wield_image -- or nil, nil when there is nothing to
-- wear, which is the caller's signal to remove the overrides (C2).
--
-- Escaping: `src` is wrapped in `^( ... )` rather than backslash-escaped.
-- generateImage splits on top-level `^` only, tracking parentheses
-- (src/client/imagesource.cpp:1819-1847), so a source image that carries its
-- own modifier -- every grug_gear weapon does, they are tinted per bracket --
-- composes correctly as a group. Backslash escaping (lua_api.md:698-708) is
-- required only by modifiers that take a texture NAME as an argument
-- ([combine, [mask, [lowpart); we use none of those.
local function skin_images(color, src)
	if src == "" then
		return nil, nil
	end
	return ORB_TEXTURE .. "^[multiply:" .. color ..
		"^[opacity:" .. ORB_BACKDROP_ALPHA .. "^(" .. src .. ")", src
end

local function skin_token(src)
	if src == "" then
		return ""
	end
	return SKIN_VERSION .. "|" .. src
end

-- Skin one ability stack IN PLACE; returns true only when something actually
-- changed, i.e. only when the caller has to spend an inventory write.
--
-- Touches nothing but the three meta keys: the wear bar is the cooldown display
-- and stays whatever it was, and so does the elf `range` override.
local function apply_skin(stack, def, src)
	local meta = stack:get_meta()
	local token = skin_token(src)
	if meta:get_string(SKIN_TOKEN_KEY) == token then
		return false
	end
	local inv_img, wield_img = skin_images(def.color, src)
	-- Writing "" REMOVES the key (same as the `range` override below), which is
	-- how the empty slot gets back to the definition's own orb.
	meta:set_string("inventory_image", inv_img or "")
	meta:set_string("wield_image", wield_img or "")
	meta:set_string(SKIN_TOKEN_KEY, token)
	return true
end

-- Resolve each hand at most once per pass, and only when a stack actually asks
-- for it.
local function skin_source_cache(player)
	local cache = {}
	return function(def)
		local src = cache[def.slot]
		if not src then
			src = slot_image(player, def.slot)
			cache[def.slot] = src
		end
		return src
	end
end

-- Rewrite the skins of the granted ability items. `slot` limits the pass to one
-- hand; nil means both. Ability items live in "main" only (the allow callback
-- above enforces it), so this is one list, and it writes only the stacks whose
-- token is stale.
local function sync_skins(player, slot)
	local inv = player:get_inventory()
	local list = inv and inv:get_list("main")
	if not list then
		return
	end
	local source_of = skin_source_cache(player)
	for i = 1, #list do
		local stack = list[i]
		local def = item_defs[stack:get_name()]
		if def and (slot == nil or def.slot == slot) then
			if apply_skin(stack, def, source_of(def)) then
				inv:set_stack("main", i, stack)
			end
		end
	end
end

-- C4's third trigger (join and class pick are sync_kit's). Consumers of this
-- hook must be idempotent and cheap and may be called twice for one change --
-- both are the token compare's job.
--
-- `listname` is the one equipment list that changed, or nil for "assume
-- everything". An armor or trinket list cannot change any ability skin, so it
-- returns before touching the inventory at all; a list we do NOT recognise
-- (nil, or a slot added later) falls through to the full pass, because being
-- slow is recoverable and being silently wrong is not.
grug_core.register_on_equipment_change(function(player, listname)
	if listname then
		local slot = SLOT_OF_LIST[listname]
		if not slot then
			return
		end
		sync_skins(player, slot)
	else
		sync_skins(player, nil)
	end
end)

-- The list names above are a string contract with a mod we do not depend on.
-- If grug_inventory ever renames a slot list, the skins would simply stop
-- following the weapon, with nothing in the log to say why -- so check it once,
-- after every mod has registered its slots.
core.register_on_mods_loaded(function()
	if not core.global_exists("grug_inventory")
			or not grug_inventory.equipment_slots then
		return
	end
	local seen = {}
	for _, entry in ipairs(grug_inventory.equipment_slots) do
		if SLOT_OF_LIST[entry.list] then
			seen[SLOT_OF_LIST[entry.list]] = true
		end
	end
	for list, slot in pairs(SLOT_OF_LIST) do
		if not seen[slot] then
			core.log("error", "[grug_abilities] no equipment slot uses list \"" ..
				list .. "\" -- ability skins will not follow the " .. slot ..
				" slot")
		end
	end
end)

--
-- Kit granting: exactly one item per class ability, foreign class items are
-- purged, wear resets with the (runtime) cooldowns. Runs on join and on
-- class pick/switch. Talent-gated abilities (def.talent_gated, e.g. Renew)
-- stay registered but are NOT part of the base kit — WP11's talent system
-- will grant them. The elf range passive lands here as a per-stack meta
-- `range` override (engine 5.9+: overrides the pointing range), so
-- pointed_thing reaches as far as grug_abilities.get_range allows.
--

-- Does this ability belong in THIS character's kit? One predicate, used by both
-- the purge below and the grant loop, so the two can never disagree about what
-- a kit is. T3's universal auto-attack is granted to every class and must be
-- exempt from the purge (or it is granted and destroyed in the same pass): it
-- adds its flag HERE and to the grant loop's ability list, and nothing else in
-- sync_kit has to know.
local function in_kit(def, class)
	return def.class == class
end

local function sync_kit(player)
	local class = grug_classes.get_class(player)
	local name = player:get_player_name()
	cooldowns[name] = {}
	gcd_expiry[name] = nil
	wear_steps[name] = {}
	slot_cache[name] = {}
	local range_bonus = grug_classes.get_race_perk(player, "ability_range_bonus") or 0
	local source_of = skin_source_cache(player)
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
				if not in_kit(def, class) or def.talent_gated or
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
					-- The skin, same discipline as the range override above:
					-- compare first, write once, or not at all.
					if apply_skin(stack, def, source_of(def)) then
						changed = true
					end
					if changed then
						inv:set_stack(listname, i, stack)
					end
				end
			end
		end
	end
	for _, def in ipairs(grug_abilities.by_class[class] or {}) do
		local itemname = "grug_abilities:" .. def.id
		if not def.talent_gated and not have[itemname] then
			local stack = ItemStack(itemname)
			if range_bonus > 0 then
				stack:get_meta():set_float("range",
					(def.range or 4) + range_bonus)
			end
			-- Skin it BEFORE it reaches the inventory: a freshly granted item
			-- must not spend one write appearing as an orb and a second one
			-- turning into the weapon.
			apply_skin(stack, def, source_of(def))
			inv:add_item("main", stack)
		end
	end
end

grug_classes.register_on_class_chosen(function(player, class_id)
	sync_kit(player)
	refill_mana(player)
	rage[player:get_player_name()] = 0
	hud_update(player)
end)

--
-- Rage generation (classes.md §1): +12 per melee auto-attack hit dealt
-- (ability punches excluded via grug_core.in_ability_punch), +4 per hit
-- taken (+1 with the orc passive, world.md §7). Charge's +15 lives in the
-- ability itself. Punches also refresh the soft target lock ("last
-- punched enemy or ally").
--

grug_core.register_on_player_hit_mob(function(player, mob_ent, damage)
	if mob_ent.object and (mob_ent.health or 0) > 0 then
		grug_abilities.set_target(player, mob_ent.object, false)
	end
	if not grug_core.in_ability_punch and damage > 0 then
		grug_abilities.add_rage(player, 12)
	end
end)

core.register_on_punchplayer(function(player, hitter)
	if not (hitter and hitter:is_player()) then
		return
	end
	if grug_factions.hostile(hitter, player) then
		grug_abilities.set_target(hitter, player, false)
		if not grug_core.in_ability_punch then
			grug_core.mark_in_combat(hitter)
			grug_abilities.add_rage(hitter, 12)
		end
	elseif grug_factions.same_faction(hitter, player) then
		-- Friendly fire deals no damage (grug_factions), but punching an
		-- ally targets them for heals.
		grug_abilities.set_target(hitter, player, true)
	end
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change < 0 and reason.type == "punch" then
		grug_abilities.add_rage(player, 4
			+ (grug_classes.get_race_perk(player, "rage_per_hit_taken_bonus") or 0))
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
			local max = grug_classes.get_max_mana(player)
			local cur = math.min(mana[name] or 0, max)
			-- Troll passive (world.md §7): +50% out-of-combat regen. Today
			-- this multiplier only reaches mana (HP regen does not exist
			-- yet); WP21's HP regen must consume the same perk.
			local rate
			if grug_core.in_combat(player) then
				rate = 0.005
			else
				rate = 0.02
					* (grug_classes.get_race_perk(player, "ooc_regen_mult") or 1)
			end
			local new = math.min(max, cur + max * rate * elapsed)
			if math.floor(new) ~= math.floor(mana[name] or 0) then
				mana[name] = new
				hud_update(player)
			else
				mana[name] = new
			end
		elseif res == "rage" and not grug_core.in_combat(player) then
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
					local frac = remaining / grug_abilities.registered[id].cooldown
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
grug_xp.register_on_level_change(function(player, old_level, new_level)
	hud_update(player)
end)

dofile(core.get_modpath(core.get_current_modname()) .. "/kits.lua")
