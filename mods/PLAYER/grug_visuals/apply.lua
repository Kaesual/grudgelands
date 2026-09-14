--
-- The engine half of grug_visuals: who gets a composed look, when, and the one
-- attached entity that carries the visible weapon.
--
-- Everything here is IDEMPOTENT and TOKEN-GUARDED. `compose` hands back the key
-- it composed from; a character whose key has not changed costs one table
-- lookup and writes nothing -- which matters because the equipment-change seam
-- fires on every inventory action and may fire twice for one change
-- (grug_core/combat.lua).
--

--
-- The visible weapon: ONE attached entity per character (contract §1), never a
-- per-frame update. `visual = "wielditem"` renders the item's own inventory
-- image as the extruded mesh, so a grug_gear weapon arrives already tinted for
-- its bracket and no texture of ours is involved at all.
--
-- The offhand is deliberately absent (contract §1, "offhand later").
--
local WIELD_ENTITY = "grug_visuals:wield"

-- `character.b3d` carries the bones Body / Head / Arm_Left / Arm_Right /
-- Leg_Right / Leg_Left (read out of the mesh itself, not guessed). The arm
-- bone sits at the SHOULDER, 6.3 model units above the hand, and its own
-- rotation flips y and z -- hence a positive y and a negative z here for
-- "down the arm and slightly forward".
--
-- FIRST VERSION, tuned by eye against the geometry and NOT verified in a
-- client: the visuals lane cannot see the model. These five numbers are the
-- one place to adjust it (docs/design/character_visuals.md, "Open points").
local WIELD_BONE = "Arm_Right"
local WIELD_POS = {x = 0, y = 5.5, z = -1.5}
local WIELD_ROT = {x = -90, y = 180, z = 0}
local WIELD_SIZE = {x = 0.22, y = 0.22}

-- How often an orphaned wield entity notices that its character is gone.
-- Luanti DETACHES the children of a removed object instead of removing them,
-- so without this a killed guard leaves its sword floating for good. The cost
-- is one float add and one compare per entity per step; the price of the
-- interval is that a dropped weapon hangs in the air for up to a second after
-- its owner dies.
local ORPHAN_CHECK = 1.0

core.register_entity(WIELD_ENTITY, {
	initial_properties = {
		hp_max = 1,
		physical = false,
		pointable = false,
		collide_with_objects = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		-- Never saved: the owner re-creates it on every activation, and a
		-- persisted copy would accumulate one sword per world load.
		static_save = false,
		visual = "wielditem",
		visual_size = WIELD_SIZE,
		textures = {"air"},
	},
	_grug_age = 0,
	on_step = function(self, dtime)
		self._grug_age = self._grug_age + dtime
		if self._grug_age < ORPHAN_CHECK then
			return
		end
		self._grug_age = 0
		if not self.object:get_attach() then
			self.object:remove()
		end
	end,
})

-- Nothing to draw for an item nobody registered: `wielditem` would render the
-- engine's "unknown item" cube, which looks like a bug and is one.
local function drawable(itemname)
	return type(itemname) == "string" and itemname ~= "" and
		core.registered_items[itemname] ~= nil
end

local function spawn_wield(parent, itemname)
	local pos = parent:get_pos()
	if not pos then
		return nil
	end
	local obj = core.add_entity(pos, WIELD_ENTITY)
	if not obj then
		return nil
	end
	obj:set_properties({textures = {itemname}})
	obj:set_attach(parent, WIELD_BONE, WIELD_POS, WIELD_ROT)
	return obj
end

-- Bring `holder`'s wield entity in line with `itemname` (nil = empty hands).
-- `holder` is any table that may carry `_grug_wield_obj` (the ObjectRef we own)
-- and `_grug_wield_item` (what it currently shows): the per-player entry below
-- and a mob's own entity table both work. On a mob entity those two names are
-- deliberately `_grug_`-prefixed and the ObjectRef is userdata, which mobs_redo
-- drops from staticdata -- so a reactivated mob re-creates its weapon rather
-- than inheriting a dead handle.
local function sync_wield(holder, parent, itemname)
	if not drawable(itemname) then
		itemname = nil
	end
	local obj = holder._grug_wield_obj
	if obj and not obj:get_pos() then
		obj = nil -- removed under us (its parent died)
	end
	if not itemname then
		if obj then
			obj:remove()
		end
		holder._grug_wield_obj = nil
		holder._grug_wield_item = nil
		return
	end
	if obj then
		if holder._grug_wield_item ~= itemname then
			obj:set_properties({textures = {itemname}})
			holder._grug_wield_item = itemname
		end
		return
	end
	holder._grug_wield_obj = spawn_wield(parent, itemname)
	holder._grug_wield_item = holder._grug_wield_obj and itemname or nil
