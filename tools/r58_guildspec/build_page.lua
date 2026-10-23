-- Round 58 lane GUILDSPEC: the tuning page for the Miner's Guild numbers
-- (German text; numbers and item names as in the game).
--
--   luajit tools/r58_guildspec/build_page.lua REPO OUT_HTML
--
-- Writes one self-contained page from page.html: every number of the
-- catalogue (mods/PLAYER/grug_guild/catalog.lua VALUES, the keys unchanged),
-- the yield model's inputs (model.lua) and its results at the proposed
-- numbers, which the page's own copy of the model checks on load. The page
-- saves {values, notes, general, savedAt} to the document picks/tuning of
-- its shared store; tools/r58_guildspec/apply_tuning.py writes the values
-- back into the catalogue. The item names come from the game's registry
-- (the r57_details harness), so they read as in the game.

local M = {}

-- One line of reason per number (German), by key or key group.
local REASONS = {
	["rank.1"] = "Ein erster Schritt: etwa eine halbe Stunde in T1, dann ist Ore Sense I und Treasure Hunt I kaufbar.",
	["rank.2"] = "Etwa anderthalb Stunden in T2 (Stufe 11–20), dann die T2-Ware.",
	["rank.3"] = "Etwa zwei Stunden in T3; der erste Umhang (Achievement Rang 3).",
	["rank.4"] = "Etwa drei Stunden in T4 (Stufe 31–40), dann die T4-Ware.",
	["rank.5"] = "Etwa vier Stunden in T5.",
	["rank.6"] = "Etwa fünf Stunden in T6: alle Verbrauchsgüter frei, der zweite Umhang.",
	["rank.7"] = "Ab hier nur noch Ansehen: knapp acht Stunden in T6.",
	["rank.8"] = "Gut elf Stunden in T6.",
	["rank.9"] = "Knapp fünfzehn Stunden in T6.",
	["rank.10"] = "Gut vierundzwanzig Stunden in T6: der geflügelte Umhang, bewusst schwer (insgesamt ~75 h).",
	bulk = "Stein, Sand und Kies sehr niedrig: 1 Punkt je 50, so bleibt Stein ein paar Prozent des Rufs.",
	ore = "Gewöhnliches Erz: 1 Punkt, je Erntestufe über T1 verdoppelt.",
	precious = "Edelmetall oder Kristall (seltener als gewöhnliches Erz): 2 Punkte, je Erntestufe verdoppelt.",
	gem = "Edelstein (etwa ein Viertel so häufig wie Erz): 4 Punkte, je Erntestufe verdoppelt.",
	pending = "Noch nicht im Tausch: der Steinmetz verkauft es, bis REP es aus dem Regal nimmt (§2a).",
	["ore_sense.price"] = "Teuer: etwa eine Stunde Abbau in dieser Stufe für eine halbe Stunde Wirkung.",
	["treasure_hunt.price"] = "Wie Ore Sense: etwa eine Stunde Abbau in dieser Stufe.",
	["consumable.sell_copper"] = "Ein Händler zahlt 5 % des Rufpreises in Kupfer (1 Ruf ≈ 1c an Material): nie mehr, als das Material dahinter brachte.",
	["ore_sense.duration"] = "30 Minuten: eine Bergbausitzung; läuft weiter über Logout und Tod.",
	["ore_sense.range"] = "Suchradius in Blöcken: groß genug, dass fast immer ein Ziel darin liegt, klein genug für eine kurze Suche.",
	["ore_sense.interval_min"] = "Regel: alle 60–120 s ein Hinweis (untere Grenze).",
	["ore_sense.interval_max"] = "Regel: alle 60–120 s ein Hinweis (obere Grenze).",
	["ore_sense.marker_seconds"] = "Regel: die Markierung bleibt 5 s sichtbar, nur für dich.",
	["treasure_hunt.duration"] = "30 Minuten, wie Ore Sense.",
	["treasure_hunt.place_min"] = "Mindestabstand des versteckten Blocks: nicht direkt neben dir.",
	["treasure_hunt.place_max"] = "Höchstabstand: in ein bis zwei Minuten erreichbar.",
	["treasure_hunt.marker_range"] = "Bis zu dieser Entfernung ist der Block für dich markiert.",
	["treasure_hunt.remove_distance"] = "Weiter weg (oder offline) entfernt sich der Block selbst.",
	["treasure_hunt.respawn_seconds"] = "Pause bis zum nächsten Block, nachdem einer abgebaut oder verschwunden ist.",
	["treasure_hunt.check_seconds"] = "So oft prüft der Block, ob du noch in der Nähe bist.",
	["remains.copper"] = "Kupfer im Münzbeutel: der größere Teil des Werts, tiefer mehr.",
	["remains.bars"] = "Barren der Stufe: nützlich zum Handwerk, nicht tauschbar (kein Ruf-Kreislauf).",
	["remains.gem_chance"] = "Einmal in so vielen Funden ein geschliffener Edelstein der Stufe.",
	["model.active"] = "Anteil der Stunde, in dem wirklich gegraben wird (Rest: Aufzug, Wege, Suchen, Sortieren, Kämpfe).",
	["model.overhead"] = "Sekunden je Block neben dem Graben selbst (Schritt, Zielen, Aufsammeln).",
	["model.exposure"] = "Gesehene Felsblöcke je gegrabenem Block (ein Gang zeigt Wände, Boden, Decke).",
	["model.stone_carried"] = "Anteil des gegrabenen Steins, den man zum Tausch mitnimmt.",
	["model.sense_extra"] = "Anteil der Ore-Sense-Hinweise, die man sonst nicht gefunden hätte.",
	["model.hunt_reach"] = "Sekunden, bis ein neuer Remains-Block gefunden und abgebaut ist.",
}

