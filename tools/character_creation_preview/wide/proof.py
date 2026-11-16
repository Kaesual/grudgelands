#!/usr/bin/env python3
"""Measure the wide layer's effect through each unchanged game camera."""
import argparse
import json
import subprocess
from PIL import Image, ImageChops
from build import HERE, SOURCE, RACES, sha, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chrome', default='/usr/bin/chromium-browser')
    args = parser.parse_args()
    for mode in ('base', 'layered'):
        subprocess.run(['node', str(SOURCE/'render-scenes.mjs'), '--directory', str(HERE/'proof'/mode),
                        '--width', '1540', '--height', '1400', '--chrome', args.chrome], check=True)
    results = {}
    for race in RACES:
        images = [HERE/'proof'/mode/'renders'/(race+'.png') for mode in ('base', 'layered')]
        with Image.open(images[0]) as a, Image.open(images[1]) as b:
            assert a.size == b.size == (1540, 1400)
            difference = ImageChops.difference(a.convert('RGB'), b.convert('RGB'))
        channels = difference.split()
        mask = ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])
        changed = 1540*1400-mask.histogram()[0]
        maximum = max(c.getextrema()[1] for c in channels)
        diff = HERE/'proof'/('diff-'+race+'.png')
        difference.point(lambda v: min(255, v*8)).save(diff, optimize=True)
        results[race] = {'differing_pixels': changed, 'largest_channel_difference': maximum,
                         'difference_bbox': mask.getbbox(), 'diff_amplification': 8,
                         'diff_sha256': sha(diff), 'base_sha256': sha(images[0]),
                         'layered_sha256': sha(images[1]), 'width': 1540, 'height': 1400}
        print(race+': '+str(changed)+' differing pixels; largest channel difference '+str(maximum))
    write_json(HERE/'proof/comparison.json', results)


if __name__ == '__main__':
    main()
