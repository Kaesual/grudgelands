-- The respawn lock (Round 78, ruling 11): a player who dies in their run while a living
-- member inside the same run is in combat waits LOCK_SECONDS before the respawn; when
-- no living member inside fights any more, the respawn is free at once, and it stays
-- free until the respawn.
--
-- The death screen is server Lua: builtin/game/death_screen.lua shows its form
-- `__builtin:death` through core.show_death_screen at a death (on_dieplayer), at a join
-- with hp 0 (on_joinplayer) and when any other form is closed while the player is dead,
-- and any quit of its own form respawns (lua_api.md, "core.show_death_screen ... You can
-- override this to show a custom death screen"). So this file overrides that function:
-- a locked player sees this file's form FORM, whose Respawn button is grey and does not
-- quit; Esc, a relog with hp 0 and any other form closed come back through the builtin
-- calls above and show it again with the time that is left. A free player, and every
-- death outside a run, gets the builtin screen unchanged. Replacing an open form keeps
-- the client's window (luanti src/client/game_formspec.cpp GameFormSpec::showFormSpec,
-- "Replace the currently open formspec": GUIFormSpecMenu::create reuses the open menu
-- with the new source), so the countdown and the lock's end update in place.
--
-- One core.after chain per locked dead player, a tick when the shown second drops; it
-- stops when the lock ends or the player leaves (a relog starts it again). The lock's
-- end is server time and runs on through a logout. Nothing is saved: a restart ends
-- every run, so it frees every lock.
local M = grug_expeditions

M.RESPAWN_LOCK_SECONDS = 10
local FORM = "grug_expeditions:death"
local F = core.formspec_escape
local builtin_screen = core.show_death_screen

-- name -> {run = the run they died in, ends = core.get_us_time() of the lock's end,
-- free = true once it ended, ticking = a tick is due}; from the first screen of a death
-- in a run to the respawn.
local locks = {}

-- A living member inside `run`, other than `name`, in combat.
local function fighting(run, name)
	for other in pairs(run.inside) do
		local player = other ~= name and core.get_player_by_name(other)
		if player and player:get_hp() > 0 and grug_core.in_combat(player) then return true end
	end
	return false
end

-- The seconds the lock still holds `name`, or nil: free, for good.
local function left_of(lock, name)
	if lock.free then return nil end
	local run = lock.run
	local left = (lock.ends - core.get_us_time()) / 1e6
	if left <= 0 or run.state == "ended" or not run.entered[name] or not M.belongs(run, name) or
			not fighting(run, name) then
		lock.free = true
		return nil
	end
	return left
end

-- The builtin screen's frame and "You died", one line why and the grey button with the
-- seconds left (a label with a size where the client knows it, as the builtin does).
local function locked_form(name, left)
	local info = core.get_player_information(name)
	local sized = info ~= nil and (info.formspec_version or 0) >= 11
	local fs = {"formspec_version[2]", "size[14.25,7.275,true]", "bgcolor[#320000b4;true]"}
	local function centred(y, width, text)
		local box = ("%s,%s;%s,0.8;"):format((14.25 - width) / 2, y, width)
		if sized then
			fs[#fs + 1] = "style_type[label;halign=center;valign=center]label[" .. box .. F(text) .. "]"
		else
			fs[#fs + 1] = "style_type[button;border=false]button[" .. box .. ";" .. F(text) ..
				"]style_type[button;border=true]"
		end
	end
	centred(1.85, 3.5, "You died")
	centred(2.65, 8, "Your group is still fighting.")
	fs[#fs + 1] = "style[respawn,respawn:hovered,respawn:pressed;bgcolor=#4a4a4a;textcolor=#a0a0a0]"
	fs[#fs + 1] = "button[5.375,3.725;3.5,0.8;respawn;" ..
		F(("Respawn in %d s"):format(math.ceil(left))) .. "]"
	return table.concat(fs)
end

local tick

-- The screen as the lock stands now; a locked one keeps its tick going.
local function show(player, lock, reason)
	local name = player:get_player_name()
	local left = left_of(lock, name)
	if not left then return builtin_screen(player, reason) end
	core.show_formspec(name, FORM, locked_form(name, left))
	if not lock.ticking then
		lock.ticking = true
		-- The next look when the shown number drops, so a late step skips none.
		core.after(left - (math.ceil(left) - 1), tick, name, lock)
	end
end

tick = function(name, lock)
	lock.ticking = false
	local player = core.get_player_by_name(name)
	if locks[name] ~= lock or not player or player:get_hp() > 0 then return end
	show(player, lock, nil)
end

function core.show_death_screen(player, reason)
	local name = player:get_player_name()
	local lock = locks[name]
	if not lock then
		local run = M.run_at(player:get_pos())
		if not (run and run.entered[name] and M.belongs(run, name)) then
			return builtin_screen(player, reason)
		end
		lock = {run = run, ends = core.get_us_time() + M.RESPAWN_LOCK_SECONDS * 1e6}
		locks[name] = lock
	end
	show(player, lock, reason)
end

-- The grey button: the screen again, the builtin one once the lock has ended. Esc is a
-- quit, which the builtin's own handler answers with core.show_death_screen.
core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return end
	if fields.respawn and player:get_hp() == 0 then core.show_death_screen(player, nil) end
	return true
end)

core.register_on_respawnplayer(function(player)
	locks[player:get_player_name()] = nil
end)

-- A lock outlives a logout; a player who joins alive has none.
core.register_on_joinplayer(function(player)
	if player:get_hp() > 0 then locks[player:get_player_name()] = nil end
end)
