-- Round 64 before/after HUD benchmark, actual seed-42 roster from probe/init.lua.
-- luajit tools/r64_map/bench.lua CODE_TREE REPO ROSTER SCENARIO SPEED
-- SCENARIO: capital/camp/sparse; SPEED: 4/8/12 nodes per second.
-- All faction quest givers are available: deliberate visibility upper bound.
-- Protocol payload bytes include HUDADD/HUDCHANGE, not UDP/reliable framing,
-- retransmissions, compression or media. CPU timings are stand-in diagnostics.
local tree, repo = assert(arg[1]),assert(arg[2])
local roster=assert(loadfile(assert(arg[3])))()
local scenario,speed=assert(arg[4]),assert(tonumber(arg[5]))
local label=scenario .. " " .. speed
local centre
local candidates={}
for _,r in ipairs(roster.settlements) do
 if scenario=="capital" and r.key=="highcourt" then centre=r.anchor end
 if scenario=="camp" and r.slot=="mining_camp" then candidates[#candidates+1]=r end
end
table.sort(candidates,function(a,b) return a.key<b.key end)
if scenario=="camp" then centre=assert(candidates[1]).anchor end
if scenario=="sparse" then centre={x=0,z=-3000} end
assert(centre,"missing route " .. scenario)


local steps, joins = {}, {}
local function now_us() return os.clock()*1e6 end
local players, windows = {}, {}
-- Simulated seconds since 04:30 at the day phase's clock speed (60): the
-- daytime band beside the minimap (Round 48) changes once per 30 s.
local clock = 0
local traffic={packets=0,bytes=0,adds=0,add_bytes=0,max_visible=0}
local textures={}
local function reset() traffic={packets=0,bytes=0,adds=0,add_bytes=0,max_visible=0} end
local function new_player(name, pos)
	local meta, huds, next_id = {}, {}, 0
	local p = {name = name, pos = pos, yaw = 0.7}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return self.yaw end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, v) meta[k] = v end}
	end
	function p:hud_add(def)
  next_id=next_id+1
  local copy={};for k,v in pairs(def) do copy[k]=v end;huds[next_id]=copy
  if self.name=="me" then
   traffic.adds=traffic.adds+1
   traffic.add_bytes=traffic.add_bytes+82+#(def.name or "")+#(def.text or "")+#(def.text2 or "")
  end
  return next_id
 end
 function p:visible()
  local n=0
  for _,h in pairs(huds) do
   local t=h.text or ""
   if t:match("^grug_map_") and not t:find("minimap_") and not t:find("heading_") and not t:find("rim_") then n=n+1 end
  end
  return n
 end
 function p:get_wielded_item() return {get_name=function() return "" end} end
	function p:hud_change(id, stat, value)
  huds[id][stat]=value
  if stat=="text" and type(value)=="string" and value:match("^%[combine:") then textures[value]=true end
		if self.name ~= "me" then return end
		traffic.packets = traffic.packets + 1
		local size = type(value) == "string" and 2 + #value or type(value) == "table" and 8 or 4
		traffic.bytes = traffic.bytes + 5 + size
	end
	function p:hud_remove(id) huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	return p
end
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(mod)
		local roots = {grug_map = tree .. "/mods/PLAYER/grug_map",
			grug_jobs = repo .. "/mods/PLAYER/grug_jobs",
			grug_mounts = repo .. "/mods/PLAYER/grug_mounts"}
		return roots[mod]
	end,
	get_modnames = function() return {"grug_jobs", "grug_map", "grug_mounts"} end,
	get_worldpath = function() return "/nonexistent-world" end,
	get_us_time = now_us,
	log = function() end,
	settings = {get = function() return nil end},
	encode_png = function(w, h, data) return data end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_mods_loaded = function(fn) steps.loaded = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		return list
	end,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function(name) return windows[name] end,
	get_timeofday = function() return 0.1875 + clock * 60 / 86400 end,
	formspec_escape = function(text) return text end,
	registered_entities = {},
})
rawset(_G, "grug_core", {DAY_PHASE_START=0.1875,DAY_PHASE_END=0.8125,
 settlement_socket_settlements=function() return roster.settlements end,
 settlement_sockets_at=function(key) return roster.sockets[key] end,
 faction_ids={"accord","throng"},start_identities=function() return roster.identities end})
rawset(_G, "grug_factions", {get_faction = function() return "accord" end,
	register_on_faction_chosen = function() end})
dofile(tree .. "/mods/CORE/grug_core/hud_layout.lua")
local npcs = roster.npcs
-- marker_state for trees before Round 30, marker_states (one table for all
-- givers) since Round 30 lane P1; the minimap listens to
-- register_on_markers_changed since lane P1b.
local marker_states = {}
for id in pairs(npcs) do marker_states[id] = "available" end
rawset(_G, "grug_quests", {registered_npcs = npcs, marker_state = function() return "available" end,
	marker_states = function() return marker_states, 1 end,
	register_on_change = function() end, register_on_markers_changed = function() end})
rawset(_G, "grug_parties", {view = function()
	return {members = {{name = "me"}, {name = "p1"}, {name = "p2"}}}
end, register_on_change = function() end})
rawset(_G,"grug_home",{get=function() return nil end,locations=function() return roster.homes end,
 known_waypoints=function() return {} end,claim_waypoint=function() return nil end})
local professions={}
for _,list in pairs(roster.sockets) do for _,r in ipairs(list) do
 if r.profession then professions[r.profession]={name=r.profession} end
end end
rawset(_G,"grug_jobs",{PROFESSIONS=professions,MENDER_TITLE="Mender",
 trainer_teaches=function(p) return p~="cooking" end})
