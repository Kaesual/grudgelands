-- The Talents page (Round 52 lane GRAPH, C6, D3, D5, D7; live since Round
-- 53): one inner tab per tree, the tree's background (or a plain one) in the
-- tab content rectangle, the graph's connection lines as box[] segments
-- under the nodes, nodes with their icon or, without one, their name.
-- talents_ui.lua puts graph.page_content into Talents & Skills: it uses the
-- sfinv frame's coordinates and ends above the skill row (d5-geometry.md).

local graph = grug_classes.graph

local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

-- The tree menu sits left of the complete artwork, with points at its foot.
-- Artwork keeps its original aspect ratio and fills its own area. The hint
-- strip and unframed native skill row follow below, above the two inventory
-- rows shared with other pages. Graph nodes and connectors use this one
-- geometry; no talent coordinates or purchasing rules change.
graph.PAGE = {x = 5.4, y = 0.25, w = 14.35, h = 6.07, pad = 0.5, col_gap = 0.3,
	node_h = 0.68, row_gap = 0.18, line = 0.06, strip_y = 6.36, strip_h = 0.6,
	tab_w = 4.7, tab_gap = 0.1}
local PLAIN_BACKGROUND = "#101318c8"
local GATE_COLOR = "#a0a0a0"

--
-- Art (D7): a texture is used once its file ships; until then the page
-- draws a plain background and text nodes. The two texture folders are
-- listed once at load.
--
local shipped = {}
for _, mod in ipairs({"grug_classes", "grug_abilities"}) do
	local path = core.get_modpath(mod)
	for _, file in ipairs(path and core.get_dir_list(path .. "/textures", false) or {}) do
		shipped[file] = true
	end
end

-- A granting node shows its skill's icon, any other node its own talent
-- icon, named after the id without its tree prefix (K5:
-- ember_fire_mastery -> grug_classes_talent_fire_mastery.png).
function graph.icon_texture(def)
	local file = def.ability and "grug_abilities_skill_" .. def.ability .. ".png"
		or "grug_classes_talent_" .. def.icon_name .. ".png"
	return shipped[file] and file or nil
end

-- A node's text for `viewer`: its description, and for a shared key whose
-- size depends on the level (armor, the pools) every rank's amount at the
-- viewer's level, through the same rules the consumers read.
local POOL_KEYS = {max_hp_percent_add = {"hp", "HP"}, max_mana_percent_add = {"mana", "mana"}}
local function amount_text(value)
	if value >= 10 then
		return tostring(math.floor(value + 0.5))
	end
	return (("%.1f"):format(value):gsub("%.0$", ""))
end
function graph.node_text(viewer, def)
	local parts = {}
	for key, values in pairs(def.effects) do
		local pool = POOL_KEYS[key]
		if graph.LEVEL_SCALED_KEYS[key] then
			for _, value in ipairs(values) do
				parts[#parts + 1] = "+" .. amount_text(graph.level_amount(key, value,
					grug_xp.get_level(viewer)))
			end
			return ("%s At your level: %s armor rating."):format(def.description,
				table.concat(parts, " / "))
		elseif pool then
			for _, value in ipairs(values) do
				parts[#parts + 1] = ("+%d %s"):format(
					grug_classes.pool_percent_amount(viewer, pool[1], value), pool[2])
			end
			return ("%s At your level: %s."):format(def.description, table.concat(parts, " / "))
		end
	end
	return def.description
end

function graph.background_texture(tree)
	local file = "grug_classes_tree_" .. tree.id .. ".png"
	return shipped[file] and file or nil
end