end

--
-- Players
--

-- The armor lists. grug_inventory's vocabulary, named here as plain strings so
-- this mod does not have to depend on it (the seam is grug_core's), and audited
-- against the real slot table at mods_loaded -- a silent mismatch would look
-- exactly like "the armor never shows up".
local ARMOR_LIST_SLOT = {
	grug_head = "head",
	grug_chest = "chest",
	grug_legs = "legs",
	grug_feet = "feet",
}

-- Equipment lists that provably cannot change what a character looks like.
-- Named one by one, like grug_abilities does: "not an appearance list" and
-- "a list I have never heard of" are different statements, and only the first
-- may skip the pass.
local IRRELEVANT_LIST = {
	grug_offhand = true, -- the offhand is not drawn yet (contract §1)
	grug_trinket1 = true,
	grug_trinket2 = true,
}

local players = {} -- player name -> {key, _grug_wield_obj, _grug_wield_item}

local function player_entry(name)
	local entry = players[name]
	if not entry then
		entry = {}
		players[name] = entry
	end
	return entry
end

-- What this player currently IS, in compose's vocabulary.
function grug_visuals.player_spec(player)
	local armor = {}
	local inv = player:get_inventory()
	if inv then
		for list, slot in pairs(ARMOR_LIST_SLOT) do
			local stack = inv:get_stack(list, 1)
			if stack and not stack:is_empty() then
				armor[slot] = stack:get_name()
			end
		end
	end
	-- grug_core's stub-override accessor, not grug_inventory's: the weapon slot
	-- is published there precisely so a consumer needs no dependency on the
	-- inventory mod, and the returned stack is our own copy.
	local weapon = grug_core.get_equipped_weapon(player)
	return {
		race = grug_classes.get_race(player),
		armor = armor,
		weapon = weapon and weapon:get_name() or nil,
	}
end

-- Compose and apply. Cheap on a no-op: one compose (cached) and one compare.
function grug_visuals.apply(player)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	local entry = player_entry(name)
	local result = grug_visuals.compose(grug_visuals.player_spec(player))
	if entry.key ~= result.key then
		entry.key = result.key
		-- player_api owns the texture list of the player model; going through
		-- it is what keeps its own bookkeeping (and the character-page preview,
		-- which reads the live object properties) correct.
		player_api.set_textures(player, result.textures)
	end
	if result.visual_size then
		-- VISUAL ONLY. collisionbox and eye_height stay with player_api's
		-- model/animation classes, which is why a tall elf still fits through a
		-- two-node door (contract §1).
		--
		-- UNCONDITIONAL, outside the texture token: the stature is not ours
		-- alone. mobs_redo's force_detach resets visual_size to {1, 1} on every
		-- dismount (mount.lua, also on leaveplayer), so a dwarf whose key has
		-- not changed would stay human-sized for the rest of the session. The
		-- texture list is the expensive write and stays guarded; this one is a
		-- two-number property.
		player:set_properties({visual_size = result.visual_size})
	end
	sync_wield(entry, player, result.weapon)
	return result
end

core.register_on_joinplayer(function(player)
	-- After player_api's own join hook (this mod depends on it, so its
	-- callbacks are registered first and run first): the model exists by now
	-- and set_textures has somewhere to write.
	grug_visuals.apply(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local entry = players[name]
	if entry and entry._grug_wield_obj then
		entry._grug_wield_obj:remove()
	end
	players[name] = nil
end)

core.register_on_respawnplayer(function(player)
	-- The token makes this a no-op for the skin; what it buys is a wield entity
	-- that went missing while the character was dead.
	grug_visuals.apply(player)
end)

grug_classes.register_on_race_chosen(function(player)
	grug_visuals.apply(player)
end)

grug_classes.register_on_class_chosen(function(player)
	-- A class change can unequip armor the new class may not wear; that write
	-- also fires the equipment seam, and this pass is idempotent either way.
	grug_visuals.apply(player)
end)

-- REGISTERED BEFORE grug_inventory's single page-refresh consumer, and that
-- ordering is load-bearing: the Character page renders the player's LIVE object
-- properties (pages.lua preview_model), so a refresh that runs before this
-- write shows the previous look until the next equip. grug_inventory therefore
-- carries `optional_depends = grug_visuals` -- the edge goes exactly one way,
-- because a mutual optional_depends is a dependency cycle. AGENTS.md allows
-- exactly one page-refresh consumer, so the fix is the order, not a second
-- refresh.
grug_core.register_on_equipment_change(function(player, listname)
	if listname and IRRELEVANT_LIST[listname] then
		return
	end
	grug_visuals.apply(player)
end)

--
-- Mobs and other humanoid entities (contract §2). The definition field
-- `_grug_visual` is either a spec table or a function(self) -> spec; the
-- function form is what lets a guard read its own runtime level.
--
-- mobs_redo copies only a whitelist of definition fields onto the entity
-- (api.lua register_mob), so `_grug_visual` never reaches `self`: the OWNER of
-- the registration captures it and hands it in here. grug_mobs does that in its
-- register_mob wrapper, grug_traders in the vendor definition's own
-- after_activate.
--
function grug_visuals.mob_visual(entity, cfg)
	local spec = cfg
	if type(cfg) == "function" then
		spec = cfg(entity)
	end
	if type(spec) ~= "table" then
		return nil
	end
	return grug_visuals.compose(spec)
end

-- Apply a composed look to a live entity.
--
-- `write_textures(entity, textures)` is optional and exists for grug_mobs: its
-- tier visuals (levels.lua) own `base_texture` and layer an elite's gold tint
-- on top of whatever the pristine list is, so the composed skin has to be
-- installed AS that pristine list rather than written over the tinted one.
-- Without it the plain write below is correct for an untiered NPC (a vendor).
--
-- `_grug_visual_skin` is a plain string field and therefore survives in
-- staticdata: after the first activation the composed list is already what
-- mob_activate restored, and the re-application is skipped.
function grug_visuals.apply_entity(entity, cfg, write_textures)
	if not entity or not entity.object then
		return nil
	end
	local result = grug_visuals.mob_visual(entity, cfg)
	if not result then
		return nil
	end
	local texture = result.textures[1]
	if entity._grug_visual_skin ~= texture then
		entity._grug_visual_skin = texture
		if write_textures then
			write_textures(entity, result.textures)
		else
			entity.base_texture = result.textures
			entity.textures = result.textures
			entity.object:set_properties({textures = result.textures})
		end
	end
	sync_wield(entity, entity.object, result.weapon)
	return result
end

--
-- Startup audits. Both print one action line when clean, the pattern the
-- grug_traders audits established: a check nobody sees the result of is a
-- check nobody notices breaking.
--
core.register_on_mods_loaded(function()
	local count = grug_visuals.index_armor(core.registered_items)
	core.log("action", "[grug_visuals] " .. count ..
		" armor pieces indexed for overlays, " ..
		#grug_visuals.LINES .. " art lines x " .. #grug_visuals.SLOTS ..
		" slots")

	-- Every race grug_classes offers must have art, or that character wears a
	-- stranger's skin with a warning on every login.
	local missing = {}
	for id in pairs(grug_classes.registered_races) do
		if not grug_visuals.RACES[id] then
			table.insert(missing, id)
		end
	end
	if #missing > 0 then
		table.sort(missing)
		core.log("error", "[grug_visuals] no skin for race(s) " ..
			table.concat(missing, ", ") .. " -- they fall back to " ..
			grug_visuals.FALLBACK_RACE)
	end

	-- The equipment list names above are grug_inventory's; check them against
	-- the real slot table when that mod is present.
	if core.global_exists("grug_inventory") and
			grug_inventory.equipment_slots then
		local known = {}
		for _, slot in ipairs(grug_inventory.equipment_slots) do
			known[slot.list] = true
		end
		local unknown = {}
		for list in pairs(ARMOR_LIST_SLOT) do
			if not known[list] then
				table.insert(unknown, list)
			end
		end
		for list in pairs(IRRELEVANT_LIST) do
			if not known[list] then
				table.insert(unknown, list)
			end
		end
		if #unknown > 0 then
			table.sort(unknown)
			core.log("error", "[grug_visuals] equipment list(s) " ..
				table.concat(unknown, ", ") ..
				" do not exist -- the armor overlay would never update")
		end
	end
end)
