-- Direct stable-query spawn gates. Surface mobs require both their existing
-- node whitelist and the owning named zone's explicit mob palette
-- (docs/design/world_zones.md Section 8). The old radial spawn buckets are
-- not reconstructed.

local VALID_DOMAINS = {
	contested = true,
	underground = true,
}

-- Closed named-zone mob palettes, transcribed from world_zones.md Section 8.
-- Capitals deliberately have empty palettes. Lorindor is intentionally
-- literal: its row names pale stags, not the complete forest family.
local ZONE_MOB_PALETTES = {
	elandor_hearthpine_vale = {settled = true},
	elandor_copperfell_foothills = {settled = true},
	elandor_dur_brannoc = {},
	elandor_frostbarrow_shelf = {mountain = true},
	elandor_stormvault_heights = {mountain = true},
	elandor_dawnmere_fields = {settled = true},
	elandor_goldmead_vale = {settled = true},
	elandor_highcourt = {},
	elandor_whitebridge_shire = {settled = true, forest = true},
	elandor_ashenward_march = {forest = true, war = true},
	elandor_silverleaf_glades = {settled = true},
	elandor_starbough_vale = {settled = true},
	elandor_lethariel = {},
	elandor_lorindor = {exact_mobs = {["grug_mobs:stag"] = true}},
	elandor_moonfall_wood = {forest = true},
	elandor_glassroot_wilds = {forest = true, jungle = true},
	kragmar_stillgrave_hollow = {settled = true},
	kragmar_mournfen = {settled = true, swamp = true},
	kragmar_nhal_veyr = {},
	kragmar_ossuary_reach = {forest = true},
	kragmar_blackwind_rise = {forest = true},
	kragmar_sunscar_flats = {settled = true},
	kragmar_redtusk_savanna = {settled = true, savanna = true},
	kragmar_gor_drazhak = {},
	kragmar_speargrass_reach = {savanna = true, mountain = true},
	kragmar_bannerbreak_mesa = {mountain = true, war = true},
	kragmar_kapok_cradle = {
		settled = true, jungle_edge = true,
	},
	kragmar_raincall_basin = {
		settled = true, jungle_edge = true,
	},
	kragmar_kezamba = {},
	kragmar_whispering_reedlands = {
		jungle_edge = true, swamp = true,
	},
	kragmar_totemwater_reach = {
		jungle_edge = true, swamp = true,
	},
	kragmar_thunderroot_wilds = {jungle = true},
	front_wyrmglass_crown = {mountain = true, war = true},
	front_gravesalt_escarpment = {forest = true, war = true},
	front_broken_causeway = {war = true},
	front_shattered_line = {mountain = true, war = true},
	front_skyglass_canopy = {jungle = true, war = true},
	front_stormscale_summit = {jungle = true, war = true},
}

-- A mob may name more than one Section 8 family where the catalog says so.
-- Existing mobs:spawn node lists remain the narrower habitat selector.
-- Section 3.1 makes Jungle Lynx the inner/outer bridge and Parrot the
-- jungle-edge critter; lower-jungle, jungle and high-jungle use the remaining
-- outer/coast jungle family, with the zone level supplying the adjective.
local MOB_PALETTES = {
	["grug_mobs:boar"] = {settled = true},
	["grug_mobs:plague_boar"] = {settled = true},
	["grug_mobs:jungle_boar"] = {settled = true},
	["grug_mobs:rabbit"] = {settled = true},
	["grug_mobs:hare"] = {settled = true},
	["grug_mobs:zombie"] = {settled = true, war = true},

	["grug_mobs:wolf"] = {forest = true},
	["grug_mobs:blightfang_wolf"] = {forest = true},
	["grug_mobs:bear"] = {forest = true},
	["grug_mobs:plaguehide_bear"] = {forest = true},
	["grug_mobs:stag"] = {forest = true},
	["grug_mobs:gaunt_stag"] = {forest = true},
	["grug_mobs:giant_spider"] = {forest = true},
	["grug_mobs:pale_spider"] = {forest = true},
	["grug_mobs:skeleton_archer"] = {forest = true, war = true},
	["grug_mobs:bone_weevil"] = {forest = true},

	["grug_mobs:crag_eagle"] = {mountain = true},
	["grug_mobs:vulture"] = {mountain = true},
	["grug_mobs:stone_golem"] = {mountain = true},
	["grug_mobs:mesa_golem"] = {mountain = true},
	["grug_mobs:mountain_ram"] = {mountain = true},
	["grug_mobs:hyena"] = {mountain = true, savanna = true},
	["grug_mobs:zebra"] = {savanna = true},

	["grug_mobs:jungle_lynx"] = {jungle_edge = true, jungle = true},
	["grug_mobs:panther"] = {jungle = true},
	["grug_mobs:serpent"] = {jungle = true},
	["grug_mobs:jungle_ape"] = {jungle = true},
	["grug_mobs:jungle_spider"] = {jungle = true},
	["grug_mobs:parrot"] = {jungle_edge = true},

	["grug_mobs:crocodile"] = {swamp = true},
	["grug_mobs:bog_ooze"] = {swamp = true},
	["grug_mobs:bog_fowl"] = {swamp = true},

	["grug_mobs:skeleton_raider"] = {war = true},
	["grug_mobs:carrion_crow"] = {war = true},
}

