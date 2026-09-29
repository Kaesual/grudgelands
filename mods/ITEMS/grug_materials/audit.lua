-- Startup contract audit. Structural checks run in registry.lua; this pass
-- verifies the fully loaded engine registry and fails before a world starts.
--
-- Round 24 mining contract (items_crafting.md §3.0.4): tier-N rock and
-- tier-N resources carry `level = N - 1` and nothing else does; a tier-t pick
-- digs exactly the rock and resources of tier <= t, faster the higher it is;
-- loose ground has no level and the hand digs it; a shovel beats the pick of
-- its tier on loose ground. The matrix below asks the engine itself
-- (`core.get_dig_params`, the same getDigParams the client predicts with).

local function fail(message)
	error("grug_materials startup audit: " .. message)
end

local function raw_item(name)
	return rawget(core.registered_items, name)
end

local function level_of(groups)
	return tonumber((groups or {}).level) or 0
end

local function first_line(text)
	return (tostring(text or ""):match("^[^\n]*"))
end

-- The canonical tool of a family at a tier: default owns Bronze (T1) and
-- Steel (T3), grug_materials the other four (tools.lua).
local function ladder_tool(family, tier)
	local key = grug_materials.TIERS[tier].key
	local prefix = (tier == 1 or tier == 3) and "default:" or "grug_materials:"
	return prefix .. family .. "_" .. key
end

local function caps_of(item_name)
	local def = raw_item(item_name)
	return def and def.tool_capabilities
end

local function dig(node_name, caps)
	local def = core.registered_nodes[node_name]
	return core.get_dig_params(def and def.groups or {}, caps)
end

local function check_registry()
	for _, tier in ipairs(grug_materials.TIERS) do
		local def = core.registered_nodes[tier.node]
		local groups = def and def.groups or {}
		if not def or groups.grug_stratum ~= tier.id or groups.grug_natural ~= 1 or
				groups.cracky ~= 3 or level_of(groups) ~= tier.id - 1 or
				def.drop ~= "default:cobble" or first_line(def.description) ~= "Stone" or
				not tostring(def.description):find("Requires a T" .. tier.id ..
					" pick", 1, true) then
			fail("missing or misclassified tier rock " .. tier.node)
		end
	end

	for _, rock in ipairs(grug_materials.DECORATIVE_ROCKS) do
		local def = core.registered_nodes[rock.node]
		local groups = def and def.groups or {}
		if not def or groups.cracky ~= 3 or level_of(groups) ~= 0 or
				groups.grug_stratum or groups.grug_resource or
				def.drop ~= rock.node then
			fail("missing or misclassified decorative rock " .. rock.node)
		end
	end

	for _, resource in ipairs(grug_materials.RESOURCES) do
		local node = core.registered_nodes[resource.natural_node]
		local groups = node and node.groups or {}
		if not node or groups.grug_natural ~= 1 or
				groups.grug_resource ~= resource.harvest_tier or
				level_of(groups) ~= resource.harvest_tier - 1 then
			fail("missing or misclassified resource node " .. resource.natural_node)
		end
		if groups.cracky then
			fail("resource node retains competing cracky group: " ..
				resource.natural_node)
		end
		if not core.registered_items[resource.raw_item] then
			fail("missing raw resource item " .. resource.raw_item)
		end
		if resource.cut_item and not core.registered_items[resource.cut_item] then
			fail("missing cut resource item " .. resource.cut_item)
		end
		if resource.block_node and not core.registered_nodes[resource.block_node] then
			fail("missing storage node " .. resource.block_node)
		end
	end

	for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
		local def = core.registered_nodes[node_name]
		local groups = def and def.groups or {}
		if not def or groups.grug_natural ~= 1 then
			fail("generated ground lacks natural marker: " .. node_name)
		end
		if node_name ~= "default:stone" and (level_of(groups) ~= 0 or
				(tonumber(groups.grug_loose) or 0) <= 0 or
				groups.grug_loose ~= groups.crumbly) then
			fail("loose ground is gated or lacks its loose rating: " .. node_name)
		end
	end

	for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
		if not raw_item(material.item) then
			fail("missing concrete processed item " .. material.item)
		end
		local block = rawget(core.registered_nodes, material.block_node)
		local groups = block and block.groups or {}
		if not block or groups.grug_natural or groups.grug_resource or
				groups.grug_stratum or level_of(groups) > 0 then
			fail("missing or misclassified storage node " .. material.block_node)
		end
		if block.drop ~= material.block_node then
			fail("storage node must drop itself: " .. material.block_node)
		end
	end
	for _, tier in ipairs(grug_materials.TIERS) do
		if not raw_item(tier.bar_item) or
				not rawget(core.registered_nodes, tier.block_node) then
			fail("missing processed tier forms for " .. tier.key)
		end
	end

	for _, material in pairs(grug_materials.CULTURAL_MATERIALS) do
		if not core.registered_items[material.item] then
			fail("missing cultural material for " .. material.race)
		end
		local row = grug_materials.RACE_REGIONS[material.race]
		local wood = row and grug_materials.SIGNATURE_WOODS[row.signature_wood]
		if not wood or not core.registered_nodes[wood.tree] or
				not core.registered_nodes[wood.wood] then
			fail("missing signature wood registration for " .. material.race)
		end
	end

	for _, item_name in ipairs(grug_materials.CURATED_VENDOR_REMOVALS) do
		if raw_item(item_name) then
			fail("removed vendor item remains registered: " .. item_name)
		end
	end
	for _, derivative in ipairs(grug_materials.STORAGE_DERIVATIVES) do
		local target = raw_item(derivative.target)
		if not target or target.description ~= derivative.description or
			(target.groups or {}).grug_natural then
			fail("invalid canonical storage derivative: " .. derivative.target)
		end
	end
	for name in pairs(core.registered_items) do
		for _, stem in ipairs(grug_materials.FORBIDDEN_RUNTIME_STEMS) do
			if name:find(stem, 1, true) then
				fail("forbidden material registration remains: " .. name)
			end
		end
	end
