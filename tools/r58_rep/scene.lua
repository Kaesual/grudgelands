-- Round 58 lane REP's scene for the Round 55 GAME capture probe
-- (SCENE=tools/r58_rep/scene.lua tools/r55_game/capture.sh OUT_DIR; the
-- format is in tools/r55_game/grug_probe_r55_game/init.lua): the Miner's
-- Guild as the game composes it.
--
--   R1_tradein   the vendor's Trade-in mode at a test vendor (a vendor
--                definition with `guild = true`, added to grug_traders.vendors
--                here only), the capture player at rank 3 through the real
--                /guild_rep, carrying lots of stone, sand below a lot, ores
--                and a gem; the window as grug_traders.open draws it
--   R2_tradein_done   the same after All on the Cobblestone row
--   R3_character      the Character page's Stats with the guild lines
--   R4_cloaks_back    rank 10 through /guild_rep: the three cloaks from behind
--                     (rank 3, 6, 10 with its wings)
--   R5_cloak10_3q_walk, R6_cloak10_front_side   the winged cloak
--   R7_character_back the Character page from behind in the winged cloak
-- Real cloaks: grug_achievements' own cloak source.
return function(api)
	local PI = math.pi
	local F, C = api.frames, api.cams
	local scene = {real_cloaks = true}
	local TEST = "grug_traders:r58_test_guild_vendor"

	local function chat(line)
		local privs = core.get_player_privs(api.name)
		privs.server = true
		core.set_player_privs(api.name, privs)
		for _, fn in ipairs(core.registered_on_chat_messages) do
			if fn(api.name, line) then break end
		end
	end

	-- The window grug_traders draws, captured instead of sent.
	local captured
	local function with_capture(fn)
		local real = core.show_formspec
		core.show_formspec = function(name, formname, formspec)
			if formname == "grug_traders:trade" then captured = formspec return end
			return real(name, formname, formspec)
		end
		local ok, err = pcall(fn)
		core.show_formspec = real
		if not ok then api.log("trade window failed: " .. tostring(err)) end
	end
	local function submit(player, fields)
		for _, fn in ipairs(core.registered_on_player_receive_fields) do
			if fn(player, "grug_traders:trade", fields) then return end
		end
	end

	local function open_tradein(player)
		grug_traders.vendors[TEST] = {name = TEST, kind = "r58_test", faction = "accord",
			nametag = "Miner's Guild Vendor (test)", stock = "r58_test", guild = true}
		grug_traders.profession_stock.r58_test = grug_traders.profession_stock.r58_test or {}
		chat("/guild_rep " .. api.name .. " 2734")
		local inv = player:get_inventory()
		for _, item in ipairs({"default:cobble 99", "default:cobble 43", "default:sand 49",
				"default:iron_lump 12", "default:copper_lump 7", "grug_materials:silver_lump 3",
				"grug_materials:rough_jade 2", "default:stonebrick 20"}) do
			inv:add_item("main", item)
		end
		local view = grug_guild.summary(player)
		api.log(("guild: %s rank %d lifetime %d balance %d"):format(view.guild, view.rank,
			view.lifetime, view.balance))
		with_capture(function()
			grug_traders.open(player, TEST, player:get_pos(), "accord")
		end)
	end
	local function trade_first(player)
		with_capture(function()
			grug_traders.open(player, TEST, player:get_pos(), "accord")
			submit(player, {tradein_1 = "All"})
		end)
		api.log("after All: lifetime " .. grug_guild.lifetime(player))
	end
	local function rank10()
		chat("/guild_rep " .. api.name .. " 350000")
		local player = core.get_player_by_name(api.name)
		api.log(("rank %d, cloaks: %s"):format(grug_guild.rank(player),
			table.concat(grug_achievements.unlocked_cloaks(player), ",")))
	end

	local function look(cloak_id)
		return {class = "warrior", line = "leather", tier = 3, cloak_id = cloak_id}
	end

	function scene.on()
		return {
			{name = "R1_tradein", before = open_tradein, formspec = function() return captured end},
			{name = "R2_tradein_done", before = trade_first, formspec = function() return captured end},
			{name = "R3_character", tab = look("none")},
			{name = "R4_cloaks_back", cam = C.far, pitch = 0.2, before = rank10, figures = {
				{x = -1.4, yaw = 0, frame = F.stand, look = look("miners_guild_1")},
				{x = 0, yaw = 0, frame = F.stand, look = look("miners_guild_2")},
				{x = 1.4, yaw = 0, frame = F.stand, look = look("miners_guild_3")}}},
			{name = "R5_cloak10_3q_walk", cam = C.far, pitch = 0.2, figures = {
				{x = -0.8, yaw = PI * 0.25, frame = F.stand, look = look("miners_guild_3")},
				{x = 0.8, yaw = PI * 0.25, frame = F.walk, look = look("miners_guild_3")}}},
			{name = "R6_cloak10_front_side", cam = C.far, pitch = 0.2, figures = {
				{x = -0.8, yaw = PI * 0.75, frame = F.stand, look = look("miners_guild_3")},
				{x = 0.8, yaw = PI / 2, frame = F.walk, look = look("miners_guild_3")}}},
			{name = "R7_character_back", tab = look("miners_guild_3"), rotation = api.back_view},
		}
	end
	scene.off = scene.on

	return scene
end
