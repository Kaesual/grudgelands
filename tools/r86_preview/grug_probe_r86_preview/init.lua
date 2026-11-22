-- Disposable engine probe (Round 86 lane PREVIEW): the Claim Stone preview
-- per map chunk, for screenshots. Never shipped: tools/r86_preview/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) is the r502_cmap
-- probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe picks, from
-- the world's claim mask and grug_housing.chunk_refusal, the chunks nearest
-- the start: ZONE a free chunk with a road and a camp within two chunks
-- (ROAD and CAMP those refused chunks), RING a capital-ring chunk next to a
-- free one, CLAIMED a free chunk near ZONE where it places another player's
-- claim, and QUOTA a free chunk of a quest kind whose ground the claims it
-- places (on the kind's other chunks, the largest shares first) fill until
-- the quota refuses QUOTA. Every placed claim gets its stone node (its block
-- emerged first) and is activated, so no check removes it. For each shot it
-- moves the player into the chunk's middle, puts the Claim Stone into the
-- wielded slot or empties it, waits SETTLE seconds and logs "SHOT <name>"
-- and a CHECK line (claim mode, the line beside the bezel, the red fills).
-- The last shots open the player's own draft form and Help's Basics page.
local P = "[r86preview] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r86preview_settle") or "") or 6
local FACTION = "accord"
local H = grug_housing
local CM = H.claim_mask
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r86preview_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function middle(c)
	local x0, z0 = CM.chunk_bounds(c.cx, c.cz)
	return {x = x0 + 40, z = z0 + 40}
end

