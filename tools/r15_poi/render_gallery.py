"""R15 texture gallery and eye-level geometry export using the WP13 renderer.
Run from the repository root; camera views are rendered by render_eyes.py.
"""
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/wp13'))
import render_blueprint as rb

OUT = ROOT / 'tools/r15_poi/gallery'
OUT.mkdir(parents=True, exist_ok=True)
CACHE=Path(tempfile.gettempdir())/'grug-r15-poi-render'
CACHE.mkdir(parents=True, exist_ok=True)
if sys.argv[1:] == ['--eye-sheets']:
    for name, labels in {
        'goldmead_village': ['arrival','workyard','interior'],
        'redtusk_outpost': ['arrival','stores'],
        'mournfen_bandit_camp': ['arrival','ruin','captive'],
    }.items():
        sheet=Image.new('RGB',(600*len(labels),430),(26,29,30))
        draw=ImageDraw.Draw(sheet)
        for i,label in enumerate(labels):
            panel=Image.open(CACHE/(name+'-eye-'+label+'.png')).convert('RGB')
            panel.thumbnail((600,400));sheet.paste(panel,(600*i,30))
            draw.text((600*i+10,9),name.replace('_',' ').title()+' / '+label,fill='white')
        sheet.save(OUT/(name+'-eyes.png'))
    sys.exit(0)
TILES = json.loads((ROOT / 'tools/wp13/node_tiles.json').read_text())
# Obtain the actual original display textures, not guessed flat colors.
rows = subprocess.check_output(['luajit', '-', str(ROOT)], input=b'''dofile(arg[1].."/mods/MAPGEN/grug_mapgen/poi_displays.lua")({register_node=function(n,d) io.write(n,"\\t",d.tiles[1],"\\n") end})''').decode()
for row in rows.splitlines():
    name, texture = row.split('\t')
    TILES['nodes'][name] = {'tiles': [texture], 'shape': 'cube'}
tiles_path = CACHE / 'tiles.json'
tiles_path.write_text(json.dumps(TILES))
bank = rb.TextureBank(str(tiles_path))
sprites = rb.SpriteFactory(bank, 16, 0)
# Actual fixed nodeboxes (the generic WP13 overview approximates some furniture).
boxes = {}
rows = subprocess.check_output(['luajit', '-', str(ROOT)], input=b'''local r=dofile(arg[1].."/tools/wp13/stub_registry.lua").load(arg[1]); local names={}; for n in pairs(r.nodes) do names[#names+1]=n end; table.sort(names); for _,n in ipairs(names) do local d=r.nodes[n]; if d.node_box and d.node_box.type=="fixed" then local b=d.node_box.fixed; if type(b[1])=="number" then b={b} end; for _,v in ipairs(b) do io.write(n,"\\t",table.concat(v,"\\t"),"\\n") end end end''').decode()
for row in rows.splitlines():
    fields = row.split('\t'); boxes.setdefault(fields[0], []).append(tuple(float(x)+.5 for x in fields[1:]))

regions = ['copperfell','goldmead','starbough','mournfen','redtusk','raincall']
kinds = ['village','outpost','bandit_camp']
pilots = {'goldmead_village','redtusk_outpost','mournfen_bandit_camp'}
images = []
texture_paths = {}

def texture(name, face):
    tiles = sprites.tiles_for(name)
    assert tiles, name
    spec = tiles[min(face, len(tiles)-1)]
    if spec not in texture_paths:
        path = CACHE / ('texture-' + hashlib.sha256(spec.encode()).hexdigest()[:16] + '.png')
        img = bank.texture(spec)
        assert img is not None, spec
        img.save(path); texture_paths[spec] = str(path)
    return texture_paths[spec]

for region in regions:
    for kind in kinds:
        name = region+'_'+kind
        source = ROOT / 'mods/MAPGEN/grug_mapgen/wp40' / ('r7_'+name+'_blueprint.lua')
        cells = rb.load_cells(str(source), 'luajit')
        target = OUT / (name+'.png')
        subprocess.run([sys.executable, str(ROOT/'tools/wp13/render_blueprint.py'),str(source),'--lua','luajit','--tiles',str(tiles_path),'--view','sw','--quiet','-o',str(target)],check=True)
        images.append((name,target))
        if name not in pilots: continue
        # Eye renderer consumes the same cells and WP13 shape/texture authority.
        occupied = {(x,y,z): n for x,y,z,n,p in cells if n != 'air'}
        geometry=[]
        for x,y,z,n,p in cells:
            if n == 'air': continue
            entry=bank.nodes.get(n,{})
            shape=entry.get('shape','cube')
            conn = sum(bit for dx,dz,bit in [(1,0,1),(-1,0,2),(0,1,4),(0,-1,8)] if (x+dx,y,z+dz) in occupied)
            if entry.get('drawtype')=='signlike' and p==4:
                shapes=[(0,0,.97,1,1,.99)]
            elif n in boxes:
                shapes=[rb.rot_box(b,p%4) for b in boxes[n]]
            else:
                shapes=[b for b,uv in rb.node_boxes(shape,p,conn)]
            geometry.append({'pos':[x,y,z], 'boxes':shapes,'light':n in ('grug_decor:xdecor_candle','grug_decor:xdecor_lantern'),'tiles':[texture(n,i) for i in range(6)]})
        (CACHE/(name+'.json')).write_text(json.dumps(geometry))


sheet=Image.new('RGB',(3*600,6*430),(26,29,30)); draw=ImageDraw.Draw(sheet)
for i,(name,path) in enumerate(images):
    panel=Image.open(path).convert('RGB'); panel.thumbnail((590,395))
    x=(i%3)*600+(600-panel.width)//2; y=(i//3)*430+28
    sheet.paste(panel,(x,y)); draw.text(((i%3)*600+12,(i//3)*430+8),name.replace('_',' ').title(),fill='white')
sheet.save(OUT/'all18.png')
print(OUT/'all18.png')
