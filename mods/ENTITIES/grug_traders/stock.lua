-- What a vendor offers: the level-independent core stock (items_crafting.md
-- §3.7 / §8.2) and the six bracket catalogs with their hourly rotation (§3.8).

--
-- Same-race discount (world.md §7: "one race-exclusive vendor per race" plus
-- "the vendor discount as a bonus"). The doc never fixed the number — 10% is
-- the WP7 decision and is documented alongside it. It applies to BUY prices
-- only; buy-back is never discounted, or the discount would widen the
-- buy/sell spread into a money loop at the race vendor.
--
grug_traders.RACE_DISCOUNT = 0.10

-- max(1, ...) so a 1c item can never become free (and never 0-priced, which
-- would let grug_money.take succeed on an empty purse).
function grug_traders.discounted_price(price)
	return math.max(1, math.floor(price * (1 - grug_traders.RACE_DISCOUNT)))
end

--
-- Core stock (§3.7 "the level-independent core": small bag, weak healing
-- potion, wooden/stone tools, bronze pick, torches, job supplies). Prices are
-- §8.2 VERBATIM; "Wood & stone tools / bronze pick | 5-15c / 40c" is the
-- spread spelled out below.
--
-- Every vendor offers this list, in every territory and at every level —
-- that is what "level-independent" means. The bracket catalogs of §3.8 sit on
-- top of it, on their own tabs.
--

grug_traders.stock = {} -- ordered; the UI renders it in registration order

-- {item = <name>, price = <copper>, category = "goods" | "tools"}
function grug_traders.register_stock(def)
	assert(type(def) == "table", "grug_traders.register_stock: table expected")
	assert(type(def.item) == "string" and def.item ~= "",
		"grug_traders.register_stock: item name missing")
	local price = tonumber(def.price)
	assert(price and price > 0 and price == math.floor(price),
		"grug_traders.register_stock: price must be a positive whole copper " ..
		"amount (" .. tostring(def.item) .. ")")
	local category = def.category or "goods"
	assert(category == "goods" or category == "tools",
		"grug_traders.register_stock: unknown category '" .. tostring(category) ..
		"' (" .. def.item .. ")")
	table.insert(grug_traders.stock, {
		item = def.item,
		price = price,
		category = category,
	})
end

grug_traders.register_stock({item = "grug_inventory:bag_small", price = 80, category = "goods"})
grug_traders.register_stock({item = "grug_traders:potion_healing_weak", price = 8, category = "goods"})
grug_traders.register_stock({item = "default:torch", price = 1, category = "goods"})

