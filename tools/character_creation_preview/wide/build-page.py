#!/usr/bin/env python3
"""Offline review page with project-body silhouettes in the actual perspective."""
import json
import math
from build import HERE, SOURCE, ROOT, RACES, project


def silhouette(spec):
    body = json.loads((ROOT/'tools/r54_armor/data/catalog.json').read_text())['body']
    feet = spec['portrait']['feet']
    scale = spec['portrait']['units_per_pixel']*spec['portrait']['stature']
    polygons = []
    for box in body:
        a = box['box']
        for mirror in ([1, -1] if box.get('mirror') else [1]):
            points = []
            for x, y, z in ((a[0], a[1], a[2]), (a[3], a[1], a[2]), (a[3], a[4], a[2]),
                            (a[0], a[4], a[2]), (a[0], a[1], a[5]), (a[3], a[1], a[5]),
                            (a[3], a[4], a[5]), (a[0], a[4], a[5])):
                x, y, z = x*mirror*scale, y*scale, z*scale
                world = [feet[0]+x*math.cos(.22)+z*math.sin(.22), feet[1]+y,
                         feet[2]+x*math.sin(.22)-z*math.cos(.22)]
                u, v, depth = project(world, spec['camera'], 2560/1440)
                points.append((u*2560, v*1440, depth))
            for face in ((0,1,2,3), (4,5,6,7), (0,4,7,3), (1,5,6,2), (3,2,6,7), (0,1,5,4)):
                polygons.append((sum(points[i][2] for i in face)/4,
                                 ' '.join(f'{points[i][0]:.3f},{points[i][1]:.3f}' for i in face)))
    faces = ''.join(f'<polygon points="{points}"/>' for _, points in sorted(polygons, reverse=True))
    return '<svg class="figure" viewBox="0 0 2560 1440" aria-label="Projected bare-body silhouette">'+faces+'</svg>'


def main():
    data = {}
    for race in RACES:
        spec = json.loads((SOURCE/'scenes'/(race+'.json')).read_text())
        layer = json.loads((SOURCE/'scenes/wide'/(race+'.json')).read_text())
        spec['camera'] = layer['camera']
        receipt = json.loads((HERE/'renders'/(race+'.json')).read_text())
        data[race] = {'title': spec['title'], 'description': layer['description'],
                      'figure': receipt['figure'], 'silhouette': silhouette(spec),
                      'stature': spec['portrait']['stature'], 'bytes': (ROOT/'tools/web_data/media'/('grug_creation_'+race+'_wide.png')).stat().st_size}
    page = (HERE/'page.html.in').read_text()
    page = page.replace('__DATA__', json.dumps(data, separators=(',', ':'), ensure_ascii=True))
    (HERE/'index.html').write_text(page)


if __name__ == '__main__':
    main()
