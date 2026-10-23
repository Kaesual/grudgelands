-- Round 58 lane CAMPNPC's scene for the Round 55 GAME capture probe
-- (SCENE=tools/r58_campnpc/scene.lua tools/r55_game/capture.sh OUT_DIR; the
-- format is in tools/r55_game/grug_probe_r55_game/init.lua): the camp
-- vendor, the exchange counter and the guild's quest givers as the game
-- draws their windows. The probe world is disposable: the test camp below
-- and the probe quest exist only there.
--
--   N1_page_rank0     the camp vendor's Buy mode, the reputation page, at
--                     rank 0 (every row locked)
--   N2_page_rank3     the same at rank 3 (through the real /guild_rep)
--   N3_page_bought    after a click on Ore Sense I
--   N4_camp_tradein   the camp vendor as it opens: Trade-in, with Repair
--   N5_repair         the camp vendor's Repair: the repair form with a worn
--                     piece of gear
--   N6_exchange       the Miner's Guild Exchange as it opens (Trade-in)
--   N7_exchange_buy   its Buy mode (no reputation page)
--   N8_foreman        a foreman's quest dialog (a probe quest given by the
--                     Goldmead foreman: his title and dialog)
--   N9_guild_leader   Highcourt's guild leader's dialog (the same probe quest)
-- The camp vendor's socket (N4, N5) is a test camp registered at the
-- capture player's position (the repair provider checks the socket, the
-- distance and the faction); the other shots open the window without one,
-- so they show no Repair button.
return function(api)
	local scene = {}
	local CAMP = "grug_traders:vendor_camp"
	local EXCHANGE = "grug_traders:guild_exchange"
	local KEY = "r58_campnpc_probe_camp"
	local FOREMAN = "r58_foreman_mining_camp_goldmead_vale"
	local LEADER = "r58_guild_leader_highcourt"
	local PROBE_QUEST = "r58_campnpc_probe_quest"

	local function chat(line)
		local privs = core.get_player_privs(api.name)
		privs.server = true
		core.set_player_privs(api.name, privs)
		for _, fn in ipairs(core.registered_on_chat_messages) do
			if fn(api.name, line) then break end
		end
	end

	-- The windows the game draws, captured instead of sent.
	local captured
	local function with_capture(fn)
		local real = core.show_formspec
		core.show_formspec = function(name, formname, formspec)
			if formname == "grug_traders:trade" or formname:find("^grug_repair:service:") or
					formname == "grug_quests:dialogue" then
				captured = formspec
				return
			end
			return real(name, formname, formspec)
		end
		local ok, err = pcall(fn)
		core.show_formspec = real
		if not ok then api.log("window failed: " .. tostring(err)) end
	end
	local function submit(player, formname, fields)
		for _, fn in ipairs(core.registered_on_player_receive_fields) do
			if fn(player, formname, fields) then return end
		end
	end

	-- A camp vendor socket where the player stands (the repair shot, once:
	-- the formspec shots all stand the player at the same spot).
	local origin
	local function camp_here(player)
		if not origin then
			local p = vector.round(player:get_pos())
			grug_core.register_settlement_sockets(KEY, "human", {x = p.x, y = p.y - 1, z = p.z},
				{{id = "vendor_camp", role = "vendor", kind = "camp", x = 0, y = 1, z = 0,
					dir = {x = 0, z = -1}}}, "Probe Camp", "mining_camp")
			origin = {settlement = KEY, socket = "vendor_camp"}
		end
		return origin
	end
	local function open(player, vendor, fields, with_origin)
		local o = with_origin and camp_here(player) or nil
		with_capture(function()
			grug_traders.open(player, vendor, player:get_pos(), "accord", o)
			for _, f in ipairs(fields or {}) do submit(player, "grug_traders:trade", f) end
		end)
	end
	local function carry(player)
		local inv = player:get_inventory()
		for _, item in ipairs({"default:cobble 99", "default:iron_lump 12",
				"grug_materials:silver_lump 3", "default:sand 49"}) do
			inv:add_item("main", item)
		end
	end
	local function worn_gear(player)
		local inv = player:get_inventory()
		for _, name in ipairs({"grug_gear:sword_t2", "default:pick_steel"}) do
			if core.registered_items[name] then
				local stack = ItemStack(name)
				stack:set_wear(30000)
				inv:add_item("main", stack)
			end
		end
		local list = inv:get_list("main")
		for _, stack in ipairs(list) do
			if grug_repair.eligible(stack) and stack:get_wear() == 0 and stack:get_name() ~= "" then
				stack:set_wear(20000)
			end
		end
		inv:set_list("main", list)
		grug_money.add(player, 50000)
	end

	-- The probe quest: given by one foreman and one leader (registered in
	-- the probe world only, so their dialogs open).
	local function probe_quest()
		if grug_quests.registered_quests[PROBE_QUEST] then return end
		grug_quests.register_quest(PROBE_QUEST, {title = "Probe: Ore for the Lift",
			description = "A probe quest for the screenshot (never shipped): the giver's " ..
				"dialog with its title.", rewards = {weight = 1}, min_level = 1,
			variants = {{key = "probe", givers = {FOREMAN, LEADER},
				objectives = {{type = "item", item = "default:iron_lump", count = 5}}}}})
	end
	local function dialog(player, npc_id)
		probe_quest()
		local npc = grug_quests.registered_npcs[npc_id]
		api.log(("%s: title %s, faction %s, role %s, socket %s/%s"):format(npc_id,
			tostring(npc and npc.title), tostring(npc and npc.faction), tostring(npc and npc.role),
			tostring(npc and npc.settlement), tostring(npc and npc.socket)))
		if not npc then return end
		local entity = {_grug_start = npc.settlement, _grug_socket = npc.socket, object = player}
		with_capture(function() grug_quests.open_npc(player, entity) end)
	end

	function scene.on()
		local shot = function() return captured end
		return {
			{name = "N1_page_rank0", before = function(p) open(p, CAMP, {{mode_buy = "Buy"}}) end,
				formspec = shot},
			{name = "N2_page_rank3", before = function(p)
				chat("/guild_rep " .. api.name .. " 2734")
				open(p, CAMP, {{mode_buy = "Buy"}})
			end, formspec = shot},
			{name = "N3_page_bought", before = function(p)
				local index
				for i, row in ipairs(grug_guild.catalog.CONSUMABLES) do
					if row.item == "grug_guild:ore_sense_t1" then index = i end
				end
				open(p, CAMP, {{mode_buy = "Buy"}, {["repbuy_" .. index] = "x"}})
				api.log("balance after the buy " .. grug_guild.balance(p) .. ", lifetime " ..
					grug_guild.lifetime(p))
			end, formspec = shot},
			{name = "N4_camp_tradein", before = function(p)
				carry(p)
				open(p, CAMP, nil, true)
			end, formspec = shot},
			{name = "N5_repair", before = function(p)
				worn_gear(p)
				open(p, CAMP, {{repair = "Repair"}}, true)
			end, formspec = shot},
			{name = "N6_exchange", before = function(p) open(p, EXCHANGE) end, formspec = shot},
			{name = "N7_exchange_buy", before = function(p) open(p, EXCHANGE, {{mode_buy = "Buy"}}) end,
				formspec = shot},
			{name = "N8_foreman", before = function(p) dialog(p, FOREMAN) end, formspec = shot},
			{name = "N9_guild_leader", before = function(p) dialog(p, LEADER) end, formspec = shot},
		}
	end
	scene.off = scene.on

	return scene
end
