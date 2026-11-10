-- Disposable engine probe (Round 74 lane HUD): the hotbar with the action
-- clock's cover, a real cooldown beside it and the waiting cast's marker,
-- for screenshots. Never shipped: tools/r74_hud/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client twice (desktop,
-- then web scaling). The driver (character creation, SHOT / ack handshake)
-- is tools/r48_hud's; the leave and rejoin handshake tools/r74_mount's.
--
-- A headless client cannot hold the mouse button, so the probe stands in
-- for the held fight: it freezes the overlay's read-only clock seam
-- (cooldown_hud.cast_block) on a block 1000 s long whose recorded start
-- puts the cover at the shot's share, so the step stays put for the
-- screenshot; the waiting cast is the overlay's waiting seam. The covers,
-- the cooldown (a real arm_cooldown of Charge) and the elements are the
-- shipped overlay's own.
local P = "[r74hud] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r74hud_settle") or "") or 4
local function log(msg) core.log("action", P .. msg) end

-- The warrior's bar: three swing skills, five casts (Unbroken, not Taunt:
-- Bellow is Taunt's transformation and takes its place).
local BAR = {"strike", "mighty_blow", "hamstring", "charge", "unbroken", "bellow",
	"ruination", "hold_ground"}
local SESSIONS = {"desktop", "web"}
local D = 1000 -- s: the frozen block
-- Each at two cover strengths (for the user's choice; the user then picked
-- the cooldown's own 50 %, CLOCK_OPACITY 255): CLOCK_OPACITY 128 (25 % black)
-- and 192 (38 %), the second set by the probe only (below).
local SHOTS = {}
for _, strength in ipairs({{128, "25"}, {192, "38"}}) do
	local tag = "_" .. strength[2]
	SHOTS[#SHOTS + 1] = {name = "C1_clock_step0" .. tag, share = 0.05, strength = strength[1]}
	SHOTS[#SHOTS + 1] = {name = "C2_clock_step2" .. tag, share = 0.6, strength = strength[1]}
	-- Ruination selected (slot 1) and waiting, the cover a quarter through.
	SHOTS[#SHOTS + 1] = {name = "W1_waiting_marker" .. tag, share = 0.3,
		waiting = "ruination", swap = true, strength = strength[1]}
end

-- Probe only: the cover's strength per shot. After each of the overlay's
-- updates the shipped opacity in a shown cover's texture is rewritten to
-- the shot's (one write per change); the overlay's own state is untouched.
local strength = 128
local hud_update = grug_abilities.cooldown_hud.update
grug_abilities.cooldown_hud.update = function(player, now)
	local result = hud_update(player, now)
	local st = grug_abilities.cooldown_hud.state(player:get_player_name())
	for _, el in pairs(st and st.shown or {}) do
		local want = el.tex:gsub("%^%[opacity:128", "^[opacity:" .. strength)
		if want ~= (el.probe_tex or el.tex) then
			player:hud_change(el.pie, "text", want)
		end
		el.probe_tex = want
	end
	return result
end

local wanted = {}
for _, id in ipairs(BAR) do wanted[id] = true end
local talent_rank = grug_classes.talent_rank
grug_classes.talent_rank = function(player, talent_id)
	for id in pairs(wanted) do
		local def = grug_abilities.registered[id]
		if def and (def.talent or def.id) == talent_id then return 1 end
	end
	return talent_rank(player, talent_id)
end

local state = {phase = "wait", clock = 0, session = 1}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r74hud_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function set_bar(player, swap)
	local inv = player:get_inventory()
	for i, id in ipairs(BAR) do
		local slot = i
		if swap and id == "strike" then slot = 7 end
		if swap and id == "ruination" then slot = 1 end
		inv:set_stack("main", slot, grug_abilities.stack_for(player, id) or ItemStack(""))
	end
	grug_abilities.cooldown_hud.rescan(NAME)
end

local function show(player, shot)
	local H = grug_abilities.cooldown_hud
	strength = shot.strength
	set_bar(player, shot.swap)
	grug_abilities.arm_cooldown(player, grug_abilities.registered.charge, 40)
	local now = core.get_us_time()
	local u = now + (1 - shot.share) * D * 1e6
	H.cast_block = function() return u end
	H.waiting = function() return shot.waiting end
	H.block(player, u, now)
	H.state(NAME).starts[u] = now - shot.share * D * 1e6
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if state.phase == "gone" then
		if player then return end
		state.session = state.session + 1
		state.phase = "wait"
		log("JOIN " .. state.session)
		return
	end
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
		core.set_timeofday(0.5)
		local info = core.get_player_window_information(NAME)
		log(("session %d (%s) window information: %s"):format(state.session,
			SESSIONS[state.session], core.write_json(info or {})))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			if state.session < #SESSIONS then
				state.phase = "gone"
				log("LEAVE " .. state.session)
			else
				state.phase = "done"
				log("shutdown")
				core.request_shutdown("probe done", false, 0)
			end
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		local name = shot.name .. "_" .. SESSIONS[state.session]
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local mine = {}
			for _, def in pairs(player:hud_get_all()) do
				local text = type(def.text) == "string" and def.text or ""
				if def.z_index == 1 or def.z_index == 2 then
					mine[#mine + 1] = ("%s@%.1f,%.1f"):format(text == "" and "-" or
						text:gsub("%^%[fill.*", "^MARKER"), def.offset.x, def.offset.y)
				end
			end
			table.sort(mine)
			log("SHOT " .. name)
			log(("CHECK %s: %d overlay elements: %s"):format(name, #mine,
				table.concat(mine, " ")))
		elseif state.logged and read_ack() == name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
