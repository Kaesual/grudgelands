-- Shared offline-harness phase selector. With no list every phase runs.

return function(text)
	if text == "" then error("WP40_T2_ONLY is empty", 0) end
	local selected
	if text ~= nil then
		selected = {}
		for name in text:gmatch("[^,]+") do
			if not name:match("^[a-z][a-z0-9_]*$") or selected[name] then
				error("WP40_T2_ONLY contains an invalid or duplicate phase", 0)
			end
			selected[name] = true
		end
		if next(selected) == nil or text:sub(1, 1) == "," or
				text:sub(-1) == "," or text:find(",,", 1, true) then
			error("WP40_T2_ONLY contains an empty phase", 0)
		end
	end
	local known = {}
	local selector = {}
	function selector.enabled(name)
		if type(name) ~= "string" or not name:match("^[a-z][a-z0-9_]*$") or
				known[name] then
			error("T2 phase declaration is invalid or duplicated", 0)
		end
		known[name] = true
		return selected == nil or selected[name] == true
	end
	function selector.finish()
		if selected then
			for name in pairs(selected) do
				if not known[name] then error("unknown WP40_T2_ONLY phase " .. name, 0) end
			end
		end
	end
	return selector
end
