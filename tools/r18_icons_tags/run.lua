local repo = arg[1] or "."
io.write(dofile(repo .. "/tools/r18_icons_tags/fixture.lua")(repo))
