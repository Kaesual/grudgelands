# Round 11 ART handoff

User approved full R11 plan, native Sol preferred. Read root docs/research/round11-plan/README.md and living character_visuals.md. No PUC runtime. No new player decisions needed.

Current code owners: GEAR owns grug_gear/init, grug_inventory bags/quiver and grug_jobs/station_nodes; FARM owns grug_farming/init/hoes; WORLD owns grug_decor/capital+parts. Return assets and small isolated art modules/patches to each owner; do not race edits. Can own grug_visuals compose/wield_geometry for bow pose after notifying root.

GEAR provisional icons to replace: seven bows currently staffs/stick; six shields chestplates; six books default_book tint; arrow stick; quiver small bag tint; new bags repeat old variants. Need licensed representative media for all. Root visually inspected22 reference previews at /tmp/grudgelands-r11-reference-contact.png: LotT shield sprites are excellent readable shield shapes, bronze/copper, steel/silver, gold/mithril/galvorn suitable candidates; LotT five wood bows have good style and different grips/palettes; Voxe mcl_bows_bow_0 + arrow_inv, mcl_enchanting_book_enchanted/closed also usable. These are candidate suggestions, not blind filename approvals. Read source licenses beforeimport. LotT top README86 saysCCBYSA3; lottarmor/license.txt gives author. Voxe LEGAL.md42+ and mcl_farming README givesCCBYSA4 texture defaults. No upstreamcode unless vendorledger.

Seed silhouettes: compare actualVoxe/farming/x_farming. x_farming carrotseed is four little carrotshoots; cornseed clearly kernels, potatoseed smalltubers. User wants distinctseed/harvest silhouette, reuse allowed for remaining families. Source files for all17 andlocalledger. Keepgrowthnodes unchanged.

Stations: GEAR reserves new grug_jobs/station_visuals.lua seam. Proposed pure return map station->visual record; existing record texture,boxes,groups,sounds. Must add tiles (6faces) support factory at ownerhandoff. Voxe anvil nodebox4boxes at mcl_anvils/init.lua383+, top/base/side textures; nofallingbehavior import. Goldsmith mutedgoldhead/darkbase. Voxe loom regularcube6textures loom_top,bottom,side,front so Tailor loom can use fullcube boxes; uprightWoodcarver bench correct nodebox tabletopnear+.35legsdown-.5. No gameplay/gates change.

Silversteel: diamondderivedarmor icons/worn overlays currentlytoo blue. Preserveaccepted silhouettes, neutralbright silver subtleshadows. Prefer changing repo-native engine texturecomposition/code palette, no needAI art. Weapons/tools change onlymetalparts, preservewoodgrips. Existingtools/r10_art/build_armor_assets.sh shows source provenance. Engine supports ^[hsl:0:-90:5 per pinnedlua_api1022; use actualvisualinspection/tuning. Publish same treatment foricons/worn so no divergence.

Hoe assets already imported by rootFARM: grug_farming_woodhoe.png,grug_farming_steelhoe.png are Voxe originals; sevenIDs/uses declared. ART provides sixmaterial treatments through code orassetmap, not anotherrecipe. RootFARMwater buckets already visuallyinspected unchangedminetest_gamebucket.png/water, localledgerElementWCCBYSA3; don'tredo.

No quiver filename found in pinnedrefs via rg. First look for suitableexistingcontainers/bundles; ifneednewart gap stateit and use appropriate imagegenskill/tool. Quiver must readasarrowholder ratherthanbag. Do not generate broadnewart bydefault.

Visual/evidence boundary: assetcontactsheetandbowpose are actualpreviewevidence; finalGUIstilluser. Keep assetfilenames+commit+license/treatment manifest and minimalregistration checks. No broadruntime/testsuite. Root finalintegrationchecks all registeredtexture paths and importerlicenses.
