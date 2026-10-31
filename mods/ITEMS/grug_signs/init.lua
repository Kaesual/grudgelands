-- grug_signs: the standing sign, the waypost and the notice board (Round 68
-- lane SIGNS, rulings 6-8). Their text shows in the world through
-- grug_text (one text entity per written surface), never as hover text
-- (the user, 2026-10-31); the 512-byte limit, the control-character
-- stripping and the rights are the wall sign's (default/nodes.lua): writing
-- asks core.is_protected, reading is free
-- (grug_housing.INTERACTION_EXCEPTIONS lists every node here).
--
-- The models are lane ART's picks (standing sign A, waypost B, notice
-- board B, the board split into its two node halves; wood set B;
-- tools/r68_art, LICENSE-media.md), copied byte for byte. Luanti's
-- OBJ loader negates x ("change handedness",
-- irr/src/COBJMeshFileLoader.cpp:314), so in the game each model is ART's
-- mirrored in x; every number below is in the game's coordinates (ART's
-- spec with x negated). Unrotated, a sign's reader looks along +z (its
-- board faces -z) and the waypost's arrow points along -z.
--
-- Rotation: the standing sign and the waypost turn freely (`degrotate`,
-- 240 steps of 1.5 degrees, the mesh turned by the client,
-- client/content_mapblock.cpp:1726-1739). The engine never turns `fixed`
-- boxes of a degrotate node (mapnode.cpp getFaceDir answers 0 for it), so
-- their selection boxes are unrotated squares around everything the board
-- or the arrow sweeps. The notice board is two nodes wide and stands on the
-- grid, so it turns in four steps (`4dir`), its boxes with it.

grug_signs = {}

local MAX_BYTES = 512
local UP = vector.new(0, 1, 0)
-- The text sits 1/64 node in front of its board, as on the wall sign
-- (grug_text/surfaces.lua).
local GAP = 1 / 64

local STANDING = "grug_signs:standing_sign"
local WAYPOST = "grug_signs:waypost"
local BOARD = "grug_signs:notice_board"
-- The board's left half as its reader sees it: its half of the model and
-- its boxes, no text.
local BOARD_PART = "grug_signs:notice_board_part"
grug_signs.NODES = {STANDING, WAYPOST, BOARD, BOARD_PART}

-- One param2 step of degrotate per 1.5 degrees of yaw; `turn` adds steps.
local function yaw_param2(placer, turn)
	local yaw = placer and placer.get_look_horizontal and placer:get_look_horizontal() or 0
	return (math.floor(math.deg(yaw) / 1.5 + 0.5) + turn) % 240
end
grug_signs.yaw_param2 = yaw_param2

-- The reader's right for a look direction (x of grug_text's surface frame).
local function right_of(look)
	return vector.new(look.z, 0, -look.x)
end

--
-- The form: a text box sized to the surface's grid; Save writes.
--

local FORMS = {
	[STANDING] = {w = 9, h = 4.5, lines = 4, chars = 15, title = "Sign text",
		hint = "4 lines of 15 characters"},
	[WAYPOST] = {w = 9, h = 3.6, lines = 1, chars = 14, title = "Waypost text",
		hint = "14 characters, shown on both sides"},
	[BOARD] = {w = 12.5, h = 6, lines = 7, chars = 30, title = "Notice board text",
		hint = "7 lines of 30 characters"},
}

local function form_builder(spec)
	return function(pos, player)
		local ui = grug_core.ui
		local text = core.formspec_escape(core.get_meta(pos):get_string("text"))
		local box_w = spec.w - 1
		local fs = ui.frame(spec.w, spec.h, spec.title, nil, player) ..
			("label[0.5,1.05;%s]"):format(core.formspec_escape(
				core.colorize(ui.colors.muted, spec.hint)))
		if spec.lines == 1 then
			fs = fs .. ui.input_background(0.5, 1.4, box_w, 0.65, "text") ..
				("set_focus[text;true]field[0.5,1.4;%.2f,0.65;text;;%s]"):format(box_w, text)
		else
			local box_h = spec.lines * 0.42 + 0.2
			fs = fs .. ui.input_background(0.5, 1.4, box_w, box_h, "text") ..
				("set_focus[text;true]textarea[0.5,1.4;%.2f,%.2f;text;;%s]"):format(
					box_w, box_h, text)
		end
		return fs .. ui.button_style("save", "selected") ..
			("button_exit[%.2f,%.2f;2.3,0.65;save;Save]"):format(spec.w - 2.8, spec.h - 0.95)
	end
end

local builders = {}
for name, spec in pairs(FORMS) do builders[name] = form_builder(spec) end