local ORE_CLASS = {coal = "ore", copper = "ore", tin = "ore", iron = "ore", quartz = "ore",
	anthracite = "ore", gold = "precious", silver = "precious", emberglass = "precious",
	abyssal_crystal = "precious"}

local function encode(value)
	local kind = type(value)
	if kind == "number" then
		if value == math.floor(value) and math.abs(value) < 1e15 then
			return string.format("%d", value)
		end
		return string.format("%.10g", value)
	elseif kind == "string" then
		return '"' .. value:gsub('[%c"\\]', function(c)
			if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
			return string.format("\\u%04x", c:byte())
		end) .. '"'
	elseif kind == "boolean" then
		return value and "true" or "false"
	elseif kind == "table" then
		if #value > 0 or next(value) == nil then
			local out = {}
			for index = 1, #value do out[index] = encode(value[index]) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys)
		local out = {}
		for index, key in ipairs(keys) do out[index] = encode(key) .. ":" .. encode(value[key]) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end
M.encode = encode

-- The page's data: catalogue values and rows, model inputs, reference results.
function M.data(repo, names)
	local model = dofile(repo .. "/tools/r58_guildspec/model.lua")
	local data = model.data(repo)
	local catalog = data.catalog
	local result = model.run(repo)
	local function name(item) return names and names[item] or item end
	local out = {values = catalog.VALUES, reasons = REASONS, assumptions = model.ASSUMPTIONS,
		income = model.INCOME, dig = {}, ores = {}, exchange = {}, consumables = {}, remains = {},
		ranks = catalog.MAX_RANK, ref = {rep = {}, hours = {}, sense = {}, hunt = {}}}
	for tier = 1, 6 do out.dig[tier] = data.dig[tier] end
	local by_item = {}
	for _, row in ipairs(data.ore_rows) do
		local resource = data.resources[row.key]
		local denominators = {}
		for tier = 1, 6 do denominators[tier] = row.denominators[tier] or 0 end
		out.ores[#out.ores + 1] = {key = row.key, item = resource.raw_item, den = denominators,
			cap = row.max_nodes_per_vein,
			copper = data.prices.payout(resource.gem and "gem" or "raw", resource.harvest_tier)}
		by_item[resource.raw_item] = resource
	end
	for _, row in ipairs(catalog.EXCHANGE) do
		local resource = by_item[row.item]
		local class = resource and (resource.gem and "gem" or ORE_CLASS[resource.key]) or "bulk"
		out.exchange[#out.exchange + 1] = {item = row.item, name = name(row.item), class = class,
			tier = resource and resource.harvest_tier or 0, pending = row.pending and true or false}
	end
	for tier = 1, 6 do
		local sense = catalog.consumable("ore_sense", tier)
		local hunt = catalog.consumable("treasure_hunt", tier)
		out.consumables[tier] = {tier = tier, use_level = sense.use_level, rank = sense.rank,
			sense = sense.name, hunt = hunt.name, target = catalog.ORE_SENSE_TARGETS[tier][1],
			target_name = name(data.resources[catalog.ORE_SENSE_TARGETS[tier][1]].raw_item)}
		local remains = catalog.remains(tier)
		out.remains[tier] = {tier = tier, bar = name(remains.bar), gem = name(remains.gem)}
	end
	local bars, gems = model.loot_copper(data)
	out.bar_copper, out.gem_copper = bars, gems
	for tier = 1, 6 do
		out.ref.rep[tier] = result.tiers[tier].rep
		out.ref.sense[tier] = result.consumables[tier].sense_extra
		out.ref.hunt[tier] = result.consumables[tier].hunt_copper
	end
	for rank = 1, catalog.MAX_RANK do out.ref.hours[rank] = result.ranks[rank].cumulative end
	return out
end

function M.build(repo, names)
	local handle = assert(io.open(repo .. "/tools/r58_guildspec/page.html", "rb"))
	local template = handle:read("*a")
	handle:close()
	local json = encode(M.data(repo, names)):gsub("</", "<\\/")
	local html = template:gsub("__DATA__", function() return json end)
	return html
end

-- The game's item names (first description line), from the harness.
function M.names(repo)
	local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
	local names = {}
	for item, def in pairs(game.items) do
		local text = (def.description or ""):match("^[^\n]*") or ""
		if text ~= "" then names[item] = text end
	end
	return names
end

if arg and arg[0] and arg[0]:match("build_page%.lua$") and arg[1] and arg[2] then
	local html = M.build(arg[1], M.names(arg[1]))
	local out = assert(io.open(arg[2], "wb"))
	out:write(html)
	out:close()
	print("R58 GUILDSPEC page written: " .. arg[2] .. " (" .. #html .. " bytes)")
end

return M
