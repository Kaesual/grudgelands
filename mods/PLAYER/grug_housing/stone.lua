-- The Claim Stone item and its three nodes (rulings 6-12, Round 26 rulings
-- 8-10).
--
-- grug_housing:claim_stone (STONE_ITEM) is the soulbound item and the
-- fuelled stone: no dig group, so nothing can dig it, the owner included.
-- grug_housing:claim_stone_draft is what placing sets: the half-transparent
-- draft, which nobody can dig either (the owner picks it up through the
-- form). It disappears DRAFT_SECONDS after placing unless it is activated.
-- grug_housing:claim_stone_empty is the activated stone without fuel: a pick
-- digs it in the engine's own time (a `grug_claim_stone` groupcap on every
-- pick, T1 60 s down to T6 10 s); the hand and the skill hand have no such
-- cap. Digging it destroys the claim and drops nothing. A periodic check
-- removes expired drafts, keeps every loaded stone on the variant its claim
-- asks for and reports expiry.

local model = grug_housing.model
local STONE = grug_housing.STONE_ITEM
local EMPTY = grug_housing.EMPTY_STONE
local DRAFT = grug_housing.DRAFT_STONE
local STONE_NODES = grug_housing.STONE_NODES

-- Ruling 12: seconds to dig an empty stone with a pick of each tier.
grug_housing.DIG_SECONDS = {60, 50, 40, 30, 20, 10}

local function tell(player, text)
	if grug_core.flash then grug_core.flash(player, text) end
	core.chat_send_player(player:get_player_name(), text)
end

local function claim_of_stone(pos)
	local claim = model.claim_at(pos)
	if claim and claim.center.x == pos.x and claim.center.y == pos.y and
			claim.center.z == pos.z then
		return claim
	end
	return nil
end

local function on_place(itemstack, placer, pointed_thing)
	if not placer or not placer:is_player() or pointed_thing.type ~= "node" then
		return itemstack
	end
	local under = pointed_thing.under
	local under_node = core.get_node(under)
	local under_def = core.registered_nodes[under_node.name]
	if under_def and under_def.on_rightclick and
			not placer:get_player_control().sneak then
		return under_def.on_rightclick(under, under_node, placer, itemstack,
			pointed_thing) or itemstack
	end
	local pos = (under_def and under_def.buildable_to) and under or
		pointed_thing.above
	local target = core.get_node_or_nil(pos)
	local target_def = target and core.registered_nodes[target.name]
	if not target_def or not target_def.buildable_to then return itemstack end
	local name = placer:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return itemstack
	end
	pos = {x = pos.x, y = pos.y, z = pos.z}
	local ok, _, message = grug_housing.validate_placement(placer, pos)
	if not ok then
		tell(placer, message)
		return itemstack
	end
	-- A new claim is a draft until the owner activates it (R26 ruling 8).
	core.set_node(pos, {name = DRAFT})
	local claim = model.create(name, pos)
	itemstack:take_item(1)
	grug_housing.notify_claim_changed(claim, "placed")
	tell(placer, ("Claim Stone placed as a draft. Open it and activate it " ..
		"with %d coal or charcoal within %d minutes, or it crumbles."):format(
		model.ACTIVATION_LUMPS, model.DRAFT_SECONDS / 60))
	core.log("action", ("[grug_housing] %s placed Claim Stone %d at %s"):format(
		name, claim.id, core.pos_to_string(pos)))
	return itemstack
end

local function on_rightclick(pos, node, clicker, itemstack)
	if not clicker or not clicker:is_player() then return itemstack end
	local claim = claim_of_stone(pos)
	if not claim then return itemstack end
	if claim.owner == clicker:get_player_name() then
		grug_housing.open_stone_interface(clicker, claim)
	else
		core.chat_send_player(clicker:get_player_name(),
			(model.is_draft(claim) and "Unfinished Claim Stone of " or
				"Claim Stone of ") .. claim.owner .. ".")
	end
	return itemstack
end

-- Ruling 8: dropping the stone destroys it.
local function on_drop(itemstack, dropper)
	if dropper and dropper:is_player() then
		local name = dropper:get_player_name()
		model.stone_lost(name)
		tell(dropper, "Your Claim Stone crumbles to dust. A Housing Steward " ..
			"in one of your faction's capitals gives you a new one.")
	end
	return ItemStack("")
end

local sounds = rawget(_G, "default") and default.node_sound_stone_defaults() or nil
local TEXTURE = "default_obsidian_block.png^[colorize:#7a5cc0:70"
-- The fuelled stone's look is also its waypoint marker on the map and the
-- minimap (Round 45 PT9, grug_home.claim_waypoint).
grug_housing.STONE_TEXTURE = TEXTURE
local EMPTY_TEXTURE = "default_obsidian_block.png^[colorize:#3a3a3a:120"
-- R26 ruling 8: the draft looks unfinished, half-transparent like water.
local DRAFT_TEXTURE = TEXTURE .. "^[opacity:150"

