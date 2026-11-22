-- Round 86 lane ART portable test (LuaJIT): the Claim Stone's look ("Under
-- One Roof", grug_housing/stone_art.lua) wired into the six nodes with
-- nothing else about the stones changed.
--
--   luajit tools/r86_art/portable_test.lua [REPO]
--
-- A. Each of the six nodes (personal and account x fuelled, empty, draft) is
--    a node box inside its node (so the arrival cube above stays free), the
--    same boxes are stood on and the one box around them is pointed at (fix
--    round 1); six tiles whose files exist; the fuelled and empty stones
--    opaque, the draft half-transparent ("blend" over its tiles' ^[opacity,
--    sunlight through it); light 8 for the fuelled stone only (ruling 20);
--    "4dir". The two items carry their flat pictures for the hand and
--    the inventory. Groups, drop, stack size and callbacks are those of
--    0.85.0, the account copies sharing the personal stone's callbacks.
--    STONE_TEXTURE and ACCOUNT_STONE_TEXTURE are the fuelled fronts.
-- B. Placing (the real stone.lua on_place) turns the door toward the placer
--    from each side; the draft -> fuelled -> empty swaps of the real
--    api.lua sync_stone_node keep that facing; a stone of 0.85.0 (param2 0)
--    keeps 0, a valid facing (door toward -Z).
-- Prints "R86 ART PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local function key(p) return p.x .. "/" .. p.y .. "/" .. p.z end
local nodes, store = {}, {}
local MOD = repo .. "/mods/PLAYER/grug_housing"

ItemStack = function(name)
	name = name or ""
	local s = {name = name, count = name == "" and 0 or 1}
	function s:get_name() return self.count > 0 and self.name or "" end
	function s:take_item(n) self.count = math.max(0, self.count - (n or 1)) end
	function s:is_empty() return self.count == 0 end
	return s
end
vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}

