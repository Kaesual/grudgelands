-- The guild's items (spec §7, §8, §10.6).
--   the twelve consumables grug_guild:ore_sense_t1 .. _t6 and
--   grug_guild:treasure_hunt_t1 .. _t6 (catalog.CONSUMABLES: name, use
--   level as _grug_req_level, the picked icons of drop-01 P2), stackable,
--   tradeable; on use grug_guild.start_effect (effect.lua), the item taken
--   only when the effect starts;
--   the six Miner's Remains nodes grug_guild:miners_remains_t1 .. _t6
--   (catalog.REMAINS: the tier rock's own tile with the picked overlay of
--   drop-01 P1, its dig level, no item of its own, is_ground_content =
--   false), dropping the roll below. They carry the tier rock's
--   `grug_stratum` so the mining transaction treats them as that rock
--   (protection, the pick tier and its hint) and the startup audit accepts
--   their level (grug_materials/audit.lua: only strata and resources carry
--   one). effect.lua places and removes them.
--
--   grug_guild.remains_loot(tier, random) -> {copper = n, items = {"name count", ...}}
--       pure: `random(lo, hi)` an integer source (math.random in the game,
--       a fixed sequence in the fixture); the copper goes into one Bag of
--       Coins (grug_money.make_bag), the bars and the gem as stacks

local catalog = grug_guild.catalog

function grug_guild.remains_loot(tier, random)
	local row = catalog.remains(tier)
	if not row then return {copper = 0, items = {}} end
	local loot = {copper = random(row.copper_min, row.copper_max), items = {}}
	local bars = random(row.bars_min, row.bars_max)
	if bars > 0 then loot.items[#loot.items + 1] = row.bar .. " " .. bars end
	if random(1, row.gem_chance) == 1 then loot.items[#loot.items + 1] = row.gem .. " 1" end
	return loot
end

-- The consumables.

local function notice(player, text)
	grug_core.feed(player, "notice", text, "mining_sense")
end

local function description(row)
	local what
	if row.kind == "ore_sense" then
		what = ("Marks a nearby ore deposit of its depth every %d-%d s, for you only."):format(
			row.interval_min, row.interval_max)
	else
		what = "Hides a Miner's Remains in the rock nearby and marks it for you."
	end
	local text = row.name .. "\n" .. what .. "\n" .. ("Lasts %d min; works only %s."):format(
		math.floor(row.duration / 60), grug_guild.band_text(row.tier))
	if row.use_level > 1 then text = text .. "\nRequires level " .. row.use_level end
	return text
end

local function use(row)
	return function(itemstack, player)
		if not player or not player.is_player or not player:is_player() or
				player:get_hp() <= 0 then return end
		local ok, err = grug_guild.start_effect(player, row.kind, row.tier)
		if not ok then
			if err == "level" then
				notice(player, "Requires level " .. row.use_level .. ".")
			elseif err == "depth" then
				notice(player, row.name .. " works only " .. grug_guild.band_text(row.tier) .. ".")
			elseif err == "active" then
				local active = grug_guild.active_effect(player)
				local running = active and catalog.consumable(active.kind, active.tier)
				notice(player, (running and running.name or catalog.UI_NAME) .. " is active (" ..
					grug_core.status_icons.remaining_text((active and active.remaining or 0) * 1e6) .. ").")
			end
			return
		end
		notice(player, row.name .. " is active for " .. math.floor(row.duration / 60) .. " min.")
		itemstack:take_item(1)
		return itemstack
	end
end

for _, row in ipairs(catalog.CONSUMABLES) do
	core.register_craftitem(row.item, {
		description = description(row),
		inventory_image = "grug_guild_" .. row.kind .. "_t" .. row.tier .. ".png",
		stack_max = 20,
		groups = {grug_guild_consumable = 1},
		_grug_req_level = row.use_level,
		on_use = use(row),
	})
end

-- The Miner's Remains.

local OVERLAY = "grug_guild_miners_remains_overlay.png"

local function give_loot(pos, digger, tier)
	local loot = grug_guild.remains_loot(tier, math.random)
	local stacks = {}
	if loot.copper > 0 then stacks[#stacks + 1] = grug_money.make_bag(loot.copper) end
	for _, item in ipairs(loot.items) do stacks[#stacks + 1] = ItemStack(item) end
	if digger and digger.is_player and digger:is_player() then
		core.handle_node_drops(pos, stacks, digger)
	else
		for _, stack in ipairs(stacks) do core.add_item(pos, stack) end
	end
end

for _, row in ipairs(catalog.REMAINS) do
	local tier = row.tier
	local host = core.registered_nodes[row.host]
	local tile = host and host.tiles and host.tiles[1]
	if type(tile) == "table" then tile = tile.name end
	local level = grug_materials.level_for_tier(tier)
	core.register_node(row.node, {
		description = row.name .. "\n" .. grug_materials.pick_requirement(level),
		tiles = {(tile or "default_stone.png") .. "^" .. OVERLAY},
		groups = grug_materials.set_gate_groups({cracky = 3, grug_stratum = tier,
			not_in_creative_inventory = 1}, level),
		drop = "",
		is_ground_content = false,
		sounds = host and host.sounds,
		on_timer = function(pos)
			return grug_guild._remains_on_timer(pos, tier)
		end,
		after_dig_node = function(pos, _, oldmeta, digger)
			grug_guild._remains_on_dig(oldmeta)
			give_loot(pos, digger, tier)
		end,
	})
end