grug_traders.register_stock({item = "default:pick_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "default:shovel_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "default:axe_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "default:sword_wood", price = 5, category = "tools"})
grug_traders.register_stock({item = "default:pick_stone", price = 10, category = "tools"})
grug_traders.register_stock({item = "default:shovel_stone", price = 10, category = "tools"})
grug_traders.register_stock({item = "default:axe_stone", price = 10, category = "tools"})
grug_traders.register_stock({item = "default:sword_stone", price = 15, category = "tools"})
grug_traders.register_stock({item = "default:pick_bronze", price = 40, category = "tools"})

-- WP10 (jobs/professions) adds the job supplies of §3.7/§8.2 from its own mod,
-- with no change in here — the same call, once per item:
--
--   grug_traders.register_stock({item = "grug_jobs:thread",     price = 1, category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:flux",       price = 2, category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:vial",       price = 3, category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:parchment",  price = 5, category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:whetstone",  price = 4, category = "goods"})
--
-- and WP24 the housing tool of world.md §5.4 / §8.2:
--
--   grug_traders.register_stock({item = "grug_housing:dowsing_rod", price = 15, category = "tools"})
--
-- None of those items exist yet, so NOTHING above this comment registers them:
-- an unknown item name would render as an "unknown item" button in the trade
-- formspec and would be buyable.

--
-- Bracket catalogs & the hourly rotation (§3.8)
--
-- A player sees their own bracket and every bracket below it. Per (vendor
-- kind, bracket) the offer is:
--   * the 9 FIXED items of grug_gear.catalog[b].fixed (sword + 4 metal + 4
--     cloth) — §3.8's guaranteed floor, always on sale;
--   * 3 ROTATING slots filled from grug_gear.catalog[b].extras (dagger,
--     greataxe, staff) in a rotation-dependent ORDER;
--   * one rotation in five, one of those three slots is replaced by a single
--     UNCOMMON item drawn from grug_gear.catalog[b].all and priced x3 —
--     "today the trader had something good".
--
-- DETERMINISM IS THE POINT. Two players standing at the same vendor in the
-- same hour must see the same shelf, and a server restart must not re-roll it.
-- So the roll is a pure function of (real hour, vendor kind, bracket), fed
-- into a PcgRandom — never math.random, whose sequence depends on how many
-- times anything else in the game called it since startup.
--

local ROTATION_SECONDS = 3600 -- §3.8 "re-rolled hourly"; real hours
local ROTATING_SLOTS = 3
local UNCOMMON_EVERY = 5 -- "roughly one rotation in five"
local UNCOMMON_PRICE_FACTOR = 3 -- §3.8 "priced x3"
local UNCOMMON_COLOR = "#4A90FF"

-- The current rotation index. os.time() is wall clock and sandbox-whitelisted
-- (docs/research/luanti-lua.md), so this number is identical on every restart
-- and identical for every player.
function grug_traders.rotation_index()
	return math.floor(os.time() / ROTATION_SECONDS)
end

-- Seed for one (vendor kind, bracket) shelf in one hour.
--
-- Packed by DECIMAL arithmetic, not by bit shifts: `bit.*` is 32-bit and the
-- rotation index alone (os.time()/3600 is ~490000 today and climbing) would
-- start colliding with the low fields once shifted. The layout is
--   rotation * 1000 + salt * 10 + bracket
-- with salt <= 99 and bracket <= 6, so the low three decimal digits are the
-- shelf identity and cannot bleed into the hour. `rotation % 1000000` keeps
-- the product inside the +-(2^53-1) exact-integer range with room to spare and
-- inside the 32-bit range PcgRandom takes (999999 * 1000 + 999 < 2^31).
-- The modulo wraps every ~114 years of real time; a wrap only means two very
-- distant hours share a shelf.
local function rotation_seed(salt, bracket, rotation)
	return (rotation % 1000000) * 1000 + (salt % 100) * 10 + bracket
end

-- Fisher-Yates on a COPY, driven by the PcgRandom above. table.shuffle would
-- use math.random and destroy the reproducibility this whole file is built on.
local function shuffled(list, rng)
	local out = {}
	for i = 1, #list do
		out[i] = list[i]
	end
	for i = #out, 2, -1 do
		local j = rng:next(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

--
-- The Uncommon stack.
--
-- WP5 SEAM — WP7 rolls NO enchants. §6.3's world window (frac 0.00-0.60) is
-- grug_items' job; until WP5 ships, the Uncommon is a blue-named Common with a
-- x3 price tag, and that is the accepted WP7 state. The call below is written
-- so WP5 needs no edit in here: the moment grug_items.roll_enchants exists,
-- the rolls appear.
--
-- core.global_exists is the only way to probe a global without tripping
-- strict.lua (docs/research/luanti-lua.md).
--
function grug_traders.make_stack(entry)
	local stack = ItemStack(entry.item)
	if not entry.uncommon then
		return stack
	end
	local meta = stack:get_meta()
	meta:set_int("grug_quality", 2)
	local def = core.registered_items[entry.item]
	local desc = (def and def.description) or entry.item
	meta:set_string("description", core.colorize(UNCOMMON_COLOR, desc))
	if core.global_exists("grug_items") and grug_items.roll_enchants then
		grug_items.roll_enchants(stack, entry.ilvl, "world") -- §6.3 world window
	end
	return stack
end

--
-- Computation + cache. No timer and no globalstep: the shelf is recomputed
-- lazily on the first access after the hour changed, which for a shelf nobody
-- visits means never.
--

local shelf_cache = {} -- salt -> bracket -> {rotation = n, entries = {...}}

local function compute(salt, bracket, rotation)
	local cat = grug_gear.catalog[bracket]
	local ilvl = grug_gear.BRACKETS[bracket].ilvl
	local entries = {}
	for _, itemname in ipairs(cat.fixed) do
		entries[#entries + 1] = {
			item = itemname,
			price = grug_gear.get_price(itemname),
			ilvl = ilvl,
			fixed = true,
		}
	end

	local rng = PcgRandom(rotation_seed(salt, bracket, rotation))
	local pool = shuffled(cat.extras, rng)
	local rotating = {}
	for i = 1, ROTATING_SLOTS do
		-- extras holds exactly ROTATING_SLOTS items today; the modulo keeps
		-- the loop correct if §3.2 ever grows a fifth weapon family.
		local itemname = pool[((i - 1) % #pool) + 1]
		rotating[i] = {
			item = itemname,
			price = grug_gear.get_price(itemname),
			ilvl = ilvl,
		}
	end

	-- The three rolls below are drawn in a FIXED order even when the first one
	-- says "no Uncommon this hour" — a conditional draw would make the stream
	-- position depend on the outcome, which is fine here (nothing is drawn
	-- afterwards) but is the classic way to make a deterministic roll fragile.
	local uncommon_roll = rng:next(1, UNCOMMON_EVERY)
	local slot = rng:next(1, ROTATING_SLOTS)
	local pick = rng:next(1, #cat.all)
	if uncommon_roll == 1 then
		local itemname = cat.all[pick]
		rotating[slot] = {
			item = itemname,
			price = grug_gear.get_price(itemname) * UNCOMMON_PRICE_FACTOR,
			ilvl = ilvl,
			uncommon = true,
		}
	end

	for i = 1, ROTATING_SLOTS do
		entries[#entries + 1] = rotating[i]
	end
	return entries
end

-- The shelf of one vendor kind for one bracket. `salt` is the per-vendor-kind
-- constant from vendors.lua: it is what makes the race vendor roll its own
-- rotation while every player at THAT vendor sees the same one.
function grug_traders.bracket_stock(salt, bracket)
	bracket = math.floor(tonumber(bracket) or 0)
	if bracket < 1 or bracket > #grug_gear.BRACKETS then
		return {}
	end
	local rotation = grug_traders.rotation_index()
	local per_salt = shelf_cache[salt]
	if not per_salt then
		per_salt = {}
		shelf_cache[salt] = per_salt
	end
	local cached = per_salt[bracket]
	if cached and cached.rotation == rotation then
		return cached.entries
	end
	local entries = compute(salt, bracket, rotation)
	per_salt[bracket] = {rotation = rotation, entries = entries}
	return entries
end

-- Highest bracket a player may shop in (§3.8: "their own bracket and every
-- bracket below").
function grug_traders.max_bracket(player)
	return grug_gear.bracket_for_level(grug_xp.get_level(player))
end

-- UI label of a bracket ("1-10", "11-20", ...).
function grug_traders.bracket_label(bracket)
	local br = grug_gear.BRACKETS[bracket]
	if not br then
		return "?"
	end
	return br.min_level .. "-" .. br.max_level
end
