#!/usr/bin/env python3
"""Create editable throne proposals without touching shipped templates."""
from pathlib import Path
import sys, json, hashlib, copy, base64
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path[:0]=[str(ROOT/'tools/character_creation_preview'),str(ROOT/'tools/r70_castle'),str(ROOT/'tools/building_templates/editor')]
import scenery as S
import importlib.util
cspec=importlib.util.spec_from_file_location('castle_build',ROOT/'tools/r70_castle/build.py')
C=importlib.util.module_from_spec(cspec);cspec.loader.exec_module(C)
import tplfile
V,T=S.V,S.T
reg=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
palettes=T.Palettes(S.G.load_palettes('luajit',set(reg['nodes'])|set(reg.get('aliases',{}))))
textures,meshes,names,indices,scenes=V.Textures(),{},[],{},{}
report={'sources':{},'measurements':{'seat_above_dais':[2,1],'arm_above_seat':[1.5,1],'body_width_depth_height':[[5,3,7],[5,3,6]]},'changes':{}}
for race,stem in C.OLD.items():
    source=ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'/(stem+'.tpl')
    raw=source.read_text(); model=tplfile.load(raw,str(source)); variant=copy.deepcopy(model)
    def setcell(x,y,z,key):
        row=variant.layers[y][z];variant.layers[y][z]=row[:x]+key+row[x+1:]
    # Remove the base and translate the surviving chair down one node.
    for y in range(5,12):
        for z in range(28,31):
            for x in range(20,25): setcell(x,y,z,'.')
    for y in range(6,12):
        for z in range(28,31):
            for x in range(20,25): setcell(x,y-1,z,model.layers[y][z][x])
    # Remove half-node caps: the full bronze arm now ends one node above cloth.
    for x in (20,24):
        for z in (28,29): setcell(x,7,z,'.')
    output=HERE/'variants'/(stem+'.tpl');output.parent.mkdir(exist_ok=True)
    output.write_text(tplfile.dump(variant))
    before=T.parse_template(str(source));after=T.parse_template(str(output))
    changes=[list(p)+[before.cells[p],after.cells[p]] for p in before.cells if before.cells[p]!=after.cells[p]]
    assert all(20<=x<=24 and 5<=y<=11 and 28<=z<=30 for x,y,z,*_ in changes)
    assert before.points==after.points
    report['changes'][race]=len(changes)
    main=Path('/home/jan/projects/grudgelands')/source.relative_to(ROOT)
    report['sources'][str(source.relative_to(ROOT))]={'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'same_as_main':main.read_bytes()==source.read_bytes()}
    for variant_name,template in [('before',before),('after',after)]:
        cells,bad=T.resolved_cells(template,T.resolve(template,palettes,C.capital_binding(palettes,race)),palettes)
        assert not bad,bad
        seat_y=6 if variant_name=='before' else 5
        assert all(cells[x,seat_y,z][0].startswith('wool:') for x in range(21,24) for z in (28,29))
        # No chair cell enters the king's original 0.96 x 2.72 collision volume.
        assert all(not all(a<p[i]+.5 and b>p[i]-.5 for i,(a,b) in enumerate(((21.52,22.48),(4.5,7.72),(26.52,27.48)))) for p,(name,_) in cells.items() if name!='air')
        if race!='human':continue
        cropped={p:n for p,n in cells.items() if 14<=p[0]<=30 and 3<=p[1]<=13 and 23<=p[2]<=32 and n[0]!='air'}
        spec={'title':variant_name.title()+' · Highcourt throne','description':'Same camera, same dais. Neutral figure: 2.72 nodes tall, matching the king collision height. Not an NPC screenshot.','camera':{'eye':[26,9.5,18],'target':[22,7.4,28.5],'fov':48},'sky':'#28343b','fog':[100,200],'tint':'#ffffff','portrait':{'stature':2.72/(32.5*.0525),'units_per_pixel':.0525,'feet':[18,4.5,28]}}
        scenes[variant_name]=V.pack_cells({'spec':spec},[(*p,*n) for p,n in sorted(cropped.items())],indices,names)
types,missing=V.build_types(names,reg['nodes'],reg.get('aliases',{}),textures,meshes)
assert not missing['skipped'] and not missing['missing_mesh'] and not textures.missing
body=json.loads((ROOT/'tools/r54_armor/data/catalog.json').read_text())['body']
payload={'scenes':scenes,'types':types,'textures':textures.images,'meshes':meshes,'body':body}
page=V.inline_renderer((S.HERE/'scenes.html.in').read_text()).replace('__PORTRAIT__',(S.HERE/'portrait.js').read_text())
page=page.replace('t.colorSpace = THREE.SRGBColorSpace;','t.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;','renderer.outputEncoding = THREE.sRGBEncoding;')
page=page.replace("new THREE.MeshBasicMaterial({color:0xe5bb77,wireframe:true})","new THREE.MeshBasicMaterial({color:0x91aab3})")
page=page.replace("pixelTextures();camera();fit(width,height);","pixelTextures();showReference(true);camera();fit(width,height);")
page=page.replace("||'human'","||'before'")
page=page.replace('Grudgelands · Character backdrop scenes','Grudgelands · Throne study').replace('tools/character_creation_preview/scenes/','tools/capital_polish_study/throne/variants/')
for token,path in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():page=page.replace(token,path.read_text().replace('</','<\\/'))
for scene in scenes.values():scene['digest']=S.digest({'scene':scene,'types':types,'textures':textures.images,'meshes':meshes,'body':body,'page':page,'builder':Path(__file__).read_text()})
page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
(HERE/'scenes.html').write_text(page)
(HERE/'measurements.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
# Embed captures only when the input receipt matches this build.
if all((HERE/'renders'/(name+'.png')).exists() and json.loads((HERE/'renders'/(name+'.json')).read_text())['input']==scene['digest'] for name,scene in scenes.items()):
    images={name:'data:image/png;base64,'+base64.b64encode((HERE/'renders'/(name+'.png')).read_bytes()).decode() for name in scenes}
    (HERE/'index.html').write_text('''<!doctype html><html lang="de"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Thron · Größenvergleich</title><style>body{background:#182026;color:#eee8dc;font:17px system-ui;margin:30px}h1{font:36px Georgia}main{display:grid;grid-template-columns:1fr 1fr;gap:20px}img{width:100%;display:block}article{background:#28343b;padding:16px}p{line-height:1.6}strong{color:#e6be79}@media(max-width:850px){main{grid-template-columns:1fr}}</style><h1>Der Thron · eine Schicht niedriger</h1><p>Entwurf zur Entscheidung · gleiche Kamera, gleiche Materialien, unverändertes Podest.<br>Die neutrale Figur ist 2,72 Blöcke hoch, entsprechend der Kollisionshöhe des Königs.</p><main><article><h2>Aktuell</h2><img src="'''+images['before']+'''"><p>Sitzfläche: <strong>2 Blöcke</strong> über dem Podest.<br>Armlehnen: <strong>1,5 Blöcke</strong> über dem Sitz.</p></article><article><h2>Vorschlag</h2><img src="'''+images['after']+'''"><p>Sitzfläche: <strong>1 Block</strong> über dem Podest.<br>Armlehnen: <strong>1 Block</strong> über dem Sitz.</p></article></main><p>Bronzene Grundschicht entfernt, Rückenlehne und Krone um einen Block abgesenkt. Halbe Abdeckungen der Armlehnen entfernt. Breite und Tiefe bleiben gleich; die fünf Ziersteine bleiben erhalten.</p><p>Reine Vorschau: Die ausgelieferten Gebäude sind unverändert.</p></html>''')
