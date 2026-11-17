-- The privilege cache (Round 81 HOT; audit X4-01, C1-07, X4-09). The engine
-- keeps none: every core.check_player_privs or core.get_player_privs runs
-- the auth handler's get_auth, an auth-database read (builtin/game/auth.lua
-- get_auth -> AuthDatabase::getAuth, two SQL statements on sqlite3, a round
-- trip on postgresql) plus a copy of the privilege table, on the server
-- thread. The contextual input pass asks for `interact` on every server step
-- for every player, so answers are kept per player name and privilege.
--
-- Every privilege change runs the grant and revoke callbacks
-- (builtin/game/auth.lua set_privileges, behind /grant, /revoke and
-- core.set_player_privs), which drop that player's answers; so do joining,
-- leaving and core.auth_reload (/auth_reload re-reads the database without
-- callbacks). The join also covers an answer cached after the leave (a later
-- mod's leave callback asking) and /remove_player, which runs no callback.
-- The callbacks return true: run_priv_callbacks (builtin/game/register.lua)
-- stops at the first one that returns nothing, and skips them all when the
-- privilege's own on_grant or on_revoke returns true (none of the game's
-- does). mobs.has_priv delegates here.

local answers = {} -- player name -> {privilege -> true | false}

-- Whether `name` holds `priv`: core.check_player_privs(name, priv)'s answer.
function grug_core.has_priv(name, priv)
	local known = answers[name]
	if not known then
		known = {}
		answers[name] = known
	end
	local answer = known[priv]
	if answer == nil then
		answer = (core.get_player_privs(name) or {})[priv] == true
		known[priv] = answer
	end
	return answer
end

local function forget(name)
	answers[name] = nil
	return true
end
core.register_on_priv_grant(forget)
core.register_on_priv_revoke(forget)
local function forget_player(player)
	answers[player:get_player_name()] = nil
end
core.register_on_joinplayer(forget_player)
core.register_on_leaveplayer(forget_player)

local auth_reload = core.auth_reload
if auth_reload then
	function core.auth_reload(...)
		answers = {}
		return auth_reload(...)
	end
end
