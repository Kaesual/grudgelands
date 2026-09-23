-- Bounded production-page fixture; caller owns interpreter/digest selection.
return function(repo)
 local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
 local page, step, leave, death
 local context = {page = "grug_map:atlas"}
 local sends, home_calls, form = 0, 0, ""
 local position, heading = {x = 0, z = 0}, 0
 local rows = true
 local player = {get_player_name = function() return "tester" end,
  get_pos = function() return position end,
  set_inventory_formspec = function(_, fs) sends = sends + 1; form = fs end}
 local sfinv = {contexts = {tester = context}}
 function sfinv.make_formspec(_, _, content, inventory, size)
  assert(not inventory); return size .. "tabheader[0,0;nav;Map;1;true;false]" .. content
 end
 function sfinv.register_page(_, definition) page = definition end
 function sfinv.set_player_inventory_formspec(p, c) p:set_inventory_formspec(page:get(p, c)) end
 function sfinv.set_page(p, name)
  page:on_leave(p, context); context.page = name
  if name == "grug_map:atlas" then page:on_enter(p, context); sfinv.set_player_inventory_formspec(p, context) end
 end
 local env = setmetatable({sfinv = sfinv, grug_map = {atlas = atlas},
  grug_core = {zone_authority_installed = function() return true end,
   settlement_socket_settlements = function() return {} end},
  grug_zones = {at = function() return {display_name = "Test"} end},
  grug_home = {get = function() return {label = "Home"} end,
   remaining = function() return 0 end, is_pending = function() return false end,
   return_home = function() home_calls = home_calls + 1 end},
  core = {formspec_escape = function(s) return s:gsub("([%[%;%,%]\\])", "\\%1") end,
   register_globalstep = function(f) step = f end,
   register_on_leaveplayer = function(f) leave = f end,
   register_on_dieplayer = function(f) death = f end,
   get_player_by_name = function() return player end}}, {__index = _G})
 local chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_map/page.lua"))
 setfenv(chunk, env); chunk()
 atlas.register_marker_provider("live", function()
  if not rows then return {} end
  return {{id = "player", label = "Viewer", detail = "Viewer", kind = "player",
   position = position, heading = heading},
   {id = "quest", label = "Quest", position = {x = 3600, z = -3200}, kind = "quest"}}
 end)
 local function send(fields) page:on_player_receive_fields(player, context, fields) end
 local function ticks() step(0.5); step(0.5) end
 local function has(text) assert(form:find(text, 1, true), text) end
 sfinv.set_page(player, "grug_map:atlas")
 has("formspec_version[4]size[10.65,11.20]")
 has("image[0,0;10.08,8.96;grug_map_atlas_world.png]")
 has("max=0;"); assert(not form:find("grug_map_view_", 1, true))
 -- Engine clipping contract: every hitbox is inside both clipper parents;
 -- navigation/actions are outside. Forged unknown fields cannot act.
 local depth = 0
 for kind, body in form:gmatch("([%w_]+)%[([^%]]*)%]") do
  if kind == "scroll_container" then depth = depth + 1 end
  if kind == "scroll_container_end" then depth = depth - 1 end
  if (kind == "button" or kind == "image_button") then
   if body:find("grug_map_marker_", 1, true) then assert(depth == 2)
   else assert(depth == 0) end
  end
 end
 assert(depth == 0)
 local ignored = sends
 send({grug_map_marker_forged = true})
 assert(sends == ignored and home_calls == 0)
 assert(#atlas.views() == 1)
 for _, zoom in ipairs({1, 2, 4}) do
  local limit = atlas.scroll_limit(zoom)
  assert(limit == (zoom-1)*1000)
  for _, x in ipairs({-3600,3600}) do for _, z in ipairs({-3200,3200}) do
   local sx, sy = atlas.world_to_screen(atlas.view(), {x=x,z=z}, 0,0,10.08*zoom,8.96*zoom)
   assert(sx == (x+3600)/7200*10.08*zoom)
   assert(sy == (3200-z)/6400*8.96*zoom)
  end end
 end
 send({grug_map_zoom_in = true})
 assert(context.grug_map_zoom == 2 and context.grug_map_scroll_x == 500)
 has("scroll_container[0,0;20.16,8.96;"); has(";0.42,0.42;")
 local before = sends
 send({grug_map_scroll_x = "CHG:750", grug_map_scroll_y = "VAL:250"})
 ticks(); assert(sends == before, "scroll-only must not resend")
 position = {x=720,z=640}; heading = math.pi
 send({grug_map_scroll_x = "CHG:800"})
 step(0.5); assert(sends == before, "active scroll must defer rebuild")
 step(0.5); assert(sends == before + 1, "unsent movement must survive scroll")
 has("grug_map_scroll_x;800]"); has("grug_map_heading_gold_08.png")
 send({grug_map_zoom_in = true, grug_map_scroll_x = "VAL:750", grug_map_scroll_y = "VAL:250"})
 assert(context.grug_map_zoom == 4 and context.grug_map_scroll_x == 2000 and context.grug_map_scroll_y == 1000)
 has("image[0,0;40.32,35.84;"); has(";0.42,0.42;")
 send({grug_map_scroll_x = "CHG:999999", grug_map_scroll_y = "VAL:-30"})
 assert(context.grug_map_scroll_x == 3000 and context.grug_map_scroll_y == 0)
 send({grug_map_scroll_x = "CHG:nan", grug_map_scroll_y = "BOGUS:200"})
 assert(context.grug_map_scroll_x == 3000 and context.grug_map_scroll_y == 0)
 local field = atlas.field_id("live:player")
 send({[field] = true}); assert(context.grug_map_selected == "live:player" and context.grug_map_zoom == 4)
 send({grug_map_home = true}); assert(home_calls == 1 and context.grug_map_scroll_x == 3000)
 rows = false; ticks(); assert(context.grug_map_selected == nil)
 send({grug_map_zoom_out = true}); send({grug_map_zoom_out = true})
 assert(context.grug_map_zoom == 1 and context.grug_map_scroll_x == 0)
 send({grug_map_zoom_in = true}); send({quit = true})
 assert(context.page == "grug_inventory:character")
 before = sends; ticks(); assert(sends == before)
 sfinv.set_page(player, "grug_map:atlas")
 assert(context.grug_map_zoom == 1 and context.grug_map_scroll_y == 0)
 death(player); assert(context.page == "grug_inventory:character")
 sfinv.set_page(player, "grug_map:atlas"); leave(player)
 before = sends; position = {x=100,z=100}; ticks(); assert(sends == before)
 return "r19_map: whole-world, projection, center-zoom, clipping-structure, fixed-markers, scroll-signature, lifecycle PASS"
end
