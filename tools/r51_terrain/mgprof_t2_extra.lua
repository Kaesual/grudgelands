-- PROBE_EXTRA for tools/mgprof/run.sh (Round 51 TERRAIN T2, seed 12345): the
-- coastal and channel region measured before and after the sea's new shape.
-- C1/C2 the Wyrmglass channel's middle (surface and floor chunk), B1 the
-- middle of bay_kragmar_west, B2 belt water off the southern coast, B3 the
-- southern land nearest the coast (T1's E1), O1 the open sea far out.
config.extra = {
	{id = "C1", x = -2672, z = -32, heights = {-32}},
	{id = "C2", x = -2672, z = -112, heights = {-32}},
	{id = "B1", x = -912, z = 2528, heights = {-32}},
	{id = "B2", x = 1648, z = -3312, heights = {-32}},
	{id = "B3", x = 1648, z = -3072, heights = {-32, 48}},
	{id = "O1", x = -32, z = -3712, heights = {-32}},
}