end

-- Only tier rock and resources may carry a level: a stray level on any other
-- node would silently gate it behind a pick tier.
local function check_levels()
	for name, def in pairs(core.registered_nodes) do
		local groups = def.groups or {}
		local level = level_of(groups)
		local required = grug_materials.required_pick_tier(name, def)
		if groups.grug_resource then
			local resource = grug_materials.resource_for_node(name)
			if not resource or groups.grug_resource ~= resource.harvest_tier or
				groups.cracky then
				fail("unregistered or malformed resource group: " .. name)
			end
		end
		if level > 0 and (required == nil or level ~= required - 1) then
			fail("node carries a level outside the tier contract: " .. name)
		end
		if required and level ~= required - 1 then
			fail("tier node lacks its level: " .. name)
		end
	end
end

local function check_tools()
	for name, def in pairs(core.registered_items) do
		local groups = def.groups or {}
		local caps = def.tool_capabilities and def.tool_capabilities.groupcaps or {}
		local pick_tier = groups.grug_pick_tier
		if pick_tier then
			local tier = tonumber(pick_tier)
			if not tier or tier ~= math.floor(tier) or tier < 1 or tier > 6 or
				not caps.cracky or not caps.grug_resource or not caps.grug_loose or
				caps.cracky.maxlevel ~= tier - 1 or
				caps.grug_resource.maxlevel ~= tier - 1 then
				fail("invalid Grudgelands pick contract: " .. name)
			end
			for harvest_tier = 1, 5 do
				if not caps.grug_resource.times[harvest_tier] then
					fail("incomplete resource capability on " .. name)
				end
			end
		elseif caps.cracky or caps.grug_resource then
			-- A foreign rock-digging tool would bypass the tier ladder.
			fail("rock-digging capability outside the pick ladder: " .. name)
		end
		if groups.grug_shovel_tier and (not caps.grug_loose or
				not tonumber(groups.grug_shovel_tier)) then
			fail("invalid Grudgelands shovel contract: " .. name)
		end
		if groups.grug_axe_tier and (not caps.choppy or
				not tonumber(groups.grug_axe_tier)) then
			fail("invalid Grudgelands axe contract: " .. name)
		end
	end
	for tier = 1, 6 do
		for _, family in ipairs({"pick", "axe", "shovel"}) do
			local def = raw_item(ladder_tool(family, tier))
			local group = "grug_" .. family .. "_tier"
			if not def or (def.groups or {})[group] ~= tier then
				fail("ladder tool lacks its tier group: " .. ladder_tool(family, tier))
			end
		end
	end

	local active_max_drop_levels = {
		["default:pick_wood"] = 0,
		["default:pick_stone"] = 0,
		["default:pick_bronze"] = 1,
		["default:pick_steel"] = 1,
	}
	for name, expected in pairs(active_max_drop_levels) do
		local def = core.registered_items[name]
		local actual = def and def.tool_capabilities and
			def.tool_capabilities.max_drop_level
		if actual ~= expected then
			fail("unexpected max_drop_level on " .. name)
		end
		if def.tool_capabilities.punch_attack_uses ~= 0 then
			fail("unexpected punch_attack_uses on " .. name)
		end
	end

	for tier = 1, 6 do
		local profile = grug_materials.PICK_PROFILES[tier]
		local caps = grug_materials.build_pick_capabilities(tier)
		if not profile or profile.tier ~= tier or
			caps.groupcaps.cracky.maxlevel ~= tier - 1 or
			caps.groupcaps.grug_resource.maxlevel ~= tier - 1 or
			profile.key ~= grug_materials.TIERS[tier].key or
			profile.ordinary_time <= 0 or profile.uses <= 0 then
			fail("invalid pure pick profile at tier " .. tier)
		end
		for rating = 1, 3 do
			if not profile.cracky_times[rating] or
				profile.cracky_times[rating] <= 0 then
				fail("incomplete cracky profile at tier " .. tier)
			end
		end
		if tier > 1 then
			local previous = grug_materials.PICK_PROFILES[tier - 1]
			if profile.ordinary_time > previous.ordinary_time then
				fail("ordinary resource time slows at tier " .. tier)
			end
			for rating, seconds in pairs(profile.cracky_times) do
				local previous_seconds = previous.cracky_times[rating]
				if previous_seconds and seconds > previous_seconds then
					fail("pick profile slows at tier " .. tier ..
						", cracky rating " .. rating)
				end
			end
		end
	end
