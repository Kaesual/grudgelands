local root = assert(arg[1])
local fixtures = {
	"tools/wp13/character_visuals_kat.lua",
	"tools/r9_farm/farming_kat.lua",
	"tools/r10_art/mount_icon_kat.lua",
	"tools/r10_art/art_kat.lua",
}
for _, relative in ipairs(fixtures) do
	io.write(assert(loadfile(root .. "/" .. relative))()(root))
end
