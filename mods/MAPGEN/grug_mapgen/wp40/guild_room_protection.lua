-- The Miner's Guild rooms' protection (Round 58 lane ROOMS), main
-- environment: one y-bounded box per room (`guild_rooms.lua`, the box the
-- room step writes), a wrapper beside the zone overlay
-- (`r7_zone_overlay.lua`, which protects whole columns upward and keeps its
-- pinned schema). Inside a box the zone session answers
--   territory_rule_at        "hard_protected" (nothing alters it: digging,
--                            placing, explosions, fire, liquids, growth),
--   hard_protection_kind_at  "guild_room" (the depth pulse and the protection
--                            hint read it),
--   compatibility.world_protected_for_faction  true, for every faction;
-- everything else, the PvP rule included, is the wrapped session's: a room
-- at -650 and below stays contested ground like all land there. The claim
-- footprint query (`hard_footprint_in`) stays the session's: a room is no
-- column footprint, so a claim above it is unaffected.
--
--   local wrapped = dofile(wp40 .. "/guild_room_protection.lua")(session, rooms)
return function(session, rooms)
	if type(session) ~= "table" or type(session.territory_rule_at) ~= "function" or
			type(session.hard_protection_kind_at) ~= "function" or
			type(session.compatibility) ~= "table" or
			type(session.compatibility.world_protected_for_faction) ~= "function" or
			type(rooms) ~= "table" or type(rooms.room_at) ~= "function" then
		error("guild room protection: construction seam differs", 0)
	end
	local room_at = rooms.room_at
	local wrapped = {}
	for key, value in pairs(session) do wrapped[key] = value end
	function wrapped.territory_rule_at(position)
		if room_at(position) then return "hard_protected" end
		return session.territory_rule_at(position)
	end
	function wrapped.hard_protection_kind_at(position)
		if room_at(position) then return "guild_room" end
		return session.hard_protection_kind_at(position)
	end
	local compatibility = {}
	for key, value in pairs(session.compatibility) do compatibility[key] = value end
	function compatibility.world_protected_for_faction(position, actor_faction)
		if room_at(position) then return true end
		return session.compatibility.world_protected_for_faction(position, actor_faction)
	end
	wrapped.compatibility = compatibility
	wrapped.guild_room_protection = {schema = "grug_wp58_guild_room_protection_v1",
		rooms = #rooms.list}
	return wrapped
end
