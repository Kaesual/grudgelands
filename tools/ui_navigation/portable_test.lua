-- Behavioral navigation contract: real sfinv dispatch/lifecycle with current
-- visibility, a shared frame, suspension and pure scrollbar events.
local repo = arg[1] or "."
local receive, loaded, joins = {}, {}, {}
local admin, creative, suspended = true, true, false
local enter, leave, actions, builds = 0, 0, 0, 0
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
		on_player_receive_fields = function() actions = actions + 1 end})
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
local size = player.fs:match('size%[([^%]]+)%]')
fields({grug_ui_tab_3 = "true"})
assert(ctx.page == ids[3] and enter == 2 and leave == 2)
assert(player.fs:match('size%[([^%]]+)%]') == size)
local before = builds
fields({grug_inv_scroll_full = "CHG:10"})
assert(builds == before and actions == 0)
fields({grug_ui_tab_8 = "true"})
assert(ctx.page == ids[8])
admin = false
fields({dangerous_admin_action = "true"})
assert(ctx.page == ids[1] and actions == 0)
-- A stale Creative button cannot be reinterpreted after privilege revocation.
creative = false
fields({grug_ui_tab_13 = "true"})
assert(ctx.page == ids[1] and actions == 0)
admin = true
sfinv.set_page(player, ids[8])
admin = false
local fs = sfinv.get_formspec(player, ctx)
assert(ctx.page == ids[1] and #ctx.grug_ui_nav == 7)
suspended = true
before = builds
fields({grug_ui_tab_3 = "true"})
assert(builds == before and ctx.page == ids[1])
-- The map's separate mapping uses the same visibility predicate.
suspended = false
local map = {}
grug_inventory.navigation(player, map, ids[6], 20)
local id, clicked = grug_inventory.navigation_target(player, map, {grug_ui_tab_2 = "true"})
assert(id == ids[2] and clicked)
id, clicked = grug_inventory.navigation_target(player, map, {grug_ui_tab_99 = "true"})
assert(id == nil and clicked)
assert(grug_core.ui.prepend(false):find('sound=click', 1, true))
print('UI NAVIGATION PASS: lifecycle, suspension, revoked/stale input, geometry and scrollbar sends')
