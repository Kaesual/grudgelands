--
-- Con-color target frame (combat_stats.md §6).
--
-- The global nametag (levels.lua) is viewer-independent and cannot be
-- colored per player, so the "how dangerous is this to ME" signal lives in
-- a HUD line instead: the thing the player is LOOKING at, colored relative
-- to the viewer.
--
-- MOBS — con color against the viewer's own level:
--   mob <= L-10  gray   (gray kill: no XP)
--   L-10 < mob <= L  green
--   mob > L      red
--
-- PLAYERS — "<Name> — <The Faction>", colored by RELATION to the viewer:
--   same faction   green
--   enemy faction  red
--   either side factionless  gray
-- This is not a bonus feature: player nametags are hidden entirely
-- (grug_factions, combat_stats §6 — any floating name is a PvP tell through
-- walls), so the frame IS the identification mechanism for players. The
-- colors are the same three, deliberately: one palette, one meaning
-- ("green = safe for me, red = a problem, gray = nothing at stake").
--
-- Being punched by a mob deliberately does not open the frame (MVP:
-- looking is enough).
--

-- OUR choice, not a spec number: combat_stats §6 asks for a con-colored target
-- frame and never names a reach for it. 20 m is picked to sit comfortably past
-- the 16 m view_range of our furthest-seeing ground mobs (so you can size up
-- what is about to see you) and inside the ability targeting ranges of
-- grug_abilities. Change it here, there is nothing to keep it in sync with.
local RANGE = 20
local INTERVAL = 0.5 -- s; AGENTS performance rule: accumulator-throttled

local COLOR_GRAY = 0xaaaaaa
local COLOR_GREEN = 0x55ff55
local COLOR_RED = 0xff5555

-- player name -> {id = hud id, text = last text, color = last color}
local frames = {}

local function con_color(mob_level, player_level)
	if mob_level <= player_level - 10 then
		return COLOR_GRAY
	elseif mob_level <= player_level then
		return COLOR_GREEN
	end
	return COLOR_RED
end

-- Relation of a framed PLAYER to the viewer. Factionless on either side is
-- gray: a character who has not picked a side yet is neither friend nor foe
-- (the same reading grug_factions.hostile/same_faction use).
local function relation_color(viewer_faction, target_faction)
	if not viewer_faction or not target_faction then
		return COLOR_GRAY
	elseif viewer_faction == target_faction then
		return COLOR_GREEN
	end
	return COLOR_RED
end

-- First framable thing on the player's look ray: one of our mobs (returns the
-- luaentity) or another player (returns the ObjectRef — tell them apart with
-- core.is_player, which is safe on a plain table). Walkable nodes block the
-- view (no targeting through walls); plants/grass do not, so a target standing
-- in tall grass stays framable. Everything else on the ray (arrows, item
-- drops, dead things) is skipped rather than blocking.
local function looked_at_target(player)
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	local eye = vector.offset(pos, 0,
		player:get_properties().eye_height or 1.5, 0)
	local dest = vector.add(eye, vector.multiply(player:get_look_dir(), RANGE))
	for pointed in core.raycast(eye, dest, true, false) do
		if pointed.type == "node" then
			local node = core.get_node(pointed.under)
			local def = core.registered_nodes[node.name]
			if not def or def.walkable then
				return nil
			end
		elseif pointed.type == "object" and pointed.ref ~= player then
			local ref = pointed.ref
			if ref:is_player() then
				if ref:get_hp() > 0 then
					return ref
				end
			else
				local ent = ref:get_luaentity()
				-- _grug_level marks an initialized mob of ours (levels.lua).
				if ent and ent._grug_level and (ent.health or 0) > 0 then
					return ent
				end
			end
		end
	end
	return nil
end

local function update(player, frame)
	local target = looked_at_target(player)
	local text, color = "", COLOR_RED
	if target and core.is_player(target) then
		-- Name plus faction, because the name alone no longer tells you
		-- whether you are looking at an ally. A factionless target gets the
		-- bare name — there is no faction to print, and gray already says it.
		local faction = grug_factions.get_faction(target)
		color = relation_color(grug_factions.get_faction(player), faction)
		text = target:get_player_name()
		local label = grug_factions.display_name(faction)
		if label then
			-- UTF-8 written literally: \u{} escapes are LuaJIT-only
			-- (luanti-lua.md).
			text = text .. " — " .. label
		end
	elseif target then
		local mob = target
		color = con_color(mob._grug_level, grug_xp.get_level(player))
		text = grug_mobs.tag_text(mob)
		if color == COLOR_GRAY then
			text = text .. " (no XP)"
		end
	end
	-- Write only on change: this runs twice a second per player.
	if text ~= frame.text then
		frame.text = text
		player:hud_change(frame.id, "text", text)
	end
	if color ~= frame.color then
		frame.color = color
		player:hud_change(frame.id, "number", color)
	end
end

local timer = 0

core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < INTERVAL then
		return
	end
	timer = 0
	local players = core.get_connected_players()
	for i = 1, #players do
		local frame = frames[players[i]:get_player_name()]
		if frame then
			update(players[i], frame)
		end
	end
end)

core.register_on_joinplayer(function(player)
	local id = player:hud_add({
		type = "text",
		position = {x = 0.5, y = 0},
		offset = {x = 0, y = 40},
		alignment = {x = 0, y = 0},
		number = COLOR_RED,
		text = "",
	})
	if id then
		frames[player:get_player_name()] = {id = id, text = "", color = COLOR_RED}
	end
end)

core.register_on_leaveplayer(function(player)
	frames[player:get_player_name()] = nil
end)