rawset(_G,"grug_mobs",{dragon_map_markers=function() return roster.dragons end})
rawset(_G,"grug_mounts",{is_flying=function() return speed==12 end})
-- The location line under the minimap (Round 28 M1) reads this every step.
rawset(_G, "grug_map", {atlas = dofile(tree .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Dawnmere Fields" end}})
local base = dofile(tree .. "/mods/PLAYER/grug_map/base.lua")
grug_map.base = base
-- the tree's normal size (1080 x 960 before Round 51, 1215 x 1080 since)
local NW, NH = base.QUALITY.normal.width, base.QUALITY.normal.height
local installed = {quality = "normal", width = NW, height = NH,
	tiles = base.tiles(NW, NH)}
installed.texture = base.combined_texture(NW, NH, installed.tiles)
installed.flight={accord=base.tiles(NW,NH,"grug_map_flight_accord")}
installed.minimap = installed -- normal quality: the minimap shows the base itself
grug_map.atlas.set_base_texture(installed.texture)
dofile(tree .. "/mods/PLAYER/grug_map/minimap.lua")
grug_map.minimap.install(installed)
dofile(tree .. "/mods/PLAYER/grug_map/providers.lua")
steps.loaded()
for name, rows in pairs(roster.layers) do
 grug_map.atlas.register_marker_provider(name,function() return rows end)
end

local me=new_player("me",{x=centre.x-100,y=20,z=centre.z-75})
local p1=new_player("p1",{x=me.pos.x+20,y=20,z=me.pos.z+10})
local p2=new_player("p2",{x=me.pos.x-30,y=20,z=me.pos.z-20})
players.me,players.p1,players.p2=me,p1,p2
windows.me={size={x=1920,y=1080},real_hud_scaling=1,real_gui_scaling=1}
local DT,SECONDS=0.09,60
local function tick()
 clock=clock+DT;for i=1,#steps do steps[i](DT) end
 traffic.max_visible=math.max(traffic.max_visible,me:visible())
end
local start=now_us()
for _,fn in ipairs(joins) do fn(me) end
for _=1,40 do tick() end
local cold=now_us()-start
print(("%s centre=%.1f,%.1f bootstrap_us=%.0f adds=%d payload=%d updates=%d/%dB"):format(
 label,centre.x,centre.z,cold,traffic.adds,traffic.add_bytes,traffic.packets,traffic.bytes))
for pass=1,2 do
 local old_textures=0;for _ in pairs(textures) do old_textures=old_textures+1 end
 reset()
 local spent,count=0,math.floor(SECONDS/DT)
 for _=1,count do
  for _,p in ipairs({me,p1,p2}) do p.pos.x=p.pos.x+speed*DT*0.8;p.pos.z=p.pos.z+speed*DT*0.6 end
  local t=now_us();tick();spent=spent+now_us()-t
 end
 local n=0;for _ in pairs(textures) do n=n+1 end
 print(("pass=%d packets/s=%.2f payload_B/s=%.1f adds=%d add_payload=%d visible_max=%d CPU_us/step=%.2f new_cells=%d RGBA_KiB=%.2f"):format(
  pass,(traffic.packets+traffic.adds)/(count*DT),(traffic.bytes+traffic.add_bytes)/(count*DT),
  traffic.adds,traffic.add_bytes,traffic.max_visible,spent/count,n-old_textures,(n-old_textures)*72*72*4/1024))
 -- Teleport back for identical traversal; account reset separately, never hide HUD adds.
 for _,p in ipairs({me,p1,p2}) do p.pos.x=p.pos.x-speed*DT*count*0.8;p.pos.z=p.pos.z-speed*DT*count*0.6 end
 if pass==1 then
  reset();for _=1,40 do tick() end
  print(("return adds=%d add_payload=%d updates=%d/%dB"):format(traffic.adds,traffic.add_bytes,traffic.packets,traffic.bytes))
 end
end
if grug_map.markers and speed==4 then
 local providers={quest=true,service=true,home=true,waypoint=true,settlement=true,poi=true,boss=true,pvp=true}
 local source={}
 for _,r in ipairs(grug_map.atlas.collect_markers(me,providers)) do
  if r.kind~="rift_boss" then source[#source+1]=r end
 end
 local view=grug_map.minimap.geometry()
 local frame=dofile(tree .. "/mods/PLAYER/grug_map/minimap_view.lua").frame(view,
  grug_core.hud_layout.minimap_box(windows.me))
 local offsets=grug_map.markers.offsets(me,providers,source,frame.f/view.npp,frame.f/view.npp,32)
 local rows,max_shift={},0
 for _,r in ipairs(source) do
  local dx,dz=r.position.x-centre.x,r.position.z-centre.z
  if dx*dx+dz*dz<=200*200 and offsets[r.id] then
   local o=offsets[r.id];rows[#rows+1]=o
   max_shift=math.max(max_shift,math.sqrt(o.dx*o.dx+o.dy*o.dy))
  end
 end
 local before,after=0,0
 local L=grug_map.markers.layout
 for i=1,#rows do for j=i+1,#rows do
  local a,b=rows[i],rows[j]
  after=after+L.overlap(a,b,32)
  before=before+L.overlap({x=a.x,y=a.y,dx=0,dy=0,mask=a.mask},
   {x=b.x,y=b.y,dx=0,dy=0,mask=b.mask},32)
 end end
 print(("layout centre radius=200nodes rows=%d pairwise_overlap_pixels=%d->%d max_shift_px=%.2f"):format(#rows,before,after,max_shift))
end
