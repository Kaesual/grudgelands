-- PROBE_EXTRA for tools/mgprof/run.sh (Round 51 TERRAIN T1, seed 12345): the
-- region measured before and after the larger world. E1 the southern land
-- nearest to the old edge (inside the old bounds), E2 the chunk holding the
-- old south edge, E3 the new ring (outside the old bounds, inside the new),
-- E4 the chunk holding the new east edge (outside the old bounds).
config.extra = {
	{id = "E1", x = 1648, z = -3072, heights = {-32, 48}},
	{id = "E2", x = -32, z = -3392, heights = {-32}},
	{id = "E3", x = -32, z = -3712, heights = {-32}},
	{id = "E4", x = 4128, z = -32, heights = {-32}},
}
