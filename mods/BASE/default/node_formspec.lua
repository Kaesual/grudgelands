-- default/node_formspec.lua

-- GRUG PATCH (whole file): server-side node formspecs.
-- A formspec stored in node metadata (key "formspec") is opened by the client
-- itself the moment RMB is pressed (luanti src/client/game.cpp,
-- Game::nodePlacement, "formspec in meta"); the server cannot defer it.
-- Grudgelands lets a held RMB with food eat even while pointing at an
-- interactive node, so no node stores its UI in metadata. Nodes open their UI
-- from on_rightclick through this module instead. It owns one session per
-- player (which node the open form belongs to), validates every submission
-- (player in range, node still the same), routes accepted fields to the
-- node's own on_receive_fields, re-shows changed forms to open viewers and
-- forgets sessions on close, on another form and on leave.
-- Inventories use `nodemeta:<x>,<y>,<z>` list locations (see `location`).

local FORMNAME = "default:node_formspec"
-- Generous against lag and the reach of long tools; not an interaction rule.
local MAX_DISTANCE = 10

local api = {formname = FORMNAME, max_distance = MAX_DISTANCE}
default.node_formspec = api

-- [player name] = {pos, names = {[node name] = true}, build, last}
local sessions = {}

function api.location(pos)
	return "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z
end

local function node_matches(session)
	local node = core.get_node_or_nil(session.pos)
	return node ~= nil and session.names[node.name] == true
end

local function in_range(player, pos)
	local at = player:get_pos()
	return at ~= nil and vector.distance(at, pos) <= MAX_DISTANCE
end

-- Open the UI of the node at `pos` for `player`. `build(pos, player)` returns
-- the formspec string; it is called again by `refresh`. `names` optionally
-- lists every node name the form stays valid for (a furnace swaps between its
-- idle and active node); by default only the node now at `pos`.
function api.show(player, pos, build, names)
	if not player or not player.is_player or not player:is_player() then
		return false
	end
	local node = core.get_node_or_nil(pos)
	if not node then return false end
	local accepted = {}
	for _, name in ipairs(names or {node.name}) do accepted[name] = true end
	if not accepted[node.name] then return false end
	local name = player:get_player_name()
	local at = vector.new(pos.x, pos.y, pos.z)
	local formspec = build(at, player)
	sessions[name] = {pos = at, names = accepted, build = build, last = formspec}
	core.show_formspec(name, FORMNAME, formspec)
	return true
end

-- Re-show the form of every open viewer of `pos` whose formspec changed.
-- Viewers that left, walked away or whose node changed are closed instead.
function api.refresh(pos)
	for name, session in pairs(sessions) do
		if vector.equals(session.pos, pos) then
			local player = core.get_player_by_name(name)
			if not player or not node_matches(session) or
					not in_range(player, session.pos) then
				sessions[name] = nil
				if player then core.close_formspec(name, FORMNAME) end
			else
				local formspec = session.build(session.pos, player)
				if formspec ~= session.last then
					session.last = formspec
					core.show_formspec(name, FORMNAME, formspec)
				end
			end
		end
	end
end

-- The open node of `name`, or nil (used by probes and diagnostics).
function api.session_pos(name)
	local session = sessions[name]
	return session and vector.new(session.pos.x, session.pos.y, session.pos.z)
end

-- The client holds one formspec at a time: a form shown by anyone else
-- replaces ours silently, and a later refresh must not pop ours back over it.
local show_formspec = core.show_formspec
function core.show_formspec(playername, formname, formspec)
	if formname ~= FORMNAME or formspec == "" then sessions[playername] = nil end
	return show_formspec(playername, formname, formspec)
end
local close_formspec = core.close_formspec
function core.close_formspec(playername, formname)
	if formname == FORMNAME or formname == "" then sessions[playername] = nil end
	return close_formspec(playername, formname)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	local session = sessions[name]
	if formname ~= FORMNAME then
		-- Fields from another form: ours is no longer open.
		sessions[name] = nil
		return
	end
	if not session then return true end
	if not node_matches(session) or not in_range(player, session.pos) then
		sessions[name] = nil
		core.close_formspec(name, FORMNAME)
		return true
	end
	if fields.quit then sessions[name] = nil end
	local pos = vector.new(session.pos.x, session.pos.y, session.pos.z)
	local def = core.registered_nodes[core.get_node(pos).name]
	if def and def.on_receive_fields then
		def.on_receive_fields(pos, formname, fields, player)
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	sessions[player:get_player_name()] = nil
end)
