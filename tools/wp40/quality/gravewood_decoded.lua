-- Portable decoded truth for the two original Gravewood MTS assets.
-- LuaJIT verification in gravewood_fixture.lua compares every cell with the
-- real compressed files through tools/wp40/r6/common.lua read_mts.

return {
	{
		filename = "grug_gravewood_small.mts",
		sha256 = "d9ed79784879da9dd29a03a1221f87e0a292d933373061798ed27d9b4f272cd0",
		size = {x = 7, y = 7, z = 7},
		wood = {
			{0,0,0}, {0,1,0}, {0,2,0}, {0,3,0}, {1,3,0},
			{1,4,0}, {1,5,0}, {-1,3,0}, {-2,3,0}, {-2,4,0},
			{-2,4,1}, {1,4,-1}, {1,4,-2}, {1,5,-2}, {1,5,1},
			{1,5,2}, {0,5,2},
		},
		leaves = {
			{-2,5,1}, {-3,4,1}, {1,6,-2}, {2,5,-2}, {0,6,2},
		},
	},
	{
		filename = "grug_gravewood_tall.mts",
		sha256 = "ae5c035abc0e03317c1014d5373113a2d09ed7944865075fdfd45504febbc2f8",
		size = {x = 7, y = 9, z = 7},
		wood = {
			{0,0,0}, {0,1,0}, {0,2,0}, {0,3,0}, {1,3,0},
			{1,4,0}, {1,5,0}, {1,6,0}, {-1,3,0}, {-2,3,0},
			{-2,4,0}, {-2,4,1}, {1,4,-1}, {1,4,-2}, {1,5,-2},
			{1,5,1}, {1,5,2}, {0,5,2}, {2,6,0}, {2,7,0},
			{2,7,-1}, {0,6,2}, {0,7,2},
		},
		leaves = {
			{-2,5,1}, {-3,4,1}, {1,6,-2}, {2,5,-2},
			{2,8,-1}, {3,7,-1}, {-1,7,2}, {0,8,2},
		},
	},
}
