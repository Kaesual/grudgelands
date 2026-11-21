-- The trade formspec.
--
-- NO DETACHED INVENTORIES ANYWHERE (decided for WP7). The reference
-- implementations (VoxeLibre's villager, LotT's lottmobs/trader.lua) both move
-- items through detached `wanted/input/offered/output` lists; that pattern
-- loses whatever sits in the input list when a player disconnects mid-trade
-- and needs an allow_/on_ callback matrix to stay consistent. Every transfer
-- in here is a direct add_item/remove on the player's own `main` list, and the
-- vendor's "stock" is a computed list of names and prices, never an inventory.
--
-- SECURITY MODEL. A formspec submission is player input: the field NAMES are
-- chosen by the client, and a modified client can send any of them at any
-- time, from anywhere, in any order. So every single action re-validates
-- from scratch before it touches anything:
--
--   1. the player is online and has a live session (an action without a
--      session is silently dropped — no session, no vendor, no prices);
--   2. the player is within TRADE_RANGE of the session's vendor POSITION
--      (not of an ObjectRef — refs must never be kept across callbacks);
--   3. the player still passes the vendor's faction access rule (a
--      faction can be changed by an admin while the form is open);
--   4. prices, item names and counts are recomputed SERVER-SIDE. The field
--      name carries an index and nothing else; that index is re-resolved
--      against a freshly computed offer/row list and cross-checked against the
--      snapshot the player was actually shown. A mismatch (the stack moved,
--      a shelf changed) aborts the action and re-renders.
--
-- THE QUANTITY RULE (Round 84 ruling 2, defaults 20 and 21). Every row that
-- trades an amount gets its buttons from one function, `quantities` below,
-- by the item's stack size, the row kind and what the player holds: 1 / 5 /
-- 20 / Stack for buying and for selling a slot, a button falling away when
-- its count exceeds the stack (or, selling, the slot) or repeats another's;
-- one lot and All for lot goods, the guild's Trade-in and the Stonewright. A
-- button's field is `<prefix><key>_<index>`, the key one of 1, 5, 20,
-- stack, all; the amount is re-derived from the key on the fresh row, never
-- read from the client.
--
-- THE TRADE-IN (Round 58, miners_guild.md §5). A vendor whose definition
-- carries `guild = true` (the camp vendor and the guild house's exchange
-- counter) is a Miner's Guild vendor: its window gets a third mode,
-- Trade-in, that trades mining materials for reputation with the player's
-- own guild (grug_guild.trade_in_rows / trade_in), and opens on it. The rows
-- re-validate like the Sell tab's lots; grug_guild takes the items only
-- after every check.
--
-- THE REPUTATION PAGE AND REPAIR (Round 58, lane CAMPNPC). A guild vendor
-- whose definition also carries `guild_page = true` (the camp vendor) sells
-- no copper goods: its Buy mode is the reputation page, the twelve
-- consumables in six rows by tier, a row locked with "Reach Reputation Rank
-- N" until the rank is reached (grug_guild.vendor_rows), each item with the
-- buy form's buttons `repbuy<key>_<catalogue index>` that buy through
-- grug_guild.buy (the rank, the balance and the room checked again there,
-- nothing spent on a refusal).
-- A vendor with `repairs = true` (the camp vendor) shows a Repair button
-- that embeds grug_repair's quote for the socket the vendor stands on
-- (grug_repair's camp vendor provider re-checks socket, distance and
-- faction on every action).
--
-- THE STONEWRIGHT (Round 70, miners_guild.md §5.3). A vendor whose definition
-- carries `stonewright = true` shows one page and no modes: the guild lines,
-- then the Trade-in's rows and lots (one lot, All), one row per recipe,
-- locked by rank like the reputation page. Its fields count only there, and
-- nothing else counts at it; grug_guild.stonewright_make checks the rank, the
-- goods, the fee and the room again and changes nothing on a refusal.

local FORMNAME = "grug_traders:trade"

local TRADE_RANGE = 6 -- m; the form closes beyond this
local SELL_ROWS = 8 -- rows per page

local FORM_W, FORM_H = 16, 10.2

-- A lot row below its lot size (sell plan §3.5.3).
local GREYED = "#8a8a8a"

-- player name -> {vendor, faction, pos, origin, mode, tab, page, offer, rows,
-- trade_rows, rep_shown, stone_rows, offers_scroll, offers_scroll_max}
local sessions = {}
local repair_serial = 0
local form_serial = 0

-- A Miner's Guild vendor (its definition's `guild = true`) shows the
-- Trade-in mode. grug_guild depends on nothing of this mod, and the window
-- reads it only at runtime.
local function guild_vendor(vendor)
	return vendor ~= nil and vendor.guild == true and rawget(_G, "grug_guild") ~= nil
end
grug_traders.guild_vendor = guild_vendor

-- A guild vendor whose Buy mode is the reputation page (the camp vendor).
local function guild_page(vendor)
	return guild_vendor(vendor) and vendor.guild_page == true
end

-- The guild house's Stonewright (its definition's `stonewright = true`).
local function stonewright(vendor)
	return vendor ~= nil and vendor.stonewright == true and rawget(_G, "grug_guild") ~= nil
end

-- A vendor that repairs (the camp vendor), with grug_repair loaded (it
-- depends on nothing of this mod) and the socket the vendor stands on.
local function repairs(vendor, session)
	local repair = rawget(_G, "grug_repair")
	return vendor ~= nil and vendor.repairs == true and repair ~= nil and
		repair.camp_vendor_quote ~= nil and session.origin ~= nil
end

local function esc(text)
	return core.formspec_escape(text)
end

-- The item's name, for one-line labels and chat (grug_core.item_name).
local function short_desc(itemname)
	return grug_core.item_name(itemname)
end

local function full_desc(itemname)
	local def = core.registered_items[itemname]
	return (def and def.description) or itemname
end

--
-- Offer / row computation. Both are pure functions of the server state, and
-- both are re-run on every action — the session copy is only ever used as the
-- "what did the player actually see" cross-check.
--

-- The buy list of the current tab, with the price THIS player pays THIS
-- vendor (i.e. the same-race discount already applied).
--
-- `discount` is the has_discount boolean, resolved ONCE by the caller: it is
-- two player-meta reads, and resolving it per entry would run it ~12 times
-- per render and again per click.
--
-- WHICH SHELF THE GENERAL TAB SHOWS (WP13 round 3, sockets contract section
-- 8.4). A PROFESSION vendor carries `stock`, the key of its own shelf in
-- `grug_traders.profession_stock`; the two original families carry none and
-- keep the level-independent core stock, unchanged. The audit in stock.lua has
-- already dropped any entry whose item is not registered, so nothing here can
-- render an "unknown item" button.
--
local function general_shelf(vendor)
	local kind = vendor and vendor.stock
	if kind then
		return grug_traders.profession_stock[kind] or {}
	end
	return grug_traders.stock
end

-- Does this vendor sell equipment at all? Profession vendors opt into full or
-- filtered views of the authoritative bracket catalog.
local function sells_gear(vendor)
	return vendor ~= nil and (vendor.stock == nil or vendor.brackets == true)
end
grug_traders.sells_gear = sells_gear