-- Kraken has an independent authority instead of a named-zone mob palette:
-- water_class_at == deep_ocean in kraken.lua.
local INDEPENDENT_AUTHORITY = {
	["grug_mobs:kraken"] = true,
}

-- The existing cave rows are exact. Keeping this list closed preserves their
-- y < -40 behavior without letting a new Grudgelands family silently bypass
-- the named-zone policy merely because it added a negative-height ABM.
local UNDERGROUND_MOBS = {
	["grug_mobs:zombie"] = true,
	["grug_mobs:giant_spider"] = true,
	["grug_mobs:stone_golem"] = true,
	["grug_mobs:mesa_golem"] = true,
	["grug_mobs:cave_bat"] = true,
	["grug_mobs:cave_crawler"] = true,
}

local RACE_FACTIONS = {
	dwarf = "accord",
	human = "accord",
	elf = "accord",
	undead = "throng",
	orc = "throng",
	troll = "throng",
}

local function zone_palette_at(pos)
	local zone_id = grug_zones.id_at(pos.x, pos.z)
	return zone_id and ZONE_MOB_PALETTES[zone_id] or nil
end

function grug_mobs.compile_spawn_domains(domains, mob_name)
	if type(domains) ~= "table" or #domains == 0 then
		error("[grug_mobs] invalid spawn domains for " .. mob_name)
	end
	local result = {}
	for i = 1, #domains do
		local domain = domains[i]
		if not VALID_DOMAINS[domain] or result[domain] then
			error("[grug_mobs] invalid spawn domain for " .. mob_name ..
				": " .. tostring(domain))
		end
		result[domain] = true
	end
	return result
end

function grug_mobs.spawn_domain_at(pos)
	if pos.y < -40 then
		return "underground"
	end
	if grug_zones.pvp_rule_at(pos) == "contested" then
		return "contested"
	end
	return nil
end

function grug_mobs.spawn_domains_allow(domains, pos)
	return domains[grug_mobs.spawn_domain_at(pos)] == true
end

-- Used by the Skeleton Archer's row-specific check: forest host nodes remain
-- valid in forest palettes, while its generic settled-top row requires the
-- explicit war palette rather than merely any contested zone.
function grug_mobs.zone_spawn_palette_allows(palette, pos)
	local zone_palette = zone_palette_at(pos)
	return zone_palette and zone_palette[palette] == true or false
end

-- Variant-side authority for mob pairs whose surface nodes are shared across
-- both continents. Contested zones deliberately have no political faction,
-- so their stable cultural race region selects the matching variant.
function grug_mobs.race_region_spawn_allows(faction_id, pos)
	return RACE_FACTIONS[grug_zones.race_region_at(pos.x, pos.z)] ==
		faction_id
end

-- Allocation-free spawn policy. Unknown ABM families fail closed.
function grug_mobs.spawn_policy_allows(mob_name, pos)
	if INDEPENDENT_AUTHORITY[mob_name] then
		return true
	end
	if pos.y < -40 then
		return UNDERGROUND_MOBS[mob_name] == true
	end
	-- The cave ABMs end at -40, but the stable depth domain begins strictly
	-- below it. Surface ABMs begin at zero, so the intervening band is closed.
	if pos.y < 0 then
		return false
	end
	-- Section 3.1's universal Beach/Strait roster is separate from Section
	-- 8's named-zone palettes. Authenticate that one logical biome directly;
	-- a beach host does not enable any other mob family.
	if mob_name == "grug_mobs:gull" then
		return grug_zones.biome_at(pos.x, pos.z) == "grug_beach"
	end
	local mob_palettes = MOB_PALETTES[mob_name]
	if not mob_palettes then
		return false
	end
	local zone_palette = zone_palette_at(pos)
	if not zone_palette then
		return false
	end
	if zone_palette.exact_mobs and zone_palette.exact_mobs[mob_name] then
		return true
	end
	for palette in pairs(mob_palettes) do
		if zone_palette[palette] then
			return true
		end
	end
	return false
end
