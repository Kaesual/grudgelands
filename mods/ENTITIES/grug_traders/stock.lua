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
-- The caster's half of the same below-ladder starter pair (WP13 round 2): a
-- Priest or Mage who loses the staff its class grant gave it must be able to
-- buy the same thing back, exactly as a Warrior can buy the stone sword above.
-- Same price, because it is the same rung.
grug_traders.register_stock({item = "grug_gear:staff_wood", price = 15, category = "tools"})
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
-- WP10 also owns the profession tomes of §8.2 — the Apprentice tome at 25c
-- (any profession) and the replacement tomes T2/T3/T4 at 1s / 3s / 10s
-- (= 100c / 300c / 1000c, economy.md §1: prices are ALWAYS copper here):
--
--   grug_traders.register_stock({item = "grug_jobs:tome_apprentice", price = 25,   category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:tome_t2",         price = 100,  category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:tome_t3",         price = 300,  category = "goods"})
--   grug_traders.register_stock({item = "grug_jobs:tome_t4",         price = 1000, category = "goods"})
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
--   * 2 ROTATING slots drawn from the 3 items of grug_gear.catalog[b].extras
--     (dagger, greataxe, staff): two weapon families are on sale each hour,
--     the third is WITHHELD and rotates back in next hour. Withholding is
--     what makes it a rotation at all — with one slot per extra the whole
--     catalog would be on the shelf every hour and the roll would only
--     permute the display order. §3.8's "guaranteed, but expensive … the
--     floor, not the ceiling" is a promise about the 9-item floor above,
--     which is untouched by this;
--   * one rotation in five, one of those two slots is replaced by a single
--     UNCOMMON item drawn from grug_gear.catalog[b].all and priced x3 —
--     "today the trader had something good". Until WP5's enchant roller
--     exists, no Uncommon is offered at all (see the WP5 SEAM below).
--
-- DETERMINISM IS THE POINT. Two players standing at the same vendor in the
-- same hour must see the same shelf, and a server restart must not re-roll it.
-- So the roll is a pure function of (real hour, vendor kind, bracket), fed
-- into a PcgRandom — never math.random, whose sequence depends on how many
-- times anything else in the game called it since startup.
--

local ROTATION_SECONDS = 3600 -- §3.8 "re-rolled hourly"; real hours
-- STRICTLY BELOW #extras (3 today), or nothing is ever withheld and the
-- hourly re-roll degenerates into a reshuffle of the same shelf. If §3.2 ever
-- grows a fourth extra weapon family, raise this to 3 — never to #extras.
local ROTATING_SLOTS = 2
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
-- WP5 SEAM — WP7 has no enchant roller of its own. §6.3's world window
-- (frac 0.00-0.60) is grug_items' job, and an Uncommon WITHOUT enchants is
-- mechanically identical to the Common next to it (Common is enchant-free by
-- definition, §3.8) while costing x3. So the whole Uncommon offer is gated on
-- the roller EXISTING: while it does not, the rotating slots simply hold the
-- normal extras and nothing is sold at a x3 premium for nothing.
--
-- Every line of the Uncommon machinery stays in place — the x3 price, the
-- grug_quality = 2 meta, the blue description, the roll call. The moment
-- grug_items.roll_enchants exists, Uncommons light up automatically: WP5
-- needs NO edit in this file.
--
-- core.global_exists is the only way to probe a global without tripping
-- strict.lua (docs/research/luanti-lua.md).
--
local function enchant_roller()
	if core.global_exists("grug_items") and grug_items.roll_enchants then
		return grug_items.roll_enchants
	end
	return nil
