-- First-entry zone XP (Round 47 rulings 21-22; docs/design/world_map.md
-- "Zone discovery"). The first time a character enters a real zone it gets a
-- quarter of a quest reward and the level-up sound; every later entry gives
-- nothing.
--
--   * A REAL ZONE is a zone record that is not civic: the six capital zones
--     (`civic_no_hostiles`) are the capitals' own ground, and inside a start
--     town or capital city the location is the town, never a zone
--     (location_view.lua `resolve`). The open sea has no zone.
--   * The XP is grug_xp.quest_reward(min(zone level_min, character level),
--     WEIGHT): a high zone pays no more than the character's own level.
--     WEIGHT is a quarter of the median quest weight (3 kill equivalents over
--     the shipped quests). Source "discovery": no race bonus, the usual
--     "+N XP" feed line.
--   * The level-up sound plays once: by grug_xp when the grant levels the
--     character up, else here.
--   * The visited set lives in player meta (KEY, a core.serialize'd sorted
--     list of zone ids). A character without one (a new character, or one
--     from before Round 47) gets the zone it stands in marked SILENTLY at its
--     first sample, which for a new character is its start zone.
--
-- Called by location.lua only when the sampled zone changes, and once at a
-- player's first sample: no work of its own per step. `D.new(api)` takes its
-- engine and game calls as arguments, so the portable fixture runs the real
-- file; `D.runtime()` binds the real ones.

local D = {}

D.KEY = "grug_map:visited_zones"
D.WEIGHT = 0.75
D.SOURCE = "discovery"

-- A zone record that counts for discovery.
function D.real(record)
	return type(record) == "table" and record.civic_no_hostiles ~= true
end

-- The XP of a first entry.
function D.amount(level_min, level, quest_reward)
	return quest_reward(math.min(level_min, level), D.WEIGHT)
end

-- api:
--   record(id)               -> zone record or nil (grug_zones.get)
--   level(player)            -> character level
--   add_xp(player, n, source)
--   quest_reward(level, weight)
--   play(event, player)      grug_sounds.play
--   read(player), write(player, text)   the KEY meta string
--   serialize(t), deserialize(text)
function D.new(api)
	local E = {}

	-- The visited set, or nil while the character has none.
	local function load(player)
		local text = api.read(player)
		if text == "" then return nil end
		local list = api.deserialize(text)
		local set = {}
		if type(list) == "table" then
			for _, id in ipairs(list) do
				if type(id) == "string" then set[id] = true end
			end
		end
		return set
	end

	local function save(player, set)
		local list = {}
		for id in pairs(set) do list[#list + 1] = id end
		table.sort(list)
		api.write(player, api.serialize(list))
	end

	-- Whether the character has a visited set yet.
	function E.started(player)
		return api.read(player) ~= ""
	end

	-- The character's first sample this session, standing in zone `here`
	-- (the zone under a town too, nil at sea). Without a visited set it gets
	-- one, with `here` marked silently if real; returns true then.
	function E.start(player, here)
		if E.started(player) then return false end
		local set = {}
		if here and D.real(api.record(here)) then set[here] = true end
		save(player, set)
		return true
	end

	-- The player entered `zone` (nil in a town or at sea). A first entry into
	-- a real zone grants the XP and the sound once; returns the XP granted
	-- (nil for none).
	function E.enter(player, zone)
		if not zone then return nil end
		local record = api.record(zone)
		if not D.real(record) then return nil end
		local set = load(player)
		if not set then
			-- No set yet (the first sample did not run): start one silently.
			E.start(player, zone)
			return nil
		end
		if set[zone] then return nil end
		set[zone] = true
		save(player, set)
		local before = api.level(player)
		local amount = D.amount(record.level_min, before, api.quest_reward)
		api.add_xp(player, amount, D.SOURCE)
		if api.level(player) == before then
			api.play("level_up", player)
		end
		return amount
	end

	return E
end

-- The game's own calls.
function D.runtime()
	return D.new({
		record = function(id) return grug_zones.get(id) end,
		level = grug_xp.get_level,
		add_xp = grug_xp.add_xp,
		quest_reward = grug_xp.quest_reward,
		play = grug_sounds.play,
		read = function(player) return player:get_meta():get_string(D.KEY) end,
		write = function(player, text) player:get_meta():set_string(D.KEY, text) end,
		serialize = core.serialize,
		deserialize = core.deserialize,
	})
end

return D
