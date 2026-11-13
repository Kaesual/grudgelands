-- 3D Wield Items for x_player_api
-- Native 3D rendering attached to Arm_Right bone via ephemeral LuaEntity

---@class WieldOffsetDefinition
---@field pos? Vector3 Translation offset relative to base hand attachment
---@field pos_glb? Vector3 Format-specific translation offset for GLB models
---@field pos_b3d? Vector3 Format-specific translation offset for B3D models
---@field rot? Vector3 Euler rotation in degrees (X, Y, Z)
---@field rot_glb? Vector3 Format-specific Euler rotation for GLB models
---@field rot_b3d? Vector3 Format-specific Euler rotation for B3D models
---@field scale? Vector3|number Scale multipliers for visual_size
---@field glow? number Explicit entity glow override (0-14)

---Custom wield properties specified directly inside an item or node definition.
---Following Luanti engine conventions (lua_api.md), custom fields must use flat prefixes starting
---with an underscore (`_`) to avoid naming collisions with future engine usage.
---@class WieldItemCustomDef
---@field _wield_offset? Vector3 Translation offset relative to base hand attachment
---@field _wield_rotation? Vector3 Euler rotation in degrees (X, Y, Z)
---@field _wield_scale? Vector3|number Visual scale multiplier (scalar number or Vector3)
---@field _wield_glow? number Explicit entity glow brightness level (0-14)

---@class WieldItemEntityData
---@field obj ObjectRef|nil Active attached child LuaEntity (glb or b3d for backward compatibility)
---@field glb ObjectRef|nil Attached child entity for modern GLB visual proxy
---@field b3d ObjectRef|nil Attached child entity for legacy B3D visual proxy
---@field item string Current cached item key
---@field visible boolean User-controlled visibility flag
---@field first_person? boolean Per-player 1st person visibility preference
---@field attached_pos_glb? Vector3 Currently attached relative position on GLB proxy
---@field attached_rot_glb? Vector3 Currently attached relative rotation on GLB proxy
---@field attached_forced_glb? boolean Currently attached forced_visible flag on GLB proxy
---@field attached_pos_b3d? Vector3 Currently attached relative position on B3D proxy
---@field attached_rot_b3d? Vector3 Currently attached relative rotation on B3D proxy
---@field attached_forced_b3d? boolean Currently attached forced_visible flag on B3D proxy
---@field attached_pos? Vector3 Currently attached relative position (fallback)
---@field attached_rot? Vector3 Currently attached relative rotation (fallback)
---@field attached_forced? boolean Currently attached forced_visible flag (fallback)
---@field last_wield_name? string Last checked wielded item name

---@class WieldOffsetsRegistry
---@field types table<string, WieldOffsetDefinition>
---@field groups table<string, WieldOffsetDefinition>
---@field items table<string, WieldOffsetDefinition>

x_player_api = rawget(_G, "x_player_api") or rawget(_G, "player_api") or {}

local enable_wield_item = core.settings:get_bool("x_player_api.enable_wield_item", true)
local enable_left_wield_first_person = core.settings:get_bool("x_player_api.enable_left_wield_first_person", true)

---Whether 3D wielded item rendering attached to the player hand is enabled
---@type boolean
x_player_api.enable_wield_item = enable_wield_item

---Whether 3D wielded item in the left hand is visible in 1st person view by default
---@type boolean
x_player_api.enable_left_wield_first_person = enable_left_wield_first_person

---Set whether 3D wielded item rendering is enabled
---@param enabled boolean Whether 3D wield items should be active
function x_player_api.set_wield_item_enabled(enabled)
	local was_enabled = x_player_api.enable_wield_item
	x_player_api.enable_wield_item = (enabled == true)
	if was_enabled and not x_player_api.enable_wield_item then
		local players = core.get_connected_players()
		for i = 1, #players do
			x_player_api.remove_wield_item(players[i])
		end
	elseif not was_enabled and x_player_api.enable_wield_item then
		local players = core.get_connected_players()
		for i = 1, #players do
			x_player_api.attach_wield_item(players[i])
		end
	end
end

---@type table<string, WieldItemEntityData>
x_player_api.wield_entities = x_player_api.wield_entities or {}
local wield_entities = x_player_api.wield_entities

-- Base configuration constants (Right Hand - Arm_Right)
local BASE_BONE = "Arm_Right"
local BASE_POS_GLB = {x = 0, y = 5.2, z = -3.5}
local BASE_ROT_GLB = {x = -90, y = 45, z = -90}
local BASE_POS_B3D = {x = 0, y = 5.2, z = 3.5}
local BASE_ROT_B3D = {x = -90, y = 225, z = 90}
local BASE_SCALE_VAL = 0.275
local WIELD_UPDATE_INTERVAL = tonumber(core.settings:get("x_player_api.wield_update_interval")) or 0.2

x_player_api.BASE_POS_GLB = BASE_POS_GLB
x_player_api.BASE_ROT_GLB = BASE_ROT_GLB
x_player_api.BASE_POS_B3D = BASE_POS_B3D
x_player_api.BASE_ROT_B3D = BASE_ROT_B3D
x_player_api.BASE_POS = BASE_POS_GLB
x_player_api.BASE_ROT = BASE_ROT_GLB

-- Base configuration constants (Left Hand - Arm_Left)
local BASE_LEFT_BONE = "Arm_Left"
local BASE_LEFT_POS_GLB = {x = 0, y = 5.2, z = -3.5}
local BASE_LEFT_ROT_GLB = {x = -90, y = -45, z = 90}
local BASE_LEFT_POS_B3D = {x = 0, y = 5.2, z = 3.5}
local BASE_LEFT_ROT_B3D = {x = -90, y = 45, z = 90}

x_player_api.BASE_LEFT_BONE = BASE_LEFT_BONE
x_player_api.BASE_LEFT_POS_GLB = BASE_LEFT_POS_GLB
x_player_api.BASE_LEFT_ROT_GLB = BASE_LEFT_ROT_GLB
x_player_api.BASE_LEFT_POS_B3D = BASE_LEFT_POS_B3D
x_player_api.BASE_LEFT_ROT_B3D = BASE_LEFT_ROT_B3D

---@type table<string, LeftWieldEntityData>
x_player_api.left_wield_entities = x_player_api.left_wield_entities or {}
local left_wield_entities = x_player_api.left_wield_entities


-- Offset and rotation customization registry
---@type WieldOffsetsRegistry
x_player_api.wield_item_offsets = {
	types = {
		node = {
			pos = {x = 0, y = -0.3, z = 2.0},
			rot = {x = 180, y = 0, z = 0},
			scale = {x = 0.60, y = 0.60, z = 0.60},
		},
		tool = {
			pos = {x = 0, y = -0.3, z = 0},
			scale = {x = 1.33, y = 1.33, z = 1.33},
		},
		craft = {
			pos = {x = 0, y = -0.3, z = 1.8},
			rot = {x = 180, y = 0, z = 0},
		},
		craftitem = {
			pos = {x = 0, y = -0.3, z = 1.8},
			rot = {x = 180, y = 0, z = 0},
		},
	},
	groups = {
		torch = {
			pos = {x = 0, y = -0.3, z = -1},
			rot = {x = -90, y = 0, z = -90},
			rot_glb = {x = -90, y = 0, z = -90},
			rot_b3d = {x = -90, y = 180, z = 90},
		},
		sapling = {
			pos = {x = 0, y = -0.2, z = 0.2},
			rot = {x = 180, y = 0, z = 0},
		},
		flower = {
			pos = {x = 0, y = -0.2, z = 0.2},
			rot = {x = 180, y = 0, z = 0},
		},
		flora = {
			pos = {x = 0, y = -0.2, z = 0.2},
			rot = {x = 180, y = 0, z = 0},
		},
		plant = {
			pos = {x = 0, y = -0.2, z = 0.2},
			rot = {x = 180, y = 0, z = 0},
		},
		shovel = {
			pos = {x = 0, y = 0, z = 0},
		},
		bow = {
			pos = {x = 0, y = 0, z = 0},
			rot = {y = 45, z = -90},
		},
		vessel = {
			pos = {x = 0, y = 0, z = 0.2},
			rot = {x = 180, y = 0, z = 0},
		},
		bucket = {
			pos = {x = 0, y = 0, z = 0.2},
			rot = {x = 180, y = 0, z = 0},
		},
		screwdriver = {
			pos = {x = 0, y = 0, z = 0},
		},
	},
	items = {},
}

