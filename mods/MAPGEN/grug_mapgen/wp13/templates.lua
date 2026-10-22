-- The building template loader (Round 56,
-- docs/technical/building-template-format.md).
--
-- A town building is a text file in `../building_templates/templates/`, and a
-- town's placements are its layout in `../building_templates/layouts/` (a
-- start town) or are made by its own code from a roster of the templates
-- and palettes it uses (a capital, `<town>.roster`). This
-- module reads them when a town composition loads, refuses a malformed file
-- right there (file, line and reason, so the server stops at load and never
-- mid-generation), and turns one placement into a part exactly like a
-- building generator's result: `{buffer, w, d, points, peak, ...meta}` in the
-- template's own frame, filled for the placement's palettes, so `parts.stamp`
-- stays the only rotation.
--
-- Every list keeps its file order; nothing deterministic walks `pairs`.
--
-- Plain Lua 5.1, no engine calls, no globals (it reads files with `io.open`).

local function loader(directory)
	local parts = dofile(directory .. "/parts.lua")
	local palettes = dofile(directory .. "/palette.lua")

	local M = {}
	M.ROOT = directory .. "/../building_templates"
	M.TEMPLATE_MAGIC = "grudgelands-building-template 1"
	M.LAYOUT_MAGIC = "grudgelands-town-layout 1"
	M.ROSTER_MAGIC = "grudgelands-town-roster 1"

	local DECLARED = {}
	for _, role in ipairs(palettes.required) do DECLARED[role] = "required" end
	for _, role in ipairs(palettes.optional) do DECLARED[role] = "optional" end
	M.DECLARED = DECLARED
	M.GROUPS = {"doors", "lights", "inside", "room_corner"}
	local KINDS = {facedir = parts.FACEDIR, wallmounted = parts.WALLMOUNTED}

	local function read(path)
		local file = io.open(path, "rb")
		if not file then error(path .. ": the file is missing", 0) end
		local text = file:read("*a")
		file:close()
		return text
	end
	M.read = read

	-- The file's lines with their numbers; a file is `\n`-terminated text.
	local function lines_of(text, path)
		local carriage = text:find("\r", 1, true)
		if carriage then
			local _, before = text:sub(1, carriage):gsub("\n", "")
			error(path .. ":" .. (before + 1) ..
				": carriage return in the file (only \\n line ends)", 0)
		end
		local out = {}
		local number = 0
		for line in (text .. (text:sub(-1) == "\n" and "" or "\n")):gmatch("([^\n]*)\n") do
			number = number + 1
			out[#out + 1] = {text = line, number = number}
		end
		return out
	end

	local function comment_or_blank(line)
		return line:match("^%s*$") ~= nil or line:match("^%s*#") ~= nil
	end

	local function words(line)
		local out = {}
		for word in line:gmatch("%S+") do out[#out + 1] = word end
		return out
	end

	local function integer(text)
		if type(text) ~= "string" or not text:match("^%-?%d+$") then return nil end
		return tonumber(text)
	end

	-- One attribute value (format doc §3.4): an integer, true/false, a bare
	-- word, a double-quoted string or a bracketed list of those.
	local function scalar(text)
		local number = integer(text)
		if number then return number end
		if text == "true" then return true end
		if text == "false" then return false end
		local quoted = text:match('^"([^"]*)"$')
		if quoted then return quoted end
		if text:match("^[A-Za-z0-9_:.{}%-]+$") then
			local outside = text:gsub("{id}", "")
			if not outside:find("[{}]") then return text end
		end
		return nil
	end
	M.scalar = scalar

	local function value_of(text)
		local inner = text:match("^%[(.*)%]$")
		if inner then
			local list = {}
			if inner == "" then return list end
			for item in (inner .. ","):gmatch("([^,]*),") do
				local parsed = scalar(item)
				if parsed == nil then return nil end
				list[#list + 1] = parsed
			end
			return list
		end
		return scalar(text)
	end
	M.value_of = value_of

	-- Split a point or meta line into tokens, keeping quoted strings whole.
	local function tokens(line)
		local out, pos = {}, 1
		while true do
			local start = line:find("%S", pos)
			if not start then break end
			local stop = start
			local quote = false
			while stop <= #line do
				local char = line:sub(stop, stop)
				if char == '"' then quote = not quote
				elseif char:match("%s") and not quote then break end
				stop = stop + 1
			end
			if quote then return nil end
			out[#out + 1] = line:sub(start, stop - 1)
			pos = stop
		end
		return out
	end
	M.tokens = tokens

	-- key=value attributes, in order; nil and the bad token on an error.
	local function attributes(list, first)
		local out = {}
		for index = first, #list do
			local key, raw = list[index]:match("^([%a_][%w_]*)=(.+)$")
			if not key then return nil, list[index] end
			local value = value_of(raw)
			if value == nil then return nil, list[index] end
			out[#out + 1] = {key = key, value = value}
		end
		return out
	end

	-- A legend entry (format doc §3.2); errors carry no position, the caller
	-- adds it.
	local function parse_entry(text, cell)
		local list = words(text)
		local kind = list[1]
		if kind == "role" then
			local role = list[2]
			if not role or not (DECLARED[role] or palettes.prefix_roles[role]) then
				error("unknown role " .. tostring(role), 0)
			end
			local entry = {kind = "role", role = role}
			for index = 3, #list do
				local key, value = list[index]:match("^([%a_]+)=(.+)$")
				if key == "variant" then entry.variant = value
				elseif key == "channel" and value:match("^[%a_][%w_]*$") then
					entry.channel = value
				elseif key == "o" then entry.o = value
				elseif key == "else" then entry.fallback = value
				else error("bad role option " .. list[index], 0) end
			end
			local family = palettes.prefix_roles[role]
			if family then
				local found = false
				for _, suffix in ipairs(family) do
					if suffix == entry.variant then found = true end
				end
				if not found then
					error("role " .. role .. " needs a variant of its family, not " ..
						tostring(entry.variant), 0)
				end
			elseif entry.variant then
				error("role " .. role .. " has no variants", 0)
			end
			local optional = DECLARED[role] == "optional" or
				role == "bed_fancy" or role == "pillar"
			entry.optional = optional
			if entry.fallback and not optional then
				error("else= on the required role " .. role, 0)
			end
			return entry
		elseif kind == "node" then
			if not list[2] or not list[2]:match("^[%w_]+:[%w_]+$") and list[2] ~= "air" then
				error("bad node name " .. tostring(list[2]), 0)
			end
			local entry = {kind = "node", name = list[2]}
			for index = 3, #list do
				local value = list[index]:match("^o=(.+)$")
				if not value then error("bad node option " .. list[index], 0) end
				entry.o = value
			end
			return entry
		elseif kind == "race" then
			local entry = {kind = "race", map = {}, order = {}}
			for index = 2, #list do
				local race, key = list[index]:match("^([%a*]+)=(.+)$")
				if not race or #key ~= cell or (race ~= "*" and not palettes.races[race]) then
					error("bad race switch " .. list[index], 0)
				end
				if entry.map[race] then error("race " .. race .. " switched twice", 0) end
				entry.map[race] = key
				entry.order[#entry.order + 1] = race
			end
			if #entry.order == 0 then error("empty race switch", 0) end
			return entry
		end
		error("unknown legend entry " .. tostring(kind), 0)
	end

	-- Orientation `o=<kind>:<value>` -> kind, value.
	local function orientation(text)
		local kind, value = text:match("^(%a+):(%d+)$")
		value = tonumber(value)
		if not kind or not KINDS[kind] then return nil end
		if kind == "facedir" and value > 23 then return nil end
		if kind == "wallmounted" and value > 5 then return nil end
		return KINDS[kind], value
	end
	M.orientation = orientation

	-- Parse one template file. `path` names it in every error.
	function M.parse_template(text, path, expected_name)
		local lines = lines_of(text, path)
		local index = 1
		local function fail(line, reason)
			error(path .. ":" .. (line and line.number or "?") .. ": " .. reason, 0)
		end
		if not lines[1] or lines[1].text ~= M.TEMPLATE_MAGIC then
			fail(lines[1], "the first line must be '" .. M.TEMPLATE_MAGIC .. "'")
		end
		index = 2
		local t = {path = path, meta = {}, meta_order = {}, legend = {},
			legend_order = {}, points = {}, point_groups = {}}
		local function next_line()
			while lines[index] and comment_or_blank(lines[index].text) do
				index = index + 1
			end
			local line = lines[index]
			index = index + 1
			return line
		end
		-- header
		while true do
			local line = next_line()
			if not line then fail(lines[#lines], "the file ends before its legend") end
			local list = words(line.text)
			local head = list[1]
			if head == "legend" and #list == 1 then break end
			if head == "name" and #list == 2 and list[2]:match("^[a-z0-9_]+$") then
				if t.name then fail(line, "name given twice") end
				t.name = list[2]
			elseif head == "pivot" and #list == 3 and integer(list[2]) and
					integer(list[3]) then
				t.w, t.d = integer(list[2]), integer(list[3])
				if t.w < 1 or t.d < 1 then fail(line, "the pivot must be at least 1 x 1") end
			elseif head == "origin" and #list == 4 and integer(list[2]) and
					integer(list[3]) and integer(list[4]) then
				t.x0, t.y0, t.z0 = integer(list[2]), integer(list[3]), integer(list[4])
			elseif head == "size" and #list == 4 and integer(list[2]) and
					integer(list[3]) and integer(list[4]) then
				t.sx, t.sy, t.sz = integer(list[2]), integer(list[3]), integer(list[4])
				if t.sx < 1 or t.sy < 1 or t.sz < 1 then fail(line, "every size must be at least 1") end
			elseif head == "cell" and #list == 2 and (list[2] == "1" or list[2] == "2") then
				t.cell = tonumber(list[2])
			elseif head == "meta" then
				local toks = tokens(line.text)
				local attrs, bad = toks and attributes(toks, 2)
				if not attrs then fail(line, "bad meta value " .. tostring(bad)) end
				for _, attr in ipairs(attrs) do
					if t.meta[attr.key] ~= nil then fail(line, "meta " .. attr.key .. " given twice") end
					t.meta[attr.key] = attr.value
					t.meta_order[#t.meta_order + 1] = attr.key
				end
			elseif head == "races" and #list >= 2 then
				t.races = {}
				for i = 2, #list do
					if not palettes.races[list[i]] then fail(line, "unknown race " .. list[i]) end
					t.races[#t.races + 1] = list[i]
				end
			else
				fail(line, "unknown header line")
			end
		end
		for _, field in ipairs({"name", "w", "x0", "sx", "cell", "races"}) do
			if t[field] == nil then fail(lines[index - 1], "the header lacks " .. field) end
		end
		if expected_name and t.name ~= expected_name then
			fail(lines[2], "name " .. t.name .. " differs from the file name " .. expected_name)
		end
		-- legend
		while true do
			local line = next_line()
			if not line then fail(lines[#lines], "the legend has no end") end
			if line.text == "end" then break end
			local key = line.text:sub(1, t.cell)
			if #key ~= t.cell or line.text:sub(t.cell + 1, t.cell + 1) ~= " " or
					key:find("[%s.|#]") or key:find("[^\33-\126]") then
				fail(line, "bad legend key")
			end
			if t.legend[key] then fail(line, "legend key '" .. key .. "' given twice") end
			local ok, entry = pcall(parse_entry, line.text:sub(t.cell + 2), t.cell)
			if not ok then fail(line, entry) end
			if entry.o and not orientation(entry.o) then fail(line, "bad orientation " .. entry.o) end
			entry.key, entry.line = key, line.number
			t.legend[key] = entry
			t.legend_order[#t.legend_order + 1] = key
		end
		-- the channels its roles name (format doc §3.2), for a roster's use key
		t.channels = {}
		for _, key in ipairs(t.legend_order) do
			local channel = t.legend[key].channel
			if channel then t.channels[channel] = true end
		end
		for _, key in ipairs(t.legend_order) do
			local entry = t.legend[key]
			local function defined(ref, what)
				local target = t.legend[ref]
				if not target then
					fail({number = entry.line}, what .. " names the undefined key '" .. ref .. "'")
				end
				return target
			end
			if entry.kind == "race" then
				for _, race in ipairs(entry.order) do
					if defined(entry.map[race], "a race switch").kind == "race" then
						fail({number = entry.line}, "a race switch names another switch")
					end
				end
			elseif entry.fallback and entry.fallback ~= "air" and entry.fallback ~= "unchanged" then
				if #entry.fallback ~= t.cell then
					fail({number = entry.line}, "bad else= " .. entry.fallback)
				end
				if defined(entry.fallback, "else=").kind == "race" then
					fail({number = entry.line}, "else= names a race switch")
				end
			end
		end
		-- grid
		local air_key, keep_key = string.rep(".", t.cell), string.rep(" ", t.cell)
		t.grid = {}
		local width = t.sx * t.cell + 2
		for y = t.y0, t.y0 + t.sy - 1 do
			local line = next_line()
			if not line or line.text ~= "layer " .. y then
				fail(line or lines[#lines], "expected 'layer " .. y .. "'")
			end
			local layer = {}
			for z = t.z0, t.z0 + t.sz - 1 do
				local row = lines[index]
				index = index + 1
				if not row or row.text:sub(1, 1) ~= "|" then
					fail(row or lines[#lines], "layer " .. y .. " lacks its row for z " .. z)
				end
				if #row.text ~= width or row.text:sub(-1) ~= "|" then
					fail(row, "the row for z " .. z .. " must be " .. t.sx ..
						" cells between two '|'")
				end
				local cells = {}
				for x = 0, t.sx - 1 do
					local token = row.text:sub(2 + x * t.cell, 1 + (x + 1) * t.cell)
					if token == keep_key then
						cells[x + 1] = false
					elseif token == air_key then
						cells[x + 1] = "."
					elseif t.legend[token] then
						cells[x + 1] = token
					else
						fail(row, "the cell '" .. token .. "' at x " .. (t.x0 + x) ..
							" is not in the legend")
					end
				end
				layer[#layer + 1] = cells
			end
			t.grid[#t.grid + 1] = layer
		end
		-- points
		local line = next_line()
		if not line or line.text ~= "points" then
			fail(line or lines[#lines], "expected 'points'")
		end
		while true do
			line = next_line()
			if not line then fail(lines[#lines], "the points have no end") end
			if line.text == "end" then break end
			local toks = tokens(line.text)
			if not toks or #toks < 4 or not toks[1]:match("^[%a_][%w_]*$") or
					not integer(toks[2]) or not integer(toks[3]) or not integer(toks[4]) then
				fail(line, "a point is '<group> <x> <y> <z> [face=n] [key=value ...]'")
			end
			local attrs, bad = attributes(toks, 5)
			if not attrs then fail(line, "bad point attribute " .. tostring(bad)) end
			local point = {group = toks[1], x = integer(toks[2]), y = integer(toks[3]),
				z = integer(toks[4]), attrs = {}, line = line.number}
			for _, attr in ipairs(attrs) do
				if attr.key == "x" or attr.key == "y" or attr.key == "z" then
					fail(line, "a point attribute may not be called " .. attr.key)
				end
				if attr.key == "face" then
					if type(attr.value) ~= "number" or attr.value < 0 or attr.value > 3 then
						fail(line, "face must be 0 to 3")
					end
					point.face = attr.value
				else
					point.attrs[#point.attrs + 1] = attr
				end
			end
			if point.x < t.x0 or point.x >= t.x0 + t.sx or point.y < t.y0 or
					point.y >= t.y0 + t.sy or point.z < t.z0 or point.z >= t.z0 + t.sz then
				fail(line, "the point lies outside the box")
			end
			if not t.points[point.group] then
				t.points[point.group] = {}
				t.point_groups[#t.point_groups + 1] = point.group
			end
			local group = t.points[point.group]
			group[#group + 1] = point
		end
		line = next_line()
		if line then fail(line, "nothing may follow the points") end
		return t
	end

	-- Parse one town layout file, or with `roster` one capital's roster
	-- (format doc §4): the same `town`, `race` and `palette` lines, then
	-- `use <template> count=<n> [main=<palette>] [<channel>=<palette> ...]`
	-- lines instead of placements.
	function M.parse_layout(text, path, roster)
		local lines = lines_of(text, path)
		local function fail(line, reason)
			error(path .. ":" .. (line and line.number or "?") .. ": " .. reason, 0)
		end
		local magic = roster and M.ROSTER_MAGIC or M.LAYOUT_MAGIC
		if not lines[1] or lines[1].text ~= magic then
			fail(lines[1], "the first line must be '" .. magic .. "'")
		end
		local layout = {path = path, palettes = {}, palette_order = {}, places = {},
			by_id = {}, uses = {}, use_by_key = {}}
		for index = 2, #lines do
			local line = lines[index]
			if not comment_or_blank(line.text) then
				local list = words(line.text)
				local head = list[1]
				if head == "town" and #list == 2 and list[2]:match("^[a-z0-9_]+$") then
					layout.town = list[2]
				elseif head == "race" and #list == 2 and palettes.races[list[2]] then
					layout.race = list[2]
				elseif head == "palette" and #list >= 3 and list[2]:match("^[a-z0-9_]+$") then
					local name = list[2]
					if layout.palettes[name] then fail(line, "palette " .. name .. " given twice") end
					local race = list[3]:match("^race=(.+)$")
					if not race or not palettes.races[race] then fail(line, "bad palette race") end
					local overrides, order = {}, {}
					for i = 4, #list do
						local role, node = list[i]:match("^([%a_]+)=([%w_]+:[%w_]+)$")
						if not role or not DECLARED[role] then
							fail(line, "bad override " .. list[i])
						end
						overrides[role] = node
						order[#order + 1] = role
					end
					layout.palettes[name] = {name = name, race = race,
						overrides = #order > 0 and overrides or nil, order = order,
						line = line.number}
					layout.palette_order[#layout.palette_order + 1] = name
				elseif roster and head == "use" and #list >= 3 and
						list[2]:match("^[a-z0-9_]+$") then
					local use = {template = list[2], channels = {}, channel_order = {},
						line = line.number}
					for i = 3, #list do
						local key, value = list[i]:match("^([%a_][%w_]*)=(.+)$")
						if not key then fail(line, "bad use field " .. list[i]) end
						if key == "count" then
							if use.count then fail(line, "count given twice") end
							use.count = integer(value)
							if not use.count or use.count < 1 then
								fail(line, "count must be a positive integer")
							end
						elseif key == "main" then
							if use.main then fail(line, "main given twice") end
							use.main = value
						elseif key == "template" or key == "x" or key == "y" or key == "z" or
								key == "turns" or key == "lift" then
							fail(line, "a roster places nothing: " .. key .. "=")
						else
							if use.channels[key] then fail(line, "channel " .. key .. " given twice") end
							use.channels[key] = value
							use.channel_order[#use.channel_order + 1] = key
						end
					end
					if not use.count then fail(line, "a use line needs count=") end
					use.key = M.use_key(use.template, use.main, use.channels)
					if layout.use_by_key[use.key] then
						fail(line, "the use " .. use.key .. " is given twice")
					end
					layout.use_by_key[use.key] = use
					layout.uses[#layout.uses + 1] = use
				elseif not roster and head == "place" and #list >= 7 and
						list[2]:match("^[a-z0-9_]+$") then
					local place = {id = list[2], channels = {}, channel_order = {},
						line = line.number}
					for i = 3, #list do
						local key, value = list[i]:match("^([%a_][%w_]*)=(.+)$")
						if not key then fail(line, "bad placement field " .. list[i]) end
						if key == "template" then place.template = value
						elseif key == "x" or key == "y" or key == "z" or key == "turns" or
								key == "lift" then
							place[key] = integer(value)
							if place[key] == nil then fail(line, key .. " must be an integer") end
						elseif key == "main" then place.main = value
						else
							if place.channels[key] then fail(line, "channel " .. key .. " given twice") end
							place.channels[key] = value
							place.channel_order[#place.channel_order + 1] = key
						end
					end
					if not place.template or not place.x or not place.y or not place.z or
							not place.turns then
						fail(line, "a placement needs template=, x=, y=, z= and turns=")
					end
					if place.turns < 0 or place.turns > 3 then fail(line, "turns must be 0 to 3") end
					if layout.by_id[place.id] then fail(line, "placement " .. place.id .. " given twice") end
					layout.by_id[place.id] = place
					layout.places[#layout.places + 1] = place
				else
					fail(line, "unknown layout line")
				end
			end
		end
		if not layout.town or not layout.race then
			fail(lines[1], "a layout names its town and race")
		end
		for _, list in ipairs({layout.places, layout.uses}) do
			for _, place in ipairs(list) do
				local function known(name, what)
					if not layout.palettes[name] then
						fail({number = place.line}, what .. " names the undefined palette " .. name)
					end
				end
				if place.main then known(place.main, "main=") end
				for _, channel in ipairs(place.channel_order) do
					known(place.channels[channel], channel .. "=")
				end
			end
		end
		return layout
	end

	-- A placement's palettes as one key, the way a roster's use line names
	-- them: the template, `main=` (when not the town's race palette) and the
	-- channels in name order.
	function M.use_key(template, main, channels)
		local out = {template}
		if main then out[#out + 1] = "main=" .. main end
		local names = {}
		for channel in pairs(channels) do names[#names + 1] = channel end
		table.sort(names)
		for _, channel in ipairs(names) do
			out[#out + 1] = channel .. "=" .. channels[channel]
		end
		return table.concat(out, " ")
	end

	-- The node and param2 a legend entry resolves to for one placement, in the
	-- template frame; nil for "write nothing".
	local function resolve(t, key, palette_of, race, depth)
		if key == "." then return parts.AIR, 0 end
		local entry = t.legend[key]
		if entry.kind == "race" then
			local target = entry.map[race] or entry.map["*"]
			if not target then
				error(t.path .. ":" .. entry.line .. ": the race switch '" .. key ..
					"' does not cover " .. race, 0)
			end
			return resolve(t, target, palette_of, race, depth)
		end
		local name
		if entry.kind == "node" then
			name = entry.name
		else
			local palette = palette_of(entry.channel)
			if palettes.prefix_roles[entry.role] then
				name = palette.variant(entry.role, entry.variant)
			elseif entry.optional then
				name = palette.maybe(entry.role)
			else
				name = palette.node(entry.role)
			end
			if name == nil then
				local fallback = entry.fallback or "unchanged"
				if fallback == "unchanged" then return nil end
				if fallback == "air" then return parts.AIR, 0 end
				if (depth or 0) > 8 then
					error(t.path .. ":" .. entry.line .. ": else= chain too long", 0)
				end
				return resolve(t, fallback, palette_of, race, (depth or 0) + 1)
			end
		end
		local kind = parts.param2_kind(name)
		if kind == parts.NONE then return name, 0 end
		if kind == parts.MESHOPTIONS or not entry.o then
			return name, parts.place_param2(name)
		end
		local stored, value = orientation(entry.o)
		if stored ~= kind then
			error(t.path .. ":" .. entry.line .. ": the orientation " .. entry.o ..
				" does not fit " .. name .. " (" .. kind .. ")", 0)
		end
		return name, value
	end
	M.resolve = resolve

	local function substitute(value, id)
		if type(value) == "string" then
			return (value:gsub("{id}", function() return id end))
		elseif type(value) == "table" then
			local out = {}
			for index, item in ipairs(value) do out[index] = substitute(item, id) end
			return out
		end
		return value
	end

	-- The part of one placement: the template's cells for its palettes, its
	-- points with `{id}` filled in, its pivot and its metadata.
	function M.part(t, id, race, palette_of)
		local buf = parts.buffer()
		for layer_index, layer in ipairs(t.grid) do
			local y = t.y0 + layer_index - 1
			for row_index, row in ipairs(layer) do
				local z = t.z0 + row_index - 1
				for column, key in ipairs(row) do
					if key then
						local name, param2 = resolve(t, key, palette_of, race)
						if name then buf:put(t.x0 + column - 1, y, z, name, param2) end
					end
				end
			end
		end
		local points = {}
		for _, group in ipairs(t.point_groups) do
			local list = {}
			for index, point in ipairs(t.points[group]) do
				local copy = {x = point.x, y = point.y, z = point.z, face = point.face}
				for _, attr in ipairs(point.attrs) do
					copy[attr.key] = substitute(attr.value, id)
				end
				list[index] = copy
			end
			points[group] = list
		end
		-- A generator's part always carried these groups, empty or not, and
		-- the towns walk them; a file lists no empty group.
		for _, group in ipairs(M.GROUPS) do points[group] = points[group] or {} end
		local part = {buffer = buf, w = t.w, d = t.d, points = points}
		for _, key in ipairs(t.meta_order) do part[key] = t.meta[key] end
		return part
	end

	-- A town: its layout, every template it places (each parsed once), its
	-- named palettes and its main palette. `town.part(place)` builds the part
	-- of one placement.
	function M.town(id)
		local path = M.ROOT .. "/layouts/" .. id .. ".layout"
		local layout = M.parse_layout(read(path), path)
		if layout.town ~= id then
			error(path .. ":1: the layout is for " .. layout.town .. ", not " .. id, 0)
		end
		local town = {id = id, race = layout.race, layout = layout,
			places = layout.places, templates = {}, palettes = {}}
		town.main = palettes.new(layout.race)
		for _, name in ipairs(layout.palette_order) do
			local spec = layout.palettes[name]
			town.palettes[name] = palettes.new(spec.race, spec.overrides)
		end
		for _, place in ipairs(layout.places) do
			local t = town.templates[place.template]
			if not t then
				local file = M.ROOT .. "/templates/" .. place.template .. ".tpl"
				t = M.parse_template(read(file), file, place.template)
				town.templates[place.template] = t
			end
			local race = place.main and layout.palettes[place.main].race or layout.race
			local covered = false
			for _, listed in ipairs(t.races) do
				if listed == race then covered = true end
			end
			if not covered then
				error(path .. ":" .. place.line .. ": the template " .. t.name ..
					" does not list the race " .. race, 0)
			end
			place.race = race
		end
		function town.palette_of(place)
			local main = place.main and town.palettes[place.main] or town.main
			return function(channel)
				local name = channel and place.channels[channel]
				if name then return town.palettes[name] end
				return main
			end
		end
		function town.part(place)
			return M.part(town.templates[place.template], place.id, place.race,
				town.palette_of(place))
		end
		return town
	end

	-- A capital (Round 56 lane FREEZE-CAPITALS): its roster's named palettes
	-- and every template the roster lists, each parsed once, here at load.
	-- The capital's own code places its buildings (the core's composition and
	-- the plot planner stay algorithmic, ruling 20) and names the template and
	-- the palettes of each: `capital.part(template, id, main, roof)` builds
	-- one, `main` and `roof` naming roster palettes (`main` nil: the race
	-- palette `town`); every other channel the template uses resolves to the
	-- roster palette of its own name. The placement must be one of the
	-- roster's use lines (template and palettes), so the roster cannot drift
	-- from the code; `capital.used` counts the placements per use line.
	function M.capital(id)
		local path = M.ROOT .. "/layouts/" .. id .. ".roster"
		local roster = M.parse_layout(read(path), path, true)
		if roster.town ~= id then
			error(path .. ":1: the roster is for " .. roster.town .. ", not " .. id, 0)
		end
		local capital = {id = id, race = roster.race, roster = roster, palettes = {},
			templates = {}, used = {}}
		for _, name in ipairs(roster.palette_order) do
			local spec = roster.palettes[name]
			capital.palettes[name] = palettes.new(spec.race, spec.overrides)
		end
		if not capital.palettes.town then
			capital.palettes.town = palettes.new(roster.race)
		end
		for _, use in ipairs(roster.uses) do
			local t = capital.templates[use.template]
			if not t then
				local file = M.ROOT .. "/templates/" .. use.template .. ".tpl"
				t = M.parse_template(read(file), file, use.template)
				capital.templates[use.template] = t
			end
			local race = use.main and roster.palettes[use.main].race or roster.race
			local covered = false
			for _, listed in ipairs(t.races) do
				if listed == race then covered = true end
			end
			if not covered then
				error(path .. ":" .. use.line .. ": the template " .. t.name ..
					" does not list the race " .. race, 0)
			end
			for channel in pairs(t.channels) do
				if not use.channels[channel] then
					error(path .. ":" .. use.line .. ": the template " .. t.name ..
						" uses the channel " .. channel .. ", which the line does not name", 0)
				end
			end
			for channel in pairs(use.channels) do
				if not t.channels[channel] then
					error(path .. ":" .. use.line .. ": the template " .. t.name ..
						" has no channel " .. channel, 0)
				end
			end
		end
		function capital.part(template, place_id, main, roof)
			local t = capital.templates[template]
			if not t then
				error("building templates: " .. id .. " places " .. tostring(template) ..
					", which its roster does not list", 0)
			end
			main = main or "town"
			local channels = {}
			for channel in pairs(t.channels) do
				if channel == "roof" then
					channels.roof = roof or error("building templates: " .. id .. "'s " ..
						place_id .. " (" .. template .. ") needs a roof palette", 0)
				else
					channels[channel] = channel
				end
			end
			local key = M.use_key(template, main ~= "town" and main or nil, channels)
			if not roster.use_by_key[key] then
				error("building templates: " .. id .. "'s " .. place_id .. " is '" .. key ..
					"', which its roster (" .. path .. ") does not list", 0)
			end
			capital.used[key] = (capital.used[key] or 0) + 1
			local race = roster.palettes[main] and roster.palettes[main].race or roster.race
			return M.part(t, place_id, race, function(channel)
				if channel == nil then return capital.palettes[main] end
				return capital.palettes[channels[channel]]
			end)
		end
		return capital
	end

	-- The stamped points a town takes positions from (format doc §3.4): the
	-- `sockets` points of a stamp result that carry no role (a template point
	-- of a town's own entry carries only its id and face; a socket the
	-- building itself publishes carries its role), recorded with the
	-- building that stamped them.
	function M.collect_sockets(stamped, points, building)
		for _, point in ipairs(points.sockets or {}) do
			if point.role == nil then
				if stamped[point.id] then
					error("building templates: the socket point " .. point.id .. " is in " ..
						stamped[point.id].building .. " and in " .. building, 0)
				end
				stamped[point.id] = {point = point, building = building}
			end
		end
		return stamped
	end

	-- The stamped point of the town entry `id`, which the entry says stands
	-- at `building`, or an error (also when another building has it).
	function M.stamped_point(stamped, id, building, town)
		local entry = stamped[id]
		if not entry then
			error("building templates: " .. town .. "'s socket " .. id ..
				" is not a point of " .. building, 0)
		end
		if entry.building ~= building then
			error("building templates: " .. town .. "'s socket " .. id ..
				" names " .. building .. " but is a point of " .. entry.building, 0)
		end
		entry.used = true
		return entry.point
	end

	-- Every stamped town point must have its town entry.
	function M.all_used(stamped, town)
		local ids = {}
		for id, entry in pairs(stamped) do
			if not entry.used then ids[#ids + 1] = id end
		end
		if #ids > 0 then
			table.sort(ids)
			error("building templates: " .. town .. " has no socket " ..
				table.concat(ids, ", ") .. " for its building's point", 0)
		end
	end

	-- A town's socket list in its authored order (format doc §3.4): an entry
	-- that names its `building` takes its position and facing from that
	-- building's stamped `sockets` point of the same id; every other entry is
	-- the town's own. `stamped` is what `collect_sockets` gathered.
	function M.sockets(authored, stamped, town)
		local out = {}
		for index, socket in ipairs(authored) do
			if socket.building then
				local point = M.stamped_point(stamped, socket.id, socket.building, town)
				local copy = {}
				for key, value in pairs(socket) do
					if key ~= "building" then copy[key] = value end
				end
				local dx, dz = parts.facedir_step(point.face)
				copy.x, copy.y, copy.z, copy.dir = point.x, point.y, point.z,
					{x = dx, z = dz}
				out[index] = copy
			else
				out[index] = socket
			end
		end
		M.all_used(stamped, town)
		return out
	end

	-- The point of `group` whose id is `id` in a stamp result, or an error.
	function M.point(points, group, id, where)
		for _, point in ipairs(points[group] or {}) do
			if point.id == id then return point end
		end
		error("building templates: " .. tostring(where) .. " has no " .. group ..
			" point " .. id, 0)
	end

	return M
end

return loader
