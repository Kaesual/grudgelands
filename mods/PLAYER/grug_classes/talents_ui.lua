-- The sfinv Talents & Skills page owns every player-facing talent mutation.
-- The chat command is deliberately read-only; rank purchases and full resets
-- always act on the PlayerRef that submitted this page's fixed button fields.
-- Since Round 53 the page draws the class's graph trees, one tab each,
-- through graph.page_content (talent_graph_ui.lua) and, under them, the
-- skill catalog row grug_skills installs.

local PAGE_NAME = "grug_classes:talents"
local META_RESPEC_USED = "grug_classes:respec_used"

-- Respec copper price per level bracket (1-10 ... 51-60): five minutes of
-- reliable net solo income (economy.md section 4), derived and checked by
-- tools/r29_e4/income.py (economy plan, E4). The first respec is free.
grug_classes.RESPEC_PRICES = {15, 35, 75, 200, 550, 1200}

local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

local function level_bracket(player)
	local level = grug_xp.get_level(player)
	return math.max(1, math.min(6, math.ceil(level / 10)))
end

function grug_classes.respec_price(player)
	if player:get_meta():get_int(META_RESPEC_USED) == 0 then
		return 0
	end
	return grug_classes.RESPEC_PRICES[level_bracket(player)]
end

-- Returns true, points returned, copper charged; or false plus a refusal.
-- The withdrawal happens before the deterministic full reset, so insufficient
-- funds can never alter the build. No player name or target comes from fields.
function grug_classes.buy_respec(player)
	local spent = grug_classes.talent_points_spent(player)
	if spent <= 0 then
		return false, "No talent ranks are spent."
	end
	local price = grug_classes.respec_price(player)
	if price > 0 and not grug_money.take(player, price) then
		return false, "You need " .. grug_money.format(price) .. " to respec."
	end
	player:get_meta():set_int(META_RESPEC_USED, 1)
	local returned = grug_classes.respec(player)
	return true, returned, price
end

-- Node looks: buyable (green, as before), maxed, ranked but not buyable,
-- locked; the selected node gets the shared gold selection.
local NODE_STYLES = {
	buyable = "bgcolor=#526f3f;bgcolor_hovered=#688d50;bgcolor_pressed=#3e552f;border=false;bgimg=grug_ui_button.png;bgimg_middle=2",
	maxed = "bgcolor=#5c4a2a;bgcolor_hovered=#6f5a33;bgcolor_pressed=#4a3b22;border=false;bgimg=grug_ui_button.png;bgimg_middle=2",
	ranked = "bgcolor=#4a4a4a;bgcolor_hovered=#575757;bgcolor_pressed=#3a3a3a;border=false;bgimg=grug_ui_button.png;bgimg_middle=2",
	locked = "bgcolor=#2e2e2e;bgcolor_hovered=#3a3a3a;bgcolor_pressed=#262626;" ..
		"border=false;bgimg=grug_ui_button.png;bgimg_middle=2;textcolor=#9a9a9a",
}
local CONNECTOR_MET, CONNECTOR_OPEN = "#c9a65a", "#5a5a5a"
-- The new graph page (talent_graph_ui.lua) draws its nodes and lines alike.
grug_classes.TALENT_NODE_STYLES = NODE_STYLES
grug_classes.TALENT_CONNECTOR_COLORS = {met = CONNECTOR_MET, open = CONNECTOR_OPEN}

-- The page's player-facing texts.
local HINT = "Click an available talent to buy one rank."
local BUY_TEXT = "Click to buy the next rank."

-- The class's graph trees, or none without a class.
local function trees_for_player(player)
	local class_id = grug_classes.get_class(player)
	return class_id and grug_classes.graph.trees_of_class(class_id) or {}
end

-- The respec control in the header row, right of the points.
local function respec_header(player, context)
	if grug_classes.talent_points_spent(player) <= 0 then
		return "label[0.50,5.35;" .. esc("No ranks spent") .. "]"
	elseif context.grug_talent_respec_pending then
		return "button[0.50,5.05;2.0,0.60;grug_talent_respec_confirm;Confirm]" ..
			"button[2.65,5.05;2.0,0.60;grug_talent_respec_cancel;Cancel]"
	end
	local price = grug_classes.respec_price(player)
	local price_text = price == 0 and "Free" or grug_money.format(price)
	return "button[0.50,5.05;4.1,0.60;grug_talent_respec;" ..
		esc("Respec: " .. price_text) .. "]"
end