local function show_form(player, pos)
	local node = core.get_node(pos)
	default.node_formspec.show(player, pos, builders[node.name])
end

-- The wall sign's write path (default/nodes.lua register_sign): quit-gated
-- (luanti issue 16187), core.is_protected, 512 bytes, control characters
-- stripped (tabs and newlines kept), no hover text.
local function write(pos, fields, sender)
	if not fields.quit then return end
	local name = sender:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return
	end
	local text = fields.text
	if not text then return end
	if #text > MAX_BYTES then
		grug_core.feed(sender, "notice", "Text too long", "grug_signs_text")
		return
	end
	text = text:gsub("[%z\1-\8\11-\31\127]", "")
	default.log_player_action(sender, ("wrote %q to the sign at"):format(text), pos)
	core.get_meta(pos):set_string("text", text)
	grug_text.refresh(pos)
end
grug_signs.write = write

local wood_sounds = default.node_sound_wood_defaults()

-- Close open forms of a dug or replaced sign (as the wall sign does).
local function close_forms(pos)
	default.node_formspec.refresh(pos)
end

--
-- The standing sign: ART's A, a board on a post, 4 x 15.
--

core.register_node(STANDING, {
	description = "Standing Sign",
	drawtype = "mesh",
	mesh = "grug_signs_standing.obj",
	tiles = {"grug_signs_standing.png"},
	inventory_image = "grug_signs_standing_inv.png",
	wield_image = "grug_signs_standing_inv.png",
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "degrotate",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	-- The board (0.875 wide, its far edge 3/32 off the centre) sweeps a
	-- circle of radius 0.447; the post one of 0.113.
	selection_box = {type = "fixed", fixed = {
		{-0.45, -0.125, -0.45, 0.45, 0.5, 0.45},
		{-0.125, -0.5, -0.125, 0.125, -0.125, 0.125},
	}},
	groups = {choppy = 2, oddly_breakable_by_hand = 3, flammable = 2, attached_node = 3},
	sounds = wood_sounds,
	-- The board faces the placer.
	on_place = function(itemstack, placer, pointed_thing)
		return core.item_place(itemstack, placer, pointed_thing, yaw_param2(placer, 0))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		show_form(clicker, pos)
		return itemstack
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		write(pos, fields, sender)
	end,
	after_destruct = close_forms,
})

-- The board's front lies 3/32 in front of the centre; the text block's
-- centre 3/16 up (ART's text area, 0.8125 x 0.5).
grug_text.register(STANDING, {lines = 4, chars = 15, frame = "degrotate",
	offset = {x = 0, y = 3 / 16, z = -3 / 32 - GAP}})

--
-- The waypost: ART's B, an arrow board through a post, 1 x 14 on each
-- side. Wayposts stack: each node is one arrow on a post running the
-- whole node, so the posts join.
--

-- The two reading sides. Unrotated the arrow points along -z and its faces
-- lie 1/16 off the post's axis towards +x and -x; the text block is centred
-- 3/32 from the centre towards the arrow's tail (+z), 1/4 up. A face's
-- reader looks along -x or +x: the node's turn (degrotate as grug_text's
-- frame) plus a quarter turn either way, so the tail is to the reader's
-- right on the +x face and to the left on the -x face.
local function waypost_side(quarter)
	return function(node)
		return core.yaw_to_dir(math.rad(1.5 * (node.param2 % 240)) + quarter * math.pi / 2), UP
	end
end
local WAYPOST_SIDES = {
	{lines = 1, chars = 14, frame = waypost_side(1),
		offset = {x = 3 / 32, y = 1 / 4, z = -1 / 16 - GAP}},
	{lines = 1, chars = 14, frame = waypost_side(-1),
		offset = {x = -3 / 32, y = 1 / 4, z = -1 / 16 - GAP}},
}

-- The arrow points where the placer looks: degrotate turns -z to the look
-- direction at param2 = yaw / 1.5 + 120 (half a turn).
local function place_waypost(itemstack, placer, pointed_thing)
	return core.item_place(itemstack, placer, pointed_thing, yaw_param2(placer, 120))
end

