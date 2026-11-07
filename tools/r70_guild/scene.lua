-- Round 70 lane GUILD's scene for the Round 55 GAME capture probe
-- (SCENE=tools/r70_guild/scene.lua tools/r55_game/capture.sh OUT_DIR; the
-- format is in tools/r55_game/grug_probe_r55_game/init.lua): the Stonewright's
-- window as the game draws it. The probe world is disposable.
--
--   G1_rank0        rank 0: every row locked
--   G2_rank2        rank 2 with goods: open rows with lots, a row short of
--                   goods, the rest locked
--   G3_made         after a click on the first row's All
--   G4_rank8        rank 8 with bars: the ornamented rows open
--   G5_short_of_copper  the same, poor: rows that say the fee is missing
return function(api)
	local scene = {}
	local WRIGHT = "grug_traders:stonewright"
	local captured
	local function chat(line)
		local privs = core.get_player_privs(api.name)
		privs.server = true
		core.set_player_privs(api.name, privs)
		for _, fn in ipairs(core.registered_on_chat_messages) do
			if fn(api.name, line) then break end
		end
	end
	local function submit(player, fields)
		for _, fn in ipairs(core.registered_on_player_receive_fields) do
			if fn(player, "grug_traders:trade", fields) then return end
		end
	end
	local function open(player, fields)
		local real = core.show_formspec
		core.show_formspec = function(name, formname, formspec)
			if formname == "grug_traders:trade" then
				captured = formspec
				return
			end
			return real(name, formname, formspec)
		end
		local ok, err = pcall(function()
			grug_traders.open(player, WRIGHT, player:get_pos(), "accord")
			for _, f in ipairs(fields or {}) do submit(player, f) end
		end)
		core.show_formspec = real
		if not ok then api.log("window failed: " .. tostring(err)) end
	end
	local function carry(player, items)
		local inv = player:get_inventory()
		for _, item in ipairs(items) do inv:add_item("main", item) end
	end
	local function clear(player)
		local inv = player:get_inventory()
		for _, name in ipairs({"default:cobble", "default:gravel", "default:sand", "default:stone"}) do
			inv:remove_item("main", name .. " 9999")
		end
	end
	local function money(player, copper)
		grug_money.take(player, grug_money.get(player))
		grug_money.add(player, copper)
	end
	local function rep_to(player, rank)
		local need = grug_guild.threshold(rank) - grug_guild.lifetime(player)
		if need > 0 then chat("/guild_rep " .. api.name .. " " .. need) end
	end

	function scene.on()
		local shot = function() return captured end
		return {
			{name = "G1_rank0", before = function(p)
				money(p, 250)
				carry(p, {"default:cobble 99", "default:gravel 7"})
				open(p)
			end, formspec = shot},
			{name = "G2_rank2", before = function(p)
				rep_to(p, 2)
				open(p)
			end, formspec = shot},
			{name = "G3_made", before = function(p) open(p, {{stoneall_1 = "x"}}) end, formspec = shot},
			{name = "G4_rank8", before = function(p)
				rep_to(p, 8)
				money(p, 123456)
				clear(p)
				carry(p, {"default:cobble 99", "default:cobble 99", "default:gravel 40",
					"grug_materials:iron_bar 7", "grug_materials:steel_bar 2",
					"grug_materials:silversteel_bar 12", "grug_materials:embersteel_bar 1",
					"grug_materials:abyssal_steel_bar 3"})
				open(p)
				api.log("rows at rank 8: " .. #grug_guild.stonewright_rows(p))
			end, formspec = shot},
			{name = "G5_short_of_copper", before = function(p)
				money(p, 3)
				open(p)
			end, formspec = shot},
		}
	end
	function scene.off() return {} end
	return scene
end
