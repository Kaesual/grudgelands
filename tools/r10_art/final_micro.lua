local root = assert(arg[1])
io.write(assert(loadfile(root .. "/tools/r10_art/art_kat.lua"))()(root))