local function current_offer(player, session, vendor, discount)
	local offer = {}
	if session.tab == "general" then
		for _, entry in ipairs(general_shelf(vendor)) do
			offer[#offer + 1] = {
				item = entry.item,
				base = entry.price,
				price = grug_traders.apply_discount(entry.price, discount),
			}
		end
		return offer
	end
	if not sells_gear(vendor) then
		return offer
	end
	local bracket = tonumber(session.tab)
	if not bracket or bracket < 1 or bracket > grug_traders.max_bracket() then
		return offer
	end
	for _, entry in ipairs(grug_traders.vendor_bracket_stock(vendor, bracket)) do
		offer[#offer + 1] = {
			item = entry.item,
			base = entry.price,
			price = grug_traders.apply_discount(entry.price, discount),
		}
	end
	return offer
end

-- Every stack the vendor would buy in the player's main list, bags, the
-- inactive hotbar layout and the potion belt, the belt with no marker
-- (grug_inventory.consume_lists, Round 56 ruling 8:
-- the lists every consumer counts and takes from, so a lot count never
-- promises what the take cannot find). A good that sells singly keeps one
-- row per slot ({list, index, item, count, unit}); a lot good (Round 48,
-- sell plan §3.5) gets ONE row per item name with its count over every
-- listed list ({item, count, lot, copper}: copper per lot), placed where its
-- first stack is, so 30 + 30 Cobblestone in two slots still make a lot of
-- 50. Lot goods sell without a quality factor and
-- wear is ignored, so merging their stacks changes no price. Every row keeps
-- a representative `stack` (its slot's, a lot row its first one) for the
-- row's tooltip only (Round 49 ruling 2); no action reads it.
local function current_rows(player)
	local rows, lots = {}, {}
	local inv = player:get_inventory()
	if not inv then
		return rows
	end
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		for i, stack in ipairs(inv:get_list(list) or {}) do
			if not stack:is_empty() then
				local unit = grug_traders.stack_sell_price(stack)
				if unit > 0 then
					rows[#rows + 1] = {
						list = list,
						index = i,
						item = stack:get_name(),
						count = stack:get_count(),
						unit = unit,
						stack = stack,
					}
				else
					local name = stack:get_name()
					local copper, lot = grug_traders.sell_offer(stack)
					if lots[name] then
						lots[name].count = lots[name].count + stack:get_count()
					elseif lot and lot > 1 and copper > 0 then
						lots[name] = {item = name, count = stack:get_count(),
							lot = lot, copper = copper, stack = stack}
						rows[#rows + 1] = lots[name]
					end
				end
			end
		end
	end
	return rows
end

-- "1c per 50" for a lot row, "3c each" for a single one.
local function rate_text(row)
	if row.lot then
		return grug_money.format(row.copper) .. " per " .. row.lot
	end
	return grug_money.format(row.unit) .. " each"
end

--
-- The quantity rule (Round 84 ruling 2, defaults 20 and 21)
--

-- The buttons of one row as {key, count, label}, in their columns' order:
--   "buy"  `size` the item's stack size: 1, 5, 20 and Stack (one whole
--          stack), each at most the stack size and none repeating another
--          (gear 1; a potion 1 / 5 / 20; arrows 1 / 5 / 20 / Stack 100);
--   "sell" `size` the stack size, `held` what the row's slot holds: the
--          numbers up to the slot, and Stack the whole slot (at most one
--          stack), unless a number already sells it (13 potions: 1 / 5 /
--          Stack 13; 20 potions: 1 / 5 / 20);
--   "lot"  `size` the count one lot shows, `held` the whole lots: one lot
--          and All (every whole lot), All falling away when it is the one
--          lot; nothing below one lot.
local AMOUNTS = {1, 5, 20}
local function quantities(kind, size, held)
	local buttons = {}
	if kind == "lot" then
		if held >= 1 then
			buttons[1] = {key = "1", count = 1, label = tostring(size)}
			if held > 1 then buttons[2] = {key = "all", count = held, label = "All"} end
		end
		return buttons
	end
	local top = kind == "sell" and math.min(size, held) or size
	local repeated = false
	for _, amount in ipairs(AMOUNTS) do
		if amount <= top then
			buttons[#buttons + 1] = {key = tostring(amount), count = amount, label = tostring(amount)}
			repeated = repeated or amount == top
		end
	end
	if top >= 1 and not repeated then
		buttons[#buttons + 1] = {key = "stack", count = top, label = "Stack " .. top}
	end
	return buttons
end
grug_traders.quantities = quantities

-- The count of the button `key` among `buttons`; nil when no button has it
-- (a forged or stale field).
local function amount_of(buttons, key)
	for _, button in ipairs(buttons) do
		if button.key == key then return button.count end
	end
end

-- Every key in the fixed order the field dispatch tests them.
local BUY_KEYS = {"1", "5", "20", "stack"}
local LOT_KEYS = {"1", "all"}
local SELL_KEYS = {"1", "5", "20", "stack", "all"}

-- How many of an item the player can pay for (`price` each from `funds`)
-- and carry, at most one stack: the bound of a buy row's buttons.
local function buy_limit(player, item, size, price, funds)
	local stack = ItemStack(item)
	stack:set_count(size)
	local room = grug_inventory.room_for(player, stack)
	if price <= 0 then return room end
	return math.min(room, math.floor(funds / price))
end

-- One row's buttons (`quantities`' list; `tip` the amount's total, `greyed`
-- an amount the player cannot pay for or carry, drawn as grey text): the
-- numbers in three narrow columns, Stack or All in the wide one. `dx`
-- shifts the columns into a scroll container, `wide` the wide one's width.
-- The one-item (one-lot) button has no tooltip: the row's rate says its
-- price, and a long shelf pays for every byte (the Decor Merchant).
local COLUMN = {["1"] = 10.2, ["5"] = 11.1, ["20"] = 12.0}
local function quantity_buttons(parts, dx, y, prefix, index, buttons, wide)
	for _, button in ipairs(buttons) do
		local field = prefix .. button.key .. "_" .. index
		local x = COLUMN[button.key]
		local w = x and 0.8 or (wide or 2.4)
		x = (x or 13.0) + dx
		if button.greyed then
			parts[#parts + 1] = ("label[%.2f,%.2f;%s]"):format(x + 0.25, y + 0.3,
				esc(core.colorize(GREYED, button.label)))
		else
			parts[#parts + 1] = ("button[%.2f,%.2f;%.1f,0.6;%s;%s]"):format(x, y, w, field,
				esc(button.label))
			if button.tip and button.key ~= "1" then
				parts[#parts + 1] = ("tooltip[%s;%s]"):format(field, esc(button.tip))
			end
		end
	end
end

--
-- Rendering
--

local function header(parts, player, session, vendor, discount)
	parts[#parts + 1] = grug_core.ui.title(0.5, 0.6, vendor.nametag, parts.growth, parts.growth) ..
		"style_type[label;font_size=" .. grug_core.ui.font_size(0.85, parts.growth) .. "]"
	parts[#parts + 1] = "label[0.5,1.2;Your money: " ..
		esc(grug_money.format(grug_money.get(player))) .. "]"
	if discount then
		local pct = math.floor(grug_traders.RACE_DISCOUNT * 100 + 0.5)
		parts[#parts + 1] = "label[5.0,1.2;" .. esc(core.colorize("#7ee081",
			"Kinship discount: -" .. pct .. "% on every purchase")) .. "]"
	end
	-- The Stonewright's one page needs no modes.
	local modes = stonewright(vendor) and {} or {{"buy", "Buy"}, {"sell", "Sell"}}
	if guild_vendor(vendor) then modes[#modes + 1] = {"tradein", "Trade-in"} end
	if repairs(vendor, session) then modes[#modes + 1] = {"repair", "Repair"} end
	for index, mode in ipairs(modes) do
		local name = mode[1] == "repair" and "repair" or "mode_" .. mode[1]
		local x = FORM_W - 0.5 - (#modes - index + 1) * 1.85
		parts[#parts + 1] = grug_core.ui.navigation_style(name,
			session.mode == mode[1], x, 0.3, 1.75, 0.65, false, parts.growth)
		parts[#parts + 1] = ("button[%.2f,0.3;1.75,0.65;%s;%s]"):format(x, name, mode[2])
	end
end

-- The guild lines of the Trade-in mode and the reputation page: the guild,
-- rank and balance, the lifetime towards the next rank. Returns the
-- summary, or nil (and says so) for a character without a guild.
local function guild_lines(parts, player)
	local view = grug_guild.summary(player)
	if not view then
		parts[#parts + 1] = "label[0.6,1.75;" .. esc("You belong to no guild.") .. "]"
		return nil
	end
	-- The interface says "Miner's Guild" only; the guilds' proper names
	-- belong in texts and on buildings (the user's ruling).
	parts[#parts + 1] = "label[0.6,1.75;" .. esc(grug_guild.catalog.UI_NAME) .. "]"
	parts[#parts + 1] = "label[7.4,1.75;" .. esc(("Rank %d of %d"):format(view.rank,
		grug_guild.catalog.MAX_RANK)) .. "]"
	parts[#parts + 1] = grug_guild.reputation_formspec(0.6, 2.15, view.balance)
	local lifetime = "Lifetime " .. grug_guild.format_points(view.lifetime)
	parts[#parts + 1] = "label[7.4,2.15;" .. esc(view.next and
		(lifetime .. " of " .. grug_guild.format_points(view.next) .. " for Rank " ..
			(view.rank + 1)) or (lifetime .. ": the highest rank")) .. "]"
	return view
end

-- The catalogue index of each consumable (the page's button names).
local function consumable_keys()
	local key_of = {}
	for index, row in ipairs(grug_guild.catalog.CONSUMABLES) do key_of[row.item] = index end
	return key_of
end

local function offer_scroll(parts, session, count, step, top)
	local height = 6.45
	local maximum = math.ceil(math.max(0, count * step - height) * 100)
	session.offers_scroll_max = maximum
	session.offers_scroll = math.max(0, math.min(maximum, session.offers_scroll or 0))
	if maximum > 0 then
		local thumb = math.max(1, math.min(maximum, math.floor(height * (maximum + 1) / (count * step) + 0.5)))
		parts[#parts + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=10;largestep=40;thumbsize=%d]"):format(maximum, thumb)
		parts[#parts + 1] = ("scrollbar[15.25,%.2f;0.25,6.45;vertical;offers_scroll;%d]"):format(top, session.offers_scroll)
	end
	parts[#parts + 1] = ("scroll_container[0.5,%.2f;14.6,6.45;offers_scroll;vertical;0.01]"):format(top)
end

-- The reputation page (Round 58, the camp vendor's Buy mode): the guild
-- lines, then one row per tier with its two consumables. An unlocked row's
-- items have the buy form's buttons (Round 84 default 21), an amount the
-- balance or the bags cannot take greyed; a locked row is greyed with
-- "Reach Reputation Rank N" and has no button (the mount trainer's locked
-- rows). `session.rep_shown` keeps the items shown buyable, the click's
-- cross-check.
local function render_reputation(parts, player, session)
	session.rep_shown = {}
	local view = guild_lines(parts, player)
	if not view then return end
	local key_of = consumable_keys()
	local rows = grug_guild.vendor_rows(player)
	local count = 0
	for _, row in ipairs(rows) do count = count + #row.items end
	offer_scroll(parts, session, count, 0.85, 2.65)
	local index = 0
	for _, row in ipairs(rows) do
		for _, item in ipairs(row.items) do
			local y = index * 0.85
			index = index + 1
			local function text(value) return esc(row.unlocked and value or core.colorize(GREYED, value)) end
			parts[#parts + 1] = ("item_image[0.12,%.2f;0.55,0.55;%s]"):format(y + 0.1, item.item)
			local tip = esc(full_desc(item.item) .. "\nPrice: " .. grug_guild.format_points(item.price) .. " reputation")
			parts[#parts + 1] = ("tooltip[0.12,%.2f;0.55,0.55;%s]"):format(y + 0.1, tip)
			parts[#parts + 1] = ("label[0.85,%.2f;%s]"):format(y + 0.35, text(short_desc(item.item)))
			parts[#parts + 1] = grug_guild.reputation_formspec(4.9, y + 0.35, item.price)
			if row.unlocked then
				local key = key_of[item.item]
				session.rep_shown[item.item] = true
				parts[#parts + 1] = ("label[6.8,%.2f;%s]"):format(y + 0.35,
					text(("Use from level %d"):format(item.use_level)))
				local size = ItemStack(item.item):get_stack_max()
				local buttons = quantities("buy", size)
				local limit = buy_limit(player, item.item, size, item.price, view.balance)
				for _, button in ipairs(buttons) do
					button.greyed = button.count > limit
					button.tip = ("Buy %d for %s reputation"):format(button.count,
						grug_guild.format_points(button.count * item.price))
				end
				quantity_buttons(parts, -0.5, y + 0.05, "repbuy", key, buttons, 2.1)
			else
				parts[#parts + 1] = ("label[6.8,%.2f;%s]"):format(y + 0.35, text(("Reach Reputation Rank %d"):format(row.rank)))
			end
		end
	end
	parts[#parts + 1] = "scroll_container_end[]"
end

local function render_buy(parts, player, session, vendor, discount)
	-- The camp vendor sells only for reputation: its Buy mode is the page.
	if guild_page(vendor) then
		session.offer = {}
		render_reputation(parts, player, session)
		return
	end
	-- Tab row: the level-independent core stock plus the T1 gear shelf
	-- (round33-plan.md §2.6: vendors sell T1 bases only, at every level).
	local max_bracket = grug_traders.max_bracket()
	local tabs = {{id = "general", label = "General"}}
	-- A profession vendor without bracket stock shows ONE tab: it sells no
	-- equipment, and a row of bracket buttons that all answer "nothing on this
	-- shelf" is worse than no row at all.
	if not sells_gear(vendor) then
		max_bracket = 0
	end
	for b = 1, max_bracket do
		tabs[#tabs + 1] = {id = tostring(b), label = grug_traders.bracket_label(b)}
	end
	for i, tab in ipairs(tabs) do
		local x = 0.5 + (i - 1) * 1.75
		parts[#parts + 1] = grug_core.ui.navigation_style("tab_" .. tab.id,
			session.tab == tab.id, x, 1.9, 1.65, 0.7, false, parts.growth)
		parts[#parts + 1] = ("button[%.2f,1.9;1.65,0.7;tab_%s;%s]"):format(
			x, tab.id, esc(tab.label))
	end

	local offer = current_offer(player, session, vendor, discount)
	session.offer = offer
	-- A bounded, client-scrolled catalogue: all offers keep their stable
	-- session indices, each amount one purchase per click. The item's own
	-- tooltip sits on its image; a button's says its total.
	offer_scroll(parts, session, #offer, 0.85, 2.8)
	local funds = grug_money.get(player)
	-- The names are grug_core.ui.prose's borderless text areas, its style set
	-- once for the whole shelf rather than twice per row.
	local prose = grug_core.ui.prose(0, 0, 0, 0, "", false, parts.growth)
	local prose_on, prose_off = prose:match("^(style_type%b[])textarea%b[](style_type%b[])$")
	parts[#parts + 1] = prose_on
	for i, entry in ipairs(offer) do
		local y = (i - 1) * 0.85
		parts[#parts + 1] = ("item_image[0.12,%.2f;0.55,0.55;%s]"):format(y + 0.1, entry.item)
		parts[#parts + 1] = ("textarea[0.85,%.2f;5.4,0.5;;;%s]"):format(y + 0.12, esc(short_desc(entry.item)))
		local price_text = grug_money.format(entry.price)
		local tip = full_desc(entry.item) .. "\nPrice: " .. price_text
		if entry.base ~= entry.price then
			tip = tip .. "\n(normally " .. grug_money.format(entry.base) .. ")"
		end
		parts[#parts + 1] = ("label[6.4,%.2f;%s]tooltip[0.12,%.2f;0.55,0.55;%s]"):format(y + 0.35,
			esc(core.colorize(grug_core.ui.colors.accent, price_text .. " each")), y + 0.1, esc(tip))
		local size = ItemStack(entry.item):get_stack_max()
		local buttons = quantities("buy", size)
		local limit = buy_limit(player, entry.item, size, entry.price, funds)
		for _, button in ipairs(buttons) do
			button.greyed = button.count > limit
			button.tip = ("Buy %d for %s"):format(button.count, grug_money.format(button.count * entry.price))
		end
		quantity_buttons(parts, -0.5, y + 0.05, "buy", i, buttons, 2.1)
	end
	parts[#parts + 1] = prose_off
	parts[#parts + 1] = "scroll_container_end[]"
	if #offer == 0 then
		-- The guild house's exchange counter sells nothing: the guild's goods
		-- are the camp vendors'.
		parts[#parts + 1] = "label[0.6,3.0;" .. esc(guild_vendor(vendor) and
			"The Miner's Guild sells its goods at the mining camps." or
			"The vendor has nothing on this shelf.") .. "]"
	end
	return FORM_H
end

-- A lot row's buttons (one lot, All; `lot` the count one lot shows, `lots`
-- the whole lots held) with their tips: `tip(lots, total)` for an amount,
-- `total(lots)` the text of that many lots' value, also All's label.
local function lot_buttons(lot, lots, tip, total)
	local buttons = quantities("lot", lot, lots)
	for _, button in ipairs(buttons) do
		if button.key == "all" then button.label = "All (" .. total(button.count) .. ")" end
		button.tip = tip(button.count, total(button.count))
	end
	return buttons
end

local function render_sell(parts, player, session)
	local rows = current_rows(player)
	session.rows = rows

	local pages = math.max(1, math.ceil(#rows / SELL_ROWS))
	if session.page > pages then
		session.page = pages
	end
	if session.page < 1 then
		session.page = 1
	end
	local first = (session.page - 1) * SELL_ROWS + 1

	-- esc(): the hint contains a semicolon, which is a formspec field separator.
	-- Two lines, so the long one fits the window.
	parts[#parts + 1] = "label[0.6,1.75;" .. esc("The vendor buys most things " ..
		"you carry.\nCheap goods sell in lots, e.g. 1c per 50; the rest stays " ..
		"with you.") .. "]"
	for offset = 0, SELL_ROWS - 1 do
		local i = first + offset
		local row = rows[i]
		if row then
			local y = 2.5 + offset * 0.8
			parts[#parts + 1] = grug_core.ui.panel(0.4, y - 0.03, 15.2, 0.76)
			-- Below its lot size a lot row is greyed and has no button: the
			-- player learns that the item sells in lots.
			local short = row.lot and row.count < row.lot
			local function text(value)
				return esc(short and core.colorize(GREYED, value) or value)
			end
			parts[#parts + 1] = ("item_image[0.7,%.2f;0.7,0.7;%s]"):format(y, row.item)
			-- The stack's own tooltip (quality, enchants) over the image, as
			-- the mail attachments show it (Round 49 ruling 2).
			parts[#parts + 1] = ("tooltip[0.7,%.2f;0.7,0.7;%s]"):format(y,
				esc(row.stack:get_description()))
			parts[#parts + 1] = ("label[1.7,%.2f;%s]"):format(y + 0.35,
				text(short_desc(row.item) .. " x" .. row.count))
			parts[#parts + 1] = ("label[6.9,%.2f;%s]"):format(y + 0.35, text(rate_text(row)))
			if short then
				parts[#parts + 1] = ("label[10.0,%.2f;%s]"):format(y + 0.35,
					text("Need " .. row.lot .. " to sell"))
			else
				local buttons
				if row.lot then
					buttons = lot_buttons(row.lot, math.floor(row.count / row.lot), function(lots, total)
						return ("Sell %d for %s"):format(lots * row.lot, total)
					end, function(lots) return grug_money.format(lots * row.copper) end)
				else
					buttons = quantities("sell", row.stack:get_stack_max(), row.count)
					for _, button in ipairs(buttons) do
						button.tip = ("Sell %d for %s"):format(button.count,
							grug_money.format(button.count * row.unit))
					end
				end
				quantity_buttons(parts, 0, y, "sell", i, buttons)
			end
		end
	end
	if #rows == 0 then
		parts[#parts + 1] = "label[0.7,3.0;You carry nothing this vendor wants.]"
	end
	parts[#parts + 1] = "button[6.4,8.95;0.7,0.6;sell_prev;<]"
	parts[#parts + 1] = ("label[7.45,9.25;%d / %d]"):format(session.page, pages)
	parts[#parts + 1] = "button[8.9,8.95;0.7,0.6;sell_next;>]"
end

-- "1 point each", "1 point per 50".
local function points_text(points, lot)
	local text = grug_guild.format_points(points) .. (points == 1 and " point" or " points")
	return text .. (lot > 1 and (" per " .. lot) or " each")
end

-- The Trade-in mode (Round 58): the player's guild, rank and balance, then a
-- row per exchanged item carried (the Sell tab's lot rows: greyed with
-- "Need N to trade" below one lot, else one lot and All).
local function render_tradein(parts, player, session)
	if not guild_lines(parts, player) then
		session.trade_rows = {}
		return
	end

	local rows = grug_guild.trade_in_rows(player)
	session.trade_rows = rows
	-- A row's button carries its item's catalogue index, never its place on
	-- the screen: a second click from an older form names the same item.
	local key_of = {}
	for index, rate in ipairs(grug_guild.catalog.EXCHANGE) do key_of[rate.item] = index end
	local pages = math.max(1, math.ceil(#rows / SELL_ROWS))
	session.page = math.min(math.max(session.page, 1), pages)
	local first = (session.page - 1) * SELL_ROWS + 1
	for offset = 0, SELL_ROWS - 1 do
		local i = first + offset
		local row = rows[i]
		if row then
			local y = 2.5 + offset * 0.8
			parts[#parts + 1] = grug_core.ui.panel(0.4, y - 0.03, 15.2, 0.76)
			local short = row.lots < 1
			local function text(value)
				return esc(short and core.colorize(GREYED, value) or value)
			end
			parts[#parts + 1] = ("item_image[0.7,%.2f;0.7,0.7;%s]"):format(y, row.item)
			parts[#parts + 1] = ("tooltip[0.7,%.2f;0.7,0.7;%s]"):format(y,
				esc(full_desc(row.item)))
			parts[#parts + 1] = ("label[1.7,%.2f;%s]"):format(y + 0.35,
				text(short_desc(row.item) .. " x" .. row.count))
			parts[#parts + 1] = ("label[6.9,%.2f;%s]"):format(y + 0.35,
				text(points_text(row.points, row.lot)))
			if short then
				parts[#parts + 1] = ("label[10.0,%.2f;%s]"):format(y + 0.35,
					text("Need " .. row.lot .. " to trade"))
			else
				quantity_buttons(parts, 0, y, "tradein", key_of[row.item], lot_buttons(row.lot,
					row.lots, function(lots, total)
						return ("Trade %d %s for %s reputation"):format(lots * row.lot,
							short_desc(row.item), total)
					end, function(lots) return grug_guild.format_points(lots * row.points) end))
			end
		end
	end
	if #rows == 0 then
		parts[#parts + 1] = "label[0.7,3.0;" .. esc("You carry nothing the guild takes.\n" ..
			"The guild takes raw ores, rough gems, stone and sand.") .. "]"
	end
	parts[#parts + 1] = "button[6.4,8.95;0.7,0.6;tradein_prev;<]"
	parts[#parts + 1] = ("label[7.45,9.25;%d / %d]"):format(session.page, pages)
	parts[#parts + 1] = "button[8.9,8.95;0.7,0.6;tradein_next;>]"
end

-- "10 Cobblestone + 1c", "8 Cobblestone + 1 Iron Bar + 5c".
local function recipe_cost(recipe)
	local parts = {}
	for _, input in ipairs(recipe.inputs) do
		parts[#parts + 1] = input.count .. " " .. short_desc(input.item)
	end
	parts[#parts + 1] = grug_money.format(recipe.fee)
	return table.concat(parts, " + ")
end

-- The Stonewright's page (Round 70): the guild lines, then one row per recipe
-- by catalogue index: what a lot makes and costs, then the Trade-in's lots; a
-- locked row is greyed and says the rank, a row without a lot says what is
-- missing. `session.stone_rows` keeps the rows shown, the click's cross-check.
local function render_stonewright(parts, player, session)
	session.stone_rows = {}
	if not guild_lines(parts, player) then return end
	local rows = grug_guild.stonewright_rows(player)
	session.stone_rows = rows
	-- The cost line in the smaller size, so the longest one stays clear of the
	-- lots on a small screen (the Trade-in's rows have one short line).
	local name_size = "style_type[label;font_size=" .. grug_core.ui.font_size(0.85, parts.growth) .. "]"
	local cost_size = "style_type[label;font_size=" .. grug_core.ui.font_size(0.75, parts.growth) .. "]"
	for index, row in ipairs(rows) do
		local y = 2.5 + (index - 1) * 0.77
		local recipe = row.recipe
		parts[#parts + 1] = grug_core.ui.panel(0.4, y - 0.03, 15.2, 0.76)
		local function text(value)
			return esc((row.unlocked and row.lots >= 1) and value or core.colorize(GREYED, value))
		end
		parts[#parts + 1] = ("item_image[0.7,%.2f;0.7,0.7;%s]"):format(y, recipe.output)
		parts[#parts + 1] = ("tooltip[0.7,%.2f;0.7,0.7;%s]"):format(y, esc(full_desc(recipe.output)))
		parts[#parts + 1] = ("label[1.7,%.2f;%s]"):format(y + 0.2,
			text(recipe.output_count .. " " .. short_desc(recipe.output)))
		parts[#parts + 1] = cost_size .. ("label[1.7,%.2f;%s]"):format(y + 0.52,
			text(recipe_cost(recipe))) .. name_size
		if not row.unlocked then
			parts[#parts + 1] = ("label[10.0,%.2f;%s]"):format(y + 0.35,
				text(("Reach Reputation Rank %d"):format(recipe.rank)))
		elseif row.lots < 1 then
			local short = row.short
			parts[#parts + 1] = ("label[10.0,%.2f;%s]"):format(y + 0.35, text("Need " ..
				(short == "money" and grug_money.format(recipe.fee) or
					(short.count .. " " .. short_desc(short.item)))))
		else
			-- One lot is one conversion; its button and All count what it makes.
			local buttons = lot_buttons(recipe.output_count, row.lots, function(lots)
				return ("Make %d %s for %s"):format(lots * recipe.output_count, short_desc(recipe.output),
					grug_money.format(lots * recipe.fee))
			end, function(lots) return tostring(lots * recipe.output_count) end)
			quantity_buttons(parts, 0, y, "stone", index, buttons)
		end
	end
end

local function build(player, session, vendor, status)
	-- The body is rendered FIRST because the buy grid decides the window
	-- height; size[] is prepended afterwards. Its text grows as the base
	-- height's form does (grug_core.ui.text_growth).
	local body = {growth = grug_core.ui.text_growth(player, FORM_W, FORM_H)}
	-- Once per render, for the header label AND every offer row (see
	-- current_offer).
	local discount = grug_traders.has_discount(player, vendor)
	header(body, player, session, vendor, discount)
	local needed
	if session.mode == "repair" and session.repair_quote then
		local repair_body
		repair_body, session.page = grug_repair.quote_formspec(session.repair_quote, session.page, FORM_W, 2.5, 8.95, session.repair_prefix)
		body[#body + 1] = repair_body
	elseif session.mode == "sell" then
		render_sell(body, player, session)
	elseif session.mode == "tradein" then
		render_tradein(body, player, session)
	elseif session.mode == "stonewright" then
		render_stonewright(body, player, session)
	else
		needed = render_buy(body, player, session, vendor, discount)
	end
	local height = math.max(FORM_H, needed or 0)
	if status and status ~= "" then
		body[#body + 1] = ("label[0.5,%.2f;%s]"):format(height - 0.5, esc(status))
	end
	return grug_core.ui.frame(FORM_W, height, nil, nil, player) ..
		table.concat(body)
end

-- Re-render (never close) after a transaction, so the player sees the new
-- balance and the new stock immediately.
--
-- EVERY RENDER TAKES A NEW FORM NAME (Round 84 fix round 1), FORMNAME ..
-- ":" .. serial, kept in `session.formname`: the client swaps the open
-- form's name without a quit (luanti src/client/game_formspec.cpp:235-249,
-- a new TextDestPlayerInventory per form) and sends each packet under the
-- name of the form it came from, so a click from a form drawn before the
-- last render (a double click on Stack, the row under it replaced by the
-- next item) names an older form and the handler drops it.
local function show(player, status)
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then
		return
	end
	local vendor = grug_traders.get_vendor(session.vendor)
	if not vendor then
		sessions[name] = nil
		if session.formname then core.close_formspec(name, session.formname) end
		return
	end
	local formspec = build(player, session, vendor, status)
	form_serial = form_serial + 1
	session.formname = FORMNAME .. ":" .. form_serial
	core.show_formspec(name, session.formname, formspec)
end

-- The name of a player's open trade form, for the probes and fixtures that
-- answer it; the bare FORMNAME (which acts on nothing) without a session.
function grug_traders.trade_formname(name)
	local session = sessions[name]
	return session and session.formname or FORMNAME
end

local function close(player, message)
	local name = player:get_player_name()
	local session = sessions[name]
	sessions[name] = nil
	-- The empty form closes only a form of this name (game_formspec.cpp:226).
	if session and session.formname then core.close_formspec(name, session.formname) end
	if message then
		core.chat_send_player(name, message)
	end
end

--
-- Entry point (called from the vendor entity's on_rightclick)
--

-- `faction`: the faction the vendor serves (grug_traders.vendor_faction);
-- `origin` (optional): {settlement, socket} the vendor stands on, plain
-- strings (the camp vendor's repair provider).
function grug_traders.open(clicker, vendor_name, pos, faction, origin)
	if not clicker or not clicker:is_player() or not pos then
		return
	end
	local vendor = grug_traders.get_vendor(vendor_name)
	-- The other faction gets the shared refusal line, at most once every two
	-- seconds (Round 31, ruling 13); can_trade re-checks every action.
	if vendor and not grug_factions.serves(faction, clicker) then
		grug_factions.refuse(clicker, vendor.nametag, faction)
		return
	end
	local ok, message = grug_traders.can_trade(clicker, vendor, faction)
	if not ok then
		core.chat_send_player(clicker:get_player_name(), message)
		return
	end
	sessions[clicker:get_player_name()] = {
		vendor = vendor_name,
		faction = faction,
		-- A POSITION, never the ObjectRef: the entity may be unloaded or
		-- replaced between two field submissions (AGENTS.md).
		pos = {x = pos.x, y = pos.y, z = pos.z},
		origin = type(origin) == "table" and type(origin.settlement) == "string" and
			type(origin.socket) == "string" and
			{settlement = origin.settlement, socket = origin.socket} or nil,
		-- A guild vendor opens on its Trade-in mode, the Stonewright has one
		-- page.
		mode = stonewright(vendor) and "stonewright" or guild_vendor(vendor) and "tradein" or "buy",
		tab = "general",
		page = 1,
	}
	grug_sounds.play("npc_vendor", clicker)
	show(clicker)
end

--
-- Re-validation: points 1-3 of the security model above. Returns
-- session, vendor — or nil after closing the form.
--

local function validate(player)
	local session = sessions[player:get_player_name()]
	if not session then
		return nil
	end
	local vendor = grug_traders.get_vendor(session.vendor)
	if not vendor then
		close(player)
		return nil
	end
	local pos = player:get_pos()
	if not pos or vector.distance(pos, session.pos) > TRADE_RANGE then
		close(player, "You walked away from the vendor.")
		return nil
	end
	local ok, message = grug_traders.can_trade(player, vendor, session.faction)
	if not ok then
		close(player, message)
		return nil
	end
	-- The Trade-in mode exists only at a guild vendor.
	if session.mode == "tradein" and not guild_vendor(vendor) then
		session.mode = "buy"
		session.repair_quote = nil
		session.offers_scroll = 0
	end
	-- A stale bracket tab (an unknown id, or one above the player's level)
	-- falls back to the always-available core stock.
	if session.tab ~= "general" then
		local bracket = tonumber(session.tab)
		if not bracket or bracket < 1 or
				bracket > grug_traders.max_bracket() or
				-- ... or a bracket tab at a vendor that has none at all: a
				-- client may submit any field name it likes, so the tab a
				-- session is ON is validated here and not only where the
				-- buttons are drawn (WP13 round 3's profession vendors).
				not sells_gear(vendor) then
			session.tab = "general"
			session.offers_scroll = 0
		end
	end
	return session, vendor
end

--
-- Transactions
--

local function do_buy(player, session, vendor, index, key)
	-- Point 4: recompute the offer from the catalog and cross-check the index
	-- against the snapshot the player was shown. A shelf can change between
	-- the render and the click; buying "slot 11" must never silently become a
	-- different, more expensive item.
	local offer = current_offer(player, session, vendor,
		grug_traders.has_discount(player, vendor))
	local entry = offer[index]
	local shown = session.offer and session.offer[index]
	if not entry or not shown or entry.item ~= shown.item or
			entry.price ~= shown.price then
		show(player, "The vendor's stock has changed.")
		return
	end
	-- The amount from the button's key on the item's own stack size; the
	-- price is per item, the discount included, exactly as for one.
	local count = amount_of(quantities("buy", ItemStack(entry.item):get_stack_max()), key)
	if not count then
		show(player)
		return
	end
	local total = count * entry.price
	local stack = ItemStack(entry.item)
	stack:set_count(count)

	-- One transaction or none: the room first, then the money, then the
	-- items. Items are NEVER dropped on the ground as a fallback: a full bag
	-- next to a busy vendor would turn a purchase into a giveaway.
	if not grug_inventory.fits(player, {stack}) then
		show(player, count == 1 and "Your inventory is full." or
			("You have no room for %d."):format(count))
		return
	end
	-- grug_money.take is atomic: on an insufficient balance nothing at all
	-- changes (grug_money/init.lua:122).
	if not grug_money.take(player, total) then
		show(player, "Not enough money.")
		return
	end
	-- The give helper (the quiver, the belt, main[9..], the bags, the hotbar
	-- last) also runs the weapon-tooltip initializer crafting and pickup use.
	local rest = grug_inventory.give(player, stack)
	if not rest:is_empty() then
		-- fits() and give() share one cell order, so this never happens; pay
		-- back exactly what did not arrive and say so loudly.
		grug_money.add(player, rest:get_count() * entry.price)
		core.log("error", ("[grug_traders] %s bought %d %s but %d did not fit"):format(
			player:get_player_name(), count, entry.item, rest:get_count()))
		count = count - rest:get_count()
		total = count * entry.price
	end
	grug_sounds.play("vendor_buy", player)
	show(player, "Bought " .. (count == 1 and "" or count .. "x ") .. short_desc(entry.item) ..
		" for " .. grug_money.format(total) .. ".")
end

-- A lot row's one lot or All (sell plan §3.5.4-§3.5.6; All: as many whole
-- lots as the player carries over the sell list's lists); the rest stays. The
-- row is recomputed server-side and cross-checked against the one shown
-- (item, lot, copper, total count); the money ceiling is checked before
-- anything is removed, and the units are taken with the engine's
-- remove_item, list by list, only after every check has passed.
local function do_sell_lots(player, shown, key)
	local fresh
	for _, row in ipairs(current_rows(player)) do
		if row.lot and row.item == shown.item then
			fresh = row
			break
		end
	end
	if not fresh or fresh.lot ~= shown.lot or fresh.copper ~= shown.copper or
			fresh.count ~= shown.count then
		show(player, "Your items have changed.")
		return
	end
	local lots = amount_of(quantities("lot", fresh.lot, math.floor(fresh.count / fresh.lot)), key)
	if not lots then
		show(player)
		return
	end
	local total = lots * fresh.copper
	-- As for single goods: refuse the whole sale rather than let
	-- grug_money.add clamp it after the items are gone.
	if grug_money.get(player) + total > grug_money.MAX then
		show(player, "You cannot carry that much money.")
		return
	end
	local inv = player:get_inventory()
	local wanted = lots * fresh.lot
	local removed = 0
	for _, list in ipairs(grug_inventory.consume_lists(inv)) do
		if removed >= wanted then break end
		local take = ItemStack(fresh.item)
		take:set_count(wanted - removed)
		removed = removed + inv:remove_item(list, take):get_count()
	end
	-- removed == wanted: the count was taken over the same lists in this same
	-- callback. Should it ever fall short, pay only the whole lots taken and
	-- give the part-lot back, so no unit is lost and none is paid twice.
	local sold_lots = math.floor(removed / fresh.lot)
	local rest = removed - sold_lots * fresh.lot
	if rest > 0 then
		local back = ItemStack(fresh.item)
		back:set_count(rest)
		grug_inventory.give(player, back)
	end
	if sold_lots < 1 then
		show(player)
		return
	end
	total = sold_lots * fresh.copper
	grug_money.add(player, total)
	grug_sounds.play("vendor_sell", player)
	show(player, "Sold " .. sold_lots * fresh.lot .. " " .. short_desc(fresh.item) ..
		" for " .. grug_money.format(total) .. ". " ..
		(fresh.count - sold_lots * fresh.lot) .. " left.")
end

local function do_sell(player, session, index, key)
	local shown = session.rows and session.rows[index]
	if not shown then
		show(player)
		return
	end
	if shown.lot then
		do_sell_lots(player, shown, key)
		return
	end
	local inv = player:get_inventory()
	local stack = inv and inv:get_stack(shown.list, shown.index)
	-- Re-resolve the slot: the row index is a UI position, `shown.list` and
	-- `shown.index` the slot it pointed at when the form was drawn. The
	-- player may have moved the stack in another window in between.
	if not stack or stack:is_empty() or stack:get_name() ~= shown.item then
		show(player, "That item is no longer in that slot.")
		return
	end
	-- Price recomputed from the item, never read from the form.
	local unit = grug_traders.stack_sell_price(stack)
	if unit <= 0 then
		show(player, "The vendor does not want that.")
		return
	end
	-- The slot as shown: Stack carries the count it showed, and the price.
	if stack:get_count() ~= shown.count or unit ~= shown.unit then
		show(player, "Your items have changed.")
		return
	end
	local count = amount_of(quantities("sell", stack:get_stack_max(), stack:get_count()), key)
	if not count then
		show(player)
		return
	end
	-- The money ceiling is checked BEFORE anything is removed, against the
	-- full proceeds: grug_money.add clamps at MAX, so a sale that CROSSES the
	-- ceiling would take the items and silently pay only part of the price.
	-- Refuse the whole sale instead — never sell a partial stack behind the
	-- player's back either.
	if grug_money.get(player) + count * unit > grug_money.MAX then
		show(player, "You cannot carry that much money.")
		return
	end
	local taken = stack:take_item(count)
	local sold = taken:get_count()
	if sold < 1 then
		show(player)
		return
	end
	inv:set_stack(shown.list, shown.index, stack)
	-- sold == count today (count <= available); recomputed from what was
	-- actually taken so the credit can never exceed what the check cleared.
	local total = sold * unit
	grug_money.add(player, total)
	grug_sounds.play("vendor_sell", player)
	show(player, "Sold " .. sold .. "x " .. short_desc(shown.item) .. " for " ..
		grug_money.format(total) .. ".")
end

-- A Trade-in row's one lot or All (Round 58): the row is recomputed and
-- cross-checked against the one shown (item, count, lot, points), then
-- grug_guild trades the lots, taking the items only after its own checks.
local REFUSALS = {
	no_faction = "You belong to no guild.",
	not_exchanged = "The guild does not take that.",
	too_few = "Not enough for one lot.",
}
local function do_trade_in(player, session, item, key)
	local shown
	for _, row in ipairs(session.trade_rows or {}) do
		if row.item == item then
			shown = row
			break
		end
	end
	if not shown then
		show(player)
		return
	end
	local fresh
	for _, row in ipairs(grug_guild.trade_in_rows(player)) do
		if row.item == shown.item then
			fresh = row
			break
		end
	end
	if not fresh or fresh.count ~= shown.count or fresh.lot ~= shown.lot or
			fresh.points ~= shown.points then
		show(player, "Your items have changed.")
		return
	end
	local lots = amount_of(quantities("lot", fresh.lot, fresh.lots), key)
	if not lots then
		show(player)
		return
	end
	local points, err = grug_guild.trade_in(player, shown.item, lots)
	if not points then
		show(player, REFUSALS[err] or "The guild does not take that.")
		return
	end
	grug_sounds.play("vendor_sell", player)
	show(player, ("Traded %d %s for %s reputation. %d left."):format(lots * fresh.lot,
		short_desc(fresh.item), grug_guild.format_points(points), fresh.count - lots * fresh.lot))
end

-- A reputation page item (Round 58): only an item the page showed buyable;
-- grug_guild.buy checks the faction, the rank, the balance and the room
-- again and spends nothing on a refusal.
local REP_REFUSALS = {
	no_faction = "You belong to no guild.",
	unknown = "The guild does not sell that.",
	insufficient = "Not enough reputation.",
	full = "Your inventory is full.",
}
local function do_rep_buy(player, session, row, key)
	if not (session.rep_shown and session.rep_shown[row.item]) then
		show(player)
		return
	end
	local count = amount_of(quantities("buy", ItemStack(row.item):get_stack_max()), key)
	if not count then
		show(player)
		return
	end
	local ok, err = grug_guild.buy(player, row.item, count)
	if not ok then
		show(player, err == "rank" and ("Reach Reputation Rank %d first."):format(row.rank) or
			REP_REFUSALS[err] or "The guild does not sell that.")
		return
	end
	grug_sounds.play("vendor_buy", player)
	show(player, ("Bought %s%s for %s reputation."):format(count == 1 and "" or count .. "x ",
		short_desc(row.item), grug_guild.format_points(count * row.price)))
end

-- A row of the Stonewright's page (Round 70): the row is recomputed and
-- cross-checked against the one shown, then grug_guild makes the lots.
local STONE_REFUSALS = {
	no_faction = "You belong to no guild.",
	unknown = "The Stonewright does not make that.",
	too_few = "You do not carry enough for that.",
	money = "Not enough money.",
	full = "Your inventory is full.",
}
local function do_stonewright(player, session, index, key)
	local shown = session.stone_rows and session.stone_rows[index]
	if not shown or not shown.unlocked then
		show(player)
		return
	end
	local recipe = shown.recipe
	local fresh = grug_guild.stonewright_rows(player)[index]
	if not fresh or fresh.recipe ~= recipe or fresh.lots ~= shown.lots then
		show(player, "Your items have changed.")
		return
	end
	local lots = amount_of(quantities("lot", recipe.output_count, fresh.lots), key)
	if not lots then
		show(player)
		return
	end
	local made, fee = grug_guild.stonewright_make(player, recipe.id, lots)
	if not made then
		show(player, fee == "rank" and ("Reach Reputation Rank %d first."):format(recipe.rank) or
			STONE_REFUSALS[fee] or "The Stonewright does not make that.")
		return
	end
	grug_sounds.play("vendor_buy", player)
	show(player, ("Made %d %s for %s."):format(made, short_desc(recipe.output),
		grug_money.format(fee)))
end

-- Repair stays in this validated vendor session. The service still owns
-- its single-use quote and validates the authored socket on every repair.
local function do_repair(player, session, notice)
	local quote, reason = grug_repair.camp_vendor_quote(player, session.origin.settlement, session.origin.socket)
	if quote then
		repair_serial = repair_serial + 1
		session.repair_prefix = "quote_" .. repair_serial .. "_"
		session.mode, session.repair_quote, session.page = "repair", quote, 1
		session.offers_scroll = 0
	elseif session.mode == "repair" then
		close(player, reason)
		return
	end
	show(player, reason or notice)
end

--
-- Field dispatch
--

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME and formname:sub(1, #FORMNAME + 1) ~= FORMNAME .. ":" then
		return
	end
	local name = player:get_player_name()
	-- Only the form drawn last acts (see show): an older one's rows, amounts
	-- and tabs are not the session's any more. Its quit is dropped too: the
	-- newer form is the one open on the client.
	local current = sessions[name]
	if not current or formname ~= current.formname then
		return true
	end
	if fields.quit then
		sessions[name] = nil
		return true
	end
	local session, vendor = validate(player)
	if not session then
		return true
	end

	-- CHG arrives while scrolling; VAL accompanies a purchase. Remember both
	-- before dispatch, without resending for a scrollbar-only event.
	if session.mode == "buy" and type(fields.offers_scroll) == "string" then
		local kind, value = fields.offers_scroll:match("^(%u+):(%-?%d+)$")
		if kind == "CHG" or kind == "VAL" then
			session.offers_scroll = math.max(0, math.min(session.offers_scroll_max or 0,
				tonumber(value)))
		end
	end

	-- The Stonewright's page, in a fixed order, and nothing else there (a
	-- client may send any field anywhere).
	if stonewright(vendor) then
		for index in ipairs(grug_guild.catalog.STONEWRIGHT) do
			for _, key in ipairs(LOT_KEYS) do
				if fields["stone" .. key .. "_" .. index] then
					do_stonewright(player, session, index, key)
					return true
				end
			end
		end
		return true
	end

	if fields.mode_buy then
		if session.mode ~= "buy" then session.offers_scroll = 0 end
		session.mode = "buy"
		session.repair_quote = nil
		show(player)
		return true
	end
	if fields.mode_sell then
		if session.mode ~= "sell" then session.offers_scroll = 0 end
		session.mode = "sell"
		session.repair_quote = nil
		session.page = 1
		show(player)
		return true
	end
	if fields.sell_prev then
		session.page = math.max(1, session.page - 1)
		show(player)
		return true
	end
	if fields.sell_next then
		session.page = session.page + 1
		show(player)
		return true
	end
	if fields.repair and repairs(vendor, session) then
		do_repair(player, session)
		return true
	end
	-- The reputation page's items count only on that page.
	if guild_page(vendor) and session.mode == "buy" then
		for index, row in ipairs(grug_guild.catalog.CONSUMABLES) do
			for _, key in ipairs(BUY_KEYS) do
				if fields["repbuy" .. key .. "_" .. index] then
					do_rep_buy(player, session, row, key)
					return true
				end
			end
		end
	end
	-- The Trade-in fields count only at a guild vendor (a client may send
	-- any field anywhere).
	if guild_vendor(vendor) then
		if fields.mode_tradein then
			if session.mode ~= "tradein" then session.offers_scroll = 0 end
			session.mode = "tradein"
			session.repair_quote = nil
			session.page = 1
			show(player)
			return true
		end
		if fields.tradein_prev then
			session.page = math.max(1, session.page - 1)
			show(player)
			return true
		end
		if fields.tradein_next then
			session.page = session.page + 1
			show(player)
			return true
		end
		if session.mode == "tradein" then
			-- By catalogue index, in catalogue order.
			for index, rate in ipairs(grug_guild.catalog.EXCHANGE) do
				for _, key in ipairs(LOT_KEYS) do
					if fields["tradein" .. key .. "_" .. index] then
						do_trade_in(player, session, rate.item, key)
						return true
					end
				end
			end
		end
	end

	if session.mode == "repair" then
		local quote = session.repair_quote
		if not repairs(vendor, session) or not quote or not grug_repair.provider_permitted(player, quote.provider) then
			close(player, "The repair service is no longer available.")
			return true
		end
		local prefix = session.repair_prefix
		local selected, count = nil, fields[prefix .. "all"] and 1 or 0
		for i = 1, #quote.items do
			if fields[prefix .. "repair_" .. i] then selected, count = i, count + 1 end
		end
		if count > 1 then return true end
		if count == 1 then
			local requested = selected and grug_repair.single_quote(quote, selected) or quote
			local _, reason = grug_repair.apply(player, requested)
			session.repair_quote = nil
			do_repair(player, session, reason)
			core.chat_send_player(name, reason)
		elseif fields.next or fields.previous then
			session.page = session.page + (fields.next and 1 or -1)
			show(player)
		end
		return true
	end

	-- The remaining actions carry an index in the field NAME. They are tested
	-- against `fields` in a FIXED, written-down order — never by iterating the
	-- table: a client may submit two action fields in one packet, and `pairs`
	-- would then pick the winner by hash order, which differs between LuaJIT
	-- and the bundled PUC Lua 5.1.5 (this game must behave identically on
	-- both, AGENTS.md). Every branch below re-validates from scratch and
	-- performs exactly one action, so this is about specified behaviour, not
	-- about a hole. The candidate names are bounded by what was actually
	-- rendered: tabs the player has unlocked, the offer snapshot, the sell
	-- rows. Anything outside those ranges could not pass do_buy/do_sell's
	-- snapshot cross-check anyway and is ignored.
	if fields.tab_general then
		if session.tab ~= "general" then session.offers_scroll = 0 end
		session.tab = "general"
		show(player)
		return true
	end
	local max_bracket = grug_traders.max_bracket()
	for b = 1, max_bracket do
		if fields["tab_" .. b] then
			if session.tab ~= tostring(b) then session.offers_scroll = 0 end
			session.tab = tostring(b)
			show(player)
			return true
		end
	end
	for i = 1, (session.mode == "buy" and session.offer and #session.offer or 0) do
		for _, key in ipairs(BUY_KEYS) do
			if fields["buy" .. key .. "_" .. i] then
				do_buy(player, session, vendor, i, key)
				return true
			end
		end
	end
	local row_count = session.mode == "sell" and session.rows and #session.rows or 0
	for _, key in ipairs(SELL_KEYS) do
		for i = 1, row_count do
			if fields["sell" .. key .. "_" .. i] then
				do_sell(player, session, i, key)
				return true
			end
		end
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)
