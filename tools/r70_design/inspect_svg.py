#!/usr/bin/env python3
"""Render the actual inline SVG plans with librsvg for visual inspection.

This does not test browser layout. Outputs go to the requested scratch directory.
Requires the system PyGObject, librsvg and cairo; no downloaded dependencies.
"""
import argparse
import re
from pathlib import Path
from lxml import html
import gi
import cairo

gi.require_version('Rsvg', '2.0')
from gi.repository import Rsvg


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--dark', action='store_true')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    doc = html.fromstring((here/'page.html').read_text())
    css = (here/'style.css').read_text()
    palette = dict(re.findall(r'(--[\w-]+):([^;}]+)', css.split('}', 1)[0]))
    if args.dark:
        palette.update(dict(re.findall(r'(--[\w-]+):([^;}]+)',css.split(':root[data-theme=dark]{',1)[1].split('}',1)[0])))
    css = re.sub(r'var\((--[\w-]+)\)', lambda m: palette[m[1]], css)
    args.output.mkdir(parents=True, exist_ok=True)
    groups=[(s.get('id'),s.xpath('.//svg')) for s in doc.xpath('//section[contains(@class,"place")]')]
    groups += [('compact-'+str(i+1),[s]) for i,s in enumerate(doc.xpath('//svg[@class="compact-plan"]'))]
    for name,svgs in groups:
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 640*len(svgs), 640)
        ctx = cairo.Context(surface)
        for i,svg in enumerate(svgs):
            raw = html.tostring(svg, encoding='unicode')
            raw = raw.replace('viewbox=', 'viewBox=').replace('patternunits=', 'patternUnits=')
            raw = raw.replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" ', 1)
            pos=raw.index('>')+1
            raw=raw[:pos]+'<style>'+css+'</style>'+raw[pos:]
            handle=Rsvg.Handle.new_from_data(raw.encode())
            viewport=Rsvg.Rectangle();viewport.x=i*640;viewport.y=0;viewport.width=640;viewport.height=640
            handle.render_document(ctx,viewport)
        surface.write_to_png(str(args.output/(name+'.png')))
    print('Rendered 12 pairs and 4 compact alternatives with librsvg; this is not a browser layout test.')


if __name__=='__main__':main()
