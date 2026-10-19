-- The new Talents page (Round 52 lane GRAPH, C6, D3, D5, D7): one inner tab
-- per tree, the tree's background (or a plain one) in the tab content
-- rectangle, the graph's connection lines as box[] segments under the nodes,
-- nodes with their icon or, without one, their name. In Round 52 only the
-- read-only admin preview (/talent_preview, privilege `server`) shows it,
-- with each tree's sample build held in the form's context; nothing here
-- writes player meta. Round K puts graph.page_content into Talents & Skills
-- in place of today's trees: it uses the sfinv frame's coordinates and ends
-- above the skill row (d5-geometry.md).

local graph = grug_classes.graph
local PREVIEW_FORM = "grug_classes:talent_preview"

local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

-- The geometry (D5, d5-geometry.md): the tree tabs share the header row
-- (0.15-0.75) with the points and the respec control; the tab content
-- rectangle is 13 x 5.5 at (0.25, 0.95), drawn at 80 px per unit (1040 x 440
-- art); seven gate rows of node_h with row_gap between them, centred in it;
-- the description strip below it, above the skill row.
graph.PAGE = {x = 0.25, y = 0.95, w = 13.0, h = 5.5, pad = 0.5, col_gap = 0.3,
	node_h = 0.6, row_gap = 0.18, line = 0.06, strip_y = 6.5, strip_h = 0.65,
	tab_w = 2.6, tab_gap = 0.1}
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

-- A granting node shows its skill's icon, any other node its own talent icon.
function graph.icon_texture(def)
	local file = def.ability and "grug_abilities_skill_" .. def.ability .. ".png"
		or "grug_classes_talent_" .. def.id .. ".png"
	return shipped[file] and file or nil
end

function graph.background_texture(tree)
	local file = "grug_classes_tree_" .. tree.id .. ".png"
	return shipped[file] and file or nil
end

--
-- The layout: rows by gate, columns from the data, an icon node square and
-- centred in its column, a text node as wide as the column. Connectors run
-- orthogonally like layout_tree's (talents_ui.lua): down from the parent's
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
local function node_field(id)
	return "grug_graph_node_" .. field_index[id]
end

-- One node: its state (a key of TALENT_NODE_STYLES, or "selected"), field
-- and formspec part (the button, the rank beside an icon, the tooltip).
local function node_formspec(view, def, rect)
	local field = node_field(def.id)
	local rank = view.ranks[def.id] or 0
	local reason = graph.spend_refusal(def.class, view.ranks, def.id, view.budget)
	local state = view.selected == def.id and "selected"
		or not reason and "buyable" or rank >= def.ranks and "maxed"
		or rank > 0 and "ranked" or "locked"
	local tooltip = ("%s (%d/%d) — %s"):format(def.name, rank, def.ranks, def.description)
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

local function strip_text(view)
	local def = view.selected and graph.nodes[view.selected]
	if not def then
		return view.notice or view.hint or ""
	end
	local rank = view.ranks[def.id] or 0
	local reason = graph.spend_refusal(def.class, view.ranks, def.id, view.budget)
	local status = rank >= def.ranks and "Maximum rank reached." or reason or
		view.buy_text or ""
	return ("%s — rank %d/%d: %s  %s"):format(def.name, rank, def.ranks,
		def.description, status)
end

