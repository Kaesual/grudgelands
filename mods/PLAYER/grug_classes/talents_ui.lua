-- The sfinv Talents & Skills page owns every player-facing talent mutation.
-- The chat command is deliberately read-only; rank purchases and full resets
-- always act on the PlayerRef that submitted this page's fixed button fields.
-- The page draws the class's talent trees through the tree framework below
-- and, under them, the skill catalog row grug_skills installs.

local PAGE_NAME = "grug_classes:talents"
local META_RESPEC_USED = "grug_classes:respec_used"

-- Respec copper price per level bracket (1-10 ... 51-60): five minutes of
-- reliable net solo income (economy.md section 4), derived and checked by
-- tools/r29_e4/income.py (economy plan, E4). The first respec is free.
grug_classes.RESPEC_PRICES = {15, 35, 75, 200, 525, 1200}

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

local function talent_mark(def)
	if def.capstone then
		return " **"
	elseif def.keystone then
		return " *"
	end
	return ""
end

local function trees_for_player(player)
	return grug_classes.trees_of_class(grug_classes.get_class(player))
end

local function level_number(value)
	if value >= 10 then
		return tostring(math.floor(value + 0.5))
	end
	return (string.format("%.1f", value):gsub("%.0$", ""))
end

-- Level-proof talents (Round 35) state a percentage of a base hit or of the
-- armor constant; the tooltip adds every rank's amount at the viewer's level
-- through the same talent_level_amount the consumers read. Damage is shown as
-- dealt after the level scalar (before crit and the target-level malus), so a
-- base hit reads as one eighth of the base pool.
local function level_scaled_text(player, def)
	for effect_key, values in pairs(def.effects) do
		local unit = grug_classes.TALENT_LEVEL_SCALED_KEYS[effect_key]
		if unit then
			local level = grug_xp.get_level(player)
			local factor = unit == "damage" and grug_core.level_scale(level) or 1
			local ranks = {}
			for _, value in ipairs(values) do
				ranks[#ranks + 1] = "+" .. level_number(factor *
					grug_classes.talent_level_amount(player, effect_key, value))
			end
			if unit == "damage" then
				return (" At your level a base hit is %d damage: %s damage."):format(
					math.floor(grug_core.base_pool(level) / 8),
					table.concat(ranks, " / "))
			end
			return " At your level: " .. table.concat(ranks, " / ") ..
				" armor rating."
		end
	end
	return ""
end

-- Pool talents keep their compact rule text but append every rank's concrete
-- value for the viewer's current level. The conversion is shared with future
-- consumers such as Hold Ground, so UI and settlement cannot invent separate
-- rounding or class-factor rules.
function grug_classes.talent_description_for(player, def)
	local effect_key = grug_classes.pool_talent_effect_key(def)
	if not effect_key then
		return def.description .. level_scaled_text(player, def)
	end
	local values = def.effects[effect_key]
	local unit = effect_key == "max_mana_percent_add" and "mana"
		or effect_key == "hold_ground_absorb" and "absorb" or "HP"
	local ranks = {}
	for _, percent in ipairs(values) do
		ranks[#ranks + 1] = string.format("%g%% = %d %s", percent,
			grug_classes.pool_talent_amount(player, effect_key, percent), unit)
	end
	return def.description .. " At your level: " .. table.concat(ranks, "; ") .. "."
end

local function selected_description(player, context)
	local def = context.grug_talent_selected
		and grug_classes.registered_talents[context.grug_talent_selected]
	if not def or def.class ~= grug_classes.get_class(player) then
		return context.grug_talent_notice
			or "Click an available talent to buy one rank."
	end
	local rank = grug_classes.talent_rank(player, def.id)
	local status
	if rank >= def.ranks then
		status = "Maximum rank reached."
	else
		local ok, reason = grug_classes.can_spend_talent(player, def.id)
		status = ok and "Click to buy the next rank." or reason
	end
	return ("%s%s — rank %d/%d: %s  %s"):format(def.name,
		talent_mark(def), rank, def.ranks,
		grug_classes.talent_description_for(player, def), status)
end

--
-- The tree framework (Round 44, spec ui-crafting-rework-plan.md ruling 7 and
-- §3.4). A tree is a list of sections {id, columns = {labels}} (the column
-- labels are optional) and a list of nodes {id, section, row, col, requires =
-- {node ids}}. layout_tree puts the sections side by
-- side in `area`, each node at its row and column inside its section, and
-- routes one connector per requirement, orthogonally: down from the parent's
-- bottom, across in the gap above the child's row, down into the child's top
-- (one straight segment when both share a column). A node may have any number
-- of parents and children; the page draws every connector box before the
-- nodes, so the lines run under them. Positions are real coordinates; each
-- section's layout lists its columns' left edges for their labels.
--
grug_classes.TALENT_TREE_AREA = {x = 0.25, y = 1.85, w = 13.0, section_gap = 0.3,
	pad = 0.15, col_gap = 0.25, node_h = 0.8, row_gap = 0.3, line = 0.08}

