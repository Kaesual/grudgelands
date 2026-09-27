-- WP40 authored anchor rows. The only reader is `r7_runtime.lua`, which hands
-- this module to `r7_consumer_payload.lua`; that payload takes the ten named-
-- rare patrol routes (numeric IDs 91..100) from here and checks the other
-- rows' identity against `source/simple_map.lua`. Engine-free, ordered,
-- integer records only.
--
-- Round 22 cleanup (D4): the rest of the former authored world source -- the
-- relief, zone-border, route, station, spur, crossing, island, bay,
-- hydrology, landmark, template, protection and housing tables -- had no
-- reader since the terrain, zone-border, water v2 and road v2 rebuilds and was
-- removed; git history keeps it.

local function point(x, z)
	return {x = x, z = z}
end

local function fixed_anchor(numeric_id, zone_id, slot_id, x, z, template_id)
	return {
		numeric_id = numeric_id,
		id = ("anchor_%03d"):format(numeric_id),
		zone_id = zone_id,
		slot_id = slot_id,
		placement_mode = "fixed",
		template_id = template_id,
		position = point(x, z),
	}
end

local function candidate_anchor(numeric_id, zone_id, slot_id, x, z,
		template_id)
	-- Flexible slots use one conservative three-point authored set. The small
	-- offsets keep every fallback inside the same reserved envelope.
	return {
		numeric_id = numeric_id,
		id = ("anchor_%03d"):format(numeric_id),
		zone_id = zone_id,
		slot_id = slot_id,
		placement_mode = "candidate_set",
		template_id = template_id,
		candidates = {point(x,z),point(x+32,z-16),point(x-24,z+24)},
	}
end

local function rare_anchor(numeric_id, zone_id, slot_id, x, z,
		patrol_offsets)
	local row = candidate_anchor(numeric_id, zone_id, slot_id, x, z,
		"rare_route")
	-- Named-rare routes move with the selected anchor. These ordered offsets
	-- are the complete authored route authority (r7_consumer_payload.lua ->
	-- grug_core zone authority); they are relative to the anchor, never to
	-- candidate 1.
	row.patrol_coordinate_space = "selected_candidate_relative"
	row.patrol_offsets = patrol_offsets
	return row
end

local source = {schema = "grug_wp40_authored_source_v1"}

