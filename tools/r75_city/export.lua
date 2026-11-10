-- Round 75 CITY offline authoring export. LuaJIT only; never loaded by the game.
local root, city = arg[1], arg[2]
local wp = root .. "/mods/MAPGEN/grug_mapgen/wp40"
local function keys(t) local out={};for k in pairs(t) do out[#out+1]=k end;table.sort(out);return out end
local function quote(s)
	return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
		if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
		return string.format('\\u%04x',c:byte())
	end) .. '"'
end
local function json(v)
	local kind=type(v)
	if kind=='string' then return quote(v) elseif kind=='number' or kind=='boolean' then return tostring(v) end
	if kind~='table' then return 'null' end
	local out={}
	if #v>0 then for i=1,#v do out[i]=json(v[i]) end;return '['..table.concat(out,',')..']' end
	for _,k in ipairs(keys(v)) do out[#out+1]=quote(k)..':'..json(v[k]) end
	return '{'..table.concat(out,',')..'}'
end

local original_dofile, captures = dofile, {}
_G.dofile = function(path)
	local value=original_dofile(path)
	if path:match('/wp13/templates%.lua$') then
		return function(directory)
			local mod=value(directory)
			local original_part=mod.part
			mod.part=function(t,id,race,palette_of)
				local part=original_part(t,id,race,palette_of)
				part._r75_city_id=id
				return part
			end
			return mod
		end
	elseif path:match('/wp13/parts%.lua$') and type(value)=='table' and type(value.stamp)=='function' then
		local original_stamp=value.stamp
		value.stamp=function(target,part,ox,oy,oz,turns)
			local moved=original_stamp(target,part,ox,oy,oz,turns)
			if part._r75_city_id then
				local row={id=part._r75_city_id,cells={}}
				local cells,count=part.buffer:cells()
				for index=1,count do
					local c=cells[index]
					local rx,rz=value.rotate_footprint(c.x,c.z,part.w,part.d,turns)
					row.cells[index]={x=ox+rx,y=oy+c.y,z=oz+rz}
				end
				captures[#captures+1]=row
			end
			return moved
		end
	end
	return value
end

local function emit(id,kind,blueprint)
	local row={id=id,kind=kind,cells=blueprint.cells,landmarks=blueprint.landmarks,captures=captures}
	captures={}
	return row
end
local result={city=city,rows={}}
local caps=dofile(wp..'/r7_capital_blueprint.lua')
if caps.CAPITALS[city] then
	local kit=caps.kit(city)
	result.rows[#result.rows+1]=emit('core','core',kit.core.build())
	for _,p in ipairs(kit.plots) do result.rows[#result.rows+1]=emit(p.id,p.kind,p.build()) end
else
	local settlement=dofile(wp..'/r7_settlement.lua')
	local profile
	for _,p in ipairs(settlement.roster) do if p.key==city then profile=p break end end
	assert(profile,'unknown city')
	local builder=dofile(wp..'/'..profile.blueprint_file)
	result.rows[1]=emit(city,profile.slot,profile.art and builder({},profile) or builder())
end
io.write(json(result)..'\n')
