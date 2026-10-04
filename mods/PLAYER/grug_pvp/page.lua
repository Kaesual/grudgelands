-- The PvP tab (pvp-plan.md ruling 16; Round 31 lane P2): the "Flag me for
-- PvP" button, the current state (safe, or flagged with its reason and the
-- seconds left; PvP combat) and the statistics, nothing else (no rank,
-- titles or rewards). Texts: view.lua.
--
-- Legacy coordinates like the Character page (grug_inventory/pages.lua): the
-- content ends above the shared inventory at y = 7.0. While the tab is the
-- player's page its text is compared once a second and the page re-sent only
-- when it changed, so a countdown costs one send per second and a quiet tab
-- none; a state change re-sends it at once.

local V = dofile(core.get_modpath(core.get_current_modname()) .. "/view.lua")
local PAGE = "grug_pvp:pvp"
local FLAG_FIELD = "grug_pvp_flag"
local HEADING_COLOR = "#f0c75e"
local STATS_X, VALUE_DX, STATS_Y, STATS_STEP, STATS_ROWS = {0.2, 5.3}, 3.6, 4.45, 0.45, 4

local function esc(text)
	return core.formspec_escape(tostring(text or ""))
end

local function content(player, context)
	local state, stats = grug_pvp.state(player), grug_pvp.stats(player)
	context.grug_pvp_key = V.page_key(state, stats)
	local lines = V.state_lines(state)
	local fs = {
		("label[0.2,0.1;%s]"):format(esc(core.colorize(HEADING_COLOR, "PvP status"))),
		("label[0.2,0.55;%s]"):format(esc(core.colorize(lines.color, lines.headline))),
		("label[0.2,1.0;%s]"):format(esc(lines.detail)),
	}
	if lines.combat then
		fs[#fs + 1] = ("label[0.2,1.45;%s]"):format(esc(core.colorize(V.COLOR_COMBAT,
			lines.combat)))
	end
	fs[#fs + 1] = ("button[0.2,2.05;3.6,0.8;%s;Flag me for PvP]"):format(FLAG_FIELD)
	fs[#fs + 1] = "label[0.2,2.95;" .. esc("Flags you for 60 s; pressing it again " ..
		"restarts the 60 s.") .. "]"
	fs[#fs + 1] = "label[0.2,3.35;" .. esc("PvP needs both players flagged. " ..
		"There is no early unflag.") .. "]"
	fs[#fs + 1] = ("label[0.2,4.0;%s]"):format(esc(core.colorize(HEADING_COLOR,
		"Statistics")))
	for index, row in ipairs(V.stats_rows(stats)) do
		local column = math.floor((index - 1) / STATS_ROWS) + 1
		local x = STATS_X[column]
		local y = STATS_Y + ((index - 1) % STATS_ROWS) * STATS_STEP
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]label[%.2f,%.2f;%d]"):format(x, y,
			esc(row[1]), x + VALUE_DX, y, row[2])
	end
	return table.concat(fs)
end

-- Re-sends the page when the player has it open and its text changed.
local function refresh(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == PAGE and
			V.page_key(grug_pvp.state(player), grug_pvp.stats(player)) ~=
			context.grug_pvp_key then
		sfinv.set_player_inventory_formspec(player, context)
	end
end

sfinv.register_page(PAGE, {
	title = "PvP",
	get = function(_, player, context)
		return sfinv.make_formspec(player, context, content(player, context), true)
	end,
	on_player_receive_fields = function(_, player, context, fields)
		if fields[FLAG_FIELD] then
			-- The only PvP sound: the player's own press (user, Round 34);
			-- automatic flag changes stay silent.
			if grug_pvp.flag_now(player) then grug_sounds.play("pvp_on", player) end
			refresh(player)
			return true
		end
	end,
})

grug_pvp.register_on_change(refresh)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 1 then return end
	elapsed = elapsed % 1
	for _, player in ipairs(core.get_connected_players()) do
		refresh(player)
	end
end)

-- Right after Group. Each tab's hook moves only its own page, right after its
-- predecessor as it stands when the hook runs, and the hooks run in mod load
-- order; grug_pvp loads after grug_parties (optional dependency), so Group has
-- found its place when this runs and nothing moves it afterwards.
core.register_on_mods_loaded(function()
	local page, ordered, inserted = sfinv.pages[PAGE], {}, false
	for _, def in ipairs(sfinv.pages_unordered) do
		if def ~= page then ordered[#ordered + 1] = def end
		if def.name == "grug_parties:group" then
			ordered[#ordered + 1] = page
			inserted = true
		end
	end
	if not inserted then ordered[#ordered + 1] = page end
	sfinv.pages_unordered = ordered
end)
