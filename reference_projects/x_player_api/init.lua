local modname = core.get_current_modname()
local modpath = core.get_modpath(modname) or
	core.get_modpath("x_player_api") or core.get_modpath("player_api")

dofile(modpath .. "/api.lua")
dofile(modpath .. "/b3d_wiggler.lua")
dofile(modpath .. "/models.lua")
dofile(modpath .. "/observers.lua")
dofile(modpath .. "/proxies.lua")
dofile(modpath .. "/bone_overrides.lua")
dofile(modpath .. "/wield.lua")
dofile(modpath .. "/eating.lua")
dofile(modpath .. "/equip_sounds.lua")
dofile(modpath .. "/emotes.lua")
dofile(modpath .. "/environment.lua")
dofile(modpath .. "/controls.lua")
dofile(modpath .. "/head_tracking.lua")
dofile(modpath .. "/test_anim.lua")
dofile(modpath .. "/legacy_b3d.lua")

-- Default player appearance: Dual-model (b3d + glb)
x_player_api.register_model("character.b3d", {
	mesh = "character.b3d",
	mesh_glb = "character.glb",
	animation_speed = 30,
	textures = {"character.png"},
	is_multitrack = true,

	-- Legacy single-timeline animations (B3D)
	animations = {
		stand         = {x = 1, y = 79},
		sit           = {x = 81,  y = 160, eye_height = 0.8, override_local = true,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.0, 0.3}},
		lay           = {x = 162, y = 166, eye_height = 0.3, override_local = true,
			collisionbox = {-0.6, 0.0, -0.6, 0.6, 0.3, 0.6}},
		walk          = {x = 168, y = 187},
		mine          = {x = 190, y = 200, is_action = true},
		walk_mine     = {x = 201, y = 220},
		walk_eat      = {x = 746, y = 765},
		walk_bow_aim  = {x = 770, y = 789},
		sprint        = {x = 221, y = 237},
		jump          = {x = 240, y = 250},
		fall          = {x = 251, y = 261},
		swim          = {x = 265, y = 285},
		climb         = {x = 290, y = 310},
		crouch        = {x = 315, y = 355, eye_height = 1.25,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.45, 0.3}},
		crouch_walk   = {x = 360, y = 380, eye_height = 1.25,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.45, 0.3}},
		slide         = {x = 385, y = 400, eye_height = 0.9,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.1, 0.3}},
		attack_slash  = {x = 405, y = 415, loop = false, is_action = true},
		attack_thrust = {x = 420, y = 430, loop = false, is_action = true},
		block         = {x = 436, y = 446, loop = false, is_action = true},
		bow_aim       = {x = 451, y = 466, loop = false, is_action = true},
		bow_shoot     = {x = 466, y = 474, loop = false, is_action = true},
		eat           = {x = 476, y = 496, is_action = true},
		hurt          = {x = 500, y = 510, loop = false, is_action = true},
		wave          = {x = 516, y = 536, is_action = true},
		point         = {x = 541, y = 556, is_action = true},
		cheer         = {x = 561, y = 581, is_action = true},
		bow           = {x = 585, y = 645, loop = false},
		fly           = {x = 650, y = 660, eye_height = 1.25,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.2, 0.3}},
		hover         = {x = 665, y = 725, eye_height = 1.35,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.6, 0.3}},
		equip         = {x = 730, y = 740, loop = false, is_action = true},
		freeze        = {x = 205, y = 205, override_local = true, loop = false},
	},

	-- Modern multitrack animations (GLB)
	animations_glb = {
		-- Locomotion and postures (base layer)
		stand         = {track = "stand", priority = 0, speed = 1.0},
		sit           = {track = "sit", priority = 0, eye_height = 0.8, override_local = true,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.0, 0.3}, speed = 1.0},
		lay           = {track = "lay", priority = 0, eye_height = 0.3, override_local = true,
			collisionbox = {-0.6, 0.0, -0.6, 0.6, 0.3, 0.6}, speed = 1.0},
		walk          = {track = "walk", priority = 0, speed = 1.0},
		sprint        = {track = "sprint", priority = 0, speed = 1.0},
		jump          = {track = "jump", priority = 0, speed = 1.0},
		fall          = {track = "fall", priority = 0, speed = 1.0},
		swim          = {track = "swim", priority = 0, speed = 1.0},
		climb         = {track = "climb", priority = 0, speed = 1.0},
		crouch        = {track = "crouch", priority = 0, eye_height = 1.25,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.45, 0.3}, speed = 1.0},
		crouch_walk   = {track = "crouch_walk", priority = 0, eye_height = 1.25,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.45, 0.3}, speed = 1.0},
		slide         = {track = "slide", priority = 0, eye_height = 0.9,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.1, 0.3}, speed = 1.0},
		fly           = {track = "fly", priority = 0, eye_height = 1.25,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.2, 0.3}, speed = 1.0},
		hover         = {track = "hover", priority = 0, eye_height = 1.35,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.6, 0.3}, speed = 1.0},
		bow           = {track = "bow", priority = 0, loop = false, speed = 1.0},
		freeze        = {track = "walk_mine", priority = 0, speed = 0, loop = false},

		-- Action and interaction layer
		mine          = {track = "mine", priority = 1, is_action = true, speed = 1.0},
		block         = {track = "block", priority = 1, is_action = true, speed = 1.0},
		attack_slash  = {track = "attack_slash", priority = 1, is_action = true, speed = 1.0},
		attack_thrust = {track = "attack_thrust", priority = 1, is_action = true, speed = 1.0},
		eat           = {track = "eat", priority = 1, is_action = true, speed = 1.0},
		bow_aim       = {track = "bow_aim", priority = 1, is_action = true, speed = 1.0},
		bow_shoot     = {track = "bow_shoot", priority = 1, is_action = true, loop = false, speed = 1.0},
		hurt          = {track = "hurt", priority = 1, is_action = true, loop = false, speed = 1.0},
		equip         = {track = "equip", priority = 1, is_action = true, loop = false, speed = 1.0},

		-- Gestures and emotes
		wave        = {track = "wave", priority = 1, is_action = true, loop = true, speed = 1.0},
		point       = {track = "point", priority = 1, is_action = true, loop = true, speed = 1.0},
		cheer       = {track = "cheer", priority = 1, is_action = true, loop = true, speed = 1.0},
	},
	collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
	stepheight = 0.6,
	eye_height = 1.47,
})

-- Register character.glb with dual-model definition inheriting animations,
-- hitboxes, and frame ranges from character.b3d
x_player_api.register_model("character.glb", {
	base_model = "character.b3d",
	mesh = "character.b3d",
	mesh_glb = "character.glb",
})

x_player_api.register_model_redirect("character", function()
	return x_player_api.get_model_format() == "glb" and "character.glb" or "character.b3d"
end)

-- Update appearance when the player joins
if not x_player_api._join_registered then
	x_player_api._join_registered = true
	core.register_on_joinplayer(function(player)
		x_player_api.set_model(player, x_player_api.get_default_model())
	end)
end