function grug_classes.layout_tree(sections, nodes, area)
	area = area or grug_classes.TALENT_TREE_AREA
	local cols, rows = {}, 0
	for _, node in ipairs(nodes) do
		cols[node.section] = math.max(cols[node.section] or 1, node.col)
		rows = math.max(rows, node.row)
	end
	local pitch = area.node_h + area.row_gap
	local height = rows * pitch - area.row_gap
	local section_w = (area.w - (#sections - 1) * area.section_gap) / #sections
	local layout = {sections = {}, nodes = {}, connectors = {}, bottom = area.y + height}
	for index, section in ipairs(sections) do
		local count = math.max(cols[section.id] or 1, #(section.columns or {}))
		local rect = {
			x = area.x + (index - 1) * (section_w + area.section_gap), y = area.y,
			w = section_w, h = height, columns = {},
			node_w = (section_w - 2 * area.pad - (count - 1) * area.col_gap) / count,
		}
		for col = 1, count do
			rect.columns[col] = rect.x + area.pad + (col - 1) * (rect.node_w + area.col_gap)
		end
		layout.sections[section.id] = rect
	end
	for _, node in ipairs(nodes) do
		local section = layout.sections[node.section]
		layout.nodes[node.id] = {
			x = section.columns[node.col],
			y = area.y + (node.row - 1) * pitch, w = section.node_w, h = area.node_h,
		}
	end
	local t = area.line
	for _, node in ipairs(nodes) do
		local child = layout.nodes[node.id]
		for _, parent_id in ipairs(node.requires or {}) do
			local parent = layout.nodes[parent_id]
			local px, py = parent.x + parent.w / 2, parent.y + parent.h
			local cx, cy = child.x + child.w / 2, child.y
			local segments
			if math.abs(px - cx) < 1e-9 then
				segments = {{x = px - t / 2, y = py, w = t, h = cy - py}}
			else
				local mid = cy - area.row_gap / 2
				segments = {
					{x = px - t / 2, y = py, w = t, h = mid - py + t / 2},
					{x = math.min(px, cx) - t / 2, y = mid - t / 2,
						w = math.abs(cx - px) + t, h = t},
					{x = cx - t / 2, y = mid - t / 2, w = t, h = cy - mid + t / 2},
				}
			end
			layout.connectors[#layout.connectors + 1] = {from = parent_id,
				to = node.id, segments = segments}
		end
	end
	return layout
end

-- Today's talent data as framework data: one section per tree of the class,
-- each chain a column (labelled with the chain's name), each tier a row, the
-- talent above in the same chain (the hard chain) the one requirement.
function grug_classes.talent_tree_data(trees)
	local sections, nodes = {}, {}
	for _, tree in ipairs(trees) do
		local columns = {}
		for index, chain in ipairs(tree.chains) do
			columns[index] = chain:sub(1, 1):upper() .. chain:sub(2)
		end
		sections[#sections + 1] = {id = tree.id, tree = tree, columns = columns}
		for _, def in ipairs(tree.talents) do
			local col = 1
			for index, chain in ipairs(tree.chains) do
				if chain == def.chain then col = index end
			end
			nodes[#nodes + 1] = {id = def.id, section = tree.id, row = def.tier,
				col = col, requires = def.above and {def.above.id} or {}}
		end
	end
	return sections, nodes
end

-- Node looks: buyable (green, as before), maxed, ranked but not buyable,
-- locked; the selected node gets the shared gold selection.
local NODE_STYLES = {
	buyable = "bgcolor=#526f3f;bgcolor_hovered=#688d50;bgcolor_pressed=#3e552f;border=true",
	maxed = "bgcolor=#5c4a2a;bgcolor_hovered=#6f5a33;bgcolor_pressed=#4a3b22;border=true",
	ranked = "bgcolor=#4a4a4a;bgcolor_hovered=#575757;bgcolor_pressed=#3a3a3a;border=true",
	locked = "bgcolor=#2e2e2e;bgcolor_hovered=#3a3a3a;bgcolor_pressed=#262626;" ..
		"border=false;textcolor=#9a9a9a",
}
local CONNECTOR_MET, CONNECTOR_OPEN = "#c9a65a", "#5a5a5a"

-- Button field index per talent id (registration order, fixed after load).
local field_index
local function talent_field(id)
	if not field_index then
		field_index = {}
		for index, talent_id in ipairs(grug_classes.talent_ids) do
			field_index[talent_id] = index
		end
	end
	return "grug_talent_pick_" .. field_index[id]
end

-- One node: its state (the key of NODE_STYLES, or "selected"), the button and
-- its tooltip. The page sends one style[] per state for all its nodes.
local function node_formspec(player, context, def, rect)
	local field = talent_field(def.id)
	local rank = grug_classes.talent_rank(player, def.id)
	local available, reason = grug_classes.can_spend_talent(player, def.id)
	local state = context.grug_talent_selected == def.id and "selected"
		or available and "buyable" or rank >= def.ranks and "maxed"
		or rank > 0 and "ranked" or "locked"
	local tooltip = def.name .. " — " ..
		grug_classes.talent_description_for(player, def)
	if not available and rank < def.ranks then
		tooltip = tooltip .. " Locked: " .. reason
	end
	return state, field, table.concat({
		("image_button[%.2f,%.2f;%.2f,%.2f;blank.png;%s;%s]"):format(rect.x,
			rect.y, rect.w, rect.h, field, esc(("%s%s\n%d/%d"):format(def.name,
			talent_mark(def), rank, def.ranks))),
		("tooltip[%s;%s]"):format(field, esc(grug_inventory.wrap_text(tooltip, 58))),
	})
end

local function talent_content(player, context)
	local class_id = grug_classes.get_class(player)
	local class_def = class_id and grug_classes.registered_classes[class_id]
	local trees = trees_for_player(player)
	local fs = {
		"real_coordinates[true]",
		("label[0.25,0.45;%s]"):format(esc((class_def and class_def.name or "No class") ..
			" talents")),
		("label[3.60,0.45;%s]"):format(esc(("Talent points available: %d of %d")
			:format(grug_classes.talent_points_available(player),
				grug_classes.talent_points_total(player)))),
	}

	local spent = grug_classes.talent_points_spent(player)
	if spent <= 0 then
		fs[#fs + 1] = "label[9.90,0.45;" .. esc("No ranks spent") .. "]"
	elseif context.grug_talent_respec_pending then
		fs[#fs + 1] = "button[9.90,0.15;1.60,0.60;grug_talent_respec_confirm;Confirm]"
		fs[#fs + 1] = "button[11.60,0.15;1.65,0.60;grug_talent_respec_cancel;Cancel]"
	else
		local price = grug_classes.respec_price(player)
		local price_text = price == 0 and "Free" or grug_money.format(price)
		fs[#fs + 1] = "button[9.90,0.15;3.35,0.60;grug_talent_respec;" ..
			esc("Respec: " .. price_text) .. "]"
	end

	if #trees == 0 then
		fs[#fs + 1] = "label[0.25,1.70;" ..
			esc("Choose a class before spending talent points.") .. "]"
		return table.concat(fs)
	end

	local sections, nodes = grug_classes.talent_tree_data(trees)
	local layout = grug_classes.layout_tree(sections, nodes)
	for _, section in ipairs(sections) do
		local rect = layout.sections[section.id]
		fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,%.2f;#00000030]"):format(rect.x,
			rect.y - 0.9, rect.w, rect.h + 1.05)
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(rect.x + 0.15, rect.y - 0.62,
			esc(("%s — %d points"):format(section.tree.name,
				grug_classes.tree_points(player, section.id))))
		for col, text in ipairs(section.columns) do
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(rect.columns[col] + 0.05,
				rect.y - 0.22, esc(text))
		end
	end
	for _, connector in ipairs(layout.connectors) do
		local parent = grug_classes.registered_talents[connector.from]
		local color = grug_classes.talent_rank(player, parent.id) >= parent.ranks
			and CONNECTOR_MET or CONNECTOR_OPEN
		for _, s in ipairs(connector.segments) do
			fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(s.x, s.y, s.w, s.h, color)
		end
	end
	local by_state, parts = {}, {}
	for _, node in ipairs(nodes) do
		local state, field, part = node_formspec(player, context,
			grug_classes.registered_talents[node.id], layout.nodes[node.id])
		by_state[state] = by_state[state] or {}
		table.insert(by_state[state], field)
		parts[#parts + 1] = part
	end
	for _, state in ipairs({"buyable", "maxed", "ranked", "locked", "selected"}) do
		local fields = by_state[state]
		if fields then
			fs[#fs + 1] = state == "selected"
				and grug_inventory.selected_button_style(fields[1], true)
				or ("style[%s;%s]"):format(table.concat(fields, ","), NODE_STYLES[state])
		end
	end
	fs[#fs + 1] = table.concat(parts)

	local description = context.grug_talent_notice
		or selected_description(player, context)
	fs[#fs + 1] = ("textarea[0.25,%.2f;13.00,1.15;;;%s]"):format(layout.bottom + 0.35,
		esc(description))
	return table.concat(fs)
end

grug_classes.talent_formspec_content = talent_content

-- The skill catalog row under the tree (spec §3.4, Round 44 plan ruling 4):
-- grug_skills, which depends on this mod, installs a function(player, y)
-- that returns its formspec part in real coordinates from y down (about 1.4
-- high, above the short inventory at 9.5); without it the page ends with
-- the tree and its text.
grug_classes.skill_catalog_row = nil
local CATALOG_Y = 7.6

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

	for index, id in ipairs(grug_classes.talent_ids) do
		if fields["grug_talent_pick_" .. index] then
			local def = grug_classes.registered_talents[id]
			if not def or def.class ~= grug_classes.get_class(player) then
				return true
			end
			context.grug_talent_notice = nil
			context.grug_talent_selected = id
			-- A refused click selects the node: the line under the trees then
			-- shows its text and the reason (selected_description).
			if not grug_classes.spend_talent(player, id) then
				refresh_open_page(player)
			end
			return true
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
		return sfinv.make_formspec(player, context,
			talent_content(player, context) ..
				(catalog and catalog(player, CATALOG_Y) or ""),
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
