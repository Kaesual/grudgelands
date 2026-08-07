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
--   3. the player still passes the vendor's faction/race access rule
--      (a faction/race can be changed by an admin while the form is open);
--   4. prices, item names and counts are recomputed SERVER-SIDE. The field
--      name carries an index and nothing else; that index is re-resolved
--      against a freshly computed offer/row list and cross-checked against the
--      snapshot the player was actually shown. A mismatch (the hourly rotation
--      flipped, the stack moved) aborts the action and re-renders.

local FORMNAME = "grug_traders:trade"

local TRADE_RANGE = 6 -- m; the form closes beyond this
local GRID_COLS = 6
local SELL_ROWS = 8 -- rows per page

local FORM_W, FORM_H = 14, 10.2
local UNCOMMON_COLOR = "#4A90FF"

-- player name -> {vendor, pos, mode, tab, page, offer, rows}
local sessions = {}

local function esc(text)
	return core.formspec_escape(text)
end

-- First line of an item description, for one-line labels.
local function short_desc(itemname)
	local def = core.registered_items[itemname]
	local desc = (def and def.description) or itemname
	return (desc:gsub("\n.*", ""))
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
local function current_offer(player, session, vendor, discount)
	local offer = {}
	if session.tab == "general" then
		for _, entry in ipairs(grug_traders.stock) do
			offer[#offer + 1] = {
				item = entry.item,
				base = entry.price,
				price = grug_traders.apply_discount(entry.price, discount),
			}
		end
		return offer
	end
	local bracket = tonumber(session.tab)
	if not bracket or bracket < 1 or bracket > grug_traders.max_bracket(player) then
		return offer
	end
	for _, entry in ipairs(grug_traders.bracket_stock(vendor.salt, bracket)) do
		offer[#offer + 1] = {
			item = entry.item,
			base = entry.price,
			price = grug_traders.apply_discount(entry.price, discount),
			ilvl = entry.ilvl,
			uncommon = entry.uncommon,
		}
	end
	return offer
end

-- Every stack in the player's main list the vendor would buy.
local function current_rows(player)
	local rows = {}
	local inv = player:get_inventory()
	if not inv then
		return rows
	end
	local size = inv:get_size("main")
	for i = 1, size do
		local stack = inv:get_stack("main", i)
		if not stack:is_empty() then
			local unit = grug_traders.sell_price(stack:get_name())
			if unit > 0 then
				rows[#rows + 1] = {
					index = i,
					item = stack:get_name(),
					count = stack:get_count(),
					unit = unit,
				}
			end
		end
	end
	return rows
end

--
-- Rendering
--

