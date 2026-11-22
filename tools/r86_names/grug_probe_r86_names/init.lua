-- Disposable engine probe (Round 86 lane NAMES): home names with the house
-- icon, for screenshots. Never shipped: tools/r86_names/capture.sh stages it
-- through tools/luanti_headless.sh and connects a real client twice (two
-- HUD and GUI scales). The driver (character creation, SHOT / ack
-- handshake, drafts after emerge) is tools/r502_home's probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe finds an
-- eligible column near the start, places the player's own claim there and
-- a neighbour's 110 nodes south, and activates both. Each round of shots
-- (one per client connection) shows: the entry banner and the line under
-- the minimap with the default name and with the longest name (24 W), the
-- protection hint in the neighbour's claim with both names, the Map tab,
-- the stone form's rename row, and the row after a refused name. Every shot
-- logs "SHOT <name>" and a CHECK line (location text, home flag, banner,
-- flash, the window's scales). After the first round the player is kicked;
-- the script connects the second client; after the second the server
-- shuts down.
local P = "[r86names] "
local NAME, OTHER = "grugcap", "neighbor"
local SETTLE = tonumber(core.settings:get("r86names_settle") or "") or 5
local BANNER = 1.6
local ROUNDS = 2
local FACTION = "accord"
local LONG = ("W"):rep(24)
-- "names" (the lane's pictures) or "account" (fix round 1: an account
-- claim seen by a visitor and by a member, and the personal claim's form).
local SCENE = core.settings:get("r86names_scene") or "names"
local ACCOUNT, MEMBER = "acc_demo", "Brenna"
if SCENE == "account" then
	-- Level 25, so the character may choose the account (grug_xp read
	-- through a wrapper), as tools/r86_stone's probe does.
	local get_level = grug_xp.get_level
	function grug_xp.get_level(player)
		if player and player.get_player_name and player:get_player_name() == NAME then return 25 end
		return get_level(player)
	end
end
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0, round = 0, claims = {}}

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r86names_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local world = grug_housing.placement_world
local function allowed(x, z)
	local zone = world.zone_at(x, z)
	return not grug_housing.column_problem(FACTION, world.water_class_at(x, z), zone,
		zone and world.territory_at(x, z) or nil)
end
local function clear(x, z)
	return allowed(x, z) and not world.feature_in(x - 50, z - 50, x + 50, z + 50, 16)
end

local function find_spot(from)
	local rows = {}
	for z = -3100, 3100, 32 do
		for x = -3500, 3500, 32 do
			local dx, dz = x - from.x, z - from.z
			rows[#rows + 1] = {x = x, z = z, d = dx * dx + dz * dz}
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	for _, row in ipairs(rows) do
		if clear(row.x, row.z) and clear(row.x, row.z - 110) then
			return {x = row.x, z = row.z}
		end
	end
	return {x = from.x, z = from.z}
end

local function ground(x, z)
	return math.max(grug_zones.terrain_height_at(x, z), 1)
end

local function draft(owner, x, z, kind)
	local pos = {x = x, y = ground(x, z) + 1, z = z}
	state.pending = (state.pending or 0) + 1
	local function emerged(_, _, remaining)
		if remaining > 0 then return end
		if core.get_node(pos).name == "ignore" then
			core.emerge_area(vector.subtract(pos, 16), vector.add(pos, 16), emerged)
			return
		end
		core.set_node(pos, {name = grug_housing.stone_nodes(kind or "").draft})
		local claim = grug_housing.model.create(owner, pos, kind)
		grug_housing.model.activate(claim, 5)
		grug_housing.sync_stone_node(claim)
		state.claims[owner] = claim
		log(("claim %d of %s at %s, named %q"):format(claim.id, owner,
			core.pos_to_string(pos), grug_housing.home_name(claim)))
		state.pending = state.pending - 1
	end
	core.emerge_area(vector.subtract(pos, 16), vector.add(pos, 16), emerged)
end

-- The middle of a claim's chunk, and a column 12 nodes west of it.
local function middle(owner)
	local min_x, min_z, max_x, max_z = grug_housing.claim_bounds(state.claims[owner])
	return {math.floor((min_x + max_x) / 2), math.floor((min_z + max_z) / 2)}
end
local function west_of(owner)
	local min_x, min_z, _, max_z = grug_housing.claim_bounds(state.claims[owner])
	return {min_x - 12, math.floor((min_z + max_z) / 2)}
end

local function place(player, at)
	player:set_pos({x = at[1] + 0.5, y = ground(at[1], at[2]) + 2, z = at[2] + 0.5})
end

local function own() return state.claims[NAME] end
local function other() return state.claims[OTHER] end
local function reset(claim) grug_housing.reset_name(claim) end

local SHOTS = {
	{name = "N1_banner_default", setup = function() reset(own()) end,
		pre = function() return west_of(NAME) end, pos = function() return middle(NAME) end},
	{name = "N2_banner_long", setup = function() grug_housing.rename(own(), NAME, LONG) end,
		pre = function() return west_of(NAME) end, pos = function() return middle(NAME) end},
	{name = "N3_hint_default", setup = function() reset(other()) end, hint = true,
		pos = function() return middle(OTHER) end},
	{name = "N4_hint_long", setup = function() grug_housing.model.set_name(other(), LONG) end,
		hint = true, pos = function() return middle(OTHER) end},
	{name = "N5_map_tab", setup = function() grug_housing.rename(own(), NAME, LONG) end,
		map = true, pos = function() return middle(NAME) end},
	{name = "N6_stone_form", setup = function() reset(own()) end, form = true,
		pos = function() local c = own().center return {c.x + 2, c.z + 2} end},
	{name = "N7_stone_refused", form = true, refuse = true,
		pos = function() local c = own().center return {c.x + 2, c.z + 2} end},
}

-- The account scene: the account "acc_demo" (the real grug_accounts list)
-- with its claim placed and activated by the offline member Brenna (named
-- "Brenna's Home" at placement), 110 nodes south of the character's own
-- personal claim. Each round starts with the character a visitor holding
-- its personal claim; after the personal form it picks that up, joins the
-- account (grug_housing.choose_account) and sees the claim as a member.
local function link(player)
	grug_accounts.apply_list({version = 7 + state.round, accounts = {{id = ACCOUNT,
		name = "Demo", rewards = {}}},
		characters = {{name = NAME, character_id = grug_accounts.character_id(player),
			account_id = ACCOUNT}}})
end
local function round_start(player)
	local model = grug_housing.model
	model.end_membership(NAME)
	if not state.claims[NAME] or not model.claim_by_id(state.claims[NAME].id) then
		local c = state.personal_center
		core.set_node(c, {name = grug_housing.DRAFT_STONE})
		local claim = model.create(NAME, c)
		model.activate(claim, 5)
		grug_housing.sync_stone_node(claim)
		state.claims[NAME] = claim
	end
	grug_housing.reset_name(state.claims[OTHER])
	link(player)
end
local function join(player)
	local own_claim = state.claims[NAME]
	grug_housing.remove_stone_node(own_claim)
	grug_housing.model.remove(own_claim, "picked_up")
	local inv = player:get_inventory()
	for _, list in ipairs({"main"}) do
		for i = 1, inv:get_size(list) do
			if grug_housing.is_stone_item(inv:get_stack(list, i):get_name()) then
				inv:set_stack(list, i, ItemStack(""))
			end
		end
	end
	local ok, message = grug_housing.choose_account(player)
	log(("joined: %s %s, member of %s"):format(tostring(ok), tostring(message),
		tostring(grug_housing.account_owner_of(NAME))))
end
local ACCOUNT_SHOTS = {
	{name = "A1_banner_visitor", pre = function() return west_of(OTHER) end,
		pos = function() return middle(OTHER) end},
	{name = "A2_hint_visitor", hint = true, pos = function() return middle(OTHER) end},
	{name = "A3_personal_form", form = true, form_claim = function() return own() end,
		pos = function() local c = own().center return {c.x + 2, c.z + 2} end},
	{name = "A4_banner_member", setup = function(player) join(player) end,
		pre = function() return west_of(OTHER) end, pos = function() return middle(OTHER) end},
	{name = "A5_stone_form_member", form = true, form_claim = function() return other() end,
		pos = function() local c = other().center return {c.x + 2, c.z + 2} end},
	{name = "A6_renamed_by_member", form = true, form_claim = function() return other() end,
		rename = "The Long Hearth",
		pos = function() local c = other().center return {c.x + 2, c.z + 2} end},
}
if SCENE == "account" then SHOTS = ACCOUNT_SHOTS end

local function hud_text(player, pred)
	for _, def in pairs(player:hud_get_all()) do
		if def.type == "text" and pred(def) then return def.text end
	end
	return "?"
end

local function icons(player)
	local n = 0
	for _, def in pairs(player:hud_get_all()) do
		if def.type == "image" and def.text == grug_housing.HOME_ICON then n = n + 1 end
	end
	return n
end

local hint = {}
local function show_hint(player)
	local c = middle(OTHER)
	local pos = {x = c[1], y = ground(c[1], c[2]), z = c[2]}
	local message, icon = grug_materials.protection_hint(pos, NAME)
	hint.message, hint.icon = message, icon
	if message then
		grug_core.flash(player, message, grug_core.FLASH_COLOR.notice, icon)
	end
end

core.register_on_joinplayer(function(player)
	if player:get_player_name() == NAME and state.phase == "kicked" then state.phase = "wait" end
end)

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.2 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		state.round = state.round + 1
		if state.spot then
			state.phase = "ready"
			return
		end
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		state.spot = find_spot(at)
		log(("spots: home %d,%d"):format(state.spot.x, state.spot.z))
		draft(NAME, state.spot.x, state.spot.z)
		if SCENE == "account" then
			-- the account's claim, placed by the offline member Brenna
			grug_housing.model.join(MEMBER, grug_housing.model.owner_text(ACCOUNT, FACTION))
			OTHER = MEMBER
			draft(OTHER, state.spot.x, state.spot.z - 110, "account")
		else
			draft(OTHER, state.spot.x, state.spot.z - 110)
		end
		log(("minimap available: %s"):format(tostring(grug_map.minimap.available())))
		state.phase = "emerge"
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		state.phase = "ready"
	elseif state.phase == "ready" then
		if SCENE == "account" then
			state.personal_center = state.personal_center or vector.new(own().center)
			round_start(player)
		end
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.entered = 1, 0, false, false
		local info = core.get_player_window_information(NAME) or {}
		log(("READY round %d: gui %s, hud %s"):format(state.round,
			tostring(info.real_gui_scaling), tostring(info.real_hud_scaling)))
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			log(("ROUND %d done"):format(state.round))
			if state.round >= ROUNDS then
				state.phase = "done"
				log("shutdown")
				core.request_shutdown("probe done", false, 0)
			else
				state.phase = "kicked"
				core.kick_player(NAME, "next round")
			end
			return
		end
		local label = ("%s_s%d"):format(shot.name, state.round)
		if state.waited == 0 then
			if shot.setup then shot.setup(player) end
			core.close_formspec(NAME, "")
			place(player, (shot.pre or shot.pos)())
		end
		state.waited = state.waited + step
		local due = SETTLE
		if shot.pre then
			if not state.entered and state.waited >= SETTLE then
				state.entered = true
				place(player, shot.pos())
			end
			due = SETTLE + BANNER
		end
		-- The hint is shown again every step until the shot is taken (one
		-- flash lasts 1.5 s).
		if shot.hint and state.waited >= SETTLE - 1 then show_hint(player) end
		if shot.map and not state.opened and state.waited >= SETTLE - 2 then
			state.opened = true
			grug_map.window.open(player)
		end
		if shot.form and not state.opened and state.waited >= SETTLE - 2 then
			state.opened = true
			grug_housing.open_stone_interface(player, shot.form_claim and shot.form_claim() or own())
			if shot.refuse then
				submit(player, "grug_housing:stone", {home_name = "Bad|Name", home_rename = ""})
			end
			if shot.rename then
				submit(player, "grug_housing:stone", {home_name = shot.rename, home_rename = ""})
			end
		end
		if not state.logged and state.waited >= due then
			state.logged = true
			local text, _, home = grug_map.location.text_of(player)
			log(("SHOT %s"):format(label))
			log(("CHECK %s: location %q, home %s, banner %q, flash %q, hint %q icon %s, " ..
				"%d house icon element(s) showing, own claim %q, other claim %q, member of %s"):format(label, text,
				tostring(home), hud_text(player, function(d) return d.size and d.size.x == 2.5 end),
				hud_text(player, function(d) return d.position and d.position.y == 0.35 end),
				tostring(hint.message), tostring(hint.icon), icons(player),
				own() and grug_housing.home_name(own()) or "-",
				grug_housing.home_name(other()), tostring(grug_housing.account_owner_of(NAME))))
		elseif state.logged and read_ack() == label then
			state.shot = state.shot + 1
			state.waited, state.logged, state.entered, state.opened = 0, false, false, false
			hint = {}
		end
	end
end)