---Wielded item texture transformation registry
---Maps item names or group identifiers ("group:screwdriver") to texture transform modifier strings (e.g. "R90")
---Provides an agnostic mechanism for aligning items whose 2D artwork is drawn with non-standard rotations
x_player_api.wield_texture_transforms = {
	["screwdriver:screwdriver"] = "R90",
	["group:screwdriver"] = "R90",
}

---Register a texture transform modifier for a wielded item or group
---@param identifier string Item name ("screwdriver:screwdriver") or group ("group:screwdriver")
---@param transform string Transform modifier string without the "^[transform" prefix (e.g. "R90", "R270", "FX")
function x_player_api.register_wield_texture_transform(identifier, transform)
	x_player_api.wield_texture_transforms[identifier] = transform
	x_player_api.clear_wield_params_cache()
end

-- Memoized static wield attachment parameters cache (item_name -> params)
local WIELD_PARAMS_CACHE = {}

---Clear internal wield attachment parameter cache
function x_player_api.clear_wield_params_cache()
	WIELD_PARAMS_CACHE = {}
end

---Register a custom wield offset, rotation, or scale adjustment
---@param identifier string Item name ("default:sword_steel"), group ("group:sword"), or type ("type:node")
---@param def WieldOffsetDefinition Table containing pos, rot, scale, and/or glow overrides
function x_player_api.register_wield_item_offset(identifier, def)
	if identifier:find("^type:") then
		local type_name = identifier:sub(6)
		x_player_api.wield_item_offsets.types[type_name] = def
	elseif identifier:find("^group:") then
		local group_name = identifier:sub(7)
		x_player_api.wield_item_offsets.groups[group_name] = def
	else
		x_player_api.wield_item_offsets.items[identifier] = def
	end
	x_player_api.clear_wield_params_cache()
end

