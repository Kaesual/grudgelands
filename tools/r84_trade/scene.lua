-- Round 84 lane TRADE's scene for the Round 55 GAME capture probe
-- (SCENE=tools/r84_trade/scene.lua tools/r55_game/capture.sh OUT_DIR; the
-- format is in tools/r55_game/grug_probe_r55_game/init.lua): the vendor
-- window's quantity buttons as the game draws them, for the user's look.
-- The probe world is disposable; the capture player is an Accord human.
--
--   Q1_buy_general     the Accord Quartermaster's shelf: the bag (1), the
--                      potion (1 / 5 / 20), torches (Stack 99), arrows
--                      (Stack 100), the tools
--   Q2_buy_poor        the same shelf with 40c: the amounts above it greyed
--   Q3_bought_arrows   after a click on arrows' 20: the status line
--   Q4_buy_gear        the gear tab: every row one button
--   Q5_buy_decor       the Decor Merchant's shelf (stacks of 99)
--   Q6_sell            the Sell tab: 13 potions (1 / 5 / Stack 13), a full
--                      potion slot, arrows, a gear piece, a lot good (one
--                      lot and All), a lot good below one lot
--   Q7_tradein         the guild exchange's Trade-in: one lot and All
--   Q8_stonewright     the Stonewright at rank 2
--   Q9_reputation      the camp vendor's reputation page at rank 3
return function(api)
	local scene = {}
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
			if fn(player, grug_traders.trade_formname(player:get_player_name()), fields) then return end
		end
	end
	local function open(player, vendor, fields)
		local real = core.show_formspec
		core.show_formspec = function(name, formname, formspec)
			if formname:find("^grug_traders:trade") then
				captured = formspec
				return
			end
			return real(name, formname, formspec)
		end
		local ok, err = pcall(function()
			grug_traders.open(player, vendor, player:get_pos(), "accord")
			for _, f in ipairs(fields or {}) do submit(player, f) end
		end)
		core.show_formspec = real
		if not ok then api.log("window failed: " .. tostring(err)) end
		api.log(("page %s: %d bytes"):format(vendor, captured and #captured or 0))
	end
	-- An empty inventory, then `items` in main from slot 9 on (one each).
	local function carry(player, items)
		local inv = player:get_inventory()
		for _, list in ipairs(grug_inventory.consume_lists(inv)) do
			for i = 1, inv:get_size(list) do inv:set_stack(list, i, ItemStack("")) end
		end
		for i, item in ipairs(items or {}) do inv:set_stack("main", 8 + i, ItemStack(item)) end
	end
	local function money(player, copper)
		grug_money.take(player, grug_money.get(player))
		grug_money.add(player, copper)
	end
	local function rep_to(player, rank)
		local need = grug_guild.threshold(rank) - grug_guild.lifetime(player)
		if need > 0 then chat("/guild_rep " .. api.name .. " " .. need) end
	end
	local GENERAL = "grug_traders:vendor_general_accord"

	function scene.on()
		local shot = function() return captured end
		local gear = grug_traders.vendor_bracket_stock(grug_traders.get_vendor(GENERAL), 1)
		local piece = gear[1] and gear[1].item or "grug_inventory:bag_small"
		return {
			{name = "Q1_buy_general", before = function(p)
				carry(p)
				money(p, 50000)
				open(p, GENERAL, {{mode_buy = "Buy"}})
			end, formspec = shot},
			{name = "Q2_buy_poor", before = function(p)
				carry(p)
				money(p, 40)
				open(p, GENERAL, {{mode_buy = "Buy"}})
			end, formspec = shot},
			{name = "Q3_bought_arrows", before = function(p)
				carry(p)
				money(p, 50000)
				local index
				for i, entry in ipairs(grug_traders.stock) do
					if entry.item == "grug_gear:arrow" then index = i end
				end
				open(p, GENERAL, {{mode_buy = "Buy"}, {["buy20_" .. tostring(index)] = "20"}})
			end, formspec = shot},
			{name = "Q4_buy_gear", before = function(p)
				carry(p)
				money(p, 50000)
				open(p, GENERAL, {{mode_buy = "Buy"}, {tab_1 = "T1"}})
			end, formspec = shot},
			{name = "Q5_buy_decor", before = function(p)
				carry(p)
				money(p, 50000)
				open(p, "grug_traders:vendor_culture", {{mode_buy = "Buy"}})
			end, formspec = shot},
			{name = "Q6_sell", before = function(p)
				carry(p, {"grug_traders:potion_healing_weak 13", "grug_traders:potion_healing_weak 20",
					"grug_gear:arrow 100", "grug_gear:arrow 3", piece, "default:cobble 99",
					"default:cobble 44", "default:sand 49"})
				money(p, 0)
				open(p, GENERAL, {{mode_sell = "Sell"}})
			end, formspec = shot},
			{name = "Q7_tradein", before = function(p)
				carry(p, {"default:cobble 99", "default:cobble 4", "default:sand 49",
					"grug_materials:silver_lump 3", "default:iron_lump 1"})
				open(p, "grug_traders:guild_exchange")
			end, formspec = shot},
			{name = "Q8_stonewright", before = function(p)
				carry(p, {"default:cobble 57", "default:gravel 7"})
				rep_to(p, 2)
				money(p, 250)
				open(p, "grug_traders:stonewright")
			end, formspec = shot},
			{name = "Q9_reputation", before = function(p)
				carry(p)
				rep_to(p, 3)
				api.log("reputation balance " .. grug_guild.balance(p))
				open(p, "grug_traders:vendor_camp", {{mode_buy = "Buy"}})
			end, formspec = shot},
		}
	end
	function scene.off() return scene.on() end
	return scene
end
