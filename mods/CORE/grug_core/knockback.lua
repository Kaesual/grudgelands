--
-- Knockback on players (Round 88 ruling 7, combat_stats.md §3 "Knockback on
-- players"). A push is a property of the attack, never of its damage or its
-- level: builtin pushes off the engine's damage (builtin/game/knockback.lua),
-- so the one override below hands builtin no push at all and pushes itself.
--   * WHO pushes stays grug_core.knockback_pushes (combat.lua): PvP melee as the
--     authoritative swing, and a mob's own hit; projectiles, casts and ability
--     damage push nothing.
--   * HOW HARD: PvP melee the fixed `pvp`; a mob its weight class, asked through
--     the seam `grug_core.mob_knockback(entity)` that grug_mobs installs
--     (grug_mobs/knockback.lua: the family table, the elite factor, the rares
--     and bosses one by one).
--   * WHERE: horizontal from the attacker to the player, with the one fixed
--     `lift`, the same for every source, so no push points into the floor.
--   * NO STACKING: per player one window of `window` seconds from its first
--     push; inside it a further push applies only by the amount it is stronger
--     than the strongest so far (the horizontal speed and the lift each).
-- Boss attacks with their own push (bosses.lua hit_players: the kings' shatter,
-- the rift boss's pulse) go through grug_core.push_player with their own
-- values and share the window; the dragon's slam keeps its arena push and its
-- own zero (boss_dragons.lua). Riders are never pushed (player_api's wrapper
-- answers 0 too, whichever of the two loads first).
--

-- The one place for the numbers (m/s, the factor and the seconds); starting
-- values by feel, tuned after the user's test (round88-plan.md §3).
grug_core.KNOCKBACK = {
	none = 0, light = 2.5, medium = 4, heavy = 6,
	-- An elite pushes this much more than its class.
	elite = 1.25,
	-- PvP melee, whatever the weapon.
	pvp = 2,
	lift = 1.5,
	window = 0.6,
}
local K = grug_core.KNOCKBACK

-- player ObjectRef -> {ends = s, speed = m/s, lift = m/s}: the open window.
local windows = setmetatable({}, {__mode = "k"})

local function now()
	return core.get_us_time() / 1e6
end

local function attached(player)
	if player:get_attach() then return true end
	local api = rawget(_G, "player_api")
	return api ~= nil and api.player_attached ~= nil
		and api.player_attached[player:get_player_name()] == true
end

-- Pushes `player` away from `from` (a position) by `speed` horizontally and
-- `lift` (default K.lift) upwards, inside the player's window only by what it
-- adds. A rider (attached, or player_api's attached flag) is never pushed.
-- Returns the velocity added, or nil.
function grug_core.push_player(player, from, speed, lift)
	lift = lift or K.lift
	local pos = player and from and speed and speed > 0 and player:get_pos()
	if not pos or attached(player) then return nil end
	local dx, dz = pos.x - from.x, pos.z - from.z
	local length = math.sqrt(dx * dx + dz * dz)
	-- Straight above or below: no horizontal direction, no push.
	if length < 0.01 then return nil end
	local t = now()
	local window = windows[player]
	local add_speed, add_lift = speed, lift
	if window and t < window.ends then
		add_speed = math.max(0, speed - window.speed)
		add_lift = math.max(0, lift - window.lift)
		window.speed = math.max(window.speed, speed)
		window.lift = math.max(window.lift, lift)
	else
		windows[player] = {ends = t + K.window, speed = speed, lift = lift}
	end
	if add_speed <= 0 and add_lift <= 0 then return nil end
	local velocity = {x = dx / length * add_speed, y = add_lift,
		z = dz / length * add_speed}
	player:add_velocity(velocity)
	return velocity
end

-- The push a punch of `hitter` on `player` carries (m/s), 0 for none.
function grug_core.knockback_speed(player, hitter)
	if not grug_core.knockback_pushes(player, hitter) then
		return 0
	end
	if hitter:is_player() then
		return K.pvp
	end
	local seam = grug_core.mob_knockback
	return seam and seam(hitter:get_luaentity()) or K.medium
end

-- builtin calls this once per punch, from its on_punchplayer, which runs before
-- any mod's (knockback_pushes needs the authoritative swing still unclaimed).
-- A punch that deals nothing (the engine's damage 0) is no hit and pushes
-- nothing; the damage's size never matters.
function core.calculate_knockback(player, hitter, _, _, _, _, damage)
	if damage == 0 or not hitter or player:get_armor_groups().immortal then
		return 0
	end
	local speed = grug_core.knockback_speed(player, hitter)
	if speed > 0 then
		grug_core.push_player(player, hitter:get_pos(), speed)
	end
	return 0
end