local function talent_content(player, context)
	local trees = trees_for_player(player)
	if #trees == 0 then
		-- The focus sink as on the graph page (0.45.1): no visible button.
		return "real_coordinates[true]" ..
			"set_focus[grug_graph_focus;true]button[0,0;0,0;grug_graph_focus;]" ..
			"label[0.25,0.45;" .. esc("Choose a class before spending talent points.") .. "]"
	end
	local tab = math.max(1, math.min(#trees, tonumber(context.grug_talent_tab) or 1))
	local selected = context.grug_talent_selected
	local def = selected and grug_classes.graph.nodes[selected]
	return grug_classes.graph.page_content(player, {
		trees = trees, tab = tab, ranks = grug_classes.talent_ranks(player),
		budget = grug_classes.talent_points_total(player),
		selected = def and def.class == grug_classes.get_class(player) and selected or nil,
		notice = context.grug_talent_notice, hint = HINT, buy_text = BUY_TEXT,
		points_text = ("Points: %d / %d"):format(
			grug_classes.talent_points_available(player),
			grug_classes.talent_points_total(player)),
		header = respec_header(player, context),
	})
end

grug_classes.talent_formspec_content = talent_content

-- The skill catalog row under the tree (spec §3.4, Round 44 plan ruling 4):
-- grug_skills, which depends on this mod, installs a function(player, y,
-- context) that returns its formspec part in real coordinates from y down
-- (its box with the hint beside the label, CATALOG_H high: the slot row and,
-- since Round 52 C13, its horizontal scrollbar below it); without it the
-- page ends with the tree and its text. The row ends a gap above the short
-- inventory view's box (grug_inventory.VIEW_GEOMETRY.top, read at build
-- time: this mod does not depend on grug_inventory).
grug_classes.skill_catalog_row = nil
local CATALOG_H = 1.8

local function refresh_open_page(player)
	if sfinv.get_page(player) == PAGE_NAME then
		sfinv.set_page(player, PAGE_NAME)
	end
end

local function receive_fields(player, context, fields)
	if sfinv.get_page(player) ~= PAGE_NAME then
		return false
	end
	if fields.grug_talent_respec then
		if grug_classes.talent_points_spent(player) > 0 then
			context.grug_talent_respec_pending = true
			context.grug_talent_notice = "Reset every talent rank? This cannot be undone."
		end
		refresh_open_page(player)
		return true
	end
	if fields.grug_talent_respec_cancel then
		context.grug_talent_respec_pending = nil
		context.grug_talent_notice = "Respec cancelled."
		refresh_open_page(player)
		return true
	end
	if fields.grug_talent_respec_confirm then
		if not context.grug_talent_respec_pending then
			return true
		end
		context.grug_talent_respec_pending = nil
		local expected_points = grug_classes.talent_points_spent(player)
		local expected_price = grug_classes.respec_price(player)
		context.grug_talent_notice = ("Talents reset: %d points returned, %s charged.")
			:format(expected_points, expected_price == 0 and "nothing"
				or grug_money.format(expected_price))
		local ok, returned_or_reason = grug_classes.buy_respec(player)
		if not ok then
			context.grug_talent_notice = returned_or_reason
			refresh_open_page(player)
		end
		-- On success respec() fired the talents-changed refresh after the final
		-- notice was set. The returned values are deliberately not trusted for a
		-- second render; the model is deterministic from the values above.
		return true
	end

	local trees = trees_for_player(player)
	for index in ipairs(trees) do
		if fields["grug_graph_tab_" .. index] then
			context.grug_talent_tab = index
			context.grug_talent_selected, context.grug_talent_notice = nil, nil
			refresh_open_page(player)
			return true
		end
	end
	-- Only the nodes of the class's own two trees answer; the graph's rules
	-- decide whether a rank may be bought.
	for _, tree in ipairs(trees) do
		for _, def in ipairs(tree.nodes) do
			if fields[grug_classes.graph.node_field(def.id)] then
				context.grug_talent_notice = nil
				context.grug_talent_selected = def.id
				-- A refused click selects the node: the strip under the tree
				-- then shows its text and the reason.
				if not grug_classes.spend_talent(player, def.id) then
					refresh_open_page(player)
				end
				return true
			end
		end
	end
	return false
end

-- One tab for the talent tree and the skill catalog (spec ruling 1), with the
-- short inventory below, so tools and food can leave the hotbar for skills.
sfinv.register_page(PAGE_NAME, {
	title = "Talents & Skills",
	get = function(self, player, context)
		local catalog = grug_classes.skill_catalog_row
		local catalog_y = grug_inventory.VIEW_GEOMETRY.top - 0.1 - CATALOG_H
		return sfinv.make_formspec(player, context,
			talent_content(player, context) ..
				(catalog and catalog(player, catalog_y, context) or ""),
			"short")
	end,
	on_player_receive_fields = function(self, player, context, fields)
		return receive_fields(player, context, fields)
	end,
})

grug_classes.register_on_talents_changed(refresh_open_page)
grug_xp.register_on_level_change(function(player, old_level, new_level)
	if old_level ~= nil then
		refresh_open_page(player)
	end
end)
