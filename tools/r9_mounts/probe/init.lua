local meta = {}
function meta:get_string(key)
	if key == "grug_factions:faction" then return "accord" end
	if key == "grug_classes:race" then return "human" end
	return ""
end
function meta:get_int() return 0 end

local fake = {name = "r9_mount_probe", velocity = {x = 0, y = 0, z = 0},
	properties = {visual_size = {x = 1, y = 1}}}
function fake:is_player() return true end
function fake:get_player_name() return self.name end
function fake:get_meta() return meta end
function fake:set_attach(object) self.attached = object end
function fake:get_attach() return self.attached end
function fake:set_detach() self.attached = nil end
function fake:set_eye_offset() end
function fake:get_properties() return self.properties end
function fake:set_properties(values)
	for key, value in pairs(values) do self.properties[key] = value end
end
function fake:get_player_control() return {} end
function fake:get_look_horizontal() return 0 end
function fake:get_velocity() return self.velocity end
function fake:set_pos(value) self.pos = value end
function fake:add_velocity(value)
	self.velocity = {x = self.velocity.x + value.x,
		y = self.velocity.y + value.y, z = self.velocity.z + value.z}
end
function fake:hud_add() return 1 end
function fake:hud_change() end
function fake:hud_remove() end

local pos = {x = 0, y = 20, z = 0}
core.after(0, function()
	core.emerge_area(vector.offset(pos, -1, -1, -1), vector.offset(pos, 1, 1, 1),
		function(_, action, remaining)
			if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
				core.log("error", "R9_MOUNTS_PROBE emerge failed")
				core.request_shutdown("R9 mounts probe failed", false, 0)
				return
			end
			if remaining ~= 0 then return end
			local ok, message = grug_mounts.spawn_entity(fake, 1, pos, true)
			local record = grug_mounts.active[fake.name]
			local object = record and record.object
			local entity = object and object:get_luaentity()
			if not ok or not object or fake.attached ~= object or not entity or
					object:get_properties().static_save ~= false or
					object:get_properties().pointable ~= true or
					entity._grug_rider ~= fake or
					object:get_armor_groups().immortal ~= 1 then
				core.log("error", "R9_MOUNTS_PROBE attach failed: " .. tostring(message))
				core.request_shutdown("R9 mounts probe failed", false, 0)
				return
			end
			local apply_visuals = grug_visuals.apply
			grug_visuals.apply = function() end
			grug_mounts.dismount(fake, nil, true, true)
			grug_visuals.apply = apply_visuals
			core.log("action", "R9_MOUNTS_PROBE PASS entity=grug_mounts:mount " ..
				"rider=fake attached=true pointable=true rider_proxy=true " ..
				"static_save=false armor=immortal cleanup=true")
			core.request_shutdown("R9 mounts probe complete", false, 0.1)
		end)
end)
