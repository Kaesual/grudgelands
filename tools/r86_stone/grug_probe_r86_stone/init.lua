-- Disposable engine probe (Round 86 lane STONE): the account Claim Stone in
-- the real engine, for tools/r86_stone/capture.sh. Never shipped. The driver
-- (character creation, SHOT / HOVER / ack handshake) follows
-- tools/r50_pgame's probe.
--
-- Once the character stands at the human start, the probe raises its level
-- to 25 (grug_xp read through a wrapper), lets the Steward's window open
-- without the NPC (grug_core.npc_window_permitted) and takes the shots:
-- the Steward without an account; linked to the account "acc_demo" (the
-- real grug_accounts.apply_list) while carrying a personal stone; with the
-- account's claim standing (an offline member "Brenna" placed and activated
-- it); as a member after joining; the stone form of the account claim; the
-- six stone nodes side by side with the account stone in hand; both items
-- in an inventory with the account stone's tooltip. It logs each state's
-- check ("check ... ok").

local P = "[r86stone] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r86stone_settle") or "") or 3
local ACCOUNT = "acc_demo"

local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local get_level = grug_xp.get_level
function grug_xp.get_level(player)
	if player and player.get_player_name and player:get_player_name() == NAME then return 25 end
	return get_level(player)
end
grug_core.npc_window_permitted = function() return true end

local last_form = ""
local show_formspec = core.show_formspec
function core.show_formspec(name, formname, formspec)
	if name == NAME and formspec ~= "" then last_form = formspec end
	return show_formspec(name, formname, formspec)
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r86stone_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function expect(ok, what)
	log(("check %s %s"):format(what, ok and "ok" or "FAIL"))
end

local base, claim
local model = grug_housing.model
local OWNER = model.owner_text(ACCOUNT, "accord")

local function steward(player)
	core.close_formspec(NAME, "")
	grug_housing.open_manager(player, {})
end

local function link(player)
	grug_accounts.apply_list({version = 7, accounts = {{id = ACCOUNT, name = "Demo", rewards = {}}},
		characters = {{name = NAME, character_id = grug_accounts.character_id(player),
			account_id = ACCOUNT}}})
end

local SHOTS = {
	{name = "S1_steward_no_account", run = function(player)
		steward(player)
		expect(last_form:find("Link this character", 1, true) ~= nil, "S1 the no-account line")
	end},
	{name = "S2_steward_account_no_claim", run = function(player)
		link(player)
		grug_housing.issue_stone(player)
		steward(player)
		expect(last_form:find("Choose the Account Claim Stone", 1, true) ~= nil and
			last_form:find("vanishes", 1, true) ~= nil, "S2 the choice with the warning")
	end},
	{name = "S3_steward_claim_standing", run = function(player)
		-- An offline member of the same account placed and activated the claim.
		model.join("Brenna", OWNER)
		local center = vector.offset(base, 0, 0, -4)
		core.set_node(center, {name = "grug_housing:account_stone_draft"})
		claim = model.create("Brenna", center, "account")
		model.activate(claim, 20)
		grug_housing.sync_stone_node(claim)
		steward(player)
		expect(last_form:find("Join your account", 1, true) ~= nil, "S3 the join button")
	end},
	{name = "S4_steward_member", run = function(player)
		local ok, message = grug_housing.choose_account(player)
		expect(ok and grug_housing.account_owner_of(NAME) == OWNER and
			not grug_housing.holds_stone(player), "S4 joined, no item, the personal stone gone (" ..
			tostring(message) .. ")")
		steward(player)
	end},
	{name = "S5_stone_form_member", run = function(player)
		core.close_formspec(NAME, "")
		grug_housing.set_permission(claim, "Mirela", "interact")
		grug_housing.open_stone_interface(player, claim)
		expect(last_form:find("Owners:", 1, true) ~= nil, "S5 the owners line")
	end},
	{name = "S6_stones_in_world", run = function(player)
		core.close_formspec(NAME, "")
		local row = {grug_housing.STONE_ITEM, grug_housing.EMPTY_STONE, grug_housing.DRAFT_STONE,
			"grug_housing:account_stone", "grug_housing:account_stone_empty",
			"grug_housing:account_stone_draft"}
		for index, node in ipairs(row) do
			local at = vector.offset(base, index - 4 + (index > 3 and 1 or 0), 0, 5)
			core.set_node(vector.offset(at, 0, -1, 0), {name = "default:stone"})
			core.set_node(at, {name = node})
		end
		local inv = player:get_inventory()
		inv:set_stack("main", 1, ItemStack("grug_housing:account_stone"))
		inv:set_stack("main", 2, ItemStack(grug_housing.STONE_ITEM))
		-- main[1] is the first hotbar slot, the one in hand after the join.
		player:set_pos(vector.offset(base, 0, 0, 1))
		player:set_look_horizontal(0)
		player:set_look_vertical(0.35)
	end},
	{name = "S7_inventory_tooltip", run = function()
		core.show_formspec(NAME, "grug_probe_r86_stone:inv", "formspec_version[6]size[11,3]" ..
			"label[0.5,0.3;Personal and Account Claim Stone]" ..
			"list[current_player;main;0.5,0.7;8,1;]")
	end},
}
-- Round 86 FORMFIX (SHOTS=form): the stone form's Claim Stone tab, the
-- personal claim and then the account claim, each within the 12-hour
-- pick-up wait and after it.
local personal
local function open_form(player, claim)
	core.close_formspec(NAME, "")
	grug_housing.open_stone_interface(player, claim)
	expect(last_form:find("Lump: 7 h 16 min", 1, true) ~= nil, "the form is open")