local function header(parts, player, session, vendor, discount)
	parts[#parts + 1] = "label[0.5,0.6;" .. esc(vendor.nametag) .. "]"
	parts[#parts + 1] = "label[0.5,1.2;Your money: " ..
		esc(grug_money.format(grug_money.get(player))) .. "]"
	if discount then
		local pct = math.floor(grug_traders.RACE_DISCOUNT * 100 + 0.5)
		parts[#parts + 1] = "label[5.0,1.2;" .. esc(core.colorize("#7ee081",
			"Kinship discount: -" .. pct .. "% on every purchase")) .. "]"
	end
	local buy_style = session.mode == "buy" and "#4a7fc0" or "#3a3a3a"
	local sell_style = session.mode == "sell" and "#4a7fc0" or "#3a3a3a"
	parts[#parts + 1] = "style[mode_buy;bgcolor=" .. buy_style .. "]"
	parts[#parts + 1] = "style[mode_sell;bgcolor=" .. sell_style .. "]"
	parts[#parts + 1] = "button[10.3,0.3;1.6,0.8;mode_buy;Buy]"
	parts[#parts + 1] = "button[12.0,0.3;1.5,0.8;mode_sell;Sell]"
end

local function render_buy(parts, player, session, vendor, discount)
	-- Tab row: the level-independent core stock plus every bracket the player
	-- has unlocked (items_crafting.md §3.8: own bracket and every one below).
	local max_bracket = grug_traders.max_bracket(player)
	local tabs = {{id = "general", label = "General"}}
	for b = 1, max_bracket do
		tabs[#tabs + 1] = {id = tostring(b), label = grug_traders.bracket_label(b)}
	end
	for i, tab in ipairs(tabs) do
		local x = 0.5 + (i - 1) * 1.75
		local color = (session.tab == tab.id) and "#4a7fc0" or "#3a3a3a"
		parts[#parts + 1] = "style[tab_" .. tab.id .. ";bgcolor=" .. color .. "]"
		parts[#parts + 1] = ("button[%.2f,1.9;1.65,0.7;tab_%s;%s]"):format(
			x, tab.id, esc(tab.label))
	end

	local offer = current_offer(player, session, vendor, discount)
	session.offer = offer
	for i, entry in ipairs(offer) do
		local col = (i - 1) % GRID_COLS
		local row = math.floor((i - 1) / GRID_COLS)
		local x = 0.6 + col * 2.2
		local y = 2.9 + row * 2.5
		parts[#parts + 1] = ("item_image_button[%.2f,%.2f;1.6,1.6;%s;buy_%d;]")
			:format(x, y, entry.item, i)
		local price_text = grug_money.format(entry.price)
		local tip = full_desc(entry.item) .. "\nPrice: " .. price_text
		if entry.uncommon then
			price_text = core.colorize(UNCOMMON_COLOR, price_text .. " *")
			tip = tip .. "\nUncommon - the vendor's find of the hour"
		end
		if entry.base ~= entry.price then
			tip = tip .. "\n(normally " .. grug_money.format(entry.base) .. ")"
		end
		parts[#parts + 1] = ("label[%.2f,%.2f;%s]"):format(x, y + 1.85, esc(price_text))
		parts[#parts + 1] = ("tooltip[buy_%d;%s]"):format(i, esc(tip))
	end
	if #offer == 0 then
		parts[#parts + 1] = "label[0.6,3.0;The vendor has nothing on this shelf.]"
	end
	-- Required form height. Today every bracket shelf is 11 entries (9 fixed
	-- + 2 rotating) = 2 rows and stays below FORM_H, but WP10's job supplies
	-- extend the General tab and a third row must grow the window instead of
	-- falling out of it.
	local grid_rows = math.ceil(#offer / GRID_COLS)
	return 2.9 + grid_rows * 2.5 + 1.2
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
	parts[#parts + 1] = "label[0.6,2.0;" .. esc("The vendor buys every drop " ..
		"you carry. One click sells; there is no confirmation.") .. "]"
	for offset = 0, SELL_ROWS - 1 do
		local i = first + offset
		local row = rows[i]
		if row then
			local y = 2.5 + offset * 0.8
			parts[#parts + 1] = ("item_image[0.7,%.2f;0.7,0.7;%s]"):format(y, row.item)
			parts[#parts + 1] = ("label[1.7,%.2f;%s]"):format(y + 0.35,
				esc(short_desc(row.item) .. " x" .. row.count))
			parts[#parts + 1] = ("label[7.4,%.2f;%s each]"):format(y + 0.35,
				esc(grug_money.format(row.unit)))
			parts[#parts + 1] = ("button[10.0,%.2f;1.3,0.7;sell1_%d;1]"):format(y, i)
			parts[#parts + 1] = ("button[11.5,%.2f;2.0,0.7;sellall_%d;All (%s)]")
				:format(y, i, esc(grug_money.format(row.count * row.unit)))
		end
	end
	if #rows == 0 then
		parts[#parts + 1] = "label[0.7,3.0;You carry nothing this vendor wants.]"
	end
	parts[#parts + 1] = "button[0.7,8.8;1.2,0.7;sell_prev;<]"
	parts[#parts + 1] = ("label[2.2,9.15;Page %d / %d]"):format(session.page, pages)
	parts[#parts + 1] = "button[4.2,8.8;1.2,0.7;sell_next;>]"
end

local function build(player, session, vendor, status)
	-- The body is rendered FIRST because the buy grid decides the window
	-- height; size[] is prepended afterwards.
	local body = {}
	-- Once per render, for the header label AND every offer row (see
	-- current_offer).
	local discount = grug_traders.has_discount(player, vendor)
	header(body, player, session, vendor, discount)
	local needed
	if session.mode == "sell" then
		render_sell(body, player, session)
	else
		needed = render_buy(body, player, session, vendor, discount)
	end
	local height = math.max(FORM_H, needed or 0)
	if status and status ~= "" then
		body[#body + 1] = ("label[0.5,%.2f;%s]"):format(height - 0.5, esc(status))
	end
	return "formspec_version[4]" ..
		("size[%.2f,%.2f]"):format(FORM_W, height) ..
		"real_coordinates[true]" ..
		table.concat(body)
end

-- Re-render (never close) after a transaction, so the player sees the new
-- balance and the new stock immediately.
local function show(player, status)
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then
		return
	end
	local vendor = grug_traders.get_vendor(session.vendor)
	if not vendor then
		sessions[name] = nil
		core.close_formspec(name, FORMNAME)
		return
	end
	core.show_formspec(name, FORMNAME, build(player, session, vendor, status))
end

local function close(player, message)
	local name = player:get_player_name()
	sessions[name] = nil
	core.close_formspec(name, FORMNAME)
	if message then
		core.chat_send_player(name, message)
	end
end

--
-- Entry point (called from the vendor entity's on_rightclick)
--

function grug_traders.open(clicker, vendor_name, pos)
	if not clicker or not clicker:is_player() or not pos then
		return
	end
	local vendor = grug_traders.get_vendor(vendor_name)
	local ok, message = grug_traders.can_trade(clicker, vendor)
	if not ok then
		core.chat_send_player(clicker:get_player_name(), message)
		return
	end
	sessions[clicker:get_player_name()] = {
		vendor = vendor_name,
		-- A POSITION, never the ObjectRef: the entity may be unloaded or
		-- replaced between two field submissions (AGENTS.md).
		pos = {x = pos.x, y = pos.y, z = pos.z},
		mode = "buy",
		tab = "general",
		page = 1,
	}
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
	local ok, message = grug_traders.can_trade(player, vendor)
	if not ok then
		close(player, message)
		return nil
	end
	-- A stale bracket tab (an unknown id, or one above the player's level)
	-- falls back to the always-available core stock.
	if session.tab ~= "general" then
		local bracket = tonumber(session.tab)
		if not bracket or bracket < 1 or
				bracket > grug_traders.max_bracket(player) then
			session.tab = "general"
		end
	end
	return session, vendor
end

--
-- Transactions
--

local function do_buy(player, session, vendor, index)
	-- Point 4: recompute the offer from the catalog and cross-check the index
	-- against the snapshot the player was shown. The hourly rotation can flip
	-- between the render and the click; buying "slot 11" must never silently
	-- become a different, more expensive item.
	local offer = current_offer(player, session, vendor,
		grug_traders.has_discount(player, vendor))
	local entry = offer[index]
	local shown = session.offer and session.offer[index]
	if not entry or not shown or entry.item ~= shown.item or
			entry.price ~= shown.price or
			(entry.uncommon or false) ~= (shown.uncommon or false) then
		show(player, "The vendor's stock has changed.")
		return
	end

	-- grug_money.take is atomic: on an insufficient balance nothing at all
	-- changes (grug_money/init.lua:122).
	if not grug_money.take(player, entry.price) then
		show(player, "Not enough money.")
		return
	end
	local stack = grug_traders.make_stack(entry)
	local inv = player:get_inventory()
	if not inv or not inv:room_for_item("main", stack) then
		-- Exact refund of exactly what was taken. Items are NEVER dropped on
		-- the ground as a fallback: a full bag next to a busy vendor would
		-- turn a purchase into a giveaway.
		grug_money.add(player, entry.price)
		show(player, "Your inventory is full.")
		return
	end
	inv:add_item("main", stack)
	show(player, "Bought " .. short_desc(entry.item) .. " for " ..
		grug_money.format(entry.price) .. ".")
end

local function do_sell(player, session, index, sell_all)
	local shown = session.rows and session.rows[index]
	if not shown then
		show(player)
		return
	end
	local inv = player:get_inventory()
	local stack = inv and inv:get_stack("main", shown.index)
	-- Re-resolve the slot: the row index is a UI position, `shown.index` the
	-- main-list slot it pointed at when the form was drawn. The player may
	-- have moved the stack in another window in between.
	if not stack or stack:is_empty() or stack:get_name() ~= shown.item then
		show(player, "That item is no longer in that slot.")
		return
	end
	-- Price recomputed from the item, never read from the form.
	local unit = grug_traders.sell_price(stack:get_name())
	if unit <= 0 then
		show(player, "The vendor does not want that.")
		return
	end
	local available = stack:get_count()
	local count = sell_all and available or 1
	if count > available then
		count = available
	end
	if count < 1 then
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
	inv:set_stack("main", shown.index, stack)
	-- sold == count today (count <= available); recomputed from what was
	-- actually taken so the credit can never exceed what the check cleared.
	local total = sold * unit
	grug_money.add(player, total)
	show(player, "Sold " .. sold .. "x " .. short_desc(shown.item) .. " for " ..
		grug_money.format(total) .. ".")
end

--
-- Field dispatch
--

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	if fields.quit then
		sessions[name] = nil
		return true
	end
	local session, vendor = validate(player)
	if not session then
		return true
	end

	if fields.mode_buy then
		session.mode = "buy"
		show(player)
		return true
	end
	if fields.mode_sell then
		session.mode = "sell"
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
		session.tab = "general"
		show(player)
		return true
	end
	local max_bracket = grug_traders.max_bracket(player)
	for b = 1, max_bracket do
		if fields["tab_" .. b] then
			session.tab = tostring(b)
			show(player)
			return true
		end
	end
	for i = 1, (session.offer and #session.offer or 0) do
		if fields["buy_" .. i] then
			do_buy(player, session, vendor, i)
			return true
		end
	end
	local row_count = session.rows and #session.rows or 0
	for i = 1, row_count do
		if fields["sell1_" .. i] then
			do_sell(player, session, i, false)
			return true
		end
	end
	for i = 1, row_count do
		if fields["sellall_" .. i] then
			do_sell(player, session, i, true)
			return true
		end
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)