end

-- The engine dig matrix. Returns the number of checked (tool, node) pairs.
local function check_dig_matrix()
	local checked = 0
	local hand = ItemStack(""):get_tool_capabilities()
	local function expect(node_name, caps, diggable, label)
		local params = dig(node_name, caps)
		checked = checked + 1
		if params.diggable ~= diggable then
			fail(label .. (diggable and " cannot dig " or " digs ") .. node_name)
		end
		return params
	end

	-- Every pick in the registry, starters included: tier gate for rock and
	-- resources at any depth, decorative rock always.
	for name, def in pairs(core.registered_items) do
		local tier = tonumber((def.groups or {}).grug_pick_tier)
		if tier then
			local caps = def.tool_capabilities
			for _, row in ipairs(grug_materials.TIERS) do
				expect(row.node, caps, tier >= row.id, name)
			end
			for _, resource in ipairs(grug_materials.RESOURCES) do
				expect(resource.natural_node, caps, tier >= resource.harvest_tier, name)
			end
			for _, rock in ipairs(grug_materials.DECORATIVE_ROCKS) do
				expect(rock.node, caps, true, name)
			end
		end
	end

	-- The hand digs every loose ground node and no rock or resource.
	for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
		expect(node_name, hand, node_name ~= "default:stone", "the hand")
	end
	for _, row in ipairs(grug_materials.TIERS) do
		expect(row.node, hand, false, "the hand")
	end
	for _, resource in ipairs(grug_materials.RESOURCES) do
		expect(resource.natural_node, hand, false, "the hand")
	end
	for _, rock in ipairs(grug_materials.DECORATIVE_ROCKS) do
		expect(rock.node, hand, false, "the hand")
	end

	-- A higher pick digs every rock it reaches strictly faster.
	for _, row in ipairs(grug_materials.TIERS) do
		local previous
		for tier = row.id, 6 do
			local seconds = dig(row.node, caps_of(ladder_tool("pick", tier))).time
			if previous and seconds >= previous then
				fail("T" .. tier .. " pick is not faster than T" .. (tier - 1) ..
					" on " .. row.node)
			end
			previous = seconds
		end
	end

	-- Loose ground: a shovel beats the pick of its tier (per material for the
	-- two starter pairs), and a higher shovel beats a lower one.
	local pairs_by_material = {{"default:shovel_wood", "default:pick_wood"},
		{"default:shovel_stone", "default:pick_stone"}}
	for tier = 1, 6 do
		pairs_by_material[#pairs_by_material + 1] =
			{ladder_tool("shovel", tier), ladder_tool("pick", tier)}
	end
	for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
		if node_name ~= "default:stone" then
			for _, pair in ipairs(pairs_by_material) do
				local shovel = expect(node_name, caps_of(pair[1]), true, pair[1])
				local pick = expect(node_name, caps_of(pair[2]), true, pair[2])
				if shovel.time >= pick.time then
					fail(pair[1] .. " is not faster than " .. pair[2] .. " on " ..
						node_name)
				end
			end
			local previous
			for tier = 1, 6 do
				local seconds = dig(node_name, caps_of(ladder_tool("shovel", tier))).time
				if previous and seconds >= previous then
					fail("T" .. tier .. " shovel is not faster than T" .. (tier - 1) ..
						" on " .. node_name)
				end
				previous = seconds
			end
		end
	end

	-- No pick or shovel digs loose ground more slowly than the bare hand (the
	-- engine uses a tool's own capability whenever it can dig).
	for name, def in pairs(core.registered_items) do
		local groups = def.groups or {}
		if groups.grug_pick_tier or groups.grug_shovel_tier then
			for _, node_name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
				if node_name ~= "default:stone" then
					local tool = expect(node_name, def.tool_capabilities, true, name)
					if tool.time > dig(node_name, hand).time then
						fail(name .. " digs " .. node_name .. " slower than the hand")
					end
				end
			end
		end
	end

	-- Wood is not gated; a better axe chops faster.
	for _, node_name in ipairs({"default:tree", "default:wood"}) do
		local previous
		for tier = 1, 6 do
			local params = expect(node_name, caps_of(ladder_tool("axe", tier)), true,
				ladder_tool("axe", tier))
			if previous and params.time >= previous then
				fail("T" .. tier .. " axe is not faster than T" .. (tier - 1) ..
					" on " .. node_name)
			end
			previous = params.time
		end
	end
	return checked
end

core.register_on_mods_loaded(function()
	check_registry()
	check_levels()
	check_tools()
	local checked = check_dig_matrix()

	if core.node_dig ~= grug_materials.node_dig_wrapper then
		fail("core.node_dig wrapper was replaced after grug_materials loaded")
	end

	core.log("action", "[grug_materials] registry audit passed: 6 tier rocks, " ..
		#grug_materials.DECORATIVE_ROCKS .. " decorative rocks, " ..
		#grug_materials.RESOURCES .. " resources, " ..
		#grug_materials.PROCESSED_MATERIALS ..
		" processed forms, 6 race regions, " .. checked .. " dig-matrix pairs")
end)
