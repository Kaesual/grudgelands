-- WP40 T2 census Scan-1 KAT fixture (plan section 6.7, milestone M1).
-- Fill counts are the known F6 witness occupancies from
-- wp40-t2-degeneracy-completeness.md section 3-F6, in source.bays order
-- (bay_elandor_west, bay_elandor_east, bay_kragmar_west, bay_kragmar_east).
-- The digest pins the complete canonical worker TSV over seeds 0 and
-- max-u64 and is the M1 determinism gate: any interpreter- or order-
-- dependent drift in the census projection changes it.
return {
	schema = "grug_wp40_census_scan1_v1",
	fills = {
		["0"] = {0, 0, 0, 0},
		["18446744073709551615"] = {1, 1, 1, 0},
	},
	digest = "e9ed2bd2b418d01c69dde138f83d13a65344fcb6be563fa1318b8553d60ce7a4",
}