core.register_node(WAYPOST, {
	description = "Waypost",
	drawtype = "mesh",
	mesh = "grug_signs_waypost.obj",
	tiles = {"grug_signs_waypost.png"},
	inventory_image = "grug_signs_waypost_inv.png",
	wield_image = "grug_signs_waypost_inv.png",
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "degrotate",
	sunlight_propagates = true,
	is_ground_content = false,
	-- Walkable, so a waypost carries the next one (attached_node needs a
	-- walkable node below); only the post collides, which is the same at
	-- every turn. The arrow (1 long, 1/8 thick, from y 1/16 to 7/16) sweeps
	-- a circle of radius 0.504.
	walkable = true,
	collision_box = {type = "fixed", fixed = {{-1 / 16, -0.5, -1 / 16, 1 / 16, 0.5, 1 / 16}}},
	selection_box = {type = "fixed", fixed = {
		{-1 / 16, -0.5, -1 / 16, 1 / 16, 0.5, 1 / 16},
		{-0.51, 1 / 16, -0.51, 0.51, 7 / 16, 0.51},
	}},
	groups = {choppy = 2, oddly_breakable_by_hand = 3, flammable = 2, attached_node = 3},
	sounds = wood_sounds,
	on_place = place_waypost,
	-- A waypost in hand on a waypost's top stacks the next one (without
	-- sneaking); otherwise the form opens.
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if itemstack:get_name() == WAYPOST and pointed_thing and pointed_thing.type == "node" and
				pointed_thing.above.y > pointed_thing.under.y then
			return (core.item_place_node(itemstack, clicker, pointed_thing,
				yaw_param2(clicker, 120)))
		end
		show_form(clicker, pos)
		return itemstack
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		write(pos, fields, sender)
	end,
	after_destruct = close_forms,
})

grug_text.register(WAYPOST, WAYPOST_SIDES)

