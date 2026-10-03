-- Dragon arena dressing (Round 31 DA2, round31-plan.md §6 item 11). The
-- terrain already carries the arena's round, gently swelling floor of the
-- local ground (`height.lua`); this pass, last in the R7 successor settle
-- (after the dragon POI's blueprint, which only clears the spawn), writes the
-- hazards of `arena_layout.lua` onto that floor, following its height:
--   * breaking ice and ember fissures replace the top node (flush with the
--     floor), basalt frames the fissures;
--   * frost terraces stand flat at one or two nodes above the ground at the
--     terrace's centre;
--   * fallen trunks lie one node high on the ground;
--   * sparse rim stones mark the arena's radius, the dragon's leash.
-- A dusting of snow or a plant on a dressed column is cleared.
return function(core_api, source, layout)
	local function fail(message) error("WP40 arena writer: " .. message, 0) end
	if type(core_api) ~= "table" or type(core_api.get_content_id) ~= "function" or
			type(core_api.registered_nodes) ~= "table" or type(source) ~= "table" or
			type(layout) ~= "table" or type(layout.hazard_at) ~= "function" then
		fail("construction seam differs")
	end
	local function cid(name)
		if not core_api.registered_nodes[name] then fail("arena node missing: " .. name) end
		return core_api.get_content_id(name)
	end
	local N = {}
	for key, name in pairs(layout.NODES) do N[key] = cid(name) end
	local trunk = cid("default:jungletree")
	local rims = {}
	for _, theme in pairs(layout.THEMES) do rims[theme.rim] = cid(theme.rim) end
	local air = core_api.CONTENT_AIR or cid("air")
	local arenas = layout.arenas(source)
	if #arenas ~= 2 then fail("two dragon arenas expected, found " .. #arenas) end

	local writer = {}
	-- `context`: the R7 successor context (min/max bounds, settled_at,
	-- column_values_at, write_road).
	function writer.dress(context)
		local min_y, max_y = context.min_y, context.max_y
		local write = context.write_road
		local function put(x, y, z, c, param2)
			if y >= min_y and y <= max_y then write(x, y, z, c, param2 or 0) end
		end
		local function clear(x, y, z)
			if y >= min_y and y <= max_y and context.settled_at(x, y, z) ~= air then
				write(x, y, z, air, 0)
			end
		end
		local function ground(x, z) return (select(6, context.column_values_at(x, z))) end
		local count = 0
		for index = 1, #arenas do
			local a = arenas[index]
			local reach = a.radius
			local x0, x1 = math.max(context.min_x, a.x - reach), math.min(context.max_x, a.x + reach)
			local z0, z1 = math.max(context.min_z, a.z - reach), math.min(context.max_z, a.z + reach)
			for z = z0, z1 do
				for x = x0, x1 do
					local kind, detail, extra = layout.hazard_at(a.theme, a.radius,
						x - a.x, z - a.z, x, z)
					if kind then
						count = count + 1
						local y = ground(x, z)
						if kind == "thin_ice" or kind == "ember" or kind == "basalt" then
							put(x, y, z, N[kind])
							clear(x, y + 1, z)
						elseif kind == "frost" then
							local top = ground(a.x + extra[1], a.z + extra[2]) + detail
							for fy = y + 1, top do put(x, fy, z, N.frost_stone) end
							clear(x, math.max(y, top) + 1, z)
						elseif kind == "trunk" then
							put(x, y + 1, z, trunk, detail)
							clear(x, y + 2, z)
						elseif kind == "rim" then
							for h = 1, detail do put(x, y + h, z, rims[extra]) end
							clear(x, y + detail + 1, z)
						end
					end
				end
			end
		end
		return count
	end
	return writer
end