end

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
	local roll = enchant_roller()
	if roll then
		roll(stack, entry.ilvl, "world") -- §6.3 world window
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
		-- The shuffle decides WHICH extras are on the shelf: taking the first
		-- ROTATING_SLOTS of the shuffled pool leaves the rest withheld until
		-- the next hour. The modulo only guards the degenerate case of a pool
		-- SMALLER than the slot count (never today: 3 extras, 2 slots).
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
	-- The WP5 seam (see make_stack): no roller, no Uncommon. Drawing the three
	-- rolls above unconditionally keeps this gate out of the RNG stream, so
	-- WP5 changes WHAT is on the shelf, not the rotation of everything else.
	if uncommon_roll == 1 and enchant_roller() then
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

--
-- PROFESSION SHELVES (WP13 playtest round 3, sockets contract section 8.4).
--
-- `vendor.kind` grew from {race, general} to also carry butcher, smith,
-- fishmonger, baker and tailor, and in wave 2 (2026-09-15) mason, brewer,
-- bowyer, herbalist, armourer, tanner and embalmer. A profession vendor is an
-- ordinary trader with
-- ONE difference: its General tab is its own shelf instead of the
-- level-independent core stock above. Everything else -- the money, the sell
-- side, the buy-back prices, the formspec -- is the same code, and the two
-- original families are untouched.
--
-- WHAT IS ON THEM is bounded by section 8.4: items the game ALREADY registers.
-- No profession invents an item, because an item nobody registered renders as
-- an "unknown item" button in the trade formspec and is buyable (the warning
-- above this block, from WP7). The audit at the bottom of this file is what
-- enforces that at load rather than in a player's hand: a shelf entry whose
-- item is not registered is DROPPED from the shelf and reported as an error.
--
-- The SMITH and, since wave 2, the ARMOURER additionally keep the bracket
-- tabs, so their shelves are the metal and the padding while the gear ladder
-- itself comes from `grug_gear`'s own catalog (items_crafting.md section
-- 3.0.3: the vendor bracket catalog and the base craft ladder are the same
-- items, so a smith that listed them again would be a second copy of the
-- ladder). The other ten sell no equipment and carry no bracket tab at all.
--
-- Prices are in COPPER (economy.md section 1) and sit above the
-- `_grug_sell_price` the same items carry as loot, so buying from a profession
-- vendor and selling it back is a loss, exactly as it is at the two original
-- families.
--
grug_traders.profession_stock = {}

local function profession_shelf(kind, entries)
	assert(type(kind) == "string" and kind ~= "",
		"grug_traders profession shelf: kind missing")
	assert(grug_traders.profession_stock[kind] == nil,
		"grug_traders profession shelf: " .. kind .. " already has a shelf")
	local shelf = {}
	for index = 1, #entries do
		local row = entries[index]
		local price = tonumber(row[2])
		assert(type(row[1]) == "string" and row[1] ~= "" and price and
			price > 0 and price == math.floor(price),
			"grug_traders profession shelf: " .. kind .. " entry " .. index ..
			" differs")
		shelf[index] = {item = row[1], price = price,
			category = row[3] or "goods"}
	end
	grug_traders.profession_stock[kind] = shelf
	return shelf
end

