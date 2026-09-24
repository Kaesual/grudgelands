-- Small additions to existing starts, before their normal blueprint digest.
-- Capital cooks are placed in the terrain-relative Cooking service plots.
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
	table.sort(cells,function(a,b) return a.z<b.z or (a.z==b.z and (a.y<b.y or (a.y==b.y and a.x<b.x))) end)
	local palette={};for name in pairs(names) do palette[#palette+1]=name end
	table.sort(palette,function(a,b)
		for i=1,math.min(#a,#b) do local x,y=a:byte(i),b:byte(i);if x~=y then return x<y end end
		return #a<#b
	end)
	source.cells,source.palette=cells,palette
	return source
end
