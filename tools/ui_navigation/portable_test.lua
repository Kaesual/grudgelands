-- Behavioral navigation contract: real sfinv dispatch/lifecycle with current
-- visibility, a shared frame, suspension and pure scrollbar events.
local repo = arg[1] or "."
local receive, loaded, joins = {}, {}, {}
local admin, creative, suspended = true, true, false
local enter, leave, actions, builds = 0, 0, 0, 0
local quits, denials = 0, 0
local denied_handles = false
core = {formspec_escape = function(s) return tostring(s) end,
	colorize = function(_, s) return s end,
	register_on_joinplayer = function(f) joins[#joins + 1] = f end,
	register_on_leaveplayer = function() end,
	register_on_mods_loaded = function(f) loaded[#loaded + 1] = f end,
	register_on_player_receive_fields = function(f) receive[#receive + 1] = f end,
	log = function() end}
minetest = core
dump = tostring
grug_core, grug_sounds = {}, {CLICK_STYLE = "style_type[button;sound=click]"}
grug_inventory = {}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
dofile(repo .. "/mods/BASE/sfinv/api.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/ui.lua")
dofile(repo .. "/mods/PLAYER/grug_inventory/navigation.lua")
local ids = grug_inventory.TAB_ORDER
for i = 1, 13 do
	local id = ids[i] or "creative:" .. i
	sfinv.register_page(id, {title = i == 3 and "Talents & Skills" or "Page " .. i,
		is_in_nav = function() return i <= 7 or (i == 8 and admin) or (i >= 9 and creative) end,
		get = function(_, player, context)
			return sfinv.make_formspec(player, context, "label[0,0;Content]", false)
		end,
		on_enter = function() enter = enter + 1 end,
		on_leave = function() leave = leave + 1 end,
		on_navigation_denied = i == 8 and function(_, player)
			assert(not admin, "refusal hook must never run for an authorized page")
			denials = denials + 1
			if denied_handles then sfinv.set_page(player, ids[1]); return true end
			return false
		end or nil,
		on_player_receive_fields = function(_, _, _, data)
			if data.quit then
				for field in pairs(data) do assert(field == "quit", "close must not submit editable values") end
				quits = quits + 1
			else actions = actions + 1 end
		end})
end
function sfinv.get_homepage_name() return ids[1] end
function sfinv.inventory_suspended() return suspended end
local player = {get_player_name = function() return "tester" end,
	set_inventory_formspec = function(self, fs) self.fs = fs; builds = builds + 1 end}
local function fields(data) for _, f in ipairs(receive) do f(player, "", data) end end
sfinv.set_page(player, ids[1])
local ctx = sfinv.get_or_create_context(player)
assert(#ctx.grug_ui_nav == 13)
assert(player.fs:find('grug_ui_tab_13', 1, true))
assert(not player.fs:find('tabheader[', 1, true))
local buttons = 0
for _, y, _, h in player.fs:gmatch('button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);grug_ui_tab_%d+;') do
	assert(tonumber(y) + tonumber(h) < ctx.grug_ui_header_h, "navigation must fit above body")
	buttons = buttons + 1
end
assert(buttons == 13)
local size = player.fs:match('size%[([^%]]+)%]')
fields({grug_ui_tab_3 = "true"})
assert(ctx.page == ids[3] and enter == 2 and leave == 2)
assert(player.fs:match('size%[([^%]]+)%]') == size)
local before = builds
fields({grug_inv_scroll_full = "CHG:10"})
assert(builds == before and actions == 0)
fields({quit = "true", grug_ui_close = "X", grug_party_health_colors = "2",
	grug_inv_scroll_full = "VAL:21", draft_text = "unsent"})
assert(quits == 1 and actions == 0 and builds == before and denials == 0)
assert(ctx.grug_inv_scroll.full == 21)
fields({quit = "true"})
assert(quits == 2 and builds == before)
fields({grug_ui_tab_8 = "true"})
assert(ctx.page == ids[8])
admin = false
fields({dangerous_admin_action = "true"})
assert(ctx.page == ids[1] and actions == 0)
assert(denials == 1)
-- Owners such as Admin Mail can perform their own refusal cleanup and exit.
admin, denied_handles = true, true
sfinv.set_page(player, ids[8])
admin = false
before = builds
fields({dangerous_admin_action = "true", grug_ui_close = "X", quit = "true"})
assert(ctx.page == ids[1] and denials == 2 and actions == 0 and builds == before + 1)
denied_handles = false
-- A stale Creative button cannot be reinterpreted after privilege revocation.
creative = false
fields({grug_ui_tab_13 = "true"})
assert(ctx.page == ids[1] and actions == 0)
admin = true
sfinv.set_page(player, ids[8])
admin = false
local fs = sfinv.get_formspec(player, ctx)
assert(ctx.page == ids[1] and #ctx.grug_ui_nav == 7)
assert(ctx.grug_ui_header_h == 1.5, 'ordinary pages use one compact row')
assert(fs:match('size%[([^%]]+)%]') ~= size, 'revoked extra pages no longer reserve a second row')
suspended = true
before = builds
fields({grug_ui_tab_3 = "true"})
assert(builds == before and ctx.page == ids[1])
-- A stale click on the revoked page itself also leaves that page safely.
suspended, creative = false, true
sfinv.set_page(player, "creative:9")
local own
for index, value in ipairs(ctx.grug_ui_nav) do if value == "creative:9" then own = index end end
creative = false
fields({["grug_ui_tab_" .. own] = "true"})
assert(ctx.page == ids[1])
-- The map's separate mapping uses the same visibility predicate.
suspended = false
local map = {}
grug_inventory.navigation(player, map, ids[6], 20)
local id, clicked = grug_inventory.navigation_target(player, map, {grug_ui_tab_2 = "true"})
assert(id == ids[2] and clicked)
id, clicked = grug_inventory.navigation_target(player, map, {grug_ui_tab_99 = "true"})
assert(id == nil and clicked)
assert(grug_core.ui.prepend(false):find('sound=click', 1, true))
-- Larger GUI fonts get additional rows, all pages remain reachable, and
-- every tab shares the same frame at this size/permission set.
core.get_player_window_information = function()
    return {size = {x = 1035, y = 696}, real_gui_scaling = 1.5, max_formspec_size = {x = 20, y = 14}}
end
assert(math.abs(grug_core.ui.text_scale(player) - 2 / 3) < 0.00001)
assert(grug_core.ui.text_scale(nil) == 1, "presentation callers may omit player")
admin, creative = true, true
sfinv.set_page(player, ids[1])
local scaled_size = player.fs:match('size%[([^%]]+)%]')
assert(#ctx.grug_ui_nav == 13 and ctx.grug_ui_header_h > 2)
for i = 1, 13 do
    fields({['grug_ui_tab_' .. i] = 'true'})
    assert(player.fs:match('size%[([^%]]+)%]') == scaled_size)
    assert(player.fs:find('grug_ui_tab_13', 1, true))
end
-- Creative titles carry translation markup; invisible bytes must not steal
-- width from the adjacent Admin Mail tab.
core.get_translated_string = function(_, text)
    return (text:gsub("\27%([^)]*%)", ""):gsub("\27E", ""))
end
local creative_page = sfinv.pages["creative:9"]
creative_page.title = "All"
local plain = grug_inventory.navigation(player, ctx, ids[1])
creative_page.title = "\27(T@creative)All\27E"
local marked = grug_inventory.navigation(player, ctx, ids[1])
local function tab_widths(fs)
    local result = {}
    for width in fs:gmatch('button%[[%d.]+,[%d.]+;([%d.]+),[%d.]+;grug_ui_tab_%d+;') do
        result[#result + 1] = width
    end
    return table.concat(result, ',')
end
assert(tab_widths(plain) == tab_widths(marked), 'translation markup must not change tab widths')
print('UI NAVIGATION PASS: lifecycle, suspension, revoked/stale input, geometry and scrollbar sends')