---Parse texture modifiers for rotation, flip, and colorization
---@param def table|nil Item definition table
---@param wield_stack any ItemStack or nil
---@param item_name? string Optional item name for texture transform lookup
---@return number rot_deg Rotation angle from texture modifiers (0, 90, 180, 270)
---@return string|nil item_color Extracted color string if specified
---@return boolean has_fx Whether horizontal flip modifier is present
local function parse_texture_modifiers(def, wield_stack, item_name)
	local rot_deg = 0
	local item_color = nil
	local has_fx = false

	-- Check ItemStack metadata for color
	if wield_stack and wield_stack.get_meta then
		local c = wield_stack:get_meta():get_string("color")
		if c ~= "" then
			item_color = c
		end
	end

	-- Check item definition color
	if not item_color and def then
		if type(def.color) == "string" and def.color ~= "" then
			item_color = def.color
		elseif type(def.color) == "table" then
			item_color = core.rgba(def.color.r or 255, def.color.g or 255, def.color.b or 255, def.color.a or 255)
		end
	end

	-- Extract texture string to inspect for modifiers
	local tex_str = ""
	if def then
		if type(def.wield_image) == "string" and def.wield_image ~= "" then
			tex_str = def.wield_image
		elseif type(def.wield_image) == "table" and def.wield_image.name then
			tex_str = def.wield_image.name
		elseif type(def.inventory_image) == "string" and def.inventory_image ~= "" then
			tex_str = def.inventory_image
		end
	end

	-- Resolve extra texture transforms if not explicitly defined on wield_image / inventory_image
	local extra_transform = nil
	if def then
		if type(def._wield_transform) == "string" and def._wield_transform ~= "" then
			extra_transform = def._wield_transform
		elseif def.groups then
			if def.groups.wield_transform then
				local wt = def.groups.wield_transform
				extra_transform = type(wt) == "number" and ("R" .. tostring(wt)) or tostring(wt)
			elseif def.groups.wield_rotation then
				local wr = def.groups.wield_rotation
				extra_transform = type(wr) == "number" and ("R" .. tostring(wr)) or tostring(wr)
			elseif def.groups.wieldview_transform then
				local wvt = def.groups.wieldview_transform
				extra_transform = type(wvt) == "number" and ("R" .. tostring(wvt)) or tostring(wvt)
			end
		end
	end

	if not extra_transform and item_name and item_name ~= "" then
		extra_transform = x_player_api.wield_texture_transforms[item_name]
	end

	if not extra_transform and def and def.groups then
		for group_name, rating in pairs(def.groups) do
			if (rating or 0) > 0 then
				local gt = x_player_api.wield_texture_transforms["group:" .. group_name]
				if gt then
					extra_transform = gt
					break
				end
			end
		end
	end

	if extra_transform and not tex_str:find("%^%[transform") then
		if extra_transform:find("^%^%[transform") then
			tex_str = tex_str .. extra_transform
		else
			tex_str = tex_str .. "^[transform" .. extra_transform
		end
	end

	if tex_str ~= "" then
		if tex_str:find("%^%[transform[^%^]*FX") then
			has_fx = true
		end

		-- Check for ^[transform... with R90, R180, R270
		for transform_args in tex_str:gmatch("%^%[transform([^%^]+)") do
			local r = transform_args:match("R(%d+)")
			if r then
				local rot_val = tonumber(r)
				if rot_val and rot_val > 0 then
					rot_deg = (rot_deg + rot_val) % 360
				end
			end
		end

		-- Check for ^[colorize:...
		if not item_color then
			local col = tex_str:match("%^%[colorize:([^:%^]+)")
			if col then
				item_color = col
			end
		end
	end

	return rot_deg, item_color, has_fx
end

---Apply scaling multiplier to a visual_size vector in-place
---@param visual_size Vector3 Target visual size vector
---@param scale number|Vector3|table|nil Scaling multiplier or dimensions table
local function apply_scale(visual_size, scale)
	if not scale then return end
	if type(scale) == "table" then
		visual_size.x = visual_size.x * (scale.x or 1.0)
		visual_size.y = visual_size.y * (scale.y or 1.0)
		visual_size.z = visual_size.z * (scale.z or 1.0)
	elseif type(scale) == "number" and scale > 0 then
		visual_size.x = visual_size.x * scale
		visual_size.y = visual_size.y * scale
		visual_size.z = visual_size.z * scale
	end
end

---Applies custom position, rotation, and scale offsets from a WieldOffsetDefinition
---@param pos Vector3 Working position vector to mutate
---@param rot Vector3 Working rotation vector to mutate
---@param visual_size Vector3 Working visual size vector to mutate
---@param override WieldOffsetDefinition Override table containing pos, rot, scale
---@param current_format "glb"|"b3d" Target model format
local function apply_override(pos, rot, visual_size, override, current_format)
	if not override then return end
	local override_pos = (current_format == "b3d" and override.pos_b3d)
		or (current_format == "glb" and override.pos_glb)
		or override.pos
	if override_pos then
		pos.x = pos.x + (override_pos.x or 0)
		pos.y = pos.y + (override_pos.y or 0)
		pos.z = pos.z + (override_pos.z or 0)
	end
	local override_rot = (current_format == "b3d" and override.rot_b3d)
		or (current_format == "glb" and override.rot_glb)
		or override.rot
	if override_rot then
		rot.x = override_rot.x or rot.x
		rot.y = override_rot.y or rot.y
		rot.z = override_rot.z or rot.z
	end
	apply_scale(visual_size, override.scale)
end

---Calculate visual_size, attachment position, rotation, glow, and color for a wielded item.
---Automatically adjusts attachment position coordinates and Euler rotation angles for B3D models
---to compensate for Blitz3D exporter axis inversions and align tool handles squarely in the palm.
---@nodiscard
---@param item_or_stack string|ItemStack ItemStack object or item name string
---@param format_override? string Optional model format override ("glb" or "b3d")
---@return Vector3 visual_size Normalised 3D scale vector
---@return Vector3 position Local attachment position offset
---@return Vector3 rotation Local Euler rotation angles
---@return number glow Entity glow brightness level (0-14)
---@return string|nil item_color Extracted color string if specified
function x_player_api.get_wield_attachment_params(item_or_stack, format_override)
	local item_name = ""
	local wield_stack = nil
	local has_meta = false
	if type(item_or_stack) == "userdata" or type(item_or_stack) == "table" then
		wield_stack = item_or_stack
		item_name = wield_stack.get_name and wield_stack:get_name() or ""
		if wield_stack.get_meta and wield_stack:get_meta() and wield_stack:get_meta().get_string
				and wield_stack:get_meta():get_string("color") ~= "" then
			has_meta = true
		end
	elseif type(item_or_stack) == "string" then
		item_name = item_or_stack:match("%S+") or ""
		if item_or_stack:find(" ") then
			wield_stack = ItemStack(item_or_stack)
			item_name = wield_stack.get_name and wield_stack:get_name() or ""
			if wield_stack.get_meta and wield_stack:get_meta() and wield_stack:get_meta().get_string
					and wield_stack:get_meta():get_string("color") ~= "" then
				has_meta = true
			end
		end
	end

	local current_format = format_override or x_player_api.get_model_format()
	local cache_key = item_name .. ":" .. current_format

	if not has_meta and item_name ~= "" then
		local cached = WIELD_PARAMS_CACHE[cache_key]
		if cached then
			return cached.visual_size, cached.pos, cached.rot, cached.glow, cached.item_color
		end
	end

	local def = core.registered_items[item_name] or {}
	local item_type = def.type or "unknown"

	-- Uniform sizing normalization:
	-- Luanti's C++ WieldMeshSceneNode internally multiplies meshes by itemdef.wield_scale.
	-- Normalize against wield_scale so all held items have consistent, uniform scale in hand.
	local ws_x, ws_y, ws_z = 1, 1, 1
	local item_ws = def.wield_scale
	if type(item_ws) == "table" then
		ws_x = (item_ws.x and item_ws.x > 0) and item_ws.x or 1
		ws_y = (item_ws.y and item_ws.y > 0) and item_ws.y or 1
		ws_z = (item_ws.z and item_ws.z > 0) and item_ws.z or 1
	elseif type(item_ws) == "number" and item_ws > 0 then
		ws_x, ws_y, ws_z = item_ws, item_ws, item_ws
	end

	local visual_size = {
		x = BASE_SCALE_VAL / ws_x,
		y = BASE_SCALE_VAL / ws_y,
		z = BASE_SCALE_VAL / ws_z,
	}

	-- Start with canonical hand transform
	local pos = {x = BASE_POS_GLB.x, y = BASE_POS_GLB.y, z = BASE_POS_GLB.z}
	local rot = (current_format == "b3d")
		and {x = BASE_ROT_B3D.x, y = BASE_ROT_B3D.y, z = BASE_ROT_B3D.z}
		or  {x = BASE_ROT_GLB.x, y = BASE_ROT_GLB.y, z = BASE_ROT_GLB.z}

	local rot_deg, item_color = parse_texture_modifiers(def, wield_stack, item_name)

	-- Apply type-level customizations if registered
	local type_override = x_player_api.wield_item_offsets.types[item_type]
	if type_override then
		apply_override(pos, rot, visual_size, type_override, current_format)
	end

	-- Apply group-level customizations if registered
	local active_group_override = nil
	if def.groups then
		for group_name, rating in pairs(def.groups) do
			if (rating or 0) > 0 then
				local group_override = x_player_api.wield_item_offsets.groups[group_name]
				if group_override then
					active_group_override = group_override
					apply_override(pos, rot, visual_size, group_override, current_format)
					break
				end
			end
		end
	end

	-- Apply exact item-level customizations if registered
	local item_override = x_player_api.wield_item_offsets.items[item_name]
	if item_override then
		apply_override(pos, rot, visual_size, item_override, current_format)
	end

	-- Direct item definition properties
	-- Following Luanti engine convention (lua_api.md), custom fields must use flat prefixes
	-- starting with '_' to avoid naming collisions with future engine usage.
	-- Supports:
	--   _wield_offset, _wield_rotation, _wield_scale, _wield_glow
	local custom_offset = def._wield_offset
	if custom_offset then
		pos.x = pos.x + (custom_offset.x or 0)
		pos.y = pos.y + (custom_offset.y or 0)
		pos.z = pos.z + (custom_offset.z or 0)
	end

	local custom_rot = def._wield_rotation
	if custom_rot then
		rot.x = custom_rot.x or rot.x
		rot.y = custom_rot.y or rot.y
		rot.z = custom_rot.z or rot.z
	end

	apply_scale(visual_size, def._wield_scale)

	-- Apply texture modifier rotation negation:
	-- If texture is rotated counter-clockwise by Luanti's ^[transformR<deg> (e.g. ^[transformR90 on shovels),
	-- compensate so held tool remains facing forward with handle in grip.
	if rot_deg ~= 0 then
		if item_type == "craftitem" or item_type == "craft" then
			rot.z = rot.z - rot_deg
		else
			rot.y = rot.y - rot_deg
		end
	end

	-- In B3D format, convert canonical hand transform into B3D bone coordinate space
	-- (B3D Arm_Right basis has X/Z inverted relative to GLB for position)
	if current_format == "b3d" then
		pos = {x = -pos.x, y = pos.y, z = -pos.z}
	end

	-- Convert item light_source to entity glow value
	-- Follows Luanti's standard item entity conversion: glow = floor(light_source / 2 + 0.5)
	local glow = 0
	if def._wield_glow ~= nil then
		glow = def._wield_glow
	else
		local light_source = def.light_source
		if not light_source and def.groups and def.groups.light_source then
			light_source = def.groups.light_source
		end
		if not light_source and core.registered_nodes[item_name] then
			local ndef = core.registered_nodes[item_name]
			light_source = ndef.light_source or (ndef.groups and ndef.groups.light_source)
		end

		if type(light_source) == "number" and light_source > 0 then
			glow = math.floor(light_source / 2 + 0.5)
		elseif type(light_source) == "boolean" and light_source then
			glow = math.floor((core.LIGHT_MAX or 14) / 2 + 0.5)
		end
	end

	-- Allow explicit glow override from wield_item_offsets if registered
	if item_override and item_override.glow ~= nil then
		glow = item_override.glow
	elseif active_group_override and active_group_override.glow ~= nil then
		glow = active_group_override.glow
	elseif type_override and type_override.glow ~= nil then
		glow = type_override.glow
	end

	glow = math.min(14, math.max(0, glow or 0))

	if not has_meta and item_name ~= "" then
		WIELD_PARAMS_CACHE[cache_key] = {
			visual_size = visual_size,
			pos = pos,
			rot = rot,
			glow = glow,
			item_color = item_color,
		}
	end
	return visual_size, pos, rot, glow, item_color
end

-- Ephemeral child LuaEntity definition
core.register_entity("x_player_api:wield_item", {
	initial_properties = {
		visual = "wielditem",
		wield_item = "",
		visual_size = {x = BASE_SCALE_VAL, y = BASE_SCALE_VAL, z = BASE_SCALE_VAL},
		pointable = false,
		physical = false,
		collide_with_objects = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		selectionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
		use_texture_alpha = true,
		backface_culling = false,
		is_visible = false,
		glow = 0,
	},
	on_activate = function(self)
		local object = self.object
		object:set_armor_groups({immortal = 1})
	end,
})

---Calculates visual size, position offset, rotation, glow, and color for a left-hand wielded item.
---Mirrors the canonical right-hand offsets onto Arm_Left coordinates.
---@nodiscard
---@param wield_stack string|ItemStack Held item name or ItemStack
---@param format_override? string Target mesh format ("glb" or "b3d")
---@return Vector3 visual_size Scaled entity visual_size
---@return Vector3 pos Relative translation vector on Arm_Left
---@return Vector3 rot Euler rotation in degrees on Arm_Left
---@return number glow Glow brightness (0-14)
---@return string? item_color Optional color tint
function x_player_api.get_left_wield_attachment_params(wield_stack, format_override)
	local v_size, r_pos, r_rot, glow, col = x_player_api.get_wield_attachment_params(wield_stack, format_override)
	local current_format = format_override or x_player_api.get_model_format()
	local base_pos = (current_format == "b3d") and BASE_LEFT_POS_B3D or BASE_LEFT_POS_GLB
	local base_rot = (current_format == "b3d") and BASE_LEFT_ROT_B3D or BASE_LEFT_ROT_GLB

	local right_base_pos = (current_format == "b3d") and BASE_POS_B3D or BASE_POS_GLB
	local right_base_rot = (current_format == "b3d") and BASE_ROT_B3D or BASE_ROT_GLB

	local delta_pos = {
		x = r_pos.x - right_base_pos.x,
		y = r_pos.y - right_base_pos.y,
		z = r_pos.z - right_base_pos.z,
	}
	local delta_rot = {
		x = r_rot.x - right_base_rot.x,
		y = r_rot.y - right_base_rot.y,
		z = r_rot.z - right_base_rot.z,
	}

	local pos = {
		x = base_pos.x - delta_pos.x,
		y = base_pos.y + delta_pos.y,
		z = base_pos.z + delta_pos.z,
	}
	local rot = {
		x = base_rot.x + delta_rot.x,
		y = base_rot.y - delta_rot.y,
		z = base_rot.z - delta_rot.z,
	}

	return v_size, pos, rot, glow, col
end

-- =============================================================================
-- Shared Wield Helper Subsystem (DRY Low-Level Engine)
-- =============================================================================

---Extracts item string and bare item name from string, ItemStack, or table
---@param item_or_stack string|ItemStack|table
---@return string stack_str Full item string representation
---@return string item_name Item name without count/wear/meta
local function parse_item_stack(item_or_stack)
	if type(item_or_stack) == "userdata" or type(item_or_stack) == "table" then
		local s = (item_or_stack.to_string and item_or_stack:to_string())
			or (item_or_stack.get_name and item_or_stack:get_name()) or ""
		local n = (item_or_stack.get_name and item_or_stack:get_name()) or ""
		return s, n
	elseif type(item_or_stack) == "string" then
		return item_or_stack, item_or_stack:match("%S+") or ""
	end
	return "", ""
end

---Constructs standard ObjectProperties for a wield item or custom mesh entity
---@param stack_str string Itemstack string
---@param is_empty boolean Whether item is empty / bare hand
---@param is_vis boolean Visibility flag
---@param v_size Vector3 Visual size
---@param glow number Glow level (0-14)
---@param col? string Color tint
---@param options? table Optional mesh/texture overrides
---@return table props ObjectProperties table
local function make_wield_properties(stack_str, is_empty, is_vis, v_size, glow, col, options)
	local props
	if options and options.mesh then
		props = {
			visual = options.visual or "mesh",
			mesh = options.mesh,
			textures = options.textures or {stack_str},
			visual_size = options.visual_size or {x = 1, y = 1, z = 1},
			glow = (options and options.glow) or glow or 0,
			pointable = false,
			use_texture_alpha = (options.use_texture_alpha == true),
			backface_culling = false,
			is_visible = is_vis,
		}
	else
		props = {
			visual = "wielditem",
			wield_item = stack_str,
			textures = {stack_str},
			visual_size = is_empty and {x = 0, y = 0, z = 0} or (options and options.visual_size) or v_size,
			glow = (options and options.glow) or glow or 0,
			pointable = false,
			use_texture_alpha = true,
			backface_culling = false,
			is_visible = is_vis,
		}
	end
	if col then
		props.color = col
	end
	return props
end

---Safely removes active child entities and resets cached transforms on a slot
---@param data WieldItemEntityData|LeftWieldEntityData
local function clear_wield_slot_data(data)
	if not data then return end
	if data.glb and data.glb:get_luaentity() then data.glb:remove(); data.glb = nil end
	if data.b3d and data.b3d:get_luaentity() then data.b3d:remove(); data.b3d = nil end
	if data.obj and data.obj:get_luaentity() then data.obj:remove(); data.obj = nil end
	data.attached_pos_glb = nil
	data.attached_rot_glb = nil
	data.attached_forced_glb = nil
	data.attached_pos_b3d = nil
	data.attached_rot_b3d = nil
	data.attached_forced_b3d = nil
	data.attached_pos = nil
	data.attached_rot = nil
	data.attached_forced = nil
end

---Applies position and rotation offsets or explicit overrides from options
---@param pos_glb Vector3
---@param rot_glb Vector3
---@param pos_b3d Vector3
---@param rot_b3d Vector3
---@param options? table
---@return Vector3 pos_glb, Vector3 rot_glb, Vector3 pos_b3d, Vector3 rot_b3d
local function apply_transform_options(pos_glb, rot_glb, pos_b3d, rot_b3d, options)
	if not options then
		return pos_glb, rot_glb, pos_b3d, rot_b3d
	end
	if options.override_transform then
		pos_glb = options.pos_glb or options.pos or pos_glb
		rot_glb = options.rot_glb or options.rot or rot_glb
		pos_b3d = options.pos_b3d or options.pos or pos_b3d
		rot_b3d = options.rot_b3d or options.rot or rot_b3d
	else
		local pg = options.pos_glb or options.pos
		if pg then
			pos_glb = {
				x = pos_glb.x + (pg.x or 0),
				y = pos_glb.y + (pg.y or 0),
				z = pos_glb.z + (pg.z or 0),
			}
		end
		local pb = options.pos_b3d or options.pos
		if pb then
			pos_b3d = {
				x = pos_b3d.x + (pb.x or 0),
				y = pos_b3d.y + (pb.y or 0),
				z = pos_b3d.z + (pb.z or 0),
			}
		end
		local rg = options.rot_glb or options.rot
		if rg then
			rot_glb = {
				x = rot_glb.x + (rg.x or 0),
				y = rot_glb.y + (rg.y or 0),
				z = rot_glb.z + (rg.z or 0),
			}
		end
		local rb = options.rot_b3d or options.rot
		if rb then
			rot_b3d = {
				x = rot_b3d.x + (rb.x or 0),
				y = rot_b3d.y + (rb.y or 0),
				z = rot_b3d.z + (rb.z or 0),
			}
		end
	end
	return pos_glb, rot_glb, pos_b3d, rot_b3d
end

---Attach or spawn a 3D wield item entity to an arbitrary entity bone (corpses, mobs, visual proxies)
---@param parent ObjectRef Target parent object to attach to
---@param item_or_stack string|ItemStack Held item name or ItemStack
---@param format_override? string Model format ("glb" or "b3d", defaults to active format or "b3d")
---@param bone? string Target bone name (defaults to "Arm_Right")
---@param entity_name? string Registered entity name (defaults to "x_player_api:wield_item")
---@param forced_visible? boolean Visibility override (true for standalone entities, false for player proxies)
---@param options? table Optional visual/mesh/transform options
---@return ObjectRef|nil wield_ent The spawned and attached entity or nil
function x_player_api.attach_wield_item_to_entity(
	parent, item_or_stack, format_override, bone, entity_name, forced_visible, options
)
	if not x_player_api.enable_wield_item then
		return nil
	end
	if not parent or not parent:is_valid() then
		return nil
	end
	local pos = parent.get_pos and parent:get_pos()
	if not pos then
		return nil
	end

	local target_bone = bone or BASE_BONE
	local fmt = format_override or x_player_api.get_model_format()
	local is_left = (target_bone == BASE_LEFT_BONE)

	local v_size, att_pos, att_rot, glow, item_col
	if is_left then
		v_size, att_pos, att_rot, glow, item_col = x_player_api.get_left_wield_attachment_params(item_or_stack, fmt)
	else
		v_size, att_pos, att_rot, glow, item_col = x_player_api.get_wield_attachment_params(item_or_stack, fmt)
	end

	if options then
		local pos_glb, rot_glb, pos_b3d, rot_b3d =
			apply_transform_options(att_pos, att_rot, att_pos, att_rot, options)
		if fmt == "glb" then
			att_pos, att_rot = pos_glb, rot_glb
		else
			att_pos, att_rot = pos_b3d, rot_b3d
		end
	end

	local stack_str, item_name = parse_item_stack(item_or_stack)
	local is_empty = (item_name == "")
		or (type(item_or_stack) == "userdata" and item_or_stack.is_empty and item_or_stack:is_empty())
	local is_vis = not is_empty
	local force_vis = true
	if forced_visible ~= nil then
		force_vis = forced_visible
	end

	local props = make_wield_properties(stack_str, is_empty, is_vis, v_size, glow, item_col, options)

	local ent_type = entity_name or "x_player_api:wield_item"
	local wield_ent = core.add_entity(pos, ent_type)
	if not wield_ent then
		return nil
	end

	wield_ent:set_properties(props)

	if wield_ent.set_attach then
		wield_ent:set_attach(parent, target_bone, att_pos, att_rot, force_vis)
	end
	return wield_ent
end

---Synchronizes format-specific proxies or direct fallback entities for a player hand slot
---@param player ObjectRef Target player
---@param data table Slot data table (wield_entities or left_wield_entities entry)
---@param target_bone string Bone to attach to (e.g. "Arm_Right" or "Arm_Left")
---@param pos_glb Vector3
---@param rot_glb Vector3
---@param props_glb table
---@param pos_b3d Vector3
---@param rot_b3d Vector3
---@param props_b3d table
---@param forced_vis boolean
---@return ObjectRef|nil entity Active attached entity
local function sync_player_wield_slot(
	player, data, target_bone, pos_glb, rot_glb, props_glb, pos_b3d, rot_b3d, props_b3d, forced_vis
)
	local pos = player:get_pos()
	if not pos then
		return nil
	end

	local proxies = x_player_api.get_visual_proxies(player)
	local is_pure_b3d = x_player_api.is_pure_native_b3d_active(player)

	if is_pure_b3d or not proxies or not (proxies.glb or proxies.b3d) then
		local obj_valid = data.obj and data.obj:get_luaentity() and data.obj:get_attach() == player
		if not obj_valid then
			if data.obj and data.obj:get_luaentity() then data.obj:remove() end
			local ent = core.add_entity(pos, "x_player_api:wield_item")
			if ent then
				ent:set_properties(props_b3d)
				ent:set_attach(player, target_bone, pos_b3d, rot_b3d, forced_vis)
				data.obj = ent
				data.attached_pos = pos_b3d
				data.attached_rot = rot_b3d
				data.attached_forced = forced_vis
			end
		else
			data.obj:set_properties(props_b3d)
			local last_pos = data.attached_pos
			local last_rot = data.attached_rot
			if not last_pos or not last_rot
					or pos_b3d.x ~= last_pos.x or pos_b3d.y ~= last_pos.y or pos_b3d.z ~= last_pos.z
					or rot_b3d.x ~= last_rot.x or rot_b3d.y ~= last_rot.y or rot_b3d.z ~= last_rot.z
					or data.attached_forced ~= forced_vis then
				data.obj:set_attach(player, target_bone, pos_b3d, rot_b3d, forced_vis)
				data.attached_pos = pos_b3d
				data.attached_rot = rot_b3d
				data.attached_forced = forced_vis
			end
		end
		if data.glb and data.glb:get_luaentity() then data.glb:remove(); data.glb = nil end
		if data.b3d and data.b3d:get_luaentity() then data.b3d:remove(); data.b3d = nil end
	else
		local active_fmt = x_player_api.get_model_format()
		local pdata = x_player_api.get_animation(player)
		local model_name = (pdata and pdata.model) or x_player_api.get_default_model()
		local model = model_name and x_player_api.get_model(model_name)
		local mesh_glb = (active_fmt ~= "b3d") and model and (model.mesh_glb
			or (model.mesh and model.mesh:sub(-4) == ".glb" and model.mesh))
		local mesh_b3d = model and ((model.mesh and model.mesh:sub(-4) ~= ".glb" and model.mesh)
			or model.mesh_b3d)
		local is_b3d_active = (active_fmt == "b3d") or not mesh_glb

		local glb_obs = nil
		if not is_b3d_active and (mesh_glb and mesh_b3d) then
			glb_obs = x_player_api.get_modern_observers()
		elseif is_b3d_active then
			glb_obs = x_player_api.get_modern_observers()
		end

		if proxies.glb and proxies.glb:is_valid() then
			local glb_valid = data.glb and data.glb:get_luaentity() and data.glb:get_attach() == proxies.glb
			if not glb_valid then
				if data.glb and data.glb:get_luaentity() then data.glb:remove() end
				local ent = core.add_entity(pos, "x_player_api:wield_item")
				if ent then
					ent:set_properties(props_glb)
					ent:set_observers(glb_obs)
					ent:set_attach(proxies.glb, target_bone, pos_glb, rot_glb, forced_vis)
					data.glb = ent
					data.attached_pos_glb = pos_glb
					data.attached_rot_glb = rot_glb
					data.attached_forced_glb = forced_vis
				end
			else
				data.glb:set_properties(props_glb)
				data.glb:set_observers(glb_obs)
				local last_pos = data.attached_pos_glb
				local last_rot = data.attached_rot_glb
				if not last_pos or not last_rot
						or pos_glb.x ~= last_pos.x or pos_glb.y ~= last_pos.y or pos_glb.z ~= last_pos.z
						or rot_glb.x ~= last_rot.x or rot_glb.y ~= last_rot.y or rot_glb.z ~= last_rot.z
						or data.attached_forced_glb ~= forced_vis then
					data.glb:set_attach(proxies.glb, target_bone, pos_glb, rot_glb, forced_vis)
					data.attached_pos_glb = pos_glb
					data.attached_rot_glb = rot_glb
					data.attached_forced_glb = forced_vis
				end
			end
		end

		if proxies.b3d and proxies.b3d:is_valid() then
			local b3d_obs = nil
			if not is_b3d_active then
				b3d_obs = x_player_api.get_legacy_observers()
			end
			local b3d_valid = data.b3d and data.b3d:get_luaentity() and data.b3d:get_attach() == proxies.b3d
			if not b3d_valid then
				if data.b3d and data.b3d:get_luaentity() then data.b3d:remove() end
				local ent = core.add_entity(pos, "x_player_api:wield_item")
				if ent then
					ent:set_properties(props_b3d)
					ent:set_observers(b3d_obs)
					ent:set_attach(proxies.b3d, target_bone, pos_b3d, rot_b3d, forced_vis)
					data.b3d = ent
					data.attached_pos_b3d = pos_b3d
					data.attached_rot_b3d = rot_b3d
					data.attached_forced_b3d = forced_vis
				end
			else
				data.b3d:set_properties(props_b3d)
				data.b3d:set_observers(b3d_obs)
				local last_pos = data.attached_pos_b3d
				local last_rot = data.attached_rot_b3d
				if not last_pos or not last_rot
						or pos_b3d.x ~= last_pos.x or pos_b3d.y ~= last_pos.y or pos_b3d.z ~= last_pos.z
						or rot_b3d.x ~= last_rot.x or rot_b3d.y ~= last_rot.y or rot_b3d.z ~= last_rot.z
						or data.attached_forced_b3d ~= forced_vis then
					data.b3d:set_attach(proxies.b3d, target_bone, pos_b3d, rot_b3d, forced_vis)
					data.attached_pos_b3d = pos_b3d
					data.attached_rot_b3d = rot_b3d
					data.attached_forced_b3d = forced_vis
				end
			end
		end

		data.obj = is_b3d_active and (data.b3d or data.glb) or (data.glb or data.b3d)
	end

	return data.obj or data.glb or data.b3d
end

---Updates forced_visible attachment state on a player slot's active entities
---@param player ObjectRef Target player
---@param data table Slot data
---@param bone string Bone name
---@param forced_vis boolean Forced visibility flag
---@param def_pos_glb Vector3
---@param def_rot_glb Vector3
---@param def_pos_b3d Vector3
---@param def_rot_b3d Vector3
local function update_slot_attachment_visibility(
	player, data, bone, forced_vis, def_pos_glb, def_rot_glb, def_pos_b3d, def_rot_b3d
)
	if not data then return end
	local proxies = x_player_api.get_visual_proxies(player)
	local is_pure_b3d = x_player_api.is_pure_native_b3d_active(player)

	if is_pure_b3d or not proxies or not (proxies.glb or proxies.b3d) then
		if data.obj and data.obj:get_luaentity() then
			local pos = data.attached_pos or def_pos_b3d
			local rot = data.attached_rot or def_rot_b3d
			data.obj:set_attach(player, bone, pos, rot, forced_vis)
			data.attached_forced = forced_vis
		end
	else
		if data.glb and data.glb:get_luaentity() and proxies.glb then
			local pos = data.attached_pos_glb or def_pos_glb
			local rot = data.attached_rot_glb or def_rot_glb
			data.glb:set_attach(proxies.glb, bone, pos, rot, forced_vis)
			data.attached_forced_glb = forced_vis
		end
		if data.b3d and data.b3d:get_luaentity() and proxies.b3d then
			local pos = data.attached_pos_b3d or def_pos_b3d
			local rot = data.attached_rot_b3d or def_rot_b3d
			data.b3d:set_attach(proxies.b3d, bone, pos, rot, forced_vis)
			data.attached_forced_b3d = forced_vis
		end
	end
end

-- =============================================================================
-- Right Hand Subsystem (Getters & Visibility)
-- =============================================================================

---Get the active wield item entity ObjectRef for a player
---@nodiscard
---@param player ObjectRef Target player
---@return ObjectRef|nil entity Active wield item entity or nil
function x_player_api.get_wield_entity(player)
	if not x_player_api.enable_wield_item then
		return nil
	end
	if not player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if not data then
		return nil
	end
	if data.obj and data.obj:get_luaentity() then
		return data.obj
	end
	return nil
end

---Set visibility of the wield item entity for a player
---@param player ObjectRef Target player
---@param visible boolean Whether held item should be rendered
function x_player_api.set_wield_item_visibility(player, visible)
	if not x_player_api.enable_wield_item then
		return
	end
	if not player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if not data then
		return
	end
	data.visible = visible
	local pdata = x_player_api.get_animation(player)
	local model = pdata and x_player_api.get_model(pdata.model)
	local active_format = x_player_api.get_model_format()
	local has_glb = (active_format ~= "b3d") and model and (model.mesh_glb or (model.mesh and model.mesh:match("%.glb$")))
	local has_b3d = not model or (model.mesh and not model.mesh:match("%.glb$")) or model.mesh_b3d

	if data.glb and data.glb:get_luaentity() then
		data.glb:set_properties({
			is_visible = (has_glb and visible and data.item ~= "") or false,
		})
	end
	if data.b3d and data.b3d:get_luaentity() then
		data.b3d:set_properties({
			is_visible = (has_b3d and visible and data.item ~= "") or false,
		})
	end
	if data.obj and data.obj:get_luaentity() and data.obj ~= data.glb and data.obj ~= data.b3d then
		data.obj:set_properties({
			is_visible = visible and data.item ~= "",
		})
	end
end

---Get visibility preference of the wield item entity for a player
---@nodiscard
---@param player ObjectRef Target player
---@return boolean visible Whether wield item entity is configured to be visible
function x_player_api.get_wield_item_visibility(player)
	if not player or not player:is_player() then
		return false
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if data and data.visible ~= nil then
		return data.visible
	end
	return true
end

-- =============================================================================
-- Left Hand Subsystem (Arm_Left Attachments)
-- =============================================================================

---Set whether 3D left-hand wielded items should be visible in 1st person view globally
---@param enabled boolean Whether 1st person left-hand wield items should be visible
function x_player_api.set_global_left_wield_first_person(enabled)
	x_player_api.enable_left_wield_first_person = (enabled == true)
	local players = core.get_connected_players()
	for i = 1, #players do
		x_player_api.update_left_wield_attachment_visibility(players[i])
	end
end

---Get whether 3D left-hand wield item is visible in 1st person view for a player
---@nodiscard
---@param player ObjectRef Target player
---@return boolean visible
function x_player_api.get_left_wield_first_person(player)
	if not player or not player:is_player() then
		return x_player_api.enable_left_wield_first_person == true
	end
	local name = player:get_player_name()
	local data = left_wield_entities[name]
	if data and data.first_person ~= nil then
		return data.first_person == true
	end
	return x_player_api.enable_left_wield_first_person == true
end

---Set whether 3D left-hand wield item should be visible in 1st person view for a specific player
---@param player ObjectRef Target player
---@param visible boolean|nil Visibility in first person (nil resets to global default)
function x_player_api.set_left_wield_first_person(player, visible)
	if not player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	local data = left_wield_entities[name]
	if not data then
		return
	end
	data.first_person = visible
	x_player_api.update_left_wield_attachment_visibility(player)
end

---Updates forced_visible attachment state on left-hand wield entities
---@param player ObjectRef Target player
function x_player_api.update_left_wield_attachment_visibility(player)
	if not player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	local data = left_wield_entities[name]
	if not data then
		return
	end
	local forced_vis = x_player_api.get_left_wield_first_person(player)
	local target_bone = (data.options and data.options.bone) or BASE_LEFT_BONE
	update_slot_attachment_visibility(
		player, data, target_bone, forced_vis,
		BASE_LEFT_POS_GLB, BASE_LEFT_ROT_GLB, BASE_LEFT_POS_B3D, BASE_LEFT_ROT_B3D
	)
end

---Attach or configure a 3D wield item on the player's left hand (Arm_Left) following SOLID principles.
---Optionally visible in 1st person view via options.first_person.
---@param player ObjectRef Target player
---@param item_or_stack string|ItemStack Held item name or ItemStack
---@param options? table Optional params: first_person, pos, rot, scale, glow, bone
---@return ObjectRef|nil entity Attached entity reference or nil
function x_player_api.attach_left_wield_item(player, item_or_stack, options)
	if not x_player_api.enable_wield_item then
		return nil
	end
	if not player or not player:is_player() then
		return nil
	end

	local name = player:get_player_name()
	local data = left_wield_entities[name]
	if not data then
		data = {
			obj = nil,
			glb = nil,
			b3d = nil,
			item = "",
			visible = true,
			first_person = nil,
			options = {},
		}
		left_wield_entities[name] = data
	end

	if type(options) == "table" and options.first_person ~= nil then
		data.first_person = (options.first_person == true)
	end
	data.options = options or {}
	local forced_vis = x_player_api.get_left_wield_first_person(player)

	local stack_str, item_name = parse_item_stack(item_or_stack)
	data.item = item_name

	local pdata = x_player_api.get_animation(player)
	local model_name = (pdata and pdata.model) or x_player_api.get_default_model()
	local model = model_name and x_player_api.get_model(model_name)
	local active_format = x_player_api.get_model_format()
	local has_glb = (active_format ~= "b3d") and model and (model.mesh_glb or (model.mesh and model.mesh:match("%.glb$")))
	local has_b3d = not model or (model.mesh and not model.mesh:match("%.glb$")) or model.mesh_b3d

	local target_bone = (options and options.bone) or BASE_LEFT_BONE
	local v_size_glb, pos_glb, rot_glb, glow_glb, col_glb =
		x_player_api.get_left_wield_attachment_params(item_or_stack, "glb")
	local v_size_b3d, pos_b3d, rot_b3d, glow_b3d, col_b3d =
		x_player_api.get_left_wield_attachment_params(item_or_stack, "b3d")

	pos_glb, rot_glb, pos_b3d, rot_b3d = apply_transform_options(
		pos_glb, rot_glb, pos_b3d, rot_b3d, options
	)

	local is_empty = (item_name == "")
	local is_vis_glb = not is_empty and (has_glb and true or false) and (data.visible ~= false)
	local is_vis_b3d = not is_empty and (has_b3d and true or false) and (data.visible ~= false)
	local props_glb = make_wield_properties(
		stack_str, is_empty or not has_glb, is_vis_glb, v_size_glb, glow_glb, col_glb, options
	)
	local props_b3d = make_wield_properties(
		stack_str, is_empty or not has_b3d, is_vis_b3d, v_size_b3d, glow_b3d, col_b3d, options
	)

	return sync_player_wield_slot(
		player, data, target_bone,
		pos_glb, rot_glb, props_glb,
		pos_b3d, rot_b3d, props_b3d,
		forced_vis
	)
end

---Updates or modifies the left-hand wield item on a player.
---@param player ObjectRef Target player
---@param item_or_stack? string|ItemStack Held item name or ItemStack
---@param options? table Optional params: first_person, pos, rot, scale, glow
---@return ObjectRef|nil entity Attached entity reference or nil
function x_player_api.update_left_wield_item(player, item_or_stack, options)
	if not player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local data = left_wield_entities[name]
	local item = item_or_stack or (data and data.item) or ""
	local opts = options or (data and data.options) or {}
	return x_player_api.attach_left_wield_item(player, item, opts)
end

---Removes the left hand wield item entity from a player.
---@param player ObjectRef|string Target player or player name
function x_player_api.remove_left_wield_item(player)
	if not player then
		return
	end
	local name
	if type(player) == "string" then
		name = player
	elseif player.is_player and player:is_player() then
		name = player:get_player_name()
	else
		return
	end
	local data = left_wield_entities[name]
	if data then
		clear_wield_slot_data(data)
		left_wield_entities[name] = nil
	end
end

---Returns the currently attached left-hand item name for a player.
---@param player ObjectRef|string Target player or player name
---@return string item_name
function x_player_api.get_left_wield_item(player)
	if not player then
		return ""
	end
	local name
	if type(player) == "string" then
		name = player
	elseif player.is_player and player:is_player() then
		name = player:get_player_name()
	else
		return ""
	end
	local data = left_wield_entities[name]
	return (data and data.item) or ""
end

---Returns the active left-hand wield entity reference for a player.
---@param player ObjectRef Target player
---@return ObjectRef|nil entity
function x_player_api.get_left_wield_entity(player)
	if not player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local data = left_wield_entities[name]
	if not data then return nil end
	local active_fmt = x_player_api.get_model_format()
	local pdata = x_player_api.get_animation(player)
	local model_name = (pdata and pdata.model) or x_player_api.get_default_model()
	local model = model_name and x_player_api.get_model(model_name)
	local mesh_glb = (active_fmt ~= "b3d") and model and (model.mesh_glb
		or (model.mesh and model.mesh:sub(-4) == ".glb" and model.mesh))
	local is_b3d_active = (active_fmt == "b3d") or not mesh_glb
	if is_b3d_active then
		return data.b3d or data.glb or data.obj
	end
	return data.glb or data.b3d or data.obj
end

-- =============================================================================
-- Right Hand Subsystem (Arm_Right Attachments & Update Loop)
-- =============================================================================

---Attach or re-attach the ephemeral wield item entity to player's Arm_Right bone
---@param player ObjectRef Target player
---@param force? boolean Force recreation of existing entity
---@return ObjectRef|nil entity Attached entity reference or nil
function x_player_api.attach_wield_item(player, force)
	if not x_player_api.enable_wield_item then
		return nil
	end
	if not player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if not data then
		data = {
			obj = nil,
			glb = nil,
			b3d = nil,
			item = "",
			visible = true,
		}
		wield_entities[name] = data
	end
	if force then
		clear_wield_slot_data(data)
	end
	x_player_api.update_wield_item(player, true)
	return data.glb or data.b3d or data.obj
end

---Remove the wield item entity for a player
---@param player ObjectRef|string Target player or player name
function x_player_api.remove_wield_item(player)
	if not player then
		return
	end
	local name
	if type(player) == "string" then
		name = player
	elseif player.is_player and player:is_player() then
		name = player:get_player_name()
	else
		return
	end
	local data = wield_entities[name]
	if data then
		clear_wield_slot_data(data)
		wield_entities[name] = nil
	end
end

---Update held wield item on the child entity (throttled delta check)
---@param player ObjectRef Target player
---@param force boolean? Force entity property updates even if held item unchanged
---@param wield_stack ItemStack? Optional cached wield ItemStack to avoid redundant get_wielded_item call
function x_player_api.update_wield_item(player, force, wield_stack)
	if not x_player_api.enable_wield_item then
		return
	end
	if not player or not player:is_player() then
		return
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if not data then
		return
	end

	-- Dead players hide wield item
	if player:get_hp() <= 0 or data.visible == false then
		if data.item ~= "" or force then
			data.item = ""
			local hide_props = {
				is_visible = false,
				wield_item = "",
				glow = 0,
			}
			if data.glb and data.glb:get_luaentity() then
				data.glb:set_properties(hide_props)
			end
			if data.b3d and data.b3d:get_luaentity() then
				data.b3d:set_properties(hide_props)
			end
			if data.obj and data.obj:get_luaentity() and data.obj ~= data.glb and data.obj ~= data.b3d then
				data.obj:set_properties(hide_props)
			end
		end
		return
	end

	wield_stack = wield_stack or player:get_wielded_item()
	local item_name = (wield_stack and wield_stack:get_name()) or ""

	-- Item identity key: combines item_name with color metadata so color changes trigger updates
	local item_key = item_name
	if wield_stack and wield_stack.get_meta then
		local c = wield_stack:get_meta():get_string("color")
		if c ~= "" then
			item_key = item_name .. ":" .. c
		end
	end

	local needs_reattach = false
	local proxies = x_player_api.get_visual_proxies(player)
	local is_pure_b3d = x_player_api.is_pure_native_b3d_active(player)

	if is_pure_b3d or not proxies or not (proxies.glb or proxies.b3d) then
		if not data.obj or not data.obj:get_luaentity() or data.obj:get_attach() ~= player then
			needs_reattach = true
		end
	else
		if proxies.glb and proxies.glb:is_valid() then
			if not data.glb or not data.glb:get_luaentity() or data.glb:get_attach() ~= proxies.glb then
				needs_reattach = true
			end
		end
		if proxies.b3d and proxies.b3d:is_valid() then
			if not data.b3d or not data.b3d:get_luaentity() or data.b3d:get_attach() ~= proxies.b3d then
				needs_reattach = true
			end
		end
	end

	-- If item identity has not changed and not forced, skip completely
	if not force and not needs_reattach and item_key == data.item then
		return
	end

	data.item = item_key

	local is_empty = (item_name == "")
		or (wield_stack and wield_stack.is_empty and wield_stack:is_empty())
	local stack_str = (wield_stack and wield_stack.to_string and wield_stack:to_string()) or item_name
	local pdata = x_player_api.get_animation(player)
	local model = pdata and x_player_api.get_model(pdata.model)
	local active_format = x_player_api.get_model_format()
	local has_glb = (active_format ~= "b3d") and model and (model.mesh_glb or (model.mesh and model.mesh:match("%.glb$")))
	local has_b3d = not model or (model.mesh and not model.mesh:match("%.glb$")) or model.mesh_b3d

	local v_size_glb, pos_glb, rot_glb, glow_glb, col_glb = x_player_api.get_wield_attachment_params(wield_stack, "glb")
	local v_size_b3d, pos_b3d, rot_b3d, glow_b3d, col_b3d = x_player_api.get_wield_attachment_params(wield_stack, "b3d")

	local is_vis_glb = not is_empty and (has_glb and true or false) and (data.visible ~= false)
	local is_vis_b3d = not is_empty and (has_b3d and true or false) and (data.visible ~= false)

	local props_glb = make_wield_properties(stack_str, is_empty or not has_glb, is_vis_glb, v_size_glb, glow_glb, col_glb)
	local props_b3d = make_wield_properties(stack_str, is_empty or not has_b3d, is_vis_b3d, v_size_b3d, glow_b3d, col_b3d)

	sync_player_wield_slot(
		player, data, BASE_BONE,
		pos_glb, rot_glb, props_glb,
		pos_b3d, rot_b3d, props_b3d,
		false
	)
end

x_player_api.WIELD_UPDATE_INTERVAL = WIELD_UPDATE_INTERVAL

---Step wield item for an individual player (called during unified globalstep)
---@param player ObjectRef Target player
---@param is_throttled_tick boolean Whether periodic throttle interval has elapsed
function x_player_api.step_player_wield(player, is_throttled_tick)
	if not x_player_api.enable_wield_item then
		return
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if data and data.obj then
		local pstates = x_player_api.controls.player_states
		local pstate = pstates and pstates[name]
		local wield_stack = (pstate and pstate.wielded_item) or player:get_wielded_item()
		local item_name = (pstate and pstate.wield_name) or (wield_stack and wield_stack:get_name()) or ""
		-- Fast-path: instantly update on item swap or run on periodic throttle
		if (item_name ~= data.last_wield_name) or is_throttled_tick then
			local item_changed = (item_name ~= data.last_wield_name)
			data.last_wield_name = item_name
			x_player_api.update_wield_item(player, false, wield_stack)

			-- Trigger upper-body skeletal equip montage on weapon/item switch if model supports it
			if item_changed and item_name ~= "" then
				local time_now = core.get_us_time() * 0.000001
				local sem_state = pstate and pstate.semantic_state
				local is_eating = (pstate and pstate.eat_until and (pstate.eat_until > time_now))
					or (sem_state and sem_state.eating)
				local is_attacking = (pstate and pstate.controls and (pstate.controls.LMB or pstate.controls.dig))
					or (sem_state and sem_state.acting)
				local is_rmb = pstate and pstate.controls and (pstate.controls.RMB or pstate.controls.place)
				local item_info = pstate and pstate.item_info
				local is_blocking = (sem_state and sem_state.blocking)
					or (is_rmb and item_info and item_info.is_shield)
				local is_aiming_bow = (sem_state and sem_state.aiming_bow)
					or (item_info and item_info.is_bow and (item_info.is_bow_charged or is_rmb))

				if not is_eating and not is_attacking and not is_blocking and not is_aiming_bow then
					x_player_api.trigger_equip(player, item_name)
				end
			end
		end
	elseif is_throttled_tick then
		x_player_api.update_wield_item(player, false)
	end
end

-- Globalstep handler: delegates to unified step if api.lua globalstep is active,
-- otherwise operates in standalone mode for isolated testing environments
local wield_timer = 0
core.register_globalstep(function(dtime)
	if x_player_api._wield_unified_active then
		return
	end
	if not x_player_api.enable_wield_item then
		return
	end
	wield_timer = wield_timer + dtime
	local is_throttled_tick = (wield_timer >= WIELD_UPDATE_INTERVAL)
	if is_throttled_tick then
		wield_timer = 0
	end

	local connected = core.get_connected_players()
	for i = 1, #connected do
		x_player_api.step_player_wield(connected[i], is_throttled_tick)
	end
end)

-- Player Lifecycle Event Handlers
core.register_on_joinplayer(function(player)
	if not x_player_api.enable_wield_item then
		return
	end
	local name = player:get_player_name()
	local wield_stack = player:get_wielded_item()
	local initial_item = (wield_stack and wield_stack:get_name()) or ""
	wield_entities[name] = {
		obj = nil,
		item = "",
		visible = true,
		last_wield_name = initial_item,
	}
	-- Delay attachment by 0.5s to ensure client has loaded character model mesh
	core.after(0.5, function()
		local p = core.get_player_by_name(name)
		if p then
			x_player_api.attach_wield_item(p)
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	x_player_api.remove_wield_item(player)
	x_player_api.remove_left_wield_item(player)
end)

core.register_on_dieplayer(function(player)
	if not x_player_api.enable_wield_item then
		return
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if data then
		data.item = ""
		local hide_props = {
			is_visible = false,
			wield_item = "",
			glow = 0,
		}
		if data.glb and data.glb:get_luaentity() then
			data.glb:set_properties(hide_props)
		end
		if data.b3d and data.b3d:get_luaentity() then
			data.b3d:set_properties(hide_props)
		end
		if data.obj and data.obj:get_luaentity() and data.obj ~= data.glb and data.obj ~= data.b3d then
			data.obj:set_properties(hide_props)
		end
	end
	local left_data = left_wield_entities[name]
	if left_data then
		local hide_props = {
			is_visible = false,
			wield_item = "",
			glow = 0,
		}
		if left_data.glb and left_data.glb:get_luaentity() then
			left_data.glb:set_properties(hide_props)
		end
		if left_data.b3d and left_data.b3d:get_luaentity() then
			left_data.b3d:set_properties(hide_props)
		end
		local obj = left_data.obj
		if obj and obj:get_luaentity() and obj ~= left_data.glb and obj ~= left_data.b3d then
			obj:set_properties(hide_props)
		end
	end
end)

core.register_on_respawnplayer(function(player)
	if not x_player_api.enable_wield_item then
		return
	end
	local name = player:get_player_name()
	local data = wield_entities[name]
	if data then
		data.item = ""
		core.after(0.1, function()
			local p = core.get_player_by_name(name)
			if p then
				x_player_api.attach_wield_item(p)
			end
		end)
	end
	local left_data = left_wield_entities[name]
	if left_data and left_data.item ~= "" then
		core.after(0.1, function()
			local p = core.get_player_by_name(name)
			if p then
				x_player_api.update_left_wield_item(p)
			end
		end)
	end
end)