core = {
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return "grug_housing" end,
	get_mod_storage = function()
		return {get_string = function(_, k) return store[k] or "" end,
			set_string = function(_, k, v) store[k] = v end,
			get_keys = function() local t = {} for k in pairs(store) do t[#t + 1] = k end return t end}
	end,
	log = function() end,
	registered_nodes = {air = {buildable_to = true}, ["default:dirt"] = {}},
	registered_items = {},
	register_node = function(name, def)
		core.registered_nodes[name] = def; core.registered_items[name] = def
	end,
	register_on_mods_loaded = function() end,
	register_globalstep = function() end,
	register_on_leaveplayer = function() end,
	register_on_joinplayer = function() end,
	get_node_or_nil = function(p)
		local node = nodes[key(p)]
		return node and {name = node.name, param2 = node.param2} or {name = "air", param2 = 0}
	end,
	get_node = function(p) return core.get_node_or_nil(p) end,
	set_node = function(p, node) nodes[key(p)] = {name = node.name, param2 = node.param2 or 0} end,
	swap_node = function(p, node) nodes[key(p)] = {name = node.name, param2 = node.param2 or 0} end,
	is_protected = function() return false end,
	chat_send_player = function() end,
	pos_to_string = function(p) return key(p) end,
	-- builtin/common/item_s.lua core.dir_to_fourdir
	dir_to_fourdir = function(d)
		if math.abs(d.x) > math.abs(d.z) then return d.x < 0 and 3 or 1 end
		return d.z < 0 and 2 or 0
	end,
}
grug_core = {
	map_reset = {clear = function() end, pending = function() return false end},
	severe = {report = function() end},
	placement_refused = function() return false end,
}
grug_housing = {}
dofile(MOD .. "/api.lua")
dofile(MOD .. "/stone.lua")
local H, model = grug_housing, grug_housing.model

-- ---------------------------------------------------------------------------
-- A: the six nodes and the two items
-- ---------------------------------------------------------------------------
local function exists(path)
	local file = io.open(path, "rb")
	if file then file:close() end
	return file ~= nil
end
local function same_boxes(a, b)
	if a.type ~= "fixed" or b.type ~= "fixed" or #a.fixed ~= #b.fixed then return false end
	for i, box in ipairs(a.fixed) do
		for j = 1, 6 do if box[j] ~= b.fixed[i][j] then return false end end
	end
	return true
end
local GROUPS = {
	item = {not_in_creative_inventory = 1, grug_soulbound = 1, grug_claim_stone_node = 1},
	empty = {not_in_creative_inventory = 1, grug_claim_stone = 1, grug_claim_stone_node = 1},
	draft = {not_in_creative_inventory = 1, grug_claim_stone_node = 1},
}
-- Ruling 20 (fix round 1): only the fuelled stone gives light, level 8.
local LIGHT = {item = 8, empty = nil, draft = nil}
local CALLBACKS = {"on_place", "on_drop", "on_rightclick", "can_dig", "after_dig_node", "on_blast"}
for kind, names in pairs(H.STONE_KINDS) do
	for variant, name in pairs(names) do
		local def = core.registered_nodes[name]
		local label = name .. " "
		check(def ~= nil, label .. "registered")
		check(def.drawtype == "nodebox" and def.node_box.type == "fixed" and
			#def.node_box.fixed > 0, label .. "a fixed node box")
		local top = -1
		local around = {1, 1, 1, -1, -1, -1}
		for _, box in ipairs(def.node_box.fixed) do
			for axis = 1, 3 do
				check(box[axis] >= -0.5 and box[axis + 3] <= 0.5 and box[axis] < box[axis + 3],
					label .. "every box inside the node")
				around[axis] = math.min(around[axis], box[axis])
				around[axis + 3] = math.max(around[axis + 3], box[axis + 3])
			end
			top = math.max(top, box[5])
		end
		check(top <= 0.5, label .. "nothing reaches into the arrival cube")
		check(same_boxes(def.collision_box, def.node_box), label .. "stood on as drawn")
		local pointed = def.selection_box.fixed
		local same = def.selection_box.type == "fixed"
		for i = 1, 6 do same = same and pointed[i] == around[i] end
		check(same, label .. "pointed at: the one box around the house")
		check(def.walkable == nil, label .. "walkable (the default)")
		check(#def.tiles == 6, label .. "six tiles")
		for _, tile in ipairs(def.tiles) do
			check(exists(MOD .. "/textures/" .. tile:match("^[^%^]+")), label .. "tile file " .. tile)
		end
		check(def.paramtype == "light" and def.paramtype2 == "4dir", label .. "light, 4dir")
		check(def.light_source == LIGHT[variant], label .. "light " .. tostring(LIGHT[variant]))
		if variant == "draft" then
			check(def.use_texture_alpha == "blend" and def.sunlight_propagates == true, label ..
				"half-transparent, sunlight through")
			for _, tile in ipairs(def.tiles) do
				check(tile:find("^[opacity:", 1, true) ~= nil, label .. "tile opacity")
			end
		else
			check(def.use_texture_alpha == "opaque" and not def.sunlight_propagates, label .. "opaque")
			for _, tile in ipairs(def.tiles) do check(not tile:find("^", 1, true), label .. "plain tile") end
		end
		if variant == "item" then
			check(def.inventory_image == def.wield_image and def.inventory_image ==
				"grug_housing_stone_" .. (kind == "" and "personal" or kind) .. "_item.png" and
				exists(MOD .. "/textures/" .. def.inventory_image), label .. "flat picture in hand and inventory")
			check(def.stack_max == 1, label .. "stack 1")
		else
			check(def.inventory_image == nil and def.wield_image == nil, label .. "no item picture")
		end
		local groups = 0
		for group, value in pairs(def.groups) do
			groups = groups + 1
			check(GROUPS[variant][group] == value, label .. "group " .. group)
		end
		local wanted = 0
		for _ in pairs(GROUPS[variant]) do wanted = wanted + 1 end
		check(groups == wanted, label .. "the groups of 0.85.0")
		check(def.drop == "" and def.node_placement_prediction == "", label .. "no drop, no prediction")
		local personal = core.registered_nodes[H.STONE_KINDS[""][variant]]
		for _, field in ipairs(CALLBACKS) do
			check(def[field] == personal[field], label .. field .. " shared")
		end
		check(def.can_dig ~= nil and def.on_rightclick ~= nil, label .. "callbacks present")
	end
end
check(core.registered_nodes[H.EMPTY_STONE].after_dig_node ~= nil, "only the empty stone is dug")
check(H.STONE_TEXTURE == core.registered_nodes[H.STONE_ITEM].tiles[6] and
	H.STONE_TEXTURE == "grug_housing_stone_personal_active_front.png", "STONE_TEXTURE: the fuelled front")
check(H.ACCOUNT_STONE_TEXTURE == core.registered_nodes[H.ACCOUNT_ITEM].tiles[6],
	"ACCOUNT_STONE_TEXTURE: the account's fuelled front")
check(core.registered_nodes[H.STONE_ITEM].tiles[1] ~=
	core.registered_nodes[H.ACCOUNT_ITEM].tiles[1], "the two kinds look different (ruling 10)")

-- ---------------------------------------------------------------------------
-- B: facing
-- ---------------------------------------------------------------------------
H.validate_placement = function() return true end
local function placer(name, at)
	return {is_player = function() return true end, get_player_name = function() return name end,
		get_pos = function() return at end,
		get_player_control = function() return {sneak = false} end}
end
-- The placer stands on one side of the target, the door turns toward it.
local SIDES = {{dx = 0, dz = -3, param2 = 0}, {dx = -3, dz = 0, param2 = 1},
	{dx = 0, dz = 3, param2 = 2}, {dx = 3, dz = 0, param2 = 3}}
local placed = {}
for index, side in ipairs(SIDES) do
	local pos = {x = index * 200, y = 10, z = 0}
	nodes[key({x = pos.x, y = 9, z = pos.z})] = {name = "default:dirt", param2 = 0}
	local stack = ItemStack(H.STONE_ITEM)
	core.registered_nodes[H.STONE_ITEM].on_place(stack, placer("p" .. index,
		{x = pos.x + side.dx + 0.3, y = 10.5, z = pos.z + side.dz - 0.2}),
		{type = "node", under = {x = pos.x, y = 9, z = pos.z}, above = pos})
	local node = nodes[key(pos)]
	check(node and node.name == H.DRAFT_STONE and node.param2 == side.param2,
		"B placed from side " .. index .. ": door toward the placer (" .. tostring(node and node.param2) .. ")")
	check(stack:is_empty(), "B the stone left the hand")
	placed[index] = model.claim_at(pos)
	check(placed[index] ~= nil, "B the claim stands")
end
-- The swaps keep the facing.
local is_draft, is_active = model.is_draft, model.is_active
local claim = placed[2]
model.is_draft, model.is_active = function() return false end, function() return true end
H.sync_stone_node(claim)
check(nodes[key(claim.center)].name == H.STONE_ITEM and nodes[key(claim.center)].param2 == 1,
	"B activation keeps the facing")
model.is_active = function() return false end
H.sync_stone_node(claim)
check(nodes[key(claim.center)].name == H.EMPTY_STONE and nodes[key(claim.center)].param2 == 1,
	"B running empty keeps the facing")
-- A 0.85.0 stone: param2 0.
nodes[key(claim.center)] = {name = H.EMPTY_STONE, param2 = 0}
model.is_active = function() return true end
H.sync_stone_node(claim)
check(nodes[key(claim.center)].name == H.STONE_ITEM and nodes[key(claim.center)].param2 == 0,
	"B a 0.85.0 stone keeps param2 0 (door toward -Z)")
model.is_draft, model.is_active = is_draft, is_active

print("R86 ART PORTABLE PASS checks=" .. checks)
