-- Startup audit 3, extended to the dual furnace (WP26, task card §3.5/gate 4).
--
-- `init.lua`'s craft walk judges only `normal` and `cooking` ENGINE recipes
-- (`CONSUMING_METHODS`), because `core.get_all_craft_recipes` is the only thing
-- it can walk and that is all the engine holds. The dual furnace's `dualfurn`
-- recipes are not engine recipes at all -- they live in `grug_smelting`'s own
-- registry -- so every alloy in the six-tier chain was invisible to the §3.8
-- anti-loop rule. This file closes that hole with the same price resolution
-- (`grug_traders.sell_price`), the same judgement (an output worth more at the
-- vendor than its priced inputs is a money printer with one extra step) and
-- the same error-level report.
--
-- It is a separate file, and the judgement is a PURE function of a recipe list,
-- for one reason: `tools/wp26/smelting_kat.lua` loads exactly these bytes under
-- a stub and proves the walk catches a deliberately overpriced synthetic
-- recipe. An audit nobody has ever seen fire is not evidence.
--
-- `grug_smelting` is an `optional_depends`: with the mod absent this file
-- registers a callback that finds nothing and says nothing.

-- "example:item 9" -> "example:item", 9. Same parse as `init.lua`'s, and for
-- the same reason: an output may carry a count, an input normally does not.
local function split_item(str)
	local name, count = str:match("^(%S+)%s+(%d+)$")
	if name then
		return name, tonumber(count)
	end
	return str, 1
end

-- Judge a list of `{output = ..., inputs = {a, b}}` rows against the vendor
-- prices and return one message per money loop, sorted for a stable log.
--
-- A recipe is only judged when EVERY input resolves to a price -- an unpriced
-- input is not a loop we can judge, it is an unknown. That is deliberately the
-- same limit `init.lua` states for the engine walk, and it is why WP26 ships
-- no price of its own: today only the Iron Bar is priced, so this audit is
-- mostly silent by construction and only WP44's later repricing makes it
-- speak. The negative test is what proves it can.
function grug_traders.alloy_loop_findings(recipes)
	local findings = {}
	for _, recipe in ipairs(recipes or {}) do
		local out_name, out_count = split_item(recipe.output)
		local out_price = grug_traders.sell_price(out_name) * out_count
		local input_total, priced, used = 0, true, {}
		for _, input in ipairs(recipe.inputs or {}) do
			local in_name, in_count = split_item(input)
			local in_price = grug_traders.sell_price(in_name)
			if in_price <= 0 then
				priced = false
				break
			end
			input_total = input_total + in_price * in_count
			used[#used + 1] = input
		end
		if priced and #used > 0 and out_price > input_total then
			findings[#findings + 1] = "'" .. out_name .. "' x" .. out_count ..
				" is worth " .. out_price .. "c at the vendor but its " ..
				"dualfurn recipe consumes only " .. input_total ..
				"c worth of priced inputs (" .. table.concat(used, ", ") ..
				") — items_crafting.md §3.8 anti-loop rule"
		end
	end
	table.sort(findings)
	return findings
end

core.register_on_mods_loaded(function()
	local smelting = rawget(_G, "grug_smelting")
	if type(smelting) ~= "table" or type(smelting.RECIPES) ~= "table" then
		return
	end
	local findings = grug_traders.alloy_loop_findings(smelting.RECIPES)
	for _, message in ipairs(findings) do
		core.log("error", "[grug_traders] CRAFT LOOP: " .. message)
	end
end)
