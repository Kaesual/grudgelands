"""Four study-only reed shapes; existing game texture, unchanged stair geometry.

These definitions exist only in the in-memory browser registry. They are not
registered with Luanti. A later implementation would add the missing shape
family through grug_decor's existing register_shapes helper.
"""
from copy import deepcopy


def install(nodes):
    source = 'grug_decor:cottages_reet'
    texture = nodes[source]['tiles'][0]
    records = {}
    for shape in ('stair', 'stair_inner', 'stair_outer', 'slab'):
        name = 'study:reed_' + shape
        geometry = 'stairs:' + shape + '_junglewood'
        assert name not in nodes
        node = deepcopy(nodes[geometry])
        node['tiles'] = [{'name': texture, 'backface_culling': True}]
        node['description'] = 'Study only: Reed ' + shape
        nodes[name] = node
        records[name] = {'geometry_source': geometry, 'texture_source': source,
                         'texture': texture, 'preview_only': True}
    return records
