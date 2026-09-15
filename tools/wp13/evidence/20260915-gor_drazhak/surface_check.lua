-- Hold every plot's real per-column relief to the plot rules, on every seed.
local SKIRT, CLEAR_FLOOR = 6, 8
local worst = {}
local rows = 0
local bad = 0
for index = 1, #arg do
	local path = arg[index]
	local file = assert(io.open(path, "r"), "cannot read " .. path)
	local header = file:read("*l")
	assert(header and header:find("perimeter_fall", 1, true), path)
	local columns = {}
	local order = 1
	for name in header:gmatch("[^\t\n]+") do
		columns[name] = order
		order = order + 1
	end
	for line in file:lines() do
		local field = {}
		for value in line:gmatch("[^\t\n]+") do field[#field + 1] = value end
		local id = field[columns.plot]
		local fall = tonumber(field[columns.perimeter_fall])
		local rise = tonumber(field[columns.perimeter_rise])
		local submerged = tonumber(field[columns.submerged])
		local margin = tonumber(field[columns.submerged_margin])
		local clear = tonumber(field[columns.clear_to])
		local wet = field[columns.reference_wet]
		rows = rows + 1
		local why
		if wet == "true" then why = "reference_in_water"
		elseif submerged > 0 then why = "submerged:" .. submerged
		elseif margin > 0 then why = "margin_in_water:" .. margin
		elseif fall > SKIRT then why = "fall:" .. fall
		elseif rise > clear then why = "rise:" .. rise .. "/clear:" .. clear
		elseif clear < CLEAR_FLOOR then why = "clear:" .. clear end
		if why then
			bad = bad + 1
			io.write("ILLEGAL\t", id, "\t", path:match("[^/]+/[^/]+$"), "\t",
				why, "\n")
		end
		local entry = worst[id] or {fall = 0, rise = 0, clear = clear}
		if fall > entry.fall then entry.fall = fall end
		if rise > entry.rise then entry.rise = rise end
		worst[id] = entry
	end
	file:close()
end
local ids = {}
for id in pairs(worst) do ids[#ids + 1] = id end
table.sort(ids)
local max_fall, max_rise, max_fall_id, max_rise_id = 0, 0, "-", "-"
for _, id in ipairs(ids) do
	local entry = worst[id]
	if entry.fall > max_fall then max_fall, max_fall_id = entry.fall, id end
	if entry.rise > max_rise then max_rise, max_rise_id = entry.rise, id end
end
io.write("rows\t", rows, "\tplots\t", #ids, "\tillegal\t", bad, "\n")
io.write("worst perimeter fall\t", max_fall, "\t", max_fall_id,
	"\t(skirt ", SKIRT, ")\n")
io.write("worst rise\t", max_rise, "\t", max_rise_id, "\n")
io.write("plot\tworst_fall\tworst_rise\tclear\n")
for _, id in ipairs(ids) do
	local entry = worst[id]
	io.write(id, "\t", entry.fall, "\t", entry.rise, "\t", entry.clear, "\n")
end