--
-- The layout: rows by gate, columns from the data, an icon node square and
-- centred in its column, a text node as wide as the column. Connectors run
-- orthogonally (Round 44's tree framework did the same): down from the parent's
-- bottom, across in the gap above the child's row, down into the child's
-- top (one segment in one column); a prerequisite in the same row is one
-- horizontal segment between the facing edges.
--
function graph.layout(tree, page)
	page = page or graph.PAGE
	local rows = #graph.GATE_ROWS
	local pitch = page.node_h + page.row_gap
	local top = page.y + (page.h - (rows * pitch - page.row_gap)) / 2
	local cell_w = (page.w - 2 * page.pad - (graph.COLUMNS - 1) * page.col_gap) /
		graph.COLUMNS
	local layout = {nodes = {}, connectors = {}, rows = {}, cell_w = cell_w}
	for index = 1, rows do
		layout.rows[index] = top + (index - 1) * pitch
	end
	for _, def in ipairs(tree.nodes) do
		local cx = page.x + page.pad + (def.col - 1) * (cell_w + page.col_gap) + cell_w / 2
		local w = graph.icon_texture(def) and page.node_h or cell_w
		local row = graph.GATE_ROW[def.gate]
		layout.nodes[def.id] = {x = cx - w / 2, y = layout.rows[row], w = w,
			h = page.node_h, cx = cx, row = row, col = def.col}
	end
	local t = page.line
	for _, def in ipairs(tree.nodes) do
		local child = layout.nodes[def.id]
		for _, parent_id in ipairs(def.requires) do
			local parent = layout.nodes[parent_id]
			local segments
			if parent.row == child.row then
				local left, right = parent, child
				if parent.cx > child.cx then left, right = child, parent end
				segments = {{x = left.x + left.w, y = child.y + child.h / 2 - t / 2,
					w = right.x - left.x - left.w, h = t}}
			elseif math.abs(parent.cx - child.cx) < 1e-9 then
				segments = {{x = child.cx - t / 2, y = parent.y + parent.h, w = t,
					h = child.y - parent.y - parent.h}}
			else
				local py = parent.y + parent.h
				local mid = child.y - page.row_gap / 2
				segments = {
					{x = parent.cx - t / 2, y = py, w = t, h = mid - py + t / 2},
					{x = math.min(parent.cx, child.cx) - t / 2, y = mid - t / 2,
						w = math.abs(child.cx - parent.cx) + t, h = t},
					{x = child.cx - t / 2, y = mid - t / 2, w = t, h = child.y - mid + t / 2},
				}
			end
			layout.connectors[#layout.connectors + 1] = {from = parent_id, to = def.id,
				segments = segments}
		end
	end
	return layout
end

-- Node field index per node id (registration order, fixed after load).
local field_index = {}
for index, id in ipairs(graph.node_ids) do field_index[id] = index end
function graph.node_field(id)
	return "grug_graph_node_" .. field_index[id]
end

-- One node: its state (a key of TALENT_NODE_STYLES, or "selected"), field
-- and formspec part (the button, the rank beside an icon, the tooltip).
local function node_formspec(viewer, view, def, rect)
	local field = graph.node_field(def.id)
	local rank = view.ranks[def.id] or 0
	local reason = graph.spend_refusal(def.class, view.ranks, def.id, view.budget)
	local state = view.selected == def.id and "selected"
		or not reason and "buyable" or rank >= def.ranks and "maxed"
		or rank > 0 and "ranked" or "locked"
	local tooltip = ("%s (%d/%d) — %s"):format(def.name, rank, def.ranks,
		graph.node_text(viewer, def))
	if reason and rank < def.ranks then
		tooltip = tooltip .. " Locked: " .. reason
	end
	local icon = graph.icon_texture(def)
	local parts = {}
	if icon then
		if state == "locked" then icon = icon .. "^[colorize:#000000:150" end
		parts[#parts + 1] = ("image_button[%.3f,%.3f;%.3f,%.3f;%s;%s;]"):format(rect.x,
			rect.y, rect.w, rect.h, esc(icon), field)
		parts[#parts + 1] = ("label[%.3f,%.3f;%d/%d]"):format(rect.x + rect.w + 0.05,
			rect.y + 0.12, rank, def.ranks)
	else
		parts[#parts + 1] = ("image_button[%.3f,%.3f;%.3f,%.3f;blank.png;%s;%s]"):format(
			rect.x, rect.y, rect.w, rect.h, field,
			esc(("%s\n%d/%d"):format(def.name, rank, def.ranks)))
	end
	parts[#parts + 1] = ("tooltip[%s;%s]"):format(field,
		esc(grug_inventory.wrap_text(tooltip, 58)))
	return state, field, table.concat(parts)
end

local function strip_text(viewer, view)
	local def = view.selected and graph.nodes[view.selected]
	if view.notice or not def then
		return view.notice or view.hint or ""
	end
	local rank = view.ranks[def.id] or 0
	local reason = graph.spend_refusal(def.class, view.ranks, def.id, view.budget)
	local status = rank >= def.ranks and "Maximum rank reached." or reason or
		view.buy_text or ""
	return ("%s — rank %d/%d: %s  %s"):format(def.name, rank, def.ranks,
		graph.node_text(viewer, def), status)
end

-- The page's content in real coordinates. view = {trees (the class's
-- trees), tab (index of the shown one), ranks ({node id = rank}, both
-- trees), budget, selected (node id or nil), notice (wins over the selected
-- node's text), hint, buy_text,
-- points_text, header (formspec for the header's right part: the respec
-- control)}.
function graph.page_content(viewer, view)
	local page = graph.PAGE
	local tree = view.trees[view.tab]
	local fs = {
		"real_coordinates[true]",
		grug_core.ui.panel(0.25, page.y, 4.9, page.h),
		-- An invisible button takes the focus at every send, so the read-only
		-- strip never does (it would eat the inventory key; talents_ui.lua).
		"set_focus[grug_graph_focus;true]button[0,0;0,0;grug_graph_focus;]",
	}
	for index, other in ipairs(view.trees) do
		local field = "grug_graph_tab_" .. index
		fs[#fs + 1] = grug_core.ui.navigation_style(field, index == view.tab,
			0.35, page.y + 0.15 + (index - 1) * 0.8, page.tab_w, 0.65, true, grug_core.ui.text_scale(viewer))
		fs[#fs + 1] = ("button[0.35,%.2f;%.2f,0.65;%s;%s]"):format(
			page.y + 0.15 + (index - 1) * 0.8, page.tab_w, field,
			esc(("%s (%d)"):format(other.name, graph.tree_points(view.ranks, other.id))))
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(field,
			esc(grug_inventory.wrap_text(other.description, 58)))
	end
	fs[#fs + 1] = "style_type[label;font_size=*0.8]"
	fs[#fs + 1] = ("label[0.5,%.2f;%s]"):format(page.y + page.h - 0.3, esc(view.points_text or ""))
	fs[#fs + 1] = view.header or ""
	fs[#fs + 1] = "style_type[label;font_size=*1]"

	fs[#fs + 1] = ("style_type[label;font_size=*%.3f]"):format(0.85 * grug_core.ui.text_scale(viewer))
	local background = graph.background_texture(tree)
	fs[#fs + 1] = background
		and ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(page.x, page.y, page.w, page.h,
			esc(background))
		or ("box[%.2f,%.2f;%.2f,%.2f;%s]"):format(page.x, page.y, page.w, page.h,
			PLAIN_BACKGROUND)
	local layout = graph.layout(tree)
	local used = {}
	for _, def in ipairs(tree.nodes) do used[def.gate] = true end
	for index, gate in ipairs(graph.GATE_ROWS) do
		if used[gate] then
			fs[#fs + 1] = ("label[%.2f,%.3f;%s]"):format(page.x + 0.12,
				layout.rows[index] + page.node_h / 2, core.colorize(GATE_COLOR, tostring(gate)))
		end
	end
	local colors = grug_classes.TALENT_CONNECTOR_COLORS
	for _, connector in ipairs(layout.connectors) do
		local color = (view.ranks[connector.from] or 0) >= 1 and colors.met or colors.open
		for _, s in ipairs(connector.segments) do
			fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(s.x, s.y, s.w, s.h, color)
		end
	end
	local by_state, parts = {}, {}
	for _, def in ipairs(tree.nodes) do
		local state, field, part = node_formspec(viewer, view, def, layout.nodes[def.id])
		by_state[state] = by_state[state] or {}
		table.insert(by_state[state], field)
		parts[#parts + 1] = part
	end
	for _, state in ipairs({"buyable", "maxed", "ranked", "locked", "selected"}) do
		local fields = by_state[state]
		if fields then
			fs[#fs + 1] = state == "selected"
				and grug_inventory.selected_button_style(fields[1], true)
				or ("style[%s;%s]"):format(table.concat(fields, ","),
					grug_classes.TALENT_NODE_STYLES[state])
		end
	end
	fs[#fs + 1] = table.concat(parts)
	fs[#fs + 1] = grug_core.ui.panel(page.x, page.strip_y, page.w, page.strip_h)
	fs[#fs + 1] = ("style_type[label;font_size=*1]style_type[textarea;font_size=*%.3f]"):format(0.8 * grug_core.ui.text_scale(viewer))
	fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,%.2f;;;%s]"):format(page.x, page.strip_y,
		page.w, page.strip_h, esc(strip_text(viewer, view)))
	fs[#fs + 1] = "style_type[textarea;font_size=*1]"
	return table.concat(fs)
end
