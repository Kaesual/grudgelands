-- Bounded final-byte fixture. Engine callbacks use real HUD/marker consumers.
-- Returns canonical output for the coordinator's one final interpreter pair.
return function(repo, dump_path, window)
	local hooks, changes, entities, players, spawned = {}, {}, {}, {}, {}
	local function register(name)
		return function(fn) hooks[name] = hooks[name] or {}; hooks[name][#hooks[name]+1] = fn end
	end
	local core = {get_player_window_information=function() return window end,registered_items={}, registered_entities=entities,
		register_on_joinplayer=register("join"),register_on_leaveplayer=register("leave"),
		register_on_dieplayer=register("die"),register_globalstep=register("step"),
		register_on_player_receive_fields=register("fields"),
		register_on_player_inventory_action=register("inventory"),
		register_chatcommand=function(name, def) hooks[name]=def end,
		register_entity=function(name, def) entities[name]=def end,
		get_connected_players=function() return players end,
		get_player_by_name=function(name) for _,p in ipairs(players) do if p.name==name then return p end end end,
		colorize=function(_,text) return text end,chat_send_player=function() end,
	}
	local host = {register_tag_visibility=register("visibility")}
	local journal = {hud_enabled=true,tracked={"a","b","c"},quests={}}
	for i,id in ipairs(journal.tracked) do
		journal.quests[i]={id=id,title="Supplies for the rain-soaked shelters beyond the old watch road "..i,
			objectives={{type="kill",count=i,required=6,description="Defeat raiders on the orchard road"}}}
	end
	local party={leader="viewer",members={}}
	local party_enabled=true
	for i=1,10 do party.members[i]={name=i==1 and "viewer" or "Companion"..i,
		online=i~=8,hp=123,hp_max=456} end
	local quest = {journal=function() return journal end,register_on_change=register("quest"),
		npc_by_socket={["place/giver"]="giver"},npc_quests=function(player)
			return {{status=player.state}}
		end}
	local inventory = {}
	local env = setmetatable({core=core,grug_core=host,grug_quests=quest,grug_inventory=inventory,
		grug_parties={hud_enabled=function() return party_enabled end,view=function() return party end,
			register_on_change=register("party")}}, {__index=_G})
	local function load(path)
		local fn=assert(loadfile(repo.."/"..path));setfenv(fn,env);fn()
	end
	-- Read the production wrapping function without loading unrelated inventory UI.
	local f=assert(io.open(repo.."/mods/PLAYER/grug_inventory/ui.lua","r"))
	local body=f:read("*a");f:close()
	local wrap=assert(loadstring(body:match("(function grug_inventory.wrap_text.-\nend)")))
	setfenv(wrap,env);wrap()
	load("mods/CORE/grug_core/hud_layout.lua")
	local layout=host.hud_layout
	local p={name="viewer",state="available",elements={},next_id=0,xp=0}
	function p:get_player_name() return self.name end
	function p:get_meta() return {get_int=function() return self.xp end,set_int=function(_,_,v) self.xp=v end} end
	function p:hud_add(def) self.next_id=self.next_id+1;self.elements[self.next_id]=def;return self.next_id end
	function p:hud_change(id,key,value) assert(self.elements[id]);self.elements[id][key]=value;changes[#changes+1]=key end
	function p:hud_remove(id) self.elements[id]=nil end
	players[1]=p
	load("mods/PLAYER/grug_xp/init.lua")
	load("mods/PLAYER/grug_quests/hud.lua")
	load("mods/PLAYER/grug_parties/hud.lua")
	load("mods/PLAYER/grug_quests/npc.lua")
	for _,fn in ipairs(hooks.join) do fn(p) end
	local function step() for _,fn in ipairs(hooks.step) do fn(0.6) end end
	local function query(predicate)
		local rows={}
		for id,def in pairs(p.elements) do if predicate(def) then rows[#rows+1]={id=id,def=def} end end
		return rows
	end
	local function side(x) return query(function(d) return d.position.x==x and d.position.y==0.5 end) end
	assert(#side(0)==30 and #side(1)==1)
	local q=side(1)[1].def
	assert(q.alignment.x==-1 and q.alignment.y==0 and q.offset.x==-20)
	assert(q.text:find("Supplies",1,true))
	local _,lines=q.text:gsub("\n","");assert(lines>=8 and lines<12)
	assert(layout.rows.xp.index==1 and layout.rows.xp.height==6)
	local previous=-62
	for _,id in ipairs(layout.order) do local row=layout.rows[id];assert(row.bottom<=previous);previous=row.top end
	local xpfill=query(function(d) return d.type=="image" and d.offset.y==layout.rows.xp.top and d.z_index==1 end)[1].def
	assert(xpfill.scale.x==0)
	env.grug_xp.set_xp(p,50);assert(xpfill.scale.x==180)
	env.grug_xp.set_xp(p,100);assert(xpfill.scale.x==0)
	env.grug_xp.set_xp(p,env.grug_xp.xp_for_level(60));assert(xpfill.scale.x==360)
	changes={};env.grug_xp.set_xp(p,p.xp);step();step();assert(#changes==0,"idle HUD writes")
	local function check_party(n)
		local top,bottom=math.huge,-math.huge
		for _,row in ipairs(side(0)) do local d=row.def
			if d.type=="text" then top=math.min(top,d.offset.y)
			else bottom=math.max(bottom,d.offset.y+d.scale.y) end
		end
		assert(#side(0)==n*3 and top==-bottom,"party block not centred")
	end
	check_party(10)
	local members=party.members
	for n=1,10 do
		party.members={}
		for i=1,n do party.members[i]=members[i] end
		step();check_party(n)
	end
	party_enabled=false;step();assert(#side(0)==0)
	party_enabled=true;step();check_party(10)
	journal.hud_enabled=false;step();assert(q.text=="")
	journal.hud_enabled=true;step();assert(q.text~="")
	journal.quests={};step();assert(q.text=="")
	for i,id in ipairs(journal.tracked) do journal.quests[i]={id=id,title="Supplies for the rain-soaked shelters beyond the old watch road "..i,
		objectives={{type="kill",count=i,required=6,description="Defeat raiders on the orchard road"}}} end
	step()
	local initial_window=window
	window={size={x=800,y=600},real_hud_scaling=1.25}
	step();assert(q.text:find("...",1,true))
	changes={};step();assert(#changes==0)
	window=initial_window;step()
	-- Exercise actual observer partitions, attach transform and teardown.
	local parent={}
	function parent:is_valid() return true end
	function parent:get_pos() return {x=0,y=0,z=0} end
	function parent:get_luaentity() return {object=self,_grug_start="place",_grug_socket="giver"} end
	core.add_entity=function(_,name)
		local child={valid=true,properties=entities[name].initial_properties}
		function child:is_valid() return self.valid end
		function child:set_observers(set) self.observers=set end
		function child:set_attach(_,_,pos) self.attach=pos end
		function child:set_properties(props) self.mesh=props.mesh end
		function child:remove() self.valid=false end
		spawned[#spawned+1]=child;return child
	end
	local notify=hooks.visibility[1]
	notify(parent,{viewer=true},false)
	assert(#spawned==1 and spawned[1].observers.viewer)
	local marker=spawned[1]
	assert(marker.properties.visual_size.x==5 and marker.properties.visual_size.y==5 and marker.properties.visual_size.z==5)
	for _,symbol in ipairs({"question","exclamation"}) do
		local file=assert(io.open(repo.."/mods/PLAYER/grug_quests/models/grug_quests_"..symbol..".obj","r"))
		local low,high=math.huge,-math.huge
		for line in file:lines() do local y=line:match("^v %S+ (%S+) ");if y then y=tonumber(y);low=math.min(low,y);high=math.max(high,y) end end
		file:close()
		for _,scale in ipairs({0.9,0.94,1,1.06,1.08,1.12}) do
			assert(math.abs((marker.attach.y+5*high)*scale-(27+high)*scale)<1e-10)
			assert(math.abs(((5*high)-(5*low))/(high-low)-5)<1e-10)
		end
	end
	p.state="ready";notify(parent,{viewer=true},false);assert(#spawned==2 and not spawned[1].observers.viewer)
	notify(parent,{},true);for _,child in ipairs(spawned) do assert(not child.valid) end
	env.grug_xp.set_xp(p,50)
	if dump_path then
		local out=assert(io.open(dump_path,"w"))
		for id=1,p.next_id do local d=p.elements[id];if d then
			out:write(table.concat({d.type,d.position.x,d.position.y,d.offset.x,d.offset.y,
				d.alignment.x,d.alignment.y,d.scale and d.scale.x or 0,d.scale and d.scale.y or 0,
				d.number or 0,(d.text:gsub("\n","\\n"))},"\t"),"\n")
		end end
		out:close()
	end
	return "r15_hud\tPASS\txp=360x6\tparty=1..10\tquest=right-centre\tmarkers=5x,top-fixed\tidle-writes=0\n"
end
