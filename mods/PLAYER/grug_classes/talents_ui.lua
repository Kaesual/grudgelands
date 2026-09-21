-- The sfinv Talents page owns every player-facing talent mutation. The chat
-- command is deliberately read-only; rank purchases and full resets always
-- act on the PlayerRef that submitted this page's fixed button fields.

local PAGE_NAME = "grug_classes:talents"
local META_RESPEC_USED = "grug_classes:respec_used"

-- COORDINATOR PLACEHOLDER: WP44 has not published its measured reliable net
-- solo income ledger yet. Replace these six already-denominated copper values
-- with the ledger's five-minute T1..T6 outputs. They deliberately mirror the
-- decided Common-weapon axis only to keep the transaction testable; they are
-- NOT presented as measured income and are a merge blocker for the coordinator.
grug_classes.COORDINATOR_PLACEHOLDER_RESPEC_PRICES = {25, 65, 160, 400, 1000, 2500}

local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

local function level_bracket(player)
	local level = grug_xp.get_level(player)
	return math.max(1, math.min(6, math.ceil(level / 10)))
end

function grug_classes.respec_price(player)
	if player:get_meta():get_int(META_RESPEC_USED) == 0 then
		return 0
	end
	return grug_classes.COORDINATOR_PLACEHOLDER_RESPEC_PRICES[
		level_bracket(player)]
end

-- Returns true, points returned, copper charged; or false plus a refusal.
-- The withdrawal happens before the deterministic full reset, so insufficient
-- funds can never alter the build. No player name or target comes from fields.
function grug_classes.buy_respec(player)
	local spent = grug_classes.talent_points_spent(player)
	if spent <= 0 then
		return false, "No talent ranks are spent."
	end
	local price = grug_classes.respec_price(player)
	if price > 0 and not grug_money.take(player, price) then
		return false, "You need " .. grug_money.format(price) .. " to respec."
	end
	player:get_meta():set_int(META_RESPEC_USED, 1)
	local returned = grug_classes.respec(player)
	return true, returned, price
end

local function talent_mark(def)
	if def.capstone then
		return " **"
	elseif def.keystone then
		return " *"
	end
	return ""
end

-- Header stats occupy their own band above tree selection. Page content uses
-- real coordinates so button heights and text bounds share one geometry.
local function stat_lines(player)
	local crit_raw = grug_classes.get_crit_chance_raw(player) * 100
	local dodge_raw = grug_classes.get_dodge_chance_raw(player) * 100
	local crit = grug_classes.get_crit_chance(player) * 100
	local dodge = grug_classes.get_dodge_chance(player) * 100
	local armor = grug_core.get_armor_rating_breakdown and
		grug_core.get_armor_rating_breakdown(player) or {
			base = grug_core.get_armor_rating(player), multiplier = 1,
			result = grug_core.get_armor_rating(player), emergency = 0}
	local armor_reduction = grug_core.armor_reduction(armor.result,
		grug_core.get_player_level(player), 0.70) * 100
	local crit_cap = math.max(30,
		grug_classes.get_talent_bonus(player, "crit_cap_override"))
	local dodge_cap = math.max(30,
		grug_classes.get_talent_bonus(player, "dodge_cap_override"))
	return ("Crit %.1f/%.1f%% (%.0f)"):format(crit, crit_raw, crit_cap),
		("Dodge %.1f/%.1f%% (%.0f)"):format(dodge, dodge_raw, dodge_cap),
		("Armor %.1f x %.2f + %.1f = %.1f (own-level %.1f%%)"):format(
			armor.base, armor.multiplier, armor.emergency,
			armor.result, armor_reduction)
end

local function trees_for_player(player)
	return grug_classes.trees_of_class(grug_classes.get_class(player))
end

local function active_tree(player, context)
	local trees = trees_for_player(player)
	for _, tree in ipairs(trees) do
		if tree.id == context.grug_talent_tree then
			return tree, trees
		end
	end
	local tree = trees[1]
	context.grug_talent_tree = tree and tree.id or nil
	return tree, trees
end

-- Pool talents keep their compact rule text but append every rank's concrete
-- value for the viewer's current level. The conversion is shared with future
-- consumers such as Hold Ground, so UI and settlement cannot invent separate
-- rounding or class-factor rules.
function grug_classes.talent_description_for(player, def)
	local effect_key = grug_classes.pool_talent_effect_key(def)
	if not effect_key then
		return def.description
	end
	local values = def.effects[effect_key]
	local unit = effect_key == "max_mana_percent_add" and "mana"
		or effect_key == "hold_ground_absorb" and "absorb" or "HP"
	local ranks = {}
	for _, percent in ipairs(values) do
		ranks[#ranks + 1] = string.format("%g%% = %d %s", percent,
			grug_classes.pool_talent_amount(player, effect_key, percent), unit)
	end
	return def.description .. " At your level: " .. table.concat(ranks, "; ") .. "."