-- Supplies used by every profession belong on both the core shelf and every
-- profession-only shelf, because those vendors do not merge the two lists.
function grug_traders.register_all_vendor_stock(def)
	grug_traders.register_stock(def)
	local source = grug_traders.stock[#grug_traders.stock]
	for _, shelf in pairs(grug_traders.profession_stock) do
		shelf[#shelf + 1] = {
			item = source.item, price = source.price, category = source.category,
		}
	end
end

-- The butcher: meat and the hides that come off the same animal
-- (biomes_mobs.md section 6's base-material map, which is where every one of
-- these items comes from).
profession_shelf("butcher", {
	{"mobs:meat_raw", 4},
	{"mobs:meat", 9},
	{"mobs:leather", 8},
	{"grug_mobs:light_leather", 6},
	{"grug_mobs:heavy_leather", 16},
	{"grug_mobs:boar_tusk", 5},
})

-- The fishmonger: the catch and what comes out of the water with it.
profession_shelf("fishmonger", {
	{"grug_mobs:raw_fish", 5},
	{"grug_mobs:scaled_hide", 16},
	{"grug_mobs:croc_tooth", 13},
	{"grug_gathering:stormkelp", 6},
})

-- The baker: what the fields and the forest floor give (WP33's gathering
-- catalog). No bread: there is no bread item, and section 8.4 builds a shelf
-- from items the game already registers.
profession_shelf("baker", {
	{"grug_gathering:corn", 3},
	{"grug_gathering:potato", 3},
	{"grug_gathering:melon", 4},
	{"grug_gathering:mushroom", 3},
})

-- The tailor: the cloth line of biomes_mobs.md section 6, plus the two wools
-- an ordinary settlement would actually have on a bolt.
profession_shelf("tailor", {
	{"grug_mobs:linen_scrap", 3},
	{"grug_mobs:linen_cloth", 8},
	{"grug_mobs:heavy_cloth", 13},
	{"grug_mobs:spider_silk", 13},
	{"wool:white", 6},
	{"wool:brown", 6},
})

-- The smith: bars and the below-ladder tools. The LADDER is the bracket tabs
-- this one vendor keeps (see the note above), not a list here.
profession_shelf("smith", {
	{"grug_materials:bronze_bar", 7},
	{"grug_materials:iron_bar", 14},
	{"grug_materials:steel_bar", 26},
	{"default:pick_bronze", 40, "tools"},
	{"default:axe_bronze", 36, "tools"},
	{"default:shovel_bronze", 32, "tools"},
})

--
-- WAVE 2 (2026-09-15): seven more shelves for contract section 8.4's second
-- row of kinds -- mason, brewer, bowyer, herbalist, armourer, tanner and
-- embalmer.
--
-- EVERY ITEM BELOW WAS MEASURED, not looked up in a design doc: one headless
-- boot of this tree dumped all 1012 registered item names and their
-- `_grug_sell_price`, and every name here and every price comparison comes out
-- of that dump (the evidence directory carries it). Two things it settled:
--
--   * THERE IS NO BOW. Nothing in the 1012 is a bow, a stave, a bowstring or a
--     quiver -- the only archery items in the game are `grug_mobs:arrow`
--     ("Bundle of Arrows", the skeleton archer's drop, whose own item comment
--     already says "there is no bow/quiver item yet") and the castle
--     ARROWSLIT nodes, which are masonry. So the bowyer sells arrows and the
--     stick-class goods they are made of, exactly as the wave-2 brief allows,
--     and gets no bracket tab (there is no ranged family in `grug_gear` to
--     reach).
--   * THERE ARE NO PROCESSED INTERMEDIATE GOODS. §3.0.3's leather grades are
--     "named, not yet registered", and nothing in the tree is a rivet, a
--     buckle, a bolt of cured hide or a jar. Twelve trades therefore share one
--     pool of about forty sellable materials, so a few items appear on two
--     shelves (the butcher and the tanner both sell hides; the tailor and the
--     embalmer both sell linen scrap). Where that happens the PRICE IS THE
--     SAME on both, so the overlap is one good in two shops and never an
--     arbitrage.
--
-- Prices sit above each item's `_grug_sell_price` buy-back the same way the
-- five original shelves do, and since this lane the audit in init.lua proves
-- it for every profession shelf instead of only for the core stock.
--

-- The mason: the ground a district is paved and walled with. Nothing here has
-- a buy-back price at all, so the trade is one-way by construction.
profession_shelf("mason", {
	{"default:cobble", 2},
	{"default:gravel", 1},
	{"default:clay_brick", 2},
	{"default:stonebrick", 5},
	{"default:sandstonebrick", 5},
	{"default:stone_block", 6},
})

-- The brewer: the one potion the game has, and what a brewhouse puts in a vat.
-- The potion keeps the core stock's own 8 c -- it is the same item on another
-- counter, not a second price for it.
profession_shelf("brewer", {
	{"grug_traders:potion_healing_weak", 8},
	{"grug_gathering:wild_cocoa", 4},
	{"grug_gathering:marshbloom", 3},
	{"grug_gathering:rock_salt", 3},
	{"default:apple", 2},
})

-- The bowyer: arrows and the stick-and-feather goods behind them (see the
-- measurement above -- no bow exists to sell).
profession_shelf("bowyer", {
	{"grug_mobs:arrow", 5},
	{"default:stick", 2},
	{"grug_mobs:feather", 3},
	{"grug_mobs:sharp_feather", 9},
})

-- The herbalist: WP33's healing herbs plus the two mob reagents that belong on
-- an apothecary's counter rather than a butcher's.
profession_shelf("herbalist", {
	{"grug_gathering:gravemoss", 3},
	{"grug_gathering:dragonweed", 5},
	{"grug_gathering:crimson_lotus", 8},
	{"grug_gathering:sunleaf", 3},
	{"grug_mobs:venom_gland", 9},
	{"grug_mobs:slime_gel", 7},
})

-- The armourer: the plate, the padding and the backing. Its distinguishing
-- offer is the BRACKET TABS (vendors.lua's GEAR_KINDS), so the general shelf
-- is deliberately materials and not a hand-copied ladder.
profession_shelf("armourer", {
	{"grug_materials:bronze_bar", 7},
	{"grug_materials:steel_bar", 26},
	{"grug_mobs:heavy_leather", 16},
	{"grug_mobs:heavy_cloth", 13},
	{"grug_mobs:shiny_scale", 9},
})

-- The tanner: hides and pelts. Two of them (the sleek pelt and the ape hair)
-- are on no other shelf; the three it shares with the butcher carry the
-- butcher's own prices.
profession_shelf("tanner", {
	{"mobs:leather", 8},
	{"grug_mobs:light_leather", 6},
	{"grug_mobs:heavy_leather", 16},
	{"grug_mobs:sleek_pelt", 18},
	{"grug_mobs:ape_hair", 10},
})

-- The embalmer: the undead capital's own trade. `grug_materials:gravesalt` is
-- the cultural material of that region and is sold nowhere else.
profession_shelf("embalmer", {
	{"grug_mobs:bone", 3},
	{"grug_materials:gravesalt", 6},
	{"grug_decor:xdecor_candle", 4},
	{"grug_mobs:linen_scrap", 3},
	{"grug_mobs:zombie_flesh", 5},
})

--
-- The audit. An unregistered item is dropped from its shelf and reported; a
-- clean roster reports itself, so a check nobody sees the result of does not
-- become a check nobody notices breaking (the pattern this mod's other audits
-- established).
--
core.register_on_mods_loaded(function()
	local kinds, offers, dropped = 0, 0, {}
	local names = {}
	for kind in pairs(grug_traders.profession_stock) do
		names[#names + 1] = kind
	end
	-- Sorted: `pairs` order over the shelf table is not reproducible and a log
	-- line that reorders itself is a log line nobody can diff.
	table.sort(names)
	for _, kind in ipairs(names) do
		local shelf = grug_traders.profession_stock[kind]
		local kept = {}
		for index = 1, #shelf do
			local entry = shelf[index]
			if core.registered_items[entry.item] then
				kept[#kept + 1] = entry
			else
				dropped[#dropped + 1] = kind .. "=" .. entry.item
			end
		end
		grug_traders.profession_stock[kind] = kept
		kinds = kinds + 1
		offers = offers + #kept
	end
	if #dropped == 0 then
		core.log("action", "[grug_traders] " .. kinds ..
			" profession shelves, " .. offers .. " offers, all registered")
		return
	end
	core.log("error", "[grug_traders] profession shelves name items nobody " ..
		"registered; those offers are dropped: " .. table.concat(dropped, " "))
end)
