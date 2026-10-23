-- Round 57 lane DETAILS: one text line per source of the index, sorted, so
-- the engine probe (init.lua here) and the portable fixture can compare the
-- index the real engine builds with the one the stub harness builds.
return function(index)
	local lines = {}
	for item, list in pairs(index.by_item) do
		for _, source in ipairs(list) do
			lines[#lines + 1] = item .. " " .. source.kind .. " " .. tostring(source.sort)
		end
	end
	table.sort(lines)
	return table.concat(lines, "\n") .. "\n"
end
