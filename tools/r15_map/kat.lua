local repo = assert(arg[1])
local env = {}; setmetatable(env, {__index = _G}); env._G = env
local loaded, steps, leaves = {}, {}, {}
local atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua")
local members, players = {}, {}
local function player(name, x, z)
	local p = {name=name, pos={x=x,y=20,z=z}, yaw=0}
	function p:get_player_name() return self.name end
	function p:get_pos() return self.pos end
	function p:get_look_horizontal() return self.yaw end
	function p:is_player() return true end
	players[name] = p; return p
end
local me, friend = player("One", 0, -2200), player("Two", 100, -2250)
members = {{name="One",online=true},{name="Two",online=true},{name="Offline",online=false}}
local sockets = {
	{id="elder",pos={x=0,y=20,z=-2200}},
	{id="local",pos={x=3,y=20,z=-2200}},
}
local state = {elder="available", second="ready"}
env.core = {
	get_player_by_name=function(name) return players[name] end,
	formspec_escape=function(s) return tostring(s):gsub("\\", "\\\\"):gsub(";", "\\;"):gsub(",", "\\,"):gsub("]", "\\]") end,
	register_on_mods_loaded=function(f) loaded[#loaded+1]=f end,
	register_globalstep=function(f) steps[#steps+1]=f end,
	register_on_leaveplayer=function(f) leaves[#leaves+1]=f end,
}
env.grug_map = {atlas=atlas}
env.grug_parties = {view=function() return {members=members} end}
env.grug_quests = {
	registered_npcs = {
		elder={settlement="goldmead_village",socket="elder",title="Marta"},
		second={settlement="goldmead_village",socket="local",title="Local"},
	},
	marker_state=function(_,id) return state[id] end,
}
env.grug_core = {
	settlement_socket_settlements=function() return {{key="goldmead_village",race_id="human",anchor=sockets[1].pos}} end,
	settlement_sockets_at=function() return sockets end,
	zone_authority_installed=function() return false end,
}
local page, context = nil, {page="grug_map:atlas"}
env.sfinv = {
	contexts={One=context},
	register_page=function(_,def) page=def end,
	make_formspec=function(_,_,text) return text end,
	set_page=function(_,name) context.page=name end,
}
local function run(path)
	local fn=assert(loadfile(repo..path));setfenv(fn,env);fn()
end
run("/mods/PLAYER/grug_map/providers.lua")
run("/mods/PLAYER/grug_map/page.lua")
for _,f in ipairs(loaded) do f() end
local rows=atlas.collect_markers(me)
assert(#rows==4 and rows[#rows].kind=="player")
local q
for _,r in ipairs(rows) do if r.kind=="quest" then q=r end end
assert(q.status=="ready" and q.detail:find("Marta",1,true) and q.detail:find("Local",1,true))
local stable=atlas.field_id(q.id)
state.second=nil
rows=atlas.collect_markers(me)
for _,r in ipairs(rows) do if r.kind=="quest" then q=r end end
assert(q.status=="available" and atlas.field_id(q.id)==stable)
assert(atlas.field_id("a:b")~=atlas.field_id("a_b"))
assert(atlas.heading_frame(0)==0 and atlas.heading_frame(math.pi/2)==4)
assert(atlas.heading_frame(-math.pi/2)==12 and atlas.heading_frame(math.pi*2)==0)
local text=page:get(me,context)
assert(text:find("grug_map_heading_gold_00.png",1,true))
assert(text:find("grug_map_heading_cyan_00.png",1,true))
assert(text:find("Two (party)",1,true) and not text:find("Offline (party)",1,true))
assert(text:find("Marta: Quest available",1,true))
assert(text:find("real_coordinates[true]",1,true))
friend.yaw=math.pi/2
text=page:get(me,context)
assert(text:find("grug_map_heading_cyan_04.png",1,true))
context.grug_map_view="dwarf"
text=page:get(me,context)
assert(not text:find("grug_map_heading_",1,true))
context.grug_map_view="human"
players.Two=nil
text=page:get(me,context)
assert(text:find("grug_map_heading_gold_",1,true) and not text:find("grug_map_heading_cyan_",1,true))
assert(page:on_player_receive_fields(me,context,{[stable]=true}))
assert(context.grug_map_detail=="Marta: Quest available")
print("r15_map geometry=pass headings=16 identity=stable party=online quest=shared-priority views=clipped")