-- Every chunk within `r` chunks of c, with its refusal.
local function around(c, r)
	local list = {}
	for dz = -r, r do
		for dx = -r, r do
			local cx, cz = c.cx + dx, c.cz + dz
			list[#list + 1] = {cx = cx, cz = cz, code = H.chunk_refusal(FACTION, cx, cz)}
		end
	end
	return list
end

local function find_spots(from)
	local fcx, fcz = CM.chunk_of(from.x), CM.chunk_of(from.z)
	local free = {}
	for _, c in ipairs(H.mask.list(FACTION)) do
		if not H.chunk_refusal(FACTION, c[1], c[2]) then
			local dx, dz = c[1] - fcx, c[2] - fcz
			free[#free + 1] = {cx = c[1], cz = c[2], d = dx * dx + dz * dz}
		end
	end
	table.sort(free, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		if a.cz ~= b.cz then return a.cz < b.cz end
		return a.cx < b.cx
	end)
	local spots = {}
	for _, c in ipairs(free) do
		local road, camp, ring
		for _, n in ipairs(around(c, 2)) do
			if n.code == "road" and not road then road = n end
			if n.code == "camp" and not camp then camp = n end
			if n.code == "capital_ring" and not ring then ring = n end
		end
		if not spots.zone and road and camp then
			spots.zone, spots.road, spots.camp = c, road, camp
		end
		if not spots.ring and ring then spots.ring = ring end
		if spots.zone and spots.ring then break end
	end
	spots.zone = spots.zone or free[1]
	-- a free neighbour of ZONE for another player's claim
	for _, n in ipairs(around(spots.zone, 2)) do
		if not n.code and (n.cx ~= spots.zone.cx or n.cz ~= spots.zone.cz) then
			spots.claimed = n
			break
		end
	end
	-- the quota: the kind that needs the fewest claims to refuse one of its
	-- free chunks
	local best
	local holders_of = {}
	for _, c in ipairs(free) do
		for _, row in ipairs(H.mask.kind_columns(c.cx, c.cz)) do
			local list = holders_of[row[1]]
			if not list then list = {}; holders_of[row[1]] = list end
			list[#list + 1] = {cx = c.cx, cz = c.cz, s = row[2], d = c.d}
		end
	end
	local taken = H.quota_taken() or {}
	for kind, list in pairs(holders_of) do
		table.sort(list, function(a, b)
			if a.s ~= b.s then return a.s > b.s end
			return a.d < b.d
		end)
		local limit = H.mask.kind_by_id[kind].limit
		local target = list[1]
		local need, sum, claims = limit - (taken[kind] or 0) - target.s, 0, {}
		for index = 2, #list do
			if sum > need then break end
			sum = sum + list[index].s
			claims[#claims + 1] = list[index]
		end
		if sum > need and #claims > 0 and (not best or #claims < #best.claims or
				(#claims == #best.claims and target.d < best.target.d)) then
			best = {kind = kind, target = target, claims = claims}
		end
	end
	spots.quota = best
	return spots
end

-- Places an activated claim of `owner` in chunk c with its stone node, its
-- block emerged first; calls done(claim) when placed.
local function place_claim(owner, c, done)
	local at = middle(c)
	local y = math.max(grug_zones.terrain_height_at(at.x, at.z), 1) + 1
	local pos = {x = at.x, y = y, z = at.z}
	core.emerge_area(pos, pos, function(_, _, remaining)
		if remaining ~= 0 then return end
		core.set_node(pos, {name = H.STONE_ITEM})
		local claim = H.model.create(owner, pos)
		H.model.activate(claim, 5)
		log(("claim %d of %s at %s"):format(claim.id, owner, core.pos_to_string(pos)))
		done(claim)
	end)
end

local function place_player(player, c)
	local at = middle(c)
	local y = grug_zones.terrain_height_at(at.x, at.z)
	player:set_pos({x = at.x + 0.5, y = math.max(y, 1) + 2, z = at.z + 0.5})
end

local function hold(player, stone)
	player:get_inventory():set_stack("main", player:get_wield_index(),
		ItemStack(stone and H.STONE_ITEM or ""))
end

-- Fix round 2: the Steward's choice for a character with an account and no
-- claim (level 25 through a wrapper, the window permitted anywhere, the
-- link through the real grug_accounts.apply_list, as tools/r86_stone's
-- probe does) and the Account Claim Stone's tooltip (the client's pointer
-- is moved onto the slot: HOVER, as r86_stone's capture.sh).
local get_level = grug_xp.get_level
function grug_xp.get_level(player)
	if player and player.get_player_name and player:get_player_name() == NAME then return 25 end
	return get_level(player)
end
grug_core.npc_window_permitted = function() return true end
local function link(player)
	grug_accounts.apply_list({version = 7, accounts = {{id = "acc_demo", name = "Demo",
		rewards = {}}}, characters = {{name = NAME, character_id = grug_accounts.character_id(player),
		account_id = "acc_demo"}}})
end

local SHOTS = {
	{name = "P1_zone_free", spot = "zone", stone = true},
	{name = "P2_zone_road", spot = "road", stone = true},
	{name = "P3_zone_camp", spot = "camp", stone = true},
	{name = "P4_capital_ring", spot = "ring", stone = true},
	{name = "P5_claimed_by_other", spot = "claimed", stone = true, claim = true},
	{name = "P6_quota", spot = "quota", stone = true, quota = true},
	{name = "P7_zone_no_stone", spot = "zone", stone = false},
	{name = "F1_draft_form", form = "draft"},
	{name = "F2_help_housing", form = "help"},
	{name = "F3_steward_account_no_claim", form = "steward"},
	{name = "F4_account_stone_tooltip", form = "tooltip", hover = {11, 3, 1.0, 1.2}},
}

-- r86preview_shots (capture.sh SHOTS): a comma list of shot names to take,
-- every shot when empty (fix round 1 took P1, P2 and P6).
do
	local wanted = core.settings:get("r86preview_shots") or ""
	if wanted ~= "" then
		local keep = {}
		for _, shot in ipairs(SHOTS) do
			if ("," .. wanted .. ","):find("," .. shot.name .. ",", 1, true) then keep[#keep + 1] = shot end
		end
		SHOTS = keep
	end
end

local function spot_of(name)
	if name == "quota" then return state.spots.quota and state.spots.quota.target end
	return state.spots[name]
end

-- Prepares a shot; calls ready() when the view can settle.
local function show(player, shot, ready)
	if shot.form == "draft" then
		core.close_formspec(NAME, "")
		hold(player, false)
		local c = state.spots.zone
		local at = middle(c)
		local pos = {x = at.x + 3, y = math.max(grug_zones.terrain_height_at(at.x + 3, at.z), 1) + 1,
			z = at.z}
		core.set_node(pos, {name = H.DRAFT_STONE})
		local claim = H.model.create(NAME, pos)
		H.open_stone_interface(player, claim)
		return ready()
	elseif shot.form == "steward" then
		core.close_formspec(NAME, "")
		hold(player, false)
		link(player)
		grug_housing.open_manager(player, {})
		return ready()
	elseif shot.form == "tooltip" then
		core.close_formspec(NAME, "")
		local inv = player:get_inventory()
		inv:set_stack("main", 1, ItemStack("grug_housing:account_stone"))
		inv:set_stack("main", 2, ItemStack(H.STONE_ITEM))
		core.show_formspec(NAME, "grug_probe_r86_preview:inv", "formspec_version[6]size[11,3]" ..
			"label[0.5,0.3;Account and personal Claim Stone]" ..
			"list[current_player;main;0.5,0.7;8,1;]")
		return ready()
	elseif shot.form == "help" then
		core.close_formspec(NAME, "")
		local context = sfinv.get_or_create_context(player)
		context.grug_help_section = "basics"
		sfinv.set_page(player, "grug_inventory:help")
		-- The page opens at its top and a formspec cannot scroll a
		-- hypertext, so the text above the Housing heading is cut, as the
		-- player sees it after scrolling there.
		local fs = sfinv.get_formspec(player, sfinv.get_or_create_context(player))
		local _, text_at = fs:find("hypertext%[[^;]*;[^;]*;[^;]*;")
		local housing = fs:find("<b>Housing</b>", 1, true)
		local style = housing and fs:sub(1, housing):match(".*()<style")
		if text_at and style and style > text_at then
			fs = fs:sub(1, text_at) .. fs:sub(style)
		else
			log("help: the Housing heading was not found")
		end
		core.show_formspec(NAME, "grug_probe_r86_preview:help", fs)
		return ready()
	end
	local spot = spot_of(shot.spot)
	if not spot then
		log("no spot for " .. shot.name)
		return ready(true)
	end
	place_player(player, spot)
	hold(player, shot.stone)
	if shot.claim and not state.claimed then
		state.claimed = true
		return place_claim("neighbor", spot, function() ready() end)
	end
	if shot.quota and not state.quota_placed then
		state.quota_placed = true
		local q = state.spots.quota
		local left = #q.claims
		for index, c in ipairs(q.claims) do
			place_claim("settler" .. index, c, function()
				left = left - 1
				if left == 0 then
					log(("quota: %s, %d claims; the target %d,%d answers %s"):format(q.kind,
						#q.claims, q.target.cx, q.target.cz,
						tostring(H.chunk_refusal(FACTION, q.target.cx, q.target.cz))))
					ready()
				end
			end)
		end
		return
	end
	ready()
end

local function check_line(player, shot)
	local texture = grug_map.minimap.texture_of(player) or ""
	local reds = 0
	for _ in texture:gmatch("%^%[fill:%d+x%d+:%d+,%d+:#dc282873") do reds = reds + 1 end
	-- the line by its right alignment (the quest box's texts are left- or
	-- centre-aligned) and its box by its z-index under the bezel
	local hint, box = "", ""
	for _, def in pairs(player:hud_get_all()) do
		if def.type == "text" and def.alignment and def.alignment.x == -1 and
				def.z_index == 45 then
			hint = def.text
		end
		if def.type == "image" and def.z_index == 44 then box = def.text end
	end
	local at = vector.round(player:get_pos())
	log(("CHECK %s: at %s chunk %d,%d, claim mode %s, %d red fills, texture %d chars, " ..
		"line %q, box %q"):format(shot.name, core.pos_to_string(at), CM.chunk_of(at.x),
		CM.chunk_of(at.z), tostring(grug_map.minimap.claim_of(player)), reds, #texture, hint, box))
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		if not H.mask then
			log("no claim mask")
			state.phase = "done"
			core.request_shutdown("probe done", false, 0)
			return
		end
		state.spots = find_spots(at)
		for _, key in ipairs({"zone", "road", "camp", "ring", "claimed"}) do
			local c = state.spots[key]
			log(("spot %s: %s"):format(key, c and (c.cx .. "," .. c.cz .. " " ..
				tostring(H.chunk_refusal(FACTION, c.cx, c.cz))) or "none"))
		end
		local q = state.spots.quota
		log(("spot quota: %s"):format(q and (q.kind .. " target " .. q.target.cx .. "," ..
			q.target.cz .. " share " .. q.target.s .. ", " .. #q.claims .. " claims") or "none"))
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.ready = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.started then
			state.started = true
			show(player, shot, function(skip)
				state.ready = true
				state.skip = skip
			end)
			return
		end
		if not state.ready then return end
		if state.skip then
			state.shot, state.started, state.ready, state.skip = state.shot + 1, false, false, false
			return
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			check_line(player, shot)
			if shot.hover then log(("HOVER %s %s %s %s %s"):format(shot.name, unpack(shot.hover))) end
			log(("SHOT %s"):format(shot.name))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.started, state.ready = 0, false, false, false
		end
	end
end)
