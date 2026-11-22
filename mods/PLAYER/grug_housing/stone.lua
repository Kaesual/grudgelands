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
--
-- Round 86 (ruling 10): the Account Claim Stone grug_housing:account_stone
-- with grug_housing:account_stone_empty and _draft, the same three nodes in
-- their own look, placing a claim of kind "account" (account.lua,
-- registry.lua).
--
-- Round 86 lane ART (ruling 19, "Under One Roof"): every stone is a small
-- house inside its node, a node box drawn by stone_art.lua: one terracotta
-- gable with a chimney (personal), two slate gables (account); the empty
-- stone's windows are shuttered, the draft is the fuelled house washed pale
-- and half-transparent. The door faces the placer ("4dir"; a stone placed
-- before 0.86.0 has param2 0 and faces -Z).

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

-- Round 86: the claim kind the item places (STONE_ITEMS).
local function kind_of(itemstack)
	return grug_housing.STONE_ITEMS[itemstack:get_name()] or ""
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
	local kind = kind_of(itemstack)
	-- Round 86: an account stone's placer is checked against its binding first.
	if kind == model.ACCOUNT then grug_housing.reconcile_player(placer) end
	local ok, code, message = grug_housing.validate_placement(placer, pos, kind)
	if not ok then
		-- Ruling 16: a leftover account stone vanishes at the attempt.
		if code == "not_member" or code == "account_stands" then itemstack:take_item(1) end
		tell(placer, message)
		return itemstack
	end
	local draft = grug_housing.stone_nodes(kind).draft
	-- Round 72: the placement rules (grug_core: in combat, a live body's cell).
	if grug_core.placement_refused(placer, draft, {pos}) then return itemstack end
	-- A new claim is a draft until the owner activates it (R26 ruling 8).
	-- The door faces the placer, as the engine turns a placed furnace.
	local from = placer:get_pos()
	core.set_node(pos, {name = draft, param2 = core.dir_to_fourdir(
		{x = pos.x - from.x, y = 0, z = pos.z - from.z})})
	local claim = model.create(name, pos, kind)
	itemstack:take_item(1)
	grug_housing.notify_claim_changed(claim, "placed")
	tell(placer, ("Claim Stone placed as a draft. Open it and activate it " ..
		"with %d coal, charcoal or anthracite within %d minutes, or it crumbles."):format(
		model.ACTIVATION_LUMPS, model.DRAFT_SECONDS / 60))
	core.log("action", ("[grug_housing] %s placed Claim Stone %d at %s"):format(
		name, claim.id, core.pos_to_string(pos)))
	return itemstack
end

local function on_rightclick(pos, node, clicker, itemstack)
	if not clicker or not clicker:is_player() then return itemstack end
	local claim = claim_of_stone(pos)
	if not claim then return itemstack end
	if grug_housing.is_owner(claim, clicker:get_player_name()) then
		grug_housing.open_stone_interface(clicker, claim)
	elseif model.parse_owner_text(claim.owner) then
		-- Round 86: an account claim names its home (lane NAMES' name), never
		-- its owner text.
		core.chat_send_player(clicker:get_player_name(),
			"Account Claim Stone of " .. grug_housing.home_name(claim) .. ".")
	else
		core.chat_send_player(clicker:get_player_name(),
			(model.is_draft(claim) and "Unfinished " or "") ..
			(claim.kind == model.ACCOUNT and "Account Claim Stone of " or "Claim Stone of ") ..
			claim.owner .. ".")
	end
	return itemstack
end

-- Ruling 8: dropping the stone destroys it. Round 86: an Account Claim
-- Stone changes no record (its member may get one again while the
-- account's claim does not stand).
local function on_drop(itemstack, dropper)
	if dropper and dropper:is_player() then
		local name = dropper:get_player_name()
		if kind_of(itemstack) == model.ACCOUNT then
			tell(dropper, "Your Account Claim Stone crumbles to dust. While your account's " ..
				"home does not stand, a Housing Steward gives you a new one.")
			return ItemStack("")
		end
		model.stone_lost(name)
		tell(dropper, "Your Claim Stone crumbles to dust. A Housing Steward " ..
			"in one of your faction's capitals gives you a new one.")
	end
	return ItemStack("")
end

local sounds = rawget(_G, "default") and default.node_sound_stone_defaults() or nil
-- The look per kind and state (lane ART's data: boxes, six tiles each).
local ART = dofile(core.get_modpath("grug_housing") .. "/stone_art.lua")
-- The fuelled stone's flat front (its door) names the stone in the claim's
-- waypoint row (Round 45 PT9, grug_home.claim_waypoint); the map and the
-- minimap draw their own claim icon there (grug_map/providers.lua).
grug_housing.STONE_TEXTURE = ART[""].marker_texture
grug_housing.ACCOUNT_STONE_TEXTURE = ART.account.marker_texture
local STATE_OF = {item = "active", empty = "empty", draft = "draft"}
-- One box around all of a house's boxes (Round 86 ART fix 1): what is
-- pointed at, so the outline is a plain box and a ray past the stepped roof
-- still hits the stone. What is stood on stays the house as drawn.
local function bounds(shape)
	local box = {0.5, 0.5, 0.5, -0.5, -0.5, -0.5}
	for _, part in ipairs(shape.fixed) do
		for axis = 1, 3 do
			box[axis] = math.min(box[axis], part[axis])
			box[axis + 3] = math.max(box[axis + 3], part[axis + 3])
		end
	end
	return {type = "fixed", fixed = box}
end
-- Sets the look of `variant` (item, empty, draft) of `kind` on def: the
-- house's boxes, which are also what is stood on, the box around them,
-- which is pointed at, and its tiles; the item carries its own flat picture
-- for the hand and the inventory.
local function look(def, kind, variant)
	local art = ART[kind][STATE_OF[variant]]
	def.drawtype = "nodebox"
	def.node_box, def.selection_box, def.collision_box =
		art.node_box, bounds(art.selection_box), art.collision_box
	def.tiles = art.tiles
	if variant == "item" then
		def.inventory_image, def.wield_image = ART[kind].inventory_image, ART[kind].wield_image
	end
	return def
end

-- The three nodes' definitions per kind (Round 86: the account stone's
-- are copies, below).
local DEFS = {}
DEFS.item = {
	description = "Claim Stone\nClaims the map square (80 x 80) it stands in " ..
		"as your home once you activate it with 5 coal within 5 minutes.\nHold " ..
		"it to see on the minimap which squares you can claim.\nSoulbound: " ..
		"dropping it destroys it.",
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "4dir",
	-- Ruling 20: only the fuelled stone gives light.
	light_source = 8,
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
}
core.register_node(STONE, look(DEFS.item, "", "item"))

DEFS.empty = {
	description = "Claim Stone (no fuel)",
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "4dir",
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
		for _, name in ipairs(model.owner_names(claim)) do
			local owner = core.get_player_by_name(name)
			if owner then tell(owner, "Your Claim Stone has been destroyed.") end
		end
		core.log("action", ("[grug_housing] Claim Stone %d of %s destroyed by %s"):format(
			claim.id, claim.owner, digger and digger:get_player_name() or "?"))
	end,
	on_blast = function() end,
}
core.register_node(EMPTY, look(DEFS.empty, "", "empty"))

-- The draft (R26 ruling 8): nobody digs it, not even the owner, who picks it
-- up through the form at any time. Half-transparent ("blend" over the tiles'
-- own opacity), so the ground behind it shows.
DEFS.draft = {
	description = "Claim Stone (draft)",
	use_texture_alpha = "blend",
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	groups = {not_in_creative_inventory = 1, grug_claim_stone_node = 1},
	drop = "",
	sounds = sounds,
	node_placement_prediction = "",
	on_place = function(itemstack) return itemstack end,
	on_drop = function() return ItemStack("") end,
	on_rightclick = on_rightclick,
	can_dig = function() return false end,
	on_blast = function() end,
}
core.register_node(DRAFT, look(DEFS.draft, "", "draft"))

-- Round 86 ruling 10: the Account Claim Stone's three nodes, copies of the
-- personal ones in the account's look.
local COPIED = {"use_texture_alpha", "paramtype", "paramtype2", "sunlight_propagates",
	"light_source", "stack_max", "groups", "drop", "sounds", "node_placement_prediction",
	"on_place", "on_drop", "on_rightclick", "can_dig", "after_dig_node", "on_blast"}
local function account_node(variant, description)
	local source = DEFS[variant]
	local def = look({description = description}, model.ACCOUNT, variant)
	for _, field in ipairs(COPIED) do
		local value = rawget(source, field)
		if type(value) == "table" then
			local copy = {}
			for key, entry in pairs(value) do copy[key] = entry end
			value = copy
		end
		def[field] = value
	end
	core.register_node(grug_housing.STONE_KINDS[model.ACCOUNT][variant], def)
end
-- The item text: the personal stone's placement lines (lane PREVIEW's),
-- with the account's line.
account_node("item", "Account Claim Stone\n" ..
	DEFS.item.description:gsub("^[^\n]*\n", "")
		:gsub("\nSoulbound", "\nShared: every character of your account in this " ..
			"faction that chose it owns it fully; only one can be activated.\nSoulbound"))
account_node("empty", "Account Claim Stone (no fuel)")
account_node("draft", "Account Claim Stone (draft)")

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
-- block loads). Round 81 (audit P4-02, X4-11): every CHECK_SECONDS cycle
-- starts with the draft and expiry scans (the registry keeps what can be due,
-- so they walk no claim when nothing is), and the stones' node check is
-- spread over SLICES ticks of the cycle, a slice of the id-ordered claims
-- each (the ordered list is copied again only when a claim came or went).
-- Each claim is still checked once per cycle, in id order; a claim placed
-- during a cycle is first checked in the next one, so a vanished stone may be
-- noticed up to one cycle later than before. The rule holds for every claim
-- whether its owner is online or not: visitors see the stone, and the
-- vanished-stone rule does not ask for the owner.
local CHECK_SECONDS = 5
local SLICES = 8
local TICK = CHECK_SECONDS / SLICES
local elapsed, tick = 0, 0
local order, order_version, slice = {}, nil, 0

local function check_stone(claim)
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

local function start_cycle()
	local drafts = model.draft_scan()
	for index = 1, #drafts do expire_draft(drafts[index]) end
	local expired = model.expiry_scan()
	for index = 1, #expired do
		grug_housing.sync_stone_node(expired[index])
		grug_housing.notify_claim_changed(expired[index], "expired")
	end
	local version = model.claim_set_version()
	if version ~= order_version then
		order, order_version = model.all_claims(), version
	end
	slice = math.ceil(#order / SLICES)
end

-- A long (lagging) step serves every tick it covered, at most SLICES.
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < TICK then return end
	local due = math.min(SLICES, math.floor(elapsed / TICK))
	elapsed = elapsed - due * TICK
	if elapsed >= TICK then elapsed = elapsed % TICK end
	for _ = 1, due do
		tick = tick % SLICES + 1
		if tick == 1 then start_cycle() end
		for index = (tick - 1) * slice + 1, math.min(tick * slice, #order) do
			local claim = order[index]
			-- A claim removed since the list was made is no longer checked.
			if model.claim_by_id(claim.id) == claim then check_stone(claim) end
		end
	end
end)
