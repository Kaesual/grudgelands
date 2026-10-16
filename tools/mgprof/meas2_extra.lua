-- Lane MEAS2 (Round 49): PROBE_EXTRA for tools/mgprof/run.sh stages. After
-- the unchanged corpus, two chunks above each corpus column (air or a
-- no-op writer over the surface) and the chunks of both columns inside the
-- cave-plant bands that the corpus lacks (Cave Cap floors y -501..-101,
-- Ember Moss floors y -1000..-702 in T5 rock), so the ore census and the
-- cave-plant count cover a few more underground chunks. The probe adds
-- these as "A_y<minp y>" and "B_y<minp y>".
config.extra = {
	{id = "A", x = 368, z = -2352,
		heights = {128, 208, -272, -352, -432, -752, -832, -912, -992}},
	{id = "B", x = 528, z = -2192,
		heights = {128, 208, -272, -352, -432, -512, -752, -832, -912, -992}},
}
