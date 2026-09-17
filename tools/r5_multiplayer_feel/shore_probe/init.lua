-- Disposable engine measurement: a player-sized physical entity receives
-- forward velocity at a one-node bank. Change STEPHEIGHT to 0.6 in a temporary
-- probe copy for the before run; the shipped after probe uses 1.1.

grug_shore_step_probe = {}

local STEPHEIGHT = 1.1
local result
local started = false

local function log(message)
	core.log("action", "GRUG_SHORE_STEP " .. message)
end

local function entity_def()
	return {
		initial_properties = {
			physical = true,
			collide_with_objects = false,
			collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			stepheight = STEPHEIGHT,
			step_up_mode = "floaty",
			visual = "cube",
			visual_size = {x = 0.6, y = 1.7},
			textures = {"default_wood.png", "default_wood.png",
				"default_wood.png", "default_wood.png",
				"default_wood.png", "default_wood.png"},
			static_save = false,
		},
		on_activate = function(self)
			self.object:set_velocity({x = 2, y = 0, z = 0})
		end,
		on_step = function(self)
			local pos = self.object:get_pos()
			if pos then result = {x = pos.x, y = pos.y, z = pos.z} end
		end,
	}
end

core.register_entity("grug_shore_step_probe:runner", entity_def())

local function build_lane(z)
	for x = -2, 8 do
		for y = 0, 5 do
			core.set_node({x = x, y = y, z = z}, {name = "air"})
		end
		core.set_node({x = x, y = 0, z = z}, {name = "default:stone"})
	end
	for x = -2, 1 do
		core.set_node({x = x, y = 1, z = z}, {name = "default:water_source"})
	end
	for x = 2, 8 do
		core.set_node({x = x, y = 1, z = z}, {name = "default:stone"})
		core.set_node({x = x, y = 2, z = z}, {name = "default:stone"})
	end
end

local function start_measurement()
	if started then return end
	started = true
	build_lane(0)
	core.add_entity({x = 0, y = 1.5, z = 0},
		"grug_shore_step_probe:runner")
	core.after(3, function()
		if not result then
			log("result=FAIL reason=missing_entity")
			core.request_shutdown("shore step probe missing entity", false, 0)
			return
		end
		local climbed = result.x > 3 and result.y > 2.25
		log(("result=PASS stepheight=%.1f climbed=%s x=%.3f y=%.3f"):format(
			STEPHEIGHT, climbed and "yes" or "no", result.x, result.y))
		core.request_shutdown("shore step probe complete", false, 0)
	end)
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		core.emerge_area({x = -16, y = -16, z = -16}, {x = 16, y = 16, z = 16},
			function(_, action, remaining)
				if action == core.EMERGE_CANCELLED or
						action == core.EMERGE_ERRORED then
					log("result=FAIL reason=emerge")
					core.request_shutdown("shore step probe emerge failed", false, 0)
				elseif remaining == 0 then
					core.after(0, start_measurement)
				end
			end)
	end)
end)
