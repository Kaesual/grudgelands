-- x_player_api/models.lua
-- Handles model registration schemas, dual-model definitions, and fallback routing.

x_player_api = x_player_api or player_api

---@type table<string, ModelDefinition> Registry of model definitions by name
x_player_api.registered_models = x_player_api.registered_models or {}
---@type table<string, ModelDefinition>
local models = x_player_api.registered_models

---@type table<string, ModelRedirectRule> Model redirection rules
x_player_api.model_redirects = x_player_api.model_redirects or {}

---@class AnimationDefinition
---@field x? number Starting frame index for legacy single-track models
---@field y? number Ending frame index for legacy single-track models
---@field track? string Named glTF animation track identifier
---@field speed? number Animation playback speed multiplier or FPS
---@field loop? boolean Whether the animation loops indefinitely
---@field priority? number Animation track priority for skeletal blending
---@field eye_height? number Custom camera eye height during this animation
---@field collisionbox? number[] Custom player collision box {minx, miny, minz, maxx, maxy, maxz}
---@field override_local? boolean Whether local client animation prediction should be overridden
---@field _equals? string Internal property group equivalence key

---@class ModelDefinition
---@field base_model? string Optional base model name to inherit animations and physical defaults from
---@field mesh string Legacy B3D mesh filename
---@field mesh_glb? string Modern GLB mesh filename (optional)
---@field animations table<string, AnimationDefinition|string> Legacy B3D frame ranges
---@field animations_glb? table<string, AnimationDefinition|string> GLB track definitions
---@field visual_size? Vector2 Mesh scale vector
---@field collisionbox? number[] Base bounding collision box
---@field stepheight? number Step height for terrain navigation
---@field eye_height? number Base camera eye height
---@field animation_speed? number Default animation playback speed
---@field textures? string[] Default texture file list
---@field is_multitrack? boolean Internal flag if it has track layers
---@field override_local? boolean Whether local client animation prediction should be overridden

---Check if two 6-element collisionbox bounding boxes are coordinate-equal
---@nodiscard
---@param collisionbox number[]|nil First collisionbox {minx, miny, minz, maxx, maxy, maxz}
---@param other_collisionbox number[]|nil Second collisionbox
---@return boolean equals True if both collisionboxes have identical coordinates
local function collisionbox_equals(collisionbox, other_collisionbox)
	if collisionbox == other_collisionbox then
		return true
	end
	if not collisionbox or not other_collisionbox then
		return false
	end
	for index = 1, 6 do
		if collisionbox[index] ~= other_collisionbox[index] then
			return false
		end
	end
	return true
end

---Normalize animation definition table or string shorthand to standard structure
---@nodiscard
---@param anim_name string Default animation track name if not specified in table
---@param anim AnimationDefinition|string|table Shorthand track name or animation definition table
---@return AnimationDefinition normalized Normalized animation definition table
local function normalize_animation_def(anim_name, anim)
	if type(anim) == "string" then
		return {track = anim, priority = 0}
	elseif type(anim) == "table" then
		local copy = {}
		for k, v in pairs(anim) do
			copy[k] = v
		end
		if not copy.track and not copy.x then
			copy.track = anim_name
			copy.priority = copy.priority or 0
		end
		-- B3D character animations start at keyframe 1; frame 0 lacks keys causing bone bind uncoupling
		if copy.x and copy.x == 0 and copy.y and copy.y > 0 then
			copy.x = 1
		end
		return copy
	end
	return {track = anim_name, priority = 0}
end

---Recompute internal metadata for a model definition
---@param def ModelDefinition Model parameters and animation table
function x_player_api.recompute_model_metadata(def)
	if not def then return end

	local check_anims = def.animations_glb or def.animations
	if not check_anims then return end

	if def.is_multitrack == nil then
		def.is_multitrack = not not (check_anims.mine and check_anims.mine.track and not check_anims.walk_mine)
	end
	if def.animations_glb and next(def.animations_glb) ~= nil then
		def.is_multitrack = true
	end

	local anim_tables = {}
	if def.animations then table.insert(anim_tables, def.animations) end
	if def.animations_glb and def.animations_glb ~= def.animations then
		table.insert(anim_tables, def.animations_glb)
	end

	local has_extended = false
	for _, anims in ipairs(anim_tables) do
		for _, animation in pairs(anims) do
			animation._equals = nil
		end

		for animation_name, animation in pairs(anims) do
			if animation_name ~= "stand" and animation_name ~= "walk" and
				animation_name ~= "mine" and animation_name ~= "walk_mine" and
				animation_name ~= "sit" and animation_name ~= "lay" then
				has_extended = true
			end
			animation.eye_height = animation.eye_height or def.eye_height
			animation.collisionbox = animation.collisionbox or def.collisionbox
			local equals
			for _, other_animation in pairs(anims) do
				if other_animation._equals and
					other_animation.eye_height == animation.eye_height and
					collisionbox_equals(other_animation.collisionbox, animation.collisionbox) then
					equals = other_animation._equals
					break
				end
			end
			if not equals then
				equals = animation_name
			end
			animation._equals = equals
		end
	end

	if def.override_local == nil and has_extended then
		def.override_local = true
	end