end

local function selected_description(player, context, tree)
	local def = context.grug_talent_selected
		and grug_classes.registered_talents[context.grug_talent_selected]
	if not def or not tree or def.tree ~= tree.id
			or def.class ~= grug_classes.get_class(player) then
		return context.grug_talent_notice
			or "Select an available talent, then click it again to buy one rank."
	end
	local rank = grug_classes.talent_rank(player, def.id)
	local status
	if rank >= def.ranks then
		status = "Maximum rank reached."
	else
		local ok, reason = grug_classes.can_spend_talent(player, def.id)
		status = ok and "Click again to buy the next rank." or reason
	end
	return ("%s%s — rank %d/%d: %s  %s"):format(def.name,
		talent_mark(def), rank, def.ranks,
		grug_classes.talent_description_for(player, def), status)
end

local function talent_content(player, context)
	local class_id = grug_classes.get_class(player)
	local class_def = class_id and grug_classes.registered_classes[class_id]
	local tree, trees = active_tree(player, context)
	local crit_line, dodge_line, armor_line = stat_lines(player)
	local fs = {
		"real_coordinates[true]",
		("label[0.20,0.35;%s]"):format(esc(class_def and class_def.name or "No class")),
		("label[9.50,0.35;%s]"):format(esc(("Points %d/%d")
			:format(grug_classes.talent_points_total(player),
				grug_classes.talent_points_available(player)))),
		("label[0.20,0.85;%s]"):format(esc(crit_line)),
		("textarea[6.65,0.65;5.95,1.00;;;%s]"):format(esc(armor_line)),
		("label[0.20,1.40;%s]"):format(esc(dodge_line)),
	}

	for index, candidate in ipairs(trees) do
		local label = candidate.name .. " " ..
			grug_classes.tree_points(player, candidate.id)
		if tree and candidate.id == tree.id then
			label = "> " .. label
		end
		fs[#fs + 1] = ("button[%.2f,2.10;2.10,0.60;grug_talent_tree_%d;%s]")
			:format(0.2 + (index - 1) * 2.25, index, esc(label))
	end

	local spent = grug_classes.talent_points_spent(player)
	if spent <= 0 then
		fs[#fs + 1] = "label[9.50,2.40;" .. esc("No ranks spent") .. "]"
	elseif context.grug_talent_respec_pending then
		fs[#fs + 1] = "button[9.50,2.10;1.45,0.60;grug_talent_respec_confirm;Confirm]"
		fs[#fs + 1] = "button[11.10,2.10;1.50,0.60;grug_talent_respec_cancel;Cancel]"
	else
		local price = grug_classes.respec_price(player)
		local price_text = price == 0 and "Free" or grug_money.format(price)
		fs[#fs + 1] = "button[9.50,2.10;3.10,0.60;grug_talent_respec;" ..
			esc("Respec: " .. price_text) .. "]"
	end

	if not tree then
		fs[#fs + 1] = "label[0.20,3.10;" ..
			esc("Choose a class before spending talent points.") .. "]"
		return table.concat(fs)
	end

	for chain_index, chain in ipairs(tree.chains) do
		local x = 0.2 + (chain_index - 1) * 6.3
		fs[#fs + 1] = ("label[%.2f,3.00;%s]"):format(x + 0.1,
			esc(chain:sub(1, 1):upper() .. chain:sub(2)))
		for tier = 1, 4 do
			local def
			for _, candidate in ipairs(tree.talents) do
				if candidate.chain == chain and candidate.tier == tier then
					def = candidate
					break
				end
			end
			if def then
				local y = 3.35 + (tier - 1) * 0.80
				local rank = grug_classes.talent_rank(player, def.id)
				local label = ("T%d %s%s %d/%d"):format(tier, def.name,
					talent_mark(def), rank, def.ranks)
				if context.grug_talent_selected == def.id then
					label = "> " .. label
				end
				local available, reason = grug_classes.can_spend_talent(player, def.id)
				if available then
					local field_index
					for index, id in ipairs(grug_classes.talent_ids) do
						if id == def.id then
							field_index = index
							break
						end
					end
					fs[#fs + 1] = ("button[%.2f,%.2f;6.05,0.65;grug_talent_pick_%d;%s]")
						:format(x, y, field_index, esc(label))
				else
					fs[#fs + 1] = ("box[%.2f,%.2f;6.05,0.65;#303030]" ..
						"textarea[%.2f,%.2f;5.89,0.65;;;%s]"):format(
						x, y, x + 0.08, y, esc(label .. (rank >= def.ranks and " [max]" or " [locked]")))
				end
				local tooltip = def.name .. " — " ..
					grug_classes.talent_description_for(player, def)
				if not available and rank < def.ranks then
					tooltip = tooltip .. " Locked: " .. reason
				end
				fs[#fs + 1] = ("tooltip[%.2f,%.2f;6.05,0.65;%s]")
					:format(x, y, esc(grug_inventory.wrap_text(tooltip, 58)))
			end
		end
	end

	local description = context.grug_talent_notice
		or selected_description(player, context, tree)
	fs[#fs + 1] = "textarea[0.20,6.65;12.35,1.45;;;" .. esc(description) .. "]"
	return table.concat(fs)
end

grug_classes.talent_formspec_content = talent_content

local function refresh_open_page(player)
	if sfinv.get_page(player) == PAGE_NAME then
		sfinv.set_page(player, PAGE_NAME)
	end
end

local function receive_fields(player, context, fields)
	if sfinv.get_page(player) ~= PAGE_NAME then
		return false
	end
	if fields.grug_talent_respec then
		if grug_classes.talent_points_spent(player) > 0 then
			context.grug_talent_respec_pending = true
			context.grug_talent_notice = "Reset every talent rank? This cannot be undone."
		end
		refresh_open_page(player)
		return true
	end
	if fields.grug_talent_respec_cancel then
		context.grug_talent_respec_pending = nil
		context.grug_talent_notice = "Respec cancelled."
		refresh_open_page(player)
		return true
	end
	if fields.grug_talent_respec_confirm then
		if not context.grug_talent_respec_pending then
			return true
		end
		context.grug_talent_respec_pending = nil
		local expected_points = grug_classes.talent_points_spent(player)
		local expected_price = grug_classes.respec_price(player)
		context.grug_talent_notice = ("Talents reset: %d points returned, %s charged.")
			:format(expected_points, expected_price == 0 and "nothing"
				or grug_money.format(expected_price))
		local ok, returned_or_reason = grug_classes.buy_respec(player)
		if not ok then
			context.grug_talent_notice = returned_or_reason
			refresh_open_page(player)
		end
		-- On success respec() fired the talents-changed refresh after the final
		-- notice was set. The returned values are deliberately not trusted for a
		-- second render; the model is deterministic from the values above.
		return true
	end

	local trees = trees_for_player(player)
	for index, tree in ipairs(trees) do
		if fields["grug_talent_tree_" .. index] then
			context.grug_talent_tree = tree.id
			context.grug_talent_selected = nil
			context.grug_talent_notice = nil
			refresh_open_page(player)
			return true
		end
	end
	for index, id in ipairs(grug_classes.talent_ids) do
		if fields["grug_talent_pick_" .. index] then
			local def = grug_classes.registered_talents[id]
			if not def or def.class ~= grug_classes.get_class(player) then
				return true
			end
			context.grug_talent_notice = nil
			if context.grug_talent_selected ~= id then
				context.grug_talent_selected = id
				refresh_open_page(player)
				return true
			end
			local ok, reason = grug_classes.spend_talent(player, id)
			if not ok then
				context.grug_talent_notice = reason
				refresh_open_page(player)
			end
			return true
		end
	end
	return false
end

sfinv.register_page(PAGE_NAME, {
	title = "Talents",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			talent_content(player, context), true)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		return receive_fields(player, context, fields)
	end,
})

-- grug_inventory establishes Character/Bags/Crafting order after this mod
-- loads. Move Talents into its specified third slot once every mod is ready,
-- without patching the vendored sfinv implementation or grug_inventory.
core.register_on_mods_loaded(function()
	local page = sfinv.pages[PAGE_NAME]
	local ordered = {}
	local inserted = false
	for _, def in ipairs(sfinv.pages_unordered) do
		if def ~= page then
			ordered[#ordered + 1] = def
		end
		if def.name == "grug_inventory:bags" then
			ordered[#ordered + 1] = page
			inserted = true
		end
	end
	if not inserted then
		ordered[#ordered + 1] = page
	end
	sfinv.pages_unordered = ordered
end)

grug_classes.register_on_talents_changed(refresh_open_page)
grug_xp.register_on_level_change(function(player, old_level, new_level)
	if old_level ~= nil then
		refresh_open_page(player)
	end
end)
