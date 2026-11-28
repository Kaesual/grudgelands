--
-- The shield bubble (Round 89 ruling 2, skill_trees.md §3.11): while a player
-- has a live absorb, ONE half-transparent egg-shaped entity is attached to them,
-- coloured by the absorb added last that is still live (a recast counts as
-- added). combat.lua's absorb bookkeeping calls `sync` at the moments it
-- already has -- an add, the lazy prune in get_absorb (the shield status's
-- value function reads it every status pass), the soak, the shield status's
-- expiry -- and `remove` on death and leave. The bubble has no on_step and no
-- pass of its own: the server does nothing for it per step, and it costs one
-- object per shielded player. Nothing is saved.
--
--   * Attached at the player's origin with the engine's default
--     forced_visible = false: the client hides an object attached to its own
--     local player while the camera is in first person
--     (src/client/content_cao.cpp GenericCAO::setAttachment, and
--     setChildrenVisible at a camera switch, src/client/game.cpp), so it
--     never covers its own player's view; other players and the third-person
--     camera see it.
--   * A child attached to bone "" hangs under the parent's mesh node, which
--     carries the parent's visual_size (content_cao.cpp updateAttachments,
--     addToScene's setScale), so the bubble and its centre height grow with
--     the race's stature (grug_visuals/wield_geometry.lua note 9). The mesh
--     is a unit-free egg around its own origin, authored at 10 units =
--     1 node (tools/r89_bubble/gen_bubble.py); the origin sits at the
--     bubble's centre so the client's transparent pass sorts it there.
--   * The engine detaches the children of a removed object
--     (src/server/unit_sao.cpp clearChildAttachments, which runs the child's
--     on_detach), so a bubble whose player is gone removes itself.
--

local bubble = {}
grug_core.shield_bubble = bubble

bubble.ENTITY = "grug_core:shield_bubble"
bubble.MESH = "grug_core_shield_bubble.obj"
-- The colour of an absorb id; every id not listed is "plain". A later skill
-- names its colour here.
bubble.COLORS = {
	shield_spell = "gold", -- the Priest's Shield
	rime_mantle = "frost", -- the Mage's Rime Mantle
}
bubble.TEXTURES = {
	gold = "grug_core_shield_bubble_gold.png",
	frost = "grug_core_shield_bubble_frost.png",
	plain = "grug_core_shield_bubble_plain.png",
}
-- The bubble's centre above the player's feet, in model units (10 = 1 node),
-- before the parent's stature scales it: the middle of the standing model
-- (0 to about 18.3 units tall).
bubble.CENTER_Y = 9.3
-- A faint light of its own, so the bubble still reads at night (the entity's
-- light is the node light raised by glow: content_cao.cpp updateLight).
bubble.GLOW = 6
-- A slow turn about its own vertical axis, drawn by the client alone
-- (content_cao.cpp step, automatic_rotate on the child's scene node).
bubble.ROTATE = 0.5

-- player name -> {object = ObjectRef, color = key}: the one bubble per player.
local shown = {}

function bubble.color_of(id)
	return bubble.COLORS[id] or "plain"
end

-- PURE: the id of the live entry added last (the highest `seq`), or nil when
-- no entry is live at `now`. `entries` is combat.lua's id -> {amount, expiry,
-- seq} table of one player, or nil.
function bubble.latest(entries, now)
	if not entries then return nil end
	local best, best_seq
	for id, entry in pairs(entries) do
		if entry.amount > 0 and now < entry.expiry and
				(not best_seq or (entry.seq or 0) > best_seq) then
			best, best_seq = id, entry.seq or 0
		end
	end
	return best
end

function bubble.remove(player)
	local name = player:get_player_name()
	local row = shown[name]
	if not row then return end
	shown[name] = nil
	local entity = row.object:get_luaentity()
	if entity then entity._grug_gone = true end
	row.object:remove()
end

-- Shows, recolours or removes the player's bubble after a change of their
-- absorb entries. An unchanged colour calls nothing in the engine.
function bubble.sync(player, entries, now)
	local id = bubble.latest(entries, now or core.get_us_time())
	if not id then
		bubble.remove(player)
		return
	end
	local color = bubble.color_of(id)
	local name = player:get_player_name()
	local row = shown[name]
	if row and row.color == color then return end
	if row and row.object:get_luaentity() then
		row.object:set_properties({textures = {bubble.TEXTURES[color]}})
		row.color = color
		return
	end
	shown[name] = nil
	local pos = player:get_pos()
	local object = pos and core.add_entity(pos, bubble.ENTITY)
	if not object then return end
	local entity = object:get_luaentity()
	if entity then entity._grug_owner = name end
	object:set_properties({textures = {bubble.TEXTURES[color]}})
	object:set_attach(player, "", {x = 0, y = bubble.CENTER_Y, z = 0},
		{x = 0, y = 0, z = 0})
	shown[name] = {object = object, color = color}
end

-- Test and probe seam: the player's bubble object and colour, or nil.
function bubble.shown(name)
	local row = shown[name]
	return row and row.object, row and row.color
end

core.register_entity(bubble.ENTITY, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		selectionbox = {0, 0, 0, 0, 0, 0},
		visual = "mesh",
		mesh = bubble.MESH,
		textures = {bubble.TEXTURES.plain},
		-- Blended, not clipped (content_cao.cpp addToScene: TILE_MATERIAL_
		-- PLAIN_ALPHA, an EMT_TRANSPARENT_ALPHA_CHANNEL that writes no depth
		-- and is drawn in the transparent pass, sorted by distance).
		use_texture_alpha = true,
		-- Only the near half: one layer over the player, and nothing at all
		-- for a viewer whose camera is inside someone else's bubble.
		backface_culling = true,
		shaded = false,
		glow = bubble.GLOW,
		automatic_rotate = bubble.ROTATE,
		static_save = false,
		show_on_minimap = false,
		damage_texture_modifier = "",
	},
	-- Never damaged by an area effect that punches every object near it.
	on_punch = function() return true end,
	on_detach = function(self)
		if self._grug_gone then return end
		self._grug_gone = true
		self.object:remove()
	end,
	on_deactivate = function(self)
		local row = self._grug_owner and shown[self._grug_owner]
		if row and row.object == self.object then
			shown[self._grug_owner] = nil
		end
	end,
})
