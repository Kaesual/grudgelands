"""Semantic palette additions for the approved monumental/open-building pass."""
D = 'grug_decor:'
# Column order: dwarf, human, elf, orc, troll, undead.
ROWS = {
 'facade_masonry': [D+'darkage_stone_brick','default:stonebrick','default:silver_sandstone_brick','default:desert_stonebrick',D+'darkage_basalt',D+'castle_dungeon_stone'],
 'facade_monument_frame': ['default:stone_block','default:stone_block',D+'darkage_marble',D+'darkage_ors_block',D+'darkage_basalt_block',D+'darkage_basalt_block'],
 'facade_monument_band': ['default:stone_block','default:stone_block',D+'darkage_serpentine','default:desert_stonebrick',D+'darkage_basalt_block',D+'darkage_basalt_block'],
 'facade_open_wood': ['grug_trees:gravewood_wood']*4+['default:junglewood','grug_trees:gravewood_wood'],
 'facade_stone_slab': ['stairs:slab_stone_block','stairs:slab_stone_block',D+'darkage_marble_slab',D+'darkage_ors_brick_slab',D+'darkage_basalt_slab',D+'darkage_basalt_slab'],
 'facade_stone_stair': ['stairs:stair_stone_block','stairs:stair_stone_block',D+'darkage_marble_stair',D+'darkage_ors_brick_stair',D+'darkage_basalt_stair',D+'darkage_basalt_stair'],
}
for shape in ('bottom','middle','top'):
    ROWS['facade_pillar_'+shape] = [D+'castle_pillar_stone_block_'+shape]*2+[
        D+'city_pillar_'+m+'_'+shape for m in ('marble','ors','junglewood','basalt')]
