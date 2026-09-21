-- Portable bounded KAT for the Round 14 POI blueprints.
-- Suitable for the repository's one final PUC/LuaJIT parity process.

local repo=(arg and arg[1]) or "."
local wp40=repo.."/mods/MAPGEN/grug_mapgen/wp40"
core=core or {get_modpath=function(name)
	assert(name=="grug_mapgen"); return repo.."/mods/MAPGEN/grug_mapgen"
end}

local settlement=dofile(wp40.."/r7_settlement.lua")
local wanted={
	anchor_013="quest_steward",anchor_015="quest_steward",anchor_017="quest_steward",
	anchor_019="quest_steward",anchor_021="quest_steward",anchor_023="quest_steward",
	anchor_025="quest_scout",anchor_029="quest_scout",anchor_033="quest_scout",
	anchor_037="quest_scout",anchor_041="quest_scout",anchor_045="quest_scout",
	anchor_049="quest_captive",anchor_051="quest_captive",anchor_053="quest_captive",
	anchor_055="quest_captive",anchor_057="quest_captive",anchor_059="quest_captive"}
local displays={}
dofile(repo.."/mods/MAPGEN/grug_mapgen/poi_displays.lua")({register_node=function(name,def)
	assert(def.diggable==false and def.drop=="" and def.buildable_to==false)
	assert(def.floodable==false and def.groups.not_in_creative_inventory==1)
	for group in pairs(def.groups) do assert(group=="not_in_creative_inventory") end
	displays[name]=def
end})
local count,total,checksum=0,0,0
local function digest(value)
	for i=1,#value do checksum=(checksum*131+value:byte(i))%2147483647 end
end
local function key(x,y,z) return x..":"..y..":"..z end
for _,profile in ipairs(settlement.roster) do
	local socket_id=wanted[profile.anchor_id]
	if socket_id then
		local source=dofile(wp40.."/"..profile.blueprint_file)()
		local prepared=settlement.prepare(profile,source,function() return string.rep("x",32) end)
		assert(#prepared.blueprints==1 and prepared.blueprints[1].descriptor.kind=="anchor")
		local blueprint=prepared.blueprints[1]
		local low,high=-12,11
		if socket_id=="quest_scout" then low,high=-8,7 end
		assert(blueprint.bounds.min.x==low and blueprint.bounds.max.x==high)
		assert(blueprint.bounds.min.z==low and blueprint.bounds.max.z==high)
		local cells={}
		digest(profile.key.."\n")
		for _,cell in ipairs(source.cells) do
			assert(cell.x>=low and cell.x<=high and cell.z>=low and cell.z<=high)
			cells[key(cell.x,cell.y,cell.z)]=cell.name
			digest(table.concat({cell.x,cell.y,cell.z,cell.name,cell.param2},"|").."\n")
			if cell.name:match("^grug_mapgen:poi_display_") then assert(displays[cell.name]) end
		end
		local function at(x,y,z) return cells[key(x,y,z)] end
		assert(at(0,0,0)~="air")
		for y=1,3 do assert(at(0,y,0)=="air") end
		-- Prove every NPC can walk from the arrival crossing with two-node
		-- clearance; this catches walls/roof supports blocking story sockets.
		local start_z=profile.reserve_anchor_root and -1 or 0
		local queue={{x=0,z=start_z}}
		local reachable={[key(0,0,start_z)]=true}
		local cursor=1
		while queue[cursor] do
			local q=queue[cursor]; cursor=cursor+1
			for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
				local x,z=q.x+d[1],q.z+d[2]
				local k=key(x,0,z)
				if not (profile.reserve_anchor_root and x==0 and z==0) and
					not reachable[k] and at(x,0,z) and at(x,0,z)~="air" and
					at(x,1,z)=="air" and at(x,2,z)=="air" then
					reachable[k]=true; queue[#queue+1]={x=x,z=z}
				end
			end
		end
		if socket_id=="quest_scout" then
			assert(reachable[key(0,0,3)], "watch house blocked by guard banner")
		elseif socket_id=="quest_steward" then
			for _,q in ipairs({{-6,-6},{6,-6},{-6,6},{6,6}}) do
				assert(reachable[key(q[1],0,q[2])], "village house inaccessible")
			end
		end
		local sockets=assert(blueprint.landmarks.sockets)
		local found
		for _,socket in ipairs(sockets) do
			assert(socket.role=="quest" or socket.role=="idle" or
				socket.role=="guard_post")
			assert(reachable[key(socket.x,0,socket.z)], "unreachable socket "..socket.id)
			digest(table.concat({socket.id,socket.role,socket.x,socket.y,socket.z},"|").."\n")
			if socket.id==socket_id then found=socket end
		end
		assert(found and found.role=="quest")
		if socket_id~="quest_steward" then
			assert(profile.reserve_anchor_root==true,
				"functional outpost/camp root is not reserved")
		end
		if socket_id=="quest_captive" then
			assert(found.x*found.x+found.z*found.z>12*12,
				"captive overlaps the hostile spawn radius")
			assert(found.x==10 and found.z==10)
			for _,q in ipairs({{-6,-6},{6,-6},{-6,6},{5,5},{9,9}}) do
				assert(at(q[1],1,q[2])=="air" and at(q[1],2,q[2])=="air")
				assert(at(q[1],3,q[2])=="air" and at(q[1],4,q[2])~="air")
				assert(at(q[1],3,q[2]-1)~="air")
			end
		end
		count=count+1
		total=total+#source.cells
		wanted[profile.anchor_id]=nil
	end
end
for anchor in pairs(wanted) do error("missing POI "..anchor,0) end
assert(count==18)
io.write(table.concat({"r14_poi_v2",count,total,checksum},"\t"),"\n")
