-- Small additions to existing starts, before their normal blueprint digest.
-- Capital cooks are placed in the terrain-relative Cooking service plots.
-- Canonical z, y, x cell order without a Lua comparator (see
-- wp13/parts.lua `sort_cells_zyx`, whose rule this copies): distinct integer
-- positions sort by one packed number; anything else keeps the comparator.
local function sort_cells_zyx(cells, less)
	local keys, by_key = {}, {}
	for index = 1, #cells do
		local cell = cells[index]
		local x, y, z = cell.x, cell.y, cell.z
		if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or
				x % 1 ~= 0 or y % 1 ~= 0 or z % 1 ~= 0 or
				x <= -32768 or x >= 32768 or y <= -32768 or y >= 32768 or
				z <= -32768 or z >= 32768 then
			table.sort(cells, less)
			return
		end
		local key = ((z + 32768) * 65536 + (y + 32768)) * 65536 + (x + 32768)
		if by_key[key] then
			table.sort(cells, less)
			return
		end
		by_key[key], keys[index] = cell, key
	end
	table.sort(keys)
	for index = 1, #keys do cells[index] = by_key[keys[index]] end
end

return function(source,profile)
	local z=(profile.race=="dwarf" or profile.race=="human" or profile.race=="elf") and 13 or -13
	local edits={}
	local function key(x,y,pz) return x..":"..y..":"..pz end
	local function edit(x,y,pz,name,param2)
		edits[key(x,y,pz)]={x=x,y=y,z=pz,name=name,param2=param2 or 0}
	end
	-- Central street verge: a standing place, a two-node clear approach and
	-- one own oven. Existing trainers remain three nodes down the same verge.
	for x=1,2 do for y=1,2 do edit(x,y,z,"air") end end
	edit(4,1,z,"default:furnace",3)
	local cells,names={},{}
	for _,cell in ipairs(source.cells) do
		local k=key(cell.x,cell.y,cell.z)
		local replacement=edits[k]
		cells[#cells+1]=replacement or cell
		names[(replacement or cell).name]=true
		edits[k]=nil
	end
	for _,cell in pairs(edits) do cells[#cells+1]=cell;names[cell.name]=true end
	sort_cells_zyx(cells,function(a,b) return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x))) end)
	local palette={};for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette,function(a,b)
		for i=1,math.min(#a,#b) do local x,y=a:byte(i),b:byte(i);if x~=y then return x<y end end
		return #a<#b
	end)
	source.cells,source.palette=cells,palette
	return source
end