-- The page's content in real coordinates. view = {trees (the class's
-- trees), tab (index of the shown one), ranks ({node id = rank}, both
-- trees), budget, selected (node id or nil), notice, hint, buy_text,
-- points_text, header (formspec for the header's right part: the respec
-- control, or the preview's note)}.
function graph.page_content(viewer, view)
	local page = graph.PAGE
	local tree = view.trees[view.tab]
	local fs = {
		"real_coordinates[true]",
		-- An invisible button takes the focus at every send, so the read-only
		-- strip never does (it would eat the inventory key; talents_ui.lua).
		"set_focus[grug_graph_focus;true]button[0,0;0,0;grug_graph_focus;]",
	}
	for index, other in ipairs(view.trees) do
		local field = "grug_graph_tab_" .. index
		fs[#fs + 1] = grug_inventory.selected_button_style(field, index == view.tab)
		fs[#fs + 1] = ("button[%.2f,0.15;%.2f,0.60;%s;%s]"):format(
			page.x + (index - 1) * (page.tab_w + page.tab_gap), page.tab_w, field,
			esc(("%s (%d)"):format(other.name, graph.tree_points(view.ranks, other.id))))
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(field,
			esc(grug_inventory.wrap_text(other.description, 58)))
	end
	fs[#fs + 1] = ("label[5.75,0.45;%s]"):format(esc(view.points_text or ""))
	fs[#fs + 1] = view.header or ""

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
		local state, field, part = node_formspec(view, def, layout.nodes[def.id])
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
	fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,%.2f;;;%s]"):format(page.x, page.strip_y,
		page.w, page.strip_h, esc(strip_text(view)))
	return table.concat(fs)
end

--
-- The admin preview (D3). Its state lives in this table, per viewer, until
-- the form closes or the viewer leaves: the class, the tab, the selected
-- node and the sample builds (both trees' in one table). It never touches
-- player meta, so grug_classes:talents is never written.
--
local contexts = {}
local PREVIEW_HINT = "Preview of the new talent trees, read only: each tab " ..
	"shows its sample build. Click a talent to read it. D, S, R, M, B: the " ..
	"class's base hits; P: the pool; K: the armor constant."

local function preview_formspec(viewer, ctx)
	local trees = graph.trees_of_class(ctx.class)
	return "formspec_version[6]size[13.50,7.40]" .. graph.page_content(viewer, {
		trees = trees, tab = ctx.tab, ranks = ctx.ranks, budget = graph.POINTS_MAX,
		selected = ctx.selected, hint = PREVIEW_HINT,
		points_text = ("Sample build: %d of %d points"):format(
			graph.tree_points(ctx.ranks, trees[ctx.tab].id), graph.POINTS_MAX),
		header = "label[9.90,0.45;" .. esc("Read-only preview") .. "]",
	})
end

local function show_preview(viewer)
	local ctx = contexts[viewer:get_player_name()]
	core.show_formspec(viewer:get_player_name(), PREVIEW_FORM,
		preview_formspec(viewer, ctx))
end

-- Opens the preview of `class_id`'s trees; returns false plus a reason when
-- there are none.
function graph.open_preview(viewer, class_id)
	local trees = graph.trees_of_class(class_id)
	if #trees == 0 then
		return false
	end
	local ranks = {}
	for _, tree in ipairs(trees) do
		for id, rank in pairs(tree.example_ranks or {}) do ranks[id] = rank end
	end
	contexts[viewer:get_player_name()] = {class = class_id, tab = 1, ranks = ranks}
	show_preview(viewer)
	return true
end

core.register_chatcommand("talent_preview", {
	params = "[mage|warrior|priest|scout]",
	description = "Preview the new talent trees (read only)",
	privs = {server = true},
	func = function(name, param)
		local viewer = core.get_player_by_name(name)
		if not viewer then
			return false, "You must be online."
		end
		local class_id = param:match("^%s*(%S+)") or grug_classes.get_class(viewer) or
			graph.trees[graph.tree_ids[1]].class
		if not graph.open_preview(viewer, class_id) then
			return false, "No new trees for '" .. class_id ..
				"'. Use mage, warrior, priest or scout."
		end
		return true
	end,
})

core.register_on_player_receive_fields(function(viewer, formname, fields)
	if formname ~= PREVIEW_FORM then
		return false
	end
	local name = viewer:get_player_name()
	local ctx = contexts[name]
	if not ctx or not core.check_player_privs(name, {server = true}) then
		return true
	end
	if fields.quit then
		contexts[name] = nil
		return true
	end
	local trees = graph.trees_of_class(ctx.class)
	for index in ipairs(trees) do
		if fields["grug_graph_tab_" .. index] then
			ctx.tab, ctx.selected = index, nil
			show_preview(viewer)
			return true
		end
	end
	for _, def in ipairs(trees[ctx.tab].nodes) do
		if fields[node_field(def.id)] then
			ctx.selected = def.id
			show_preview(viewer)
			return true
		end
	end
	return true
end)

core.register_on_leaveplayer(function(viewer)
	contexts[viewer:get_player_name()] = nil
end)