--
-- The notice board: ART's B, a roofed board on two posts, two nodes wide
-- and 1.6875 tall, 7 x 30. Placed and dug as one (the bed's two-node
-- pattern, beds/api.lua): the node with the text stands on the reader's
-- right, its part on the left; digging either removes both and drops one
-- board; the text entity lives on the board's node. Each node draws its
-- own half of the model (as the bed's halves do), so the digging cracks
-- show on the half being dug: ART's model is cut at the halves' border
-- (tools/r68_art REPORT pass 4), each half in its node's coordinates.
-- ART's left half (lower x, around the original origin) is the board's,
-- its right half the part's: mirrored by the OBJ loader, ART's +x is the
-- game's -x, where the part stands (param2 0: board at x, part at x - 1),
-- so the halves rejoin into the whole model at every turn of `4dir`.
--

-- The board's node is the part's neighbour to the reader's right.
local function board_right(node)
	return right_of(core.facedir_to_dir(node.param2 % 4))
end

-- Where the other half of a board's node stands, and its name.
local function partner_pos(pos, node)
	if node.name == BOARD then return vector.subtract(pos, board_right(node)), BOARD_PART end
	return vector.add(pos, board_right(node)), BOARD
end

-- The other half of the board at pos, or nil.
local function partner(pos, node)
	local other, expected = partner_pos(pos, node)
	local found = core.get_node(other)
	if found.name == expected and found.param2 == node.param2 then return other end
	return nil
end
grug_signs.partner = partner

-- Removes the other half without its destructors (beds/api.lua
-- remove_no_destruct): its own drop never happens. The text entity and
-- open forms go with the board's node.
local function remove_partner(pos)
	local other = partner(pos, core.get_node(pos))
	if not other then return end
	local name = core.get_node(other).name
	core.swap_node(other, {name = "air"})
	core.remove_node(other)
	if name == BOARD then
		grug_text.remove(other)
		close_forms(other)
	end
end

-- What rested on the removed other half falls, once this half is gone too:
-- checked in on_destruct, the builtin walk (falling.lua check_for_falling)
-- would still find this half standing without its ground after a support
-- loss and drop it a second time (two boards).
local function partner_falls(pos, oldnode)
	core.check_for_falling((partner_pos(pos, oldnode)))
end

local function refuse(placer, why)
	if placer and placer.is_player and placer:is_player() then
		grug_core.feed(placer, "notice", why, "grug_signs_board")
	end
end

-- Places both halves facing the placer, the part where the player points
-- and the board to its right; refused unless both nodes and the two above
-- them (the roof rises to 1.6875) are free and unprotected and both halves
-- stand on walkable ground.
local function place_board(itemstack, placer, pointed_thing)
	if pointed_thing.type ~= "node" then return itemstack end
	local under = pointed_thing.under
	local node = core.get_node(under)
	local udef = core.registered_nodes[node.name]
	if udef and udef.on_rightclick and
			not (placer and placer:is_player() and placer:get_player_control().sneak) then
		return udef.on_rightclick(under, node, placer, itemstack, pointed_thing) or itemstack
	end
	local name = placer and placer:get_player_name() or ""
	local pos = (udef and udef.buildable_to) and vector.copy(under) or vector.copy(pointed_thing.above)
	local param2 = placer and core.dir_to_fourdir(placer:get_look_dir()) or 0
	local main = vector.add(pos, board_right({param2 = param2}))
	local space = {pos, main, vector.add(pos, UP), vector.add(main, UP)}
	for _, p in ipairs(space) do
		if core.is_protected(p, name) then
			core.record_protection_violation(p, name)
			return itemstack
		end
	end
	for _, p in ipairs(space) do
		local def = core.registered_nodes[core.get_node(p).name]
		if not def or not def.buildable_to then
			refuse(placer, "The notice board needs two free nodes side by side and the two above them.")
			return itemstack
		end
	end
	for _, p in ipairs({pos, main}) do
		local def = core.registered_nodes[core.get_node(vector.subtract(p, UP)).name]
		if not def or not def.walkable then
			refuse(placer, "The notice board needs solid ground under both halves.")
			return itemstack
		end
	end
	core.set_node(pos, {name = BOARD_PART, param2 = param2})
	core.set_node(main, {name = BOARD, param2 = param2})
	core.log("action", name .. " places node " .. BOARD .. " at " .. core.pos_to_string(main))
	if not core.is_creative_enabled(name) then itemstack:take_item() end
	return itemstack
end

-- Boxes per half (ART's suggestion split at the halves' border, mirrored):
-- the board and the roof over the whole half, the post near its outer
-- edge, behind the board's middle.
local function board_boxes(post_x)
	return {type = "fixed", fixed = {
		{post_x - 1 / 16, -0.5, 0, post_x + 1 / 16, 0, 0.125},
		{-0.5, 0, -0.125, 0.5, 1, 0.125},
		{-0.5, 1, -0.25, 0.5, 1.1875, 0.25},
	}}
end

local board_groups = {choppy = 2, oddly_breakable_by_hand = 3, flammable = 2, attached_node = 3}

core.register_node(BOARD, {
	description = "Notice Board",
	drawtype = "mesh",
	mesh = "grug_signs_notice_board_main.obj",
	tiles = {"grug_signs_notice_board.png"},
	inventory_image = "grug_signs_notice_board_inv.png",
	wield_image = "grug_signs_notice_board_inv.png",
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = true,
	selection_box = board_boxes(0.375),
	collision_box = board_boxes(0.375),
	groups = board_groups,
	sounds = wood_sounds,
	-- Two nodes appear at once: no client prediction of one.
	node_placement_prediction = "",
	on_place = place_board,
	on_rightclick = function(pos, node, clicker, itemstack)
		show_form(clicker, pos)
		return itemstack
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		write(pos, fields, sender)
	end,
	on_destruct = remove_partner,
	after_destruct = function(pos, oldnode)
		close_forms(pos)
		partner_falls(pos, oldnode)
	end,
})

local part_groups = table.copy(board_groups)
part_groups.not_in_creative_inventory = 1

core.register_node(BOARD_PART, {
	description = "Notice Board",
	drawtype = "mesh",
	mesh = "grug_signs_notice_board_part.obj",
	tiles = {"grug_signs_notice_board.png"},
	use_texture_alpha = "opaque",
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = true,
	pointable = true,
	selection_box = board_boxes(-0.375),
	collision_box = board_boxes(-0.375),
	groups = part_groups,
	sounds = wood_sounds,
	drop = BOARD,
	on_rightclick = function(pos, node, clicker, itemstack)
		local main = partner(pos, node)
		if main then show_form(clicker, main) end
		return itemstack
	end,
	on_destruct = remove_partner,
	after_destruct = partner_falls,
})

-- The board's front lies 1/16 in front of the centre; the text block's
-- centre half a node towards the part (between the halves) and half a node
-- up (ART's text area, 1.75 x 0.875).
grug_text.register(BOARD, {lines = 7, chars = 30, frame = "4dir",
	offset = {x = -0.5, y = 0.5, z = -1 / 16 - GAP}})

-- No hover text (the user, 2026-10-31): the text shows only on the sign.
-- Before, a written sign kept it in its infotext (the notice board on both
-- halves); the first load of its block after this LBM came drops it, once
-- per block, as grug_text's LBM does for the wall signs (surfaces.lua).
core.register_lbm({
	label = "Drop the hover text of the standing sign, waypost and notice board",
	name = "grug_signs:drop_hover_text",
	nodenames = grug_signs.NODES,
	run_at_every_load = false,
	action = function(pos)
		local meta = core.get_meta(pos)
		if meta:get_string("infotext") ~= "" then meta:set_string("infotext", "") end
	end,
})