end

local recompute_model_metadata = x_player_api.recompute_model_metadata

---Register a player 3D model with animation definitions and physical properties
---@param name string Model registry name (e.g. "character")
---@param def ModelDefinition Model parameters, animations, and physical properties
function x_player_api.register_model(name, def)
	-- Default mesh or mesh_glb from registration identifier when omitted
	if def.mesh == nil and def.mesh_glb == nil then
		if name:match("%.glb$") then
			def.mesh_glb = name
		else
			def.mesh = name
		end
	end

	-- Automatically default base_model to character.b3d for 3d_armor variants if unspecified
	if def.base_model == nil and name:find("3d_armor_character", 1, true) and models["character.b3d"] then
		def.base_model = "character.b3d"
	end

	-- Dynamically scan and wiggle B3D mesh if needed to prevent Irrlicht matrix decomposition bug
	if def.mesh and def.mesh:match("%.b3d$") and def.mesh:sub(1, 9) ~= "_wiggled_"
			and x_player_api.scan_and_wiggle_b3d_model then
		def.mesh = x_player_api.scan_and_wiggle_b3d_model(def.mesh)
	end

	-- Merge and preserve existing model properties if model is being re-registered
	local existing = models[name]
	if existing then
		if def.base_model == nil then def.base_model = existing.base_model end
		if def.mesh == nil then def.mesh = existing.mesh end
		if def.mesh_glb == nil then def.mesh_glb = existing.mesh_glb end
		if def.mesh_b3d == nil then def.mesh_b3d = existing.mesh_b3d end
		if def.is_multitrack == nil then def.is_multitrack = existing.is_multitrack end
		if def.animation_speed == nil then def.animation_speed = existing.animation_speed end
		if def.visual_size == nil and existing.visual_size then def.visual_size = table.copy(existing.visual_size) end
		if def.collisionbox == nil and existing.collisionbox then def.collisionbox = table.copy(existing.collisionbox) end
		if def.stepheight == nil then def.stepheight = existing.stepheight end
		if def.eye_height == nil then def.eye_height = existing.eye_height end
		if def.override_local == nil then def.override_local = existing.override_local end
		if def.textures == nil and existing.textures then def.textures = table.copy(existing.textures) end

		if not def.animations_glb and existing.animations_glb then
			def.animations_glb = {}
			for k, v in pairs(existing.animations_glb) do
				def.animations_glb[k] = v
			end
		elseif def.animations_glb and existing.animations_glb then
			for k, v in pairs(existing.animations_glb) do
				if def.animations_glb[k] == nil then
					def.animations_glb[k] = v
				end
			end
		end

		if not def.override_animations then
			if not def.animations and existing.animations then
				def.animations = {}
				for k, v in pairs(existing.animations) do
					def.animations[k] = v
				end
			elseif def.animations and existing.animations then
				for k, v in pairs(existing.animations) do
					if def.animations[k] == nil then
						def.animations[k] = v
					end
				end
			end
		end
	end

	if def.base_model and models[def.base_model] then
		local base = models[def.base_model]
		if def.mesh_glb == nil and base.mesh_glb then def.mesh_glb = base.mesh_glb end
		if def.mesh == nil and base.mesh then def.mesh = base.mesh end
		if def.animation_speed == nil then def.animation_speed = base.animation_speed end
		if def.visual_size == nil and base.visual_size then def.visual_size = table.copy(base.visual_size) end
		if def.collisionbox == nil and base.collisionbox then def.collisionbox = table.copy(base.collisionbox) end
		if def.stepheight == nil then def.stepheight = base.stepheight end
		if def.eye_height == nil then def.eye_height = base.eye_height end
		if def.is_multitrack == nil then def.is_multitrack = base.is_multitrack end
		if def.override_local == nil then def.override_local = base.override_local end
		if def.textures == nil and base.textures then def.textures = table.copy(base.textures) end

		if not def.animations and base.animations then
			def.animations = {}
			for k, v in pairs(base.animations) do
				def.animations[k] = v
			end
		elseif def.animations and base.animations then
			for k, v in pairs(base.animations) do
				local cur = def.animations[k]
				-- Replace missing animations, legacy dummy emote ranges (e.g. 192..196), or if override_animations is requested
				local is_dummy_emote = (k == "wave" or k == "point") and cur and cur.x and cur.y
					and (cur.x == 192 or (cur.x == 196 and cur.y == 196))
				if cur == nil or def.override_animations or is_dummy_emote then
					def.animations[k] = v
				end
			end
		end

		if not def.animations_glb and base.animations_glb then
			def.animations_glb = {}
			for k, v in pairs(base.animations_glb) do
				def.animations_glb[k] = v
			end
		elseif def.animations_glb and base.animations_glb then
			for k, v in pairs(base.animations_glb) do
				if def.animations_glb[k] == nil or def.override_animations then
					def.animations_glb[k] = v
				end
			end
		end
	end

	models[name] = def
	if def.mesh and def.mesh:sub(1, 9) == "_wiggled_" and def.mesh ~= name then
		models[def.mesh] = def
	end
	def.animations = def.animations or {}
	def.animations_glb = def.animations_glb or {}
	def.visual_size = def.visual_size or {x = 1, y = 1}
	def.collisionbox = def.collisionbox or {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}
	def.stepheight = def.stepheight or 0.6
	def.eye_height = def.eye_height or 1.47

	-- Normalize animations
	for animation_name, animation in pairs(def.animations) do
		def.animations[animation_name] = normalize_animation_def(animation_name, animation)
	end
	for animation_name, animation in pairs(def.animations_glb) do
		def.animations_glb[animation_name] = normalize_animation_def(animation_name, animation)
	end

	if next(def.animations_glb) ~= nil then
		def.is_multitrack = true
	end

	recompute_model_metadata(def)
