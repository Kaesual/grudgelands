-- grug_text/surfaces.lua: the written surfaces of existing nodes (Round 68
-- lane TEXT): the two wall signs and every chest tier's label. Lane SIGNS
-- registers its own nodes where it defines them.

local INK = grug_text.INK

--
-- Wall signs (4 x 15). The board's front face lies 7/16 from the node's
-- centre towards the wall (default/nodes.lua `register_sign`: wall_side
-- -0.5 .. -0.4375), the text just in front of it in every wallmounted
-- orientation. Writing goes through the sign's own form handler (meta
-- `text`, core.is_protected); the text follows it. No hover text repeats it
-- (the user, 2026-10-31).
--

-- The ink of each sign, one value each: dark on the wooden board and on
-- the light grey iron board (lane ART's #2B1E14 for both).
local SIGN_INK = {
	["default:sign_wall_wood"] = INK.dark,
	["grug_materials:iron_sign_wall"] = INK.dark,
}

local SIGN = {lines = 4, chars = 15, offset = {x = 0, y = 0, z = 7 / 16 - 1 / 64}}

-- The nodes whose hover text once repeated their text (see the LBM below).
local written = {}
local chests = {}

for name, ink in pairs(SIGN_INK) do
	local def = core.registered_nodes[name]
	if def then
		written[#written + 1] = name
		local receive = def.on_receive_fields
		core.override_item(name, {
			on_receive_fields = function(pos, formname, fields, sender)
				receive(pos, formname, fields, sender)
				grug_text.refresh(pos)
			end,
		})
		local surface = table.copy(SIGN)
		surface.ink = ink
		grug_text.register(name, surface)
	end
end

--
-- Chest labels (3 x 13 of the label's 40 characters). On the front's lower
-- part, which stays when the lid opens (models/chest_open.obj: the body
-- ends at y = 3/16), below the lock plate (texture rows 4-10) and above the
-- bottom rim (row 15): the block's centre at y = -5/16, its glyphs' ink
-- (rows 3-10 of each 12 px line) centred there. Open and closed chests
-- share the front, so the open/close swap leaves the entity as it is; the
-- label save and the tier upgrade refresh it through
-- default.containers.update_infotext.
--

local LABEL = {lines = 3, chars = 13, frame = "facedir",
	offset = {x = 0, y = -5 / 16 + 0.5 / 128, z = -0.5 - 1 / 64}}

-- The ink per tier, one value each: dark on the Wooden chest, light on the
-- dark Steel-Reinforced and Abyssal fronts.
local CHEST_INK = {INK.dark, INK.light, INK.light}

local function label_text(_, _, meta)
	return meta:get_string(default.containers.LABEL_KEY)
end

for tier = 1, #default.containers.TIERS do
	for _, base in ipairs({"default:chest", "default:chest_locked"}) do
		local name = default.containers.tier_name(base, tier)
		local surface = table.copy(LABEL)
		surface.text = label_text
		surface.ink = CHEST_INK[tier]
		grug_text.register(name, surface)
		grug_text.register(name .. "_open", surface)
		for _, chest in ipairs({name, name .. "_open"}) do
			written[#written + 1] = chest
			chests[chest] = true
		end
	end
end

--
-- No hover text (the user, 2026-10-31): a sign's text and a chest's label
-- show only on the surface. Before, a written sign kept its text in its
-- infotext and a labelled chest its label as the infotext's first line.
-- The first load of such a block after this LBM came drops them: once per
-- block (`run_at_every_load = false`), as blocks saved later never carry
-- them. Only text a player wrote has them, and a block a player wrote in was
-- active, so it has the timestamp the engine compares (lua_api.md, LBM
-- definition).
--

core.register_lbm({
	label = "Drop the hover text of signs and chest labels",
	name = "grug_text:drop_hover_text",
	nodenames = written,
	run_at_every_load = false,
	action = function(pos, node)
		local meta = core.get_meta(pos)
		if chests[node.name] then
			-- A chest's hover text stays its name (and owner).
			if meta:get_string(default.containers.LABEL_KEY) ~= "" then
				default.containers.update_infotext(pos)
			end
		elseif meta:get_string("infotext") ~= "" then
			meta:set_string("infotext", "")
		end
	end,
})
