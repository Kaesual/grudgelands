-- Round 84 lane TRADE: the size of every vendor window page in bytes, for
-- the before/after comparison the lane reports (LuaJIT, never shipped). Runs
-- against any checkout that has the Round 57 game harness, so the same
-- script measures the base commit and the lane:
--
--   luajit tools/r84_trade/page_sizes.lua REPO
--
-- One rich Accord human (every rank, money for everything, eight different
-- sellable stacks) opens every registered vendor: each Buy tab, Sell,
-- Trade-in, the Stonewright's page, with the engine's escapes (world.lua).
-- Prints one line per page, largest first, and "MAX <bytes> <page>".
local repo = assert(arg and arg[1], "usage: luajit page_sizes.lua REPO")
local here = (arg[0]:match("^(.*)/[^/]*$") or ".")
local W = dofile(here .. "/world.lua")(repo)
local function measure()
	local pages = {}
	local C = grug_guild.catalog
	local names = {}
	for name in pairs(grug_traders.vendors) do names[#names + 1] = name end
	table.sort(names)
	local serial = 0
	for _, vendor_name in ipairs(names) do
		serial = serial + 1
		local p = W.player("measure" .. serial, {faction = "accord", race = "human",
			class = "warrior", copper = 100000000})
		grug_guild.add(p, C.RANKS[C.MAX_RANK], "test")
		-- Eight different sellable single goods, one slot each (one full page).
		local slot = 9
		for _, entry in ipairs(grug_traders.stock) do
			if slot > 16 then break end
			if grug_traders.sell_price(entry.item) > 0 then
				W.fill(p, {{"main", slot, entry.item}})
				slot = slot + 1
			end
		end
		local vendor = grug_traders.get_vendor(vendor_name)
		local function record(label, formspec)
			if formspec then pages[#pages + 1] = {label = vendor_name .. " " .. label, size = #formspec} end
		end
		record("open", W.open(p, vendor_name))
		if not vendor.stonewright then
			record("buy general", W.open(p, vendor_name, {mode_buy = "Buy"}, {tab_general = "General"}))
			for b = 1, grug_traders.max_bracket() do
				record("buy tab " .. b, W.open(p, vendor_name, {mode_buy = "Buy"}, {["tab_" .. b] = "T"}))
			end
			record("sell", W.open(p, vendor_name, {mode_sell = "Sell"}))
			if vendor.guild then
				W.fill(p, {{W.BAG, 1, "default:cobble 99"}, {W.BAG, 2, "default:sand 99"},
					{W.BAG, 3, "default:gravel 99"}, {W.BAG, 4, "default:iron_lump 40"},
					{W.BAG, 5, "default:copper_lump 40"}, {W.BAG, 6, "default:coal_lump 40"},
					{W.BAG, 7, "default:tin_lump 40"}, {W.BAG, 8, "default:desert_cobble 99"}})
				record("tradein", W.open(p, vendor_name, {mode_tradein = "Trade-in"}))
			end
		else
			W.fill(p, {{W.BAG, 1, "default:cobble 99"}, {W.BAG, 2, "default:gravel 99"}})
			record("page", W.open(p, vendor_name))
		end
	end
	table.sort(pages, function(a, b)
		if a.size ~= b.size then return a.size > b.size end
		return a.label < b.label
	end)
	return pages
end

local pages = measure()
for _, page in ipairs(pages) do print(("%7d %s"):format(page.size, page.label)) end
if pages[1] then print(("MAX %d %s"):format(pages[1].size, pages[1].label)) end