end
local FORM_SHOTS = {
	{name = "F1_personal_wait", run = function(player)
		grug_housing.model.issue(NAME, 30, false)
		local center = vector.offset(base, 0, 0, -4)
		core.set_node(center, {name = grug_housing.DRAFT_STONE})
		personal = grug_housing.model.create(NAME, center)
		grug_housing.model.activate(personal, 20)
		grug_housing.sync_stone_node(personal)
		open_form(player, personal)
	end},
	{name = "F2_personal_no_wait", run = function(player)
		personal.activated_at = personal.activated_at - 13 * 3600
		open_form(player, personal)
	end},
	{name = "F3_account_wait", run = function(player)
		core.close_formspec(NAME, "")
		grug_housing.remove_stone_node(personal)
		grug_housing.model.remove(personal, "picked_up")
		link(player)
		model.join("Brenna", OWNER)
		local center = vector.offset(base, 0, 0, -4)
		core.set_node(center, {name = "grug_housing:account_stone_draft"})
		claim = model.create("Brenna", center, "account")
		model.activate(claim, 20)
		grug_housing.sync_stone_node(claim)
		grug_housing.choose_account(player)
		open_form(player, claim)
	end},
	{name = "F4_account_no_wait", run = function(player)
		claim.activated_at = claim.activated_at - 13 * 3600
		open_form(player, claim)
	end},
}

-- S7's hover is on main slot 1 (the account stone): x 0.5 + 0.5, y 0.7 + 0.5.
SHOTS[7].hover = {11, 3, 1.0, 1.2}
if core.settings:get("r86stone_shots") == "form" then SHOTS = FORM_SHOTS end

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
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_human = "Human"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		local socket
		for _, entry in ipairs(grug_core.settlement_sockets("human")) do
			if entry.role == "waypoint" then socket = entry end
		end
		base = vector.offset(socket.pos, 3, 0, 0)
		state.phase = "emerge"
		core.emerge_area(vector.offset(base, -10, -4, -12), vector.offset(base, 10, 8, 12),
			function(_, _, remaining)
				if remaining ~= 0 then return end
				player:set_pos(vector.offset(base, 0, 0, -1))
				player:set_look_horizontal(math.pi)
				player:set_look_vertical(0.3)
				log("READY")
				state.phase = "shoot"
				state.shot, state.waited, state.logged, state.ran = 1, 0, false, false
			end)
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if not state.ran then
			state.ran = true
			player:set_physics_override({gravity = 0, speed = 0, jump = 0})
			shot.run(player)
			log("ran " .. shot.name)
		end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			if shot.hover then
				log(("HOVER %s %s %s %s %s"):format(shot.name, unpack(shot.hover)))
			end
			log("SHOT " .. shot.name)
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.ran = 0, false, false
		end
	end
end)
