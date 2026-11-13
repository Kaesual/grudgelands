-- x_player_api/proxies.lua
-- Manages visual proxy entity definitions, attachments, and lifecycle.

x_player_api = x_player_api or player_api

---@class PlayerProxies
---@field glb ObjectRef|nil Modern GLB visual proxy entity
---@field b3d ObjectRef|nil Legacy B3D visual proxy entity

---@type table<string, PlayerProxies> Active visual proxy entity instances by player name
x_player_api.active_proxies = {}

---Safe lighting collisionbox for visual proxies to sample ambient light within the player's core volume.
local PROXY_LIGHTING_BOX = x_player_api.PROXY_LIGHTING_BOX or {-0.25, 0.1, -0.25, 0.25, 1.75, 0.25}

-- GLB Visual Proxy
core.register_entity("x_player_api:visual_glb", {
	initial_properties = {
		hp_max = 1,
		physical = false,
		pointable = false,
		visual = "mesh",
		mesh = "character.glb",
		textures = {"character.png"},
		visual_size = {x = 1, y = 1},
		collisionbox = PROXY_LIGHTING_BOX,
		use_texture_alpha = false,
		backface_culling = false,
		is_visible = true,
		static_save = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_punch = function() return true end,
})

-- B3D Visual Proxy
core.register_entity("x_player_api:visual_b3d", {
	initial_properties = {
		hp_max = 1,
		physical = false,
		pointable = false,
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"character.png"},
		visual_size = {x = 1, y = 1},
		collisionbox = PROXY_LIGHTING_BOX,
		use_texture_alpha = false,
		backface_culling = false,
		is_visible = true,
		static_save = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_punch = function() return true end,
})

local wrapped_metatables = {}

---Wrap Player metatable to enforce hidden native player properties while visual proxies are active,
---and forward bone overrides to visual proxy entities.
---@param player ObjectRef Target player
function x_player_api.wrap_player_metatable(player)
	if not player then return end
	local meta = getmetatable(player)
	local target = (meta and meta.set_properties and meta) or (player.set_properties and player) or meta
	if not target or wrapped_metatables[target] then return end
	wrapped_metatables[target] = true

	if target.set_properties then
		local orig_set_properties = target.set_properties
		target.set_properties = function(self, props)
			if self and self.is_player and self:is_player() then
				local name = self:get_player_name()
				-- In pure native B3D mode, native player visual properties are genuine and must not be hidden
				if x_player_api.is_pure_native_b3d_active(self) then
					return orig_set_properties(self, props)
				end

				local proxies = x_player_api.active_proxies[name]
				if proxies then
					-- Forward genuine custom textures to visual proxies (ignoring transparent blanks)
					if props.textures then
						local is_blank = true
						for i = 1, #props.textures do
							local tex = props.textures[i]
							if tex ~= "blank.png" and tex ~= "" and not tex:find("trans") then
								is_blank = false
								break
							end
						end
						if not is_blank then
							local fwd_textures = props.textures
							local model_name = x_player_api.get_model_name(self)
							local model = model_name and x_player_api.get_model(model_name)
							if model and model.textures and #model.textures > #fwd_textures then
								local padded = table.copy(fwd_textures)
								for i = #fwd_textures + 1, #model.textures do
									padded[i] = model.textures[i] or "blank.png"
								end
								fwd_textures = padded
							end
							if proxies.glb and proxies.glb:is_valid() then
								proxies.glb:set_properties({ textures = fwd_textures })
							end
							if proxies.b3d and proxies.b3d:is_valid() then
								proxies.b3d:set_properties({ textures = fwd_textures })
							end
							if x_player_api._players[name] then
								x_player_api._players[name].textures = fwd_textures
							end
						end
					end
					-- Forward is_visible to visual proxies if specified
					if props.is_visible ~= nil then
						if proxies.glb and proxies.glb:is_valid() then
							proxies.glb:set_properties({ is_visible = props.is_visible })
						end
						if proxies.b3d and proxies.b3d:is_valid() then
							proxies.b3d:set_properties({ is_visible = props.is_visible })
						end
					end
					-- Forward visual_size to visual proxies if non-zero
					if props.visual_size and (props.visual_size.x ~= 0 or props.visual_size.y ~= 0) then
						if proxies.glb and proxies.glb:is_valid() then
							proxies.glb:set_properties({ visual_size = props.visual_size })
						end
						if proxies.b3d and proxies.b3d:is_valid() then
							proxies.b3d:set_properties({ visual_size = props.visual_size })
						end
					end
					-- Forward use_texture_alpha to visual proxies if specified
					if props.use_texture_alpha ~= nil then
						local b_alpha = (props.use_texture_alpha and props.use_texture_alpha ~= "opaque") and true or false
						if proxies.glb and proxies.glb:is_valid() then
							proxies.glb:set_properties({ use_texture_alpha = b_alpha })
						end
						if proxies.b3d and proxies.b3d:is_valid() then
							proxies.b3d:set_properties({ use_texture_alpha = b_alpha })
						end
					end
					-- Enforce that native player visual is ALWAYS a hidden 3D mesh with unit scale
					local safe_props = table.copy(props)
					safe_props.visual = "mesh"
					safe_props.mesh = "character.b3d"
					safe_props.visual_size = {x = 1, y = 1}
					safe_props.textures = {"blank.png", "blank.png", "blank.png"}
					safe_props.use_texture_alpha = true
					return orig_set_properties(self, safe_props)
				end
			end
			return orig_set_properties(self, props)
		end
	end

	-- Modern Luanti API: obj:set_bone_override(bone, override) with rotation.vec in radians
	if target.set_bone_override then
		local orig_set_bone_override = target.set_bone_override
		target.set_bone_override = function(self, bone, override)
			local res = orig_set_bone_override(self, bone, override)
			if self and self.is_player and self:is_player() then
				if not x_player_api.is_pure_native_b3d_active(self) then
					local proxies = x_player_api.get_visual_proxies(self)
					if proxies then
						if proxies.glb and proxies.glb:is_valid() then
							proxies.glb:set_bone_override(bone, override)
						end
						if proxies.b3d and proxies.b3d:is_valid() then
							local b3d_override = override
							if override and (override.rotation or override.position) then
								b3d_override = table.copy(override)
								if override.rotation and override.rotation.vec then
									local rv = override.rotation.vec
									b3d_override.rotation = table.copy(override.rotation)
									b3d_override.rotation.vec = {
										x = -(rv.x or 0),
										y = -(rv.y or 0),
										z = -(rv.z or 0),
									}
								end
								if override.position and override.position.vec then
									local pv = override.position.vec
									b3d_override.position = table.copy(override.position)
									b3d_override.position.vec = {
										x = -(pv.x or 0),
										y = pv.y or 0,
										z = -(pv.z or 0),
									}
								end
							end
							proxies.b3d:set_bone_override(bone, b3d_override)
						end
					end
				end
			end
			return res
		end
	end

	-- Modern Luanti API: obj:get_bone_override(bone)
	if target.get_bone_override then
		local orig_get_bone_override = target.get_bone_override
		target.get_bone_override = function(self, bone)
			if self and self.is_player and self:is_player() then
				if not x_player_api.is_pure_native_b3d_active(self) then
					local override = x_player_api.get_bone_override(self, bone)
					if override then
						return override.override_glb
					end
				end
			end
			return orig_get_bone_override(self, bone)
		end
	end
end

---Clean up a proxy entity and all of its attached children safely
---@param proxy ObjectRef Proxy entity reference
local function cleanup_proxy_and_children(proxy)
	if not proxy or not proxy:is_valid() then return end
	if proxy.get_children then
		local children = proxy:get_children()
		if children then
			for i = 1, #children do
				local child = children[i]
				if child and child:is_valid() then
					child:set_detach()
					child:remove()
				end
			end
		end
	end
	proxy:set_detach()
	proxy:remove()
end

---Initialize dual-model visual proxy entities and configure client cohorts for a joining player
---@param player ObjectRef Target player
local function setup_player_proxies(player)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()

	-- Only reuse proxies if both entities exist, are valid, and are actively attached to THIS player
	local existing = x_player_api.active_proxies[name]
	if existing then
		local glb_attached = existing.glb and existing.glb:is_valid() and existing.glb:get_attach() == player
		local b3d_attached = existing.b3d and existing.b3d:is_valid() and existing.b3d:get_attach() == player
		if glb_attached and b3d_attached then
			return existing
		end

		-- Existing proxies belong to an earlier session or are detached: clean them up
		cleanup_proxy_and_children(existing.glb)
		cleanup_proxy_and_children(existing.b3d)
		x_player_api.active_proxies[name] = nil
	end

	x_player_api.wrap_player_metatable(player)
	local pos = player:get_pos()

	-- Sweep engine children directly on player to prevent duplicate proxy attachments
	if player.get_children then
		local children = player:get_children()
		if children then
			for i = 1, #children do
				local child = children[i]
				if child and child:is_valid() then
					local ent = child:get_luaentity()
					if ent and (ent.name == "x_player_api:visual_glb" or ent.name == "x_player_api:visual_b3d") then
						child:set_detach()
						child:remove()
					end
				end
			end
		end
	end

	-- Sweep any unattached or orphaned proxy entities in the immediate area
	if core.get_objects_inside_radius and pos then
		local nearby = core.get_objects_inside_radius(pos, 5)
		if nearby then
			for i = 1, #nearby do
				local obj = nearby[i]
				if obj and obj:is_valid() and not obj:is_player() then
					local ent = obj:get_luaentity()
					if ent and (ent.name == "x_player_api:visual_glb" or ent.name == "x_player_api:visual_b3d") then
						local parent = obj:get_attach()
						if not parent or not parent:is_valid() or not parent:is_player() then
							obj:set_detach()
							obj:remove()
						end
					end
				end
			end
		end
	end

	-- Force cohort re-classification immediately so observer sets are populated before proxy creation
	x_player_api.ensure_player_cohort(name, true)

	local is_pure_b3d = x_player_api.is_pure_native_b3d_active(player)
	if is_pure_b3d then
		local model_name = x_player_api.get_model_name(player)
		local model = x_player_api.get_model(model_name)
		local mesh_b3d = (model and model.mesh and not model.mesh:match("%.glb$") and model.mesh)
			or (model and model.mesh_b3d) or "character.b3d"
		local pdata = x_player_api.get_player_data and x_player_api.get_player_data(player)
		local textures = (pdata and pdata.textures) or (model and model.textures) or {"character.png"}
		local texture_alpha = (model and model.use_texture_alpha ~= nil)
			and ((model.use_texture_alpha and model.use_texture_alpha ~= "opaque") and true or false) or false
		player:set_properties({
			visual = "mesh",
			mesh = mesh_b3d,
			visual_size = (model and model.visual_size) or {x = 1, y = 1},
			textures = textures,
			use_texture_alpha = texture_alpha,
		})
	else
		-- Hide native player visual, converting from 2D upright_sprite to unit-scale transparent mesh
		player:set_properties({
			visual = "mesh",
			mesh = "character.b3d",
			visual_size = {x = 1, y = 1},
			textures = {"blank.png", "blank.png", "blank.png"},
			use_texture_alpha = true,
		})
	end

	local glb_proxy = core.add_entity(pos, "x_player_api:visual_glb")
	local b3d_proxy = core.add_entity(pos, "x_player_api:visual_b3d")

	local active_format = x_player_api.get_model_format()
	if is_pure_b3d then
		if b3d_proxy then
			b3d_proxy:set_armor_groups({immortal = 1})
			b3d_proxy:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
			b3d_proxy:set_properties({visual_size = {x = 0, y = 0}, textures = {"blank.png"}})
		end
		if glb_proxy then
			glb_proxy:set_armor_groups({immortal = 1})
			glb_proxy:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
			glb_proxy:set_properties({visual_size = {x = 0, y = 0}, textures = {"blank.png"}})
		end
	elseif active_format == "b3d" then
		if b3d_proxy then
			b3d_proxy:set_armor_groups({immortal = 1})
			b3d_proxy:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
			b3d_proxy:set_observers(nil)
		end
		if glb_proxy then
			glb_proxy:set_armor_groups({immortal = 1})
			glb_proxy:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
			glb_proxy:set_properties({visual_size = {x = 0, y = 0}, textures = {"blank.png"}})
		end
	else
		if glb_proxy then
			glb_proxy:set_armor_groups({immortal = 1})
			glb_proxy:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
			glb_proxy:set_observers(x_player_api.get_modern_observers())
		end
		if b3d_proxy then
			b3d_proxy:set_armor_groups({immortal = 1})
			b3d_proxy:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
			b3d_proxy:set_observers(x_player_api.get_legacy_observers())
		end
	end

	x_player_api.active_proxies[name] = {
		glb = glb_proxy,
		b3d = b3d_proxy
	}
	return x_player_api.active_proxies[name]
end

---Get the active visual proxy entities for a player, auto-healing any invalid ObjectRefs
---@nodiscard
---@param player ObjectRef Target player
---@return PlayerProxies|nil proxies Visual proxy entity container
function x_player_api.get_visual_proxies(player)
	if not player or not player:is_player() then return nil end
	local name = player:get_player_name()
	local proxies = x_player_api.active_proxies[name]

	-- Auto-instantiate if called during early join callbacks before setup_player_proxies runs
	if not proxies then
		local connected = false
		local all_players = core.get_connected_players()
		for i = 1, #all_players do
			if all_players[i]:get_player_name() == name then
				connected = true
				break
			end
		end

		if not connected then return nil end

		setup_player_proxies(player)
		proxies = x_player_api.active_proxies[name]
		if not proxies then return nil end
	end

	if player:get_hp() <= 0 then
		return proxies
	end

	local glb_valid = proxies.glb and proxies.glb:is_valid()
	local b3d_valid = proxies.b3d and proxies.b3d:is_valid()

	if not glb_valid or not b3d_valid then
		setup_player_proxies(player)
		local pdata = x_player_api.get_animation(player)
		if pdata and pdata.model then
			local model_name = pdata.model
			if x_player_api._players[name] then
				x_player_api._players[name].model = nil
			end
			x_player_api.set_model(player, model_name)
		end
		return x_player_api.active_proxies[name]
	end

	return proxies
end

---Clean up dual-model visual proxy entities when a player disconnects
---@param player ObjectRef Leaving player
local function cleanup_player_proxies(player)
	if not player then return end
	if player.get_children then
		local children = player:get_children()
		if children then
			for i = 1, #children do
				local child = children[i]
				if child and child:is_valid() then
					local ent = child:get_luaentity()
					if ent and (ent.name == "x_player_api:visual_glb"
							or ent.name == "x_player_api:visual_b3d"
							or ent.name == "x_player_api:wield_item") then
						child:set_detach()
						child:remove()
					end
				end
			end
		end
	end
	local name = player:get_player_name()
	local proxies = x_player_api.active_proxies[name]
	if proxies then
		cleanup_proxy_and_children(proxies.glb)
		cleanup_proxy_and_children(proxies.b3d)
		x_player_api.active_proxies[name] = nil
	end
end

x_player_api.cleanup_player_proxies = cleanup_player_proxies

---Clean up all orphaned or disconnected player visual proxies across the server
---@return number count Number of cleaned up proxy entities
function x_player_api.cleanup_orphaned_proxies()
	local cleaned = 0
	for name, proxies in pairs(x_player_api.active_proxies) do
		local player = core.get_player_by_name(name)
		if not player then
			if proxies.glb and proxies.glb:is_valid() then
				cleanup_proxy_and_children(proxies.glb)
				cleaned = cleaned + 1
			end
			if proxies.b3d and proxies.b3d:is_valid() then
				cleanup_proxy_and_children(proxies.b3d)
				cleaned = cleaned + 1
			end
			x_player_api.active_proxies[name] = nil
		end
	end
	return cleaned
end

---Clean up all active proxy entities during server shutdown
local function on_shutdown_cleanup_proxies()
	for _, proxies in pairs(x_player_api.active_proxies) do
		cleanup_proxy_and_children(proxies.glb)
		cleanup_proxy_and_children(proxies.b3d)
	end
	x_player_api.active_proxies = {}
end

---Re-verify and enforce hidden native player properties and proxy attachment upon respawn
---@param player ObjectRef Respawned player
local function on_respawn_player_proxies(player)
	if not player or not player:is_player() then return end
	x_player_api.wrap_player_metatable(player)
	local is_pure_b3d = x_player_api.is_pure_native_b3d_active(player)
	if is_pure_b3d then
		local model_name = x_player_api.get_model_name(player)
		local model = x_player_api.get_model(model_name)
		local mesh_b3d = (model and model.mesh and not model.mesh:match("%.glb$") and model.mesh)
			or (model and model.mesh_b3d) or "character.b3d"
		local pdata = x_player_api.get_player_data and x_player_api.get_player_data(player)
		local textures = (pdata and pdata.textures) or (model and model.textures) or {"character.png"}
		local texture_alpha = (model and model.use_texture_alpha ~= nil)
			and ((model.use_texture_alpha and model.use_texture_alpha ~= "opaque") and true or false) or false
		player:set_properties({
			visual = "mesh",
			mesh = mesh_b3d,
			visual_size = (model and model.visual_size) or {x = 1, y = 1},
			textures = textures,
			use_texture_alpha = texture_alpha,
		})
	else
		-- Ensure native player visual remains hidden transparent 3D mesh with unit scale
		player:set_properties({
			visual = "mesh",
			mesh = "character.b3d",
			visual_size = {x = 1, y = 1},
			textures = {"blank.png", "blank.png", "blank.png"},
			use_texture_alpha = true,
		})
	end

	local name = player:get_player_name()
	local proxies = x_player_api.active_proxies[name]
	local glb_valid = proxies and proxies.glb and proxies.glb:is_valid()
	local b3d_valid = proxies and proxies.b3d and proxies.b3d:is_valid()

	if not glb_valid or not b3d_valid then
		setup_player_proxies(player)
		local pdata = x_player_api.get_animation(player)
		if pdata and pdata.model then
			local model_name = pdata.model
			if x_player_api._players[name] then
				x_player_api._players[name].model = nil
			end
			x_player_api.set_model(player, model_name)
		end
	else
		if proxies.glb:get_attach() ~= player then
			proxies.glb:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
		end
		if proxies.b3d:get_attach() ~= player then
			proxies.b3d:set_attach(player, "", {x=0, y=0, z=0}, {x=0, y=0, z=0})
		end
		local pdata = x_player_api.get_animation(player)
		local model_name = (pdata and pdata.model) or x_player_api.get_model_name(player)
		local model = x_player_api.get_model(model_name)
		local cur_fmt = (x_player_api.get_model_format and x_player_api.get_model_format()) or "both"
		local p_vsize = (model and model.visual_size) or {x = 1, y = 1}
		if proxies.glb then
			local glb_vs = (cur_fmt == "b3d") and {x = 0, y = 0} or p_vsize
			proxies.glb:set_properties({
				is_visible = true,
				visual_size = glb_vs,
				pointable = false,
			})
		end
		if proxies.b3d then
			local b3d_vs = (cur_fmt == "glb") and {x = 0, y = 0} or p_vsize
			proxies.b3d:set_properties({
				is_visible = true,
				visual_size = b3d_vs,
				pointable = false,
			})
		end
		x_player_api.refresh_observers(player)
	end
end

core.register_on_joinplayer(x_player_api.wrap_player_metatable)
core.register_on_joinplayer(setup_player_proxies)
core.register_on_leaveplayer(cleanup_player_proxies)
core.register_on_respawnplayer(on_respawn_player_proxies)
core.register_on_shutdown(on_shutdown_cleanup_proxies)

core.register_chatcommand("clean_proxies", {
	params = "",
	description = "Clean up orphaned or disconnected player visual proxies",
	privs = {server = true},
	func = function()
		local count = x_player_api.cleanup_orphaned_proxies()
		return true, "Cleaned up " .. count .. " orphaned proxy entities."
	end,
})