end


---Get registered model definition
---@nodiscard
---@param name_or_player string|ObjectRef Model name or player object
---@return ModelDefinition|nil model Registered model definition or nil if not registered
function x_player_api.get_model(name_or_player)
	local model_name
	if type(name_or_player) == "userdata" or (type(name_or_player) == "table" and name_or_player.get_player_name) then
		local name = name_or_player:get_player_name()
		local data = x_player_api._players[name]
		model_name = data and data.model
	else
		model_name = name_or_player
	end
	if not model_name then return nil end

	local model = models[model_name]
	if not model and type(model_name) == "string" then
		local stripped = model_name:match("^_wiggled_(.*)")
		if stripped then
			model = models[stripped]
		end
	end
	return model
end

---Register a model redirect or dynamic transformer
---@param source_model string Source model name to intercept
---@param target_model_or_fn ModelRedirectRule Target model name or callback
function x_player_api.register_model_redirect(source_model, target_model_or_fn)
	x_player_api.model_redirects[source_model] = target_model_or_fn
end

---Register a new animation to an existing model
---@param model_name string Target model identifier
---@param anim_name string Animation track or action identifier
---@param def AnimationDefinition|string Animation configuration or track string
---@return boolean success Whether the animation was successfully registered
function x_player_api.register_model_animation(model_name, anim_name, def)
	local model = x_player_api.get_model(model_name)
	if not model then return false end
	if model_name:match("%.glb$") then
		model.animations_glb = model.animations_glb or {}
		model.animations_glb[anim_name] = normalize_animation_def(anim_name, def)
	else
		model.animations = model.animations or {}
		model.animations[anim_name] = normalize_animation_def(anim_name, def)
	end
	recompute_model_metadata(model)
	return true
end

---Edit an existing animation definition on a model
---@param model_name string Registered model name
---@param anim_name string Animation identifier
---@param def table Table of animation properties to update
---@return boolean success True if animation was found and updated
function x_player_api.edit_model_animation(model_name, anim_name, def)
	local model = x_player_api.get_model(model_name)
	if not model then return false end
	local anims = model_name:match("%.glb$") and model.animations_glb or model.animations
	if not anims or not anims[anim_name] then return false end

	for k, v in pairs(def) do
		anims[anim_name][k] = v
	end
	recompute_model_metadata(model)
	return true
end

---Remove an animation definition from a model
---@param model_name string Registered model name
---@param anim_name string Animation identifier to remove
---@return boolean success True if animation was removed
function x_player_api.remove_model_animation(model_name, anim_name)
	local model = x_player_api.get_model(model_name)
	if not model then return false end
	if model.animations_glb and model.animations_glb[anim_name] then
		model.animations_glb[anim_name] = nil
	end
	if model.animations and model.animations[anim_name] then
		model.animations[anim_name] = nil
	end
	recompute_model_metadata(model)
	return true
end

---Resolve model redirect rules (supports multi-hop chained redirects)
---@nodiscard
---@param player? ObjectRef Optional player context
---@param model_name string Requested model name
---@return string resolved_model Resolved model name
function x_player_api.resolve_model(player, model_name)
	if type(player) == "string" and model_name == nil then
		model_name = player
		player = nil
	end
	if not model_name then
		return ""
	end

	local current = model_name
	local visited = {}
	for _ = 1, 5 do
		visited[current] = true
		local next_model = nil
		local redirect = x_player_api.model_redirects[current]
		if type(redirect) == "function" then
			next_model = redirect(player, current)
		elseif type(redirect) == "string" then
			next_model = redirect
		end
		if not next_model then
			local wildcard = x_player_api.model_redirects["*"]
			if type(wildcard) == "function" then
				next_model = wildcard(player, current)
			elseif type(wildcard) == "string" then
				next_model = wildcard
			end
		end
		if not next_model or next_model == current or visited[next_model] then
			break
		end
		current = next_model
	end
	return current
end