core.register_node(STONE, {
	description = "Claim Stone\nPlace it in your faction's home land (level " ..
		"11-30 zones) and activate it with 5 coal within 5 minutes to claim a " ..
		"101 x 101 home.\nSoulbound: dropping it destroys it.",
	tiles = {TEXTURE},
	paramtype = "light",
	light_source = 4,
	stack_max = 1,
	-- No dig group: nobody digs a fuelled stone (ruling 12).
	groups = {not_in_creative_inventory = 1, grug_soulbound = 1,
		grug_claim_stone_node = 1},
	drop = "",
	sounds = sounds,
	-- The server validates every placement (rulings 3-6); no client guess.
	node_placement_prediction = "",
	on_place = on_place,
	on_drop = on_drop,
	on_rightclick = on_rightclick,
	can_dig = function() return false end,
	on_blast = function() end,
})

core.register_node(EMPTY, {
	description = "Claim Stone (no fuel)",
	tiles = {EMPTY_TEXTURE},
	paramtype = "light",
	groups = {not_in_creative_inventory = 1, grug_claim_stone = 1,
		grug_claim_stone_node = 1},
	drop = "",
	sounds = sounds,
	node_placement_prediction = "",
	on_place = function(itemstack) return itemstack end,
	on_drop = function() return ItemStack("") end,
	on_rightclick = on_rightclick,
	-- The engine gates the dig by the pick groupcap; this re-checks on the
	-- server that the claim really is empty and the tool is a pick.
	can_dig = function(pos, player)
		local claim = claim_of_stone(pos)
		if claim and model.is_active(claim) then return false end
		local tool = player and player:is_player() and player:get_wielded_item()
		return tool ~= nil and tool ~= false and
			core.get_item_group(tool:get_name(), "grug_pick_tier") > 0
	end,
	after_dig_node = function(pos, _, _, digger)
		local claim = claim_of_stone(pos)
		if not claim then return end
		model.remove(claim, "destroyed")
		grug_housing.notify_claim_changed(claim, "destroyed")
		local owner = core.get_player_by_name(claim.owner)
		if owner then tell(owner, "Your Claim Stone has been destroyed.") end
		core.log("action", ("[grug_housing] Claim Stone %d of %s destroyed by %s"):format(
			claim.id, claim.owner, digger and digger:get_player_name() or "?"))
	end,
	on_blast = function() end,
})

-- The draft (R26 ruling 8): nobody digs it, not even the owner, who picks it
-- up through the form at any time. Glasslike, so the ground behind it shows.
core.register_node(DRAFT, {
	description = "Claim Stone (draft)",
	drawtype = "glasslike",
	tiles = {DRAFT_TEXTURE},
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = 2,
	groups = {not_in_creative_inventory = 1, grug_claim_stone_node = 1},
	drop = "",
	sounds = sounds,
	node_placement_prediction = "",
	on_place = function(itemstack) return itemstack end,
	on_drop = function() return ItemStack("") end,
	on_rightclick = on_rightclick,
	can_dig = function() return false end,
	on_blast = function() end,
})

-- Every pick digs an empty stone in its tier's time (ruling 12). Added once
-- all tools exist; per-stack capabilities (grug_quality) copy the definition
-- later at runtime.
core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_items) do
		local tier = tonumber((def.groups or {}).grug_pick_tier)
		local seconds = tier and grug_housing.DIG_SECONDS[tier]
		if seconds and def.tool_capabilities then
			local caps = table.copy(def.tool_capabilities)
			caps.groupcaps = caps.groupcaps or {}
			caps.groupcaps.grug_claim_stone = {times = {[1] = seconds},
				uses = 0, maxlevel = 0}
			core.override_item(name, {tool_capabilities = caps})
		end
	end
end)

-- R26 ruling 8: a draft not activated within DRAFT_SECONDS crumbles, whether
-- its owner is online or not (wall clock, so a restart does not stop it). Its
-- node goes too, its block loaded for that if needed; the owner may fetch a
-- new stone from a Housing Steward at once.
local function expire_draft(claim)
	grug_housing.remove_stone_node(claim)
	model.remove(claim, "draft_expired")
	grug_housing.notify_claim_changed(claim, "draft_expired")
	local owner = core.get_player_by_name(claim.owner)
	if owner then
		tell(owner, "Your Claim Stone was not activated in time and crumbled. " ..
			"A Housing Steward gives you a new one.")
	end
	core.log("action", ("[grug_housing] draft Claim Stone %d of %s expired"):format(
		claim.id, claim.owner))
end

-- Expiry and stone variants, every few seconds (no map loading apart from an
-- expired draft: an unloaded stone is set right by the first check after its
-- block loads).
local CHECK_SECONDS = 5
local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < CHECK_SECONDS then return end
	elapsed = 0
	local drafts = model.draft_scan()
	for index = 1, #drafts do expire_draft(drafts[index]) end
	local expired = model.expiry_scan()
	for index = 1, #expired do
		grug_housing.sync_stone_node(expired[index])
		grug_housing.notify_claim_changed(expired[index], "expired")
	end
	local claims = model.all_claims()
	for index = 1, #claims do
		local claim = claims[index]
		local node = core.get_node_or_nil(claim.center)
		if node then
			if STONE_NODES[node.name] then
				grug_housing.sync_stone_node(claim)
			else
				-- The stone is gone from a loaded block without a dig or a
				-- pick-up: the claim goes with it.
				model.remove(claim, "destroyed")
				grug_housing.notify_claim_changed(claim, "destroyed")
				core.log("warning", ("[grug_housing] Claim Stone %d of %s vanished"):format(
					claim.id, claim.owner))
			end
		end
	end
end)