source.anchors = {
	-- Six starts and six capitals retain the exact fixed §7 coordinates.
	fixed_anchor(1,"elandor_hearthpine_vale","start",-1800,-2550,"start"),
	fixed_anchor(2,"elandor_dawnmere_fields","start",0,-2550,"start"),
	fixed_anchor(3,"elandor_silverleaf_glades","start",1800,-2550,"start"),
	fixed_anchor(4,"kragmar_stillgrave_hollow","start",-1800,2550,"start"),
	fixed_anchor(5,"kragmar_sunscar_flats","start",0,2550,"start"),
	fixed_anchor(6,"kragmar_kapok_cradle","start",1800,2550,"start"),
	fixed_anchor(7,"elandor_dur_brannoc","capital",-1800,-1500,"capital_dwarf"),
	fixed_anchor(8,"elandor_highcourt","capital",0,-1500,"capital_human"),
	fixed_anchor(9,"elandor_lethariel","capital",1800,-1500,"capital_elf"),
	fixed_anchor(10,"kragmar_nhal_veyr","capital",-1800,1500,"capital_undead"),
	fixed_anchor(11,"kragmar_gor_drazhak","capital",0,1500,"capital_orc"),
	fixed_anchor(12,"kragmar_kezamba","capital",1800,1500,"capital_troll"),
	-- Twelve villages: exactly two per race region.
	candidate_anchor(13,"elandor_copperfell_foothills","village_1",-1900,-2020,"village"),
	candidate_anchor(14,"elandor_frostbarrow_shelf","village_1",-2380,-1600,"village"),
	candidate_anchor(15,"elandor_goldmead_vale","village_1",-120,-2020,"village"),
	candidate_anchor(16,"elandor_whitebridge_shire","village_1",-900,-1580,"village"),
	candidate_anchor(17,"elandor_starbough_vale","village_1",1900,-2020,"village"),
	candidate_anchor(18,"elandor_lorindor","village_1",900,-1580,"village"),
	candidate_anchor(19,"kragmar_mournfen","village_1",-1900,2020,"village"),
	candidate_anchor(20,"kragmar_ossuary_reach","village_1",-2380,1600,"village"),
	candidate_anchor(21,"kragmar_redtusk_savanna","village_1",-120,2020,"village"),
	candidate_anchor(22,"kragmar_speargrass_reach","village_1",-900,1580,"village"),
	candidate_anchor(23,"kragmar_raincall_basin","village_1",1900,2020,"village"),
	candidate_anchor(24,"kragmar_whispering_reedlands","village_1",900,1580,"village"),
	-- Twenty-four ordinary outposts: exactly four per race region.
	candidate_anchor(25,"elandor_copperfell_foothills","outpost_1",-2100,-2100,"outpost"),
	candidate_anchor(26,"elandor_frostbarrow_shelf","outpost_1",-2300,-1250,"outpost"),
	candidate_anchor(27,"elandor_stormvault_heights","outpost_1",-2050,-850,"outpost"),
	candidate_anchor(28,"elandor_stormvault_heights","outpost_2",-1500,-450,"outpost"),
	candidate_anchor(29,"elandor_goldmead_vale","outpost_1",200,-2050,"outpost"),
	candidate_anchor(30,"elandor_whitebridge_shire","outpost_1",-650,-1250,"outpost"),
	candidate_anchor(31,"elandor_ashenward_march","outpost_1",-350,-850,"outpost"),
	candidate_anchor(32,"elandor_ashenward_march","outpost_2",300,-450,"outpost"),
	candidate_anchor(33,"elandor_starbough_vale","outpost_1",2100,-2100,"outpost"),
	candidate_anchor(34,"elandor_lorindor","outpost_1",650,-1250,"outpost"),
	candidate_anchor(35,"elandor_moonfall_wood","outpost_1",2400,-1350,"outpost"),
	candidate_anchor(36,"elandor_glassroot_wilds","outpost_1",1900,-550,"outpost"),
	candidate_anchor(37,"kragmar_mournfen","outpost_1",-2100,2100,"outpost"),
	candidate_anchor(38,"kragmar_ossuary_reach","outpost_1",-2300,1250,"outpost"),
	candidate_anchor(39,"kragmar_blackwind_rise","outpost_1",-2050,850,"outpost"),
	candidate_anchor(40,"kragmar_blackwind_rise","outpost_2",-1500,450,"outpost"),
	candidate_anchor(41,"kragmar_redtusk_savanna","outpost_1",200,2050,"outpost"),
	candidate_anchor(42,"kragmar_speargrass_reach","outpost_1",-650,1250,"outpost"),
	candidate_anchor(43,"kragmar_bannerbreak_mesa","outpost_1",-350,850,"outpost"),
	candidate_anchor(44,"kragmar_bannerbreak_mesa","outpost_2",300,450,"outpost"),
	candidate_anchor(45,"kragmar_raincall_basin","outpost_1",2100,2100,"outpost"),
	candidate_anchor(46,"kragmar_whispering_reedlands","outpost_1",650,1250,"outpost"),
	candidate_anchor(47,"kragmar_totemwater_reach","outpost_1",2400,1350,"outpost"),
	candidate_anchor(48,"kragmar_thunderroot_wilds","outpost_1",1900,550,"outpost"),
	-- Twelve fixed-budget bandit slots: one home and one frontier per race.
	candidate_anchor(49,"elandor_copperfell_foothills","bandit_1",-1600,-2050,"bandit_home"),
	candidate_anchor(50,"elandor_stormvault_heights","bandit_1",-1800,-430,"bandit_frontier"),
	candidate_anchor(51,"elandor_goldmead_vale","bandit_1",320,-1980,"bandit_home"),
	candidate_anchor(52,"elandor_ashenward_march","bandit_1",0,-430,"bandit_frontier"),
	candidate_anchor(53,"elandor_starbough_vale","bandit_1",1600,-2050,"bandit_home"),
	candidate_anchor(54,"elandor_glassroot_wilds","bandit_1",1800,-430,"bandit_frontier"),
	candidate_anchor(55,"kragmar_mournfen","bandit_1",-1600,2050,"bandit_home"),
	candidate_anchor(56,"kragmar_blackwind_rise","bandit_1",-1800,430,"bandit_frontier"),
	candidate_anchor(57,"kragmar_redtusk_savanna","bandit_1",320,1980,"bandit_home"),
	candidate_anchor(58,"kragmar_bannerbreak_mesa","bandit_1",0,430,"bandit_frontier"),
	candidate_anchor(59,"kragmar_raincall_basin","bandit_1",1600,2050,"bandit_home"),
	candidate_anchor(60,"kragmar_thunderroot_wilds","bandit_1",1800,430,"bandit_frontier"),
	-- Six peaceful regional mines and four Mirefolk camps.
	candidate_anchor(61,"elandor_frostbarrow_shelf","mine",-2450,-1280,"mine"),
	candidate_anchor(62,"elandor_whitebridge_shire","mine",-1050,-1280,"mine"),
	candidate_anchor(63,"elandor_lorindor","mine",1050,-1280,"mine"),
	candidate_anchor(64,"kragmar_ossuary_reach","mine",-2450,1280,"mine"),
	candidate_anchor(65,"kragmar_speargrass_reach","mine",-1050,1280,"mine"),
	candidate_anchor(66,"kragmar_whispering_reedlands","mine",1050,1280,"mine"),
	candidate_anchor(67,"elandor_whitebridge_shire","mirefolk",-620,-1760,"mirefolk"),
	candidate_anchor(68,"elandor_lorindor","mirefolk",1120,-1740,"mirefolk"),
	candidate_anchor(69,"kragmar_mournfen","mirefolk",-2050,2250,"mirefolk"),
	candidate_anchor(70,"kragmar_whispering_reedlands","mirefolk",1120,1740,"mirefolk"),
	-- Sixteen dedicated clash anchors.
	candidate_anchor(71,"elandor_ashenward_march","clash_1",-250,-320,"clash"),
	candidate_anchor(72,"elandor_ashenward_march","clash_2",250,-320,"clash"),
	candidate_anchor(73,"kragmar_bannerbreak_mesa","clash_1",-250,320,"clash"),
	candidate_anchor(74,"kragmar_bannerbreak_mesa","clash_2",250,320,"clash"),
	candidate_anchor(75,"front_wyrmglass_crown","clash_1",-3000,170,"clash"),
	candidate_anchor(76,"front_gravesalt_escarpment","clash_1",-2200,-80,"clash"),
	candidate_anchor(77,"front_gravesalt_escarpment","clash_2",-1800,80,"clash"),
	candidate_anchor(78,"front_broken_causeway","clash_1",-1250,-100,"clash"),
	candidate_anchor(79,"front_broken_causeway","clash_2",-750,100,"clash"),
	candidate_anchor(80,"front_broken_causeway","clash_3",-250,-100,"clash"),
	candidate_anchor(81,"front_shattered_line","clash_1",250,100,"clash"),
	candidate_anchor(82,"front_shattered_line","clash_2",750,-100,"clash"),
	candidate_anchor(83,"front_shattered_line","clash_3",1250,100,"clash"),
	candidate_anchor(84,"front_skyglass_canopy","clash_1",1800,-80,"clash"),
	candidate_anchor(85,"front_skyglass_canopy","clash_2",2200,80,"clash"),
	candidate_anchor(86,"front_stormscale_summit","clash_1",3000,170,"clash"),
	-- Two dragon arenas and two all-six-gem apex mines.
	fixed_anchor(87,"front_wyrmglass_crown","dragon",-3260,-40,"dragon"),
	fixed_anchor(88,"front_stormscale_summit","dragon",3260,-40,"dragon"),
	fixed_anchor(89,"front_wyrmglass_crown","apex_mine",-3200,80,"apex_mine"),
	fixed_anchor(90,"front_stormscale_summit","apex_mine",3200,80,"apex_mine"),
	-- Ten stable named-rare route instances; Captain Bonerattle owns one
	-- instance in each of its two published route zones. Route points are
	-- explicit candidate-relative offsets because these slots are relocatable,
	-- unlike the fixed island targets above.
	rare_anchor(91,"elandor_goldmead_vale","rare_grimtusk",120,-2100,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(92,"elandor_ashenward_march","rare_old_whitefang",-180,-650,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(93,"elandor_stormvault_heights","rare_korgans_bane",-1850,-620,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(94,"front_skyglass_canopy","rare_silkfang",2050,70,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(95,"kragmar_blackwind_rise","rare_marrowclaw",-1850,620,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(96,"kragmar_bannerbreak_mesa","rare_dustwing",180,650,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(97,"front_stormscale_summit","rare_emerald_coil",3000,-120,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(98,"kragmar_redtusk_savanna","rare_ashmaw",120,2100,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(99,"front_broken_causeway","rare_captain_bonerattle",-600,80,
		{point(-48,-24),point(16,40),point(56,-16)}),
	rare_anchor(100,"front_shattered_line","rare_captain_bonerattle",600,-80,
		{point(-48,-24),point(16,40),point(56,-16)}),
}

-- Numeric ids are the canonical one-based positions of the rows.
for record_index = 1, #source.anchors do
	source.anchors[record_index].numeric_id = record_index
end

return source
