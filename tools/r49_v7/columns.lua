-- Round 49 lane V7: the extra chunk columns after the mgprof corpus (seed
-- 12345), picked from v7's own noise by grug_probe_v7pick (evidence/pick).
-- Appended to the mgprof probe's config.lua by tools/mgprof/run.sh
-- (PROBE_EXTRA); `config` is the probe's config table.
config.extra = {
	-- M: v7 mountain stone up to about y 153 over low authored land
	-- (kragmar_stillgrave_hollow, terrain 21..35, v7 base 13..21)
	{id = "M", x = -1872, z = 2288, heights = {-32, 48, 128}},
	-- H: v7 mountain stone up to about y 220 under high authored land
	-- (elandor_lorindor, terrain 50..124, v7 base -6..38)
	{id = "H", x = 1088, z = -1792, heights = {-32, 48, 128, 208}},
	-- R: v7 river channels (ridges) under authored land
	-- (elandor_lorindor, terrain 52..111, v7 base 26..75)
	{id = "R", x = 528, z = -1552, heights = {-32, 48}},
}
