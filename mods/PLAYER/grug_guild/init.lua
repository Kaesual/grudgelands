-- The Miner's Guild (Round 58, docs/design/miners_guild.md): one guild per
-- faction, The Charter of Stone (The Accord) and The Oathdelvers (The
-- Throng), "Miner's Guild" in the interface. This mod holds the guild's own
-- state and logic: the catalogue (catalog.lua: ranks, exchange rates, the
-- twelve consumables, the Miner's Remains), reputation and the trade-in, the
-- mining effect and the camp vendor's reputation page. Mapgen stays in
-- grug_mapgen, NPCs in grug_mobs, the vendor window in grug_traders, quests
-- in grug_quests.
--
-- The files and their lanes (spec §10, so parallel lanes never edit one
-- file): catalog.lua GUILDSPEC (its VALUES: the tuning page's accepted
-- numbers), store.lua and exchange.lua REP, effect.lua and items.lua
-- CONSUME, vendor.lua CAMPNPC, nodes.lua the skeleton commit, lift.lua LIFT.
-- Until a lane fills its file, its functions answer as for a character of
-- rank 0 with nothing to trade and no effect.
grug_guild = {}

local path = core.get_modpath(core.get_current_modname())
local catalog = dofile(path .. "/catalog.lua")
grug_guild.catalog = catalog

-- The catalogue API (pure, catalog.lua): read the data through these.
grug_guild.rank_for = catalog.rank_for
grug_guild.threshold = catalog.threshold
grug_guild.exchange_rate = catalog.exchange_rate
grug_guild.consumable = catalog.consumable
grug_guild.consumable_by_item = catalog.consumable_by_item
grug_guild.remains = catalog.remains
grug_guild.guild = catalog.guild

dofile(path .. "/store.lua")
dofile(path .. "/exchange.lua")
dofile(path .. "/effect.lua")
dofile(path .. "/items.lua")
dofile(path .. "/vendor.lua")
dofile(path .. "/nodes.lua")
dofile(path .. "/lift.lua")

-- The load audit: every item the catalogue names is registered once every
-- mod has loaded (the consumables and Remains only once lane CONSUME
-- registers them). A miss is an error line; the fixture is the gate.
core.register_on_mods_loaded(function()
	local missing = {}
	local function need(name)
		if not core.registered_items[name] then missing[#missing + 1] = name end
	end
	for _, row in ipairs(catalog.EXCHANGE) do need(row.item) end
	for _, row in ipairs(catalog.REMAINS) do
		need(row.host)
		need(row.bar)
		need(row.gem)
	end
	local consumables = 0
	for _, row in ipairs(catalog.CONSUMABLES) do
		if core.registered_items[row.item] then consumables = consumables + 1 end
	end
	if #missing > 0 then
		core.log("error", "[grug_guild] catalogue names unregistered items: " ..
			table.concat(missing, ", "))
	end
	core.log("action", "[grug_guild] catalogue: " .. #catalog.EXCHANGE ..
		" exchange items, " .. #catalog.CONSUMABLES .. " consumables (" .. consumables ..
		" registered), " .. #catalog.REMAINS .. " Remains tiers, " .. catalog.MAX_RANK .. " ranks")
end)
