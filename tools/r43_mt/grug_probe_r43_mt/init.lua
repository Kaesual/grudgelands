-- Disposable engine probe (Round 43 lane MT: the migration tool's test data).
-- Never shipped: tools/r43_mt/make_world.sh stages it through
-- tools/luanti_headless.sh for one boot of a world with SQLite auth and mod
-- storage and the legacy `files` player backend, then lets the engine migrate
-- the players to SQLite (`--migrate-players sqlite3`).
--
-- What the engine writes here is the ground truth of the tool's codecs
-- (tools/r43_mt/test_migrate.py holds the same values):
--   mod storage   this mod's keys: core.serialize output of several shapes
--                 (references, a cycle, odd keys, special numbers, a control-
--                 character string), core.write_json output, raw bytes, an
--                 odd key, set_int and set_float;
--   auth          three entries with privileges (one has no character);
--   characters    two player files in the `files` format whose meta comes from
--                 core.write_json and whose item lines from ItemStack:to_string
--                 (count, wear, meta, a quoted name); the engine reads them and
--                 writes the SQLite rows in the second run.
-- A headless server has no client, so no player is ever saved by a join.

local P = "[r43_mt_probe] "
local storage = core.get_mod_storage()
local world = core.get_worldpath()

local function log(msg) core.log("action", P .. msg) end

--
-- Mod storage.
--
local long = "a string long enough to be referenced"
local shared = {x = 1, y = -2.5}
local cyclic = {name = "loop"}
cyclic.self = cyclic

local serial = {
	list = {1, 2, 3, "four", true, false},
	nested = {
		level = 12, xp = 3456.75, name = "Brakka", neg = -7, small = 0.1,
		big = 1e300, tiny = 5e-324, maxint = 9007199254740991,
		flags = {pvp = true, afk = false},
		list = {"a", "b", {deep = {1, 2}}},
	},
	special = {inf = math.huge, ninf = -math.huge, nan = 0 / 0},
	refs = {a = long, b = long, c = shared, d = shared, e = {long, long}},
	cycle = cyclic,
	keys = {
		["end"] = 1, ["a-b"] = 2, [10] = "ten", [1.5] = "x", [-1] = "neg",
		[true] = "yes", ["1"] = "string one", _ok = 3,
	},
	mixed = {1, 2, n = 3},
	string = "quote\" back\\ nl\n cr\r nul\0 bell\7 tab\t del\127 utf8 Gr\195\188\195\159e high\255 end",
	number = 42,
	empty = {},
}

local function write_storage()
	for name, value in pairs(serial) do
		storage:set_string("ser:" .. name, core.serialize(value))
	end
	storage:set_string("json:obj", core.write_json({
		name = "Brakka", level = 12, ratio = 0.5, tags = {"a", "b"},
		nested = {ok = true}, text = "line\nnext \"q\" \195\188",
	}))
	storage:set_string("raw:binary", "\0\1\2\31 \127\128\255 end")
	storage:set_string("key with spaces\n\255", "odd key")
	storage:set_int("int", 7)
	storage:set_float("float", 0.25)
end

--
-- Auth.
--
local function write_auth()
	local handler = core.get_auth_handler()
	local privs = {
		oldhero = {interact = true, shout = true, fly = true},
		newbie = {interact = true},
		authonly = {shout = true},
	}
	for _, name in ipairs({"oldhero", "newbie", "authonly"}) do
		if not handler.get_auth(name) then
			handler.create_auth(name, core.get_password_hash(name, "secret"))
		end
		core.set_player_privs(name, privs[name])
	end
end

--
-- Characters, as files of the legacy `files` player backend
-- (database-files.cpp PlayerDatabaseFiles::deSerialize).
--
local function sword()
	local stack = ItemStack("default:sword_steel")
	local meta = stack:get_meta()
	meta:set_string("description", "Blade of the Accord\n\195\156bung \"q\"")
	meta:set_string("grug_ench", core.serialize({{stat = "str", tier = 2}, {stat = "crit", tier = 1}}))
	meta:set_string("bell", "a\7b\tc")
	stack:set_wear(65535)
	return stack
end

local function bread()
	local stack = ItemStack("default:apple 5")
	stack:get_meta():set_string("grug_quality", "fine")
	return stack
end

local function pick()
	local stack = ItemStack("default:pick_steel")
	stack:set_wear(1200)
	return stack
end

local characters = {
	{
		name = "oldhero", hp = 18, breath = 10, pitch = 12.5, yaw = 90,
		position = "(1000.5,205,-300.25)",
		meta = {
			["grug_classes:race"] = "human",
			["grug_core:reset_world"] = "1",
			["grug_quests:state"] = core.serialize({
				active = {"q_wolves", "q_herbs"}, tracked = {"q_wolves"},
				completed = {q_intro = 1234567, q_first = 1234999},
				progress = {q_wolves = {kills = 3}},
			}),
			["grug_visuals:appearance"] = core.write_json({v = 1, race = "human", look = {hair = 2}}),
			text = "tab\there\nnewline \"quoted\" back\\slash Gr\195\188\195\159e",
			number = "42",
		},
		lists = {
			{name = "main", size = 32, width = 8, items = {
				[1] = ItemStack("default:dirt 99"), [2] = pick(), [3] = sword(),
				[4] = bread(), [5] = ItemStack({name = "grug_probe:odd name", count = 3}),
				[32] = ItemStack("default:torch"),
			}},
			{name = "craft", size = 9, width = 3, items = {[5] = ItemStack("default:stick 4")}},
		},
	},
	{
		name = "newbie", hp = 20, breath = 10, pitch = 0, yaw = 0,
		position = "(0,105,0)",
		meta = {},
		lists = {{name = "main", size = 32, width = 8, items = {}}},
	},
}

local function player_file(c)
	local lines = {
		"version = 1",
		"name = " .. c.name,
		"hp = " .. c.hp,
		"position = " .. c.position,
		"pitch = " .. c.pitch,
		"yaw = " .. c.yaw,
		"breath = " .. c.breath,
		"extended_attributes = " .. core.write_json(c.meta),
		"PlayerArgsEnd",
	}
	for _, list in ipairs(c.lists) do
		lines[#lines + 1] = "List " .. list.name .. " " .. list.size
		lines[#lines + 1] = "Width " .. list.width
		for index = 1, list.size do
			local stack = list.items[index]
			lines[#lines + 1] = stack and "Item " .. stack:to_string() or "Empty"
		end
		lines[#lines + 1] = "EndInventoryList"
	end
	lines[#lines + 1] = "EndInventory"
	return table.concat(lines, "\n") .. "\n"
end

local function write_characters()
	core.mkdir(world .. "/players")
	for _, c in ipairs(characters) do
		assert(core.safe_file_write(world .. "/players/" .. c.name, player_file(c)),
			"cannot write the player file of " .. c.name)
	end
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		write_storage()
		write_auth()
		write_characters()
		assert(core.safe_file_write(world .. "/r43_mt_probe.txt", "RESULT PASS\n"))
		log("RESULT PASS")
		core.after(1, function() core.request_shutdown("r43 mt probe done") end)
	end)
end)
