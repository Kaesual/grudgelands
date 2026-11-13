#!/usr/bin/env python3
"""Render all historically deferred city contexts and attach editorial proposals."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from collections import Counter
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0,str(ROOT/'tools/r75_5_architecture'))
import integrate as I
sys.path.insert(0,str(ROOT/'tools/building_templates/viewer'))
import build_viewer as V
from proposals import proposal, LABELS, PALETTES
T,G = I.T,I.G

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    original_audit=ROOT/'tools/city_architecture_rollout/audit.json'
    excluded=json.loads(original_audit.read_text())['excluded']
    registry=json.loads((ROOT/'tools/building_templates/nodes.json').read_text())
    nodes=registry['nodes']; palettes=T.Palettes(G.load_palettes('luajit',set(nodes)))
    templates,layouts=G.read_sources(str(ROOT/I.BASE))
    by_name={t.name:t for t in templates}
    by_layout={str(Path(l.path).relative_to(ROOT)):l for l in layouts}
    jobs=[]
    for p in excluded:
        lay=by_layout[p['layout']]
        rec=next(r for r in lay.places+lay.uses if r['line']==p['line'])
        assert rec['template']==p['template']
        jobs.append(dict(name=p['template'],race=p['race'],id=rec.get('id') or p['template'],binding=G.placement_binding(palettes,lay,rec)))
    with tempfile.TemporaryDirectory(prefix='grug-specials-') as temporary:
        manifest=Path(temporary)/'jobs.lua';manifest.write_text('return '+I.lua(jobs)+'\n')
        output=subprocess.check_output(['luajit',str(HERE/'export.lua'),str(ROOT),str(manifest)],text=True)
    exported=[{} for _ in jobs]
    for line in output.splitlines():
        i,x,y,z,n,p2=line.split('\t')
        exported[int(i)-1][int(x),int(y),int(z)]=(n,int(p2))
    special_keys = set(json.loads((ROOT/'tools/r75_5_architecture/specials.json').read_text())['buildings'])
    implemented_keys = {k for f in ('shrine.json','services.json','specials.json') for k in json.loads((ROOT/'tools/r75_5_architecture'/f).read_text())['buildings']}
    original_live = I.live_original(jobs)
    names=[];indices={};scenes={};buildings={}
    for p,job,current,original in zip(excluded,jobs,exported,original_live):
        tpl=by_name[p['template']]; race=p['race']; key=p['town']+'__'+tpl.name+'__'+str(p['line'])
        old=T.parse_template(tpl.path,text=I.source(I.BASE+'/templates/'+tpl.name+'.tpl'))
        roles={e['name'] for e in old.legend.values() if e.get('kind')=='role'}
        roof_nodes=sorted({n for e in old.legend.values() if e.get('kind')=='role' and e['name'].startswith('roof_') for n in [e['name']]})
        spec=proposal(tpl.name,race,roles,roof_nodes)
        if key in implemented_keys and key not in special_keys:
            spec['details'] = ['Klare Stützen und waagerechte Abschlüsse; geschlossene Wandfelder folgen der abgestimmten Volkspalette.',
                               'Geometrie, Fenster, Türen, Einrichtung und Dienstpunkte erhalten. Im Worktree umgesetzt, noch zur Abnahme.']
            if tpl.name.endswith('_miners_guild'):
                spec['details'].append('Nur die Gildenhalle angeglichen. Fördergerüst, Erzhof, Maschinen und sechs Tiersteine unverändert.')
            if 'drill_yard' in tpl.name or 'tollhouse' in tpl.name:
                spec['details'].append('Untergeschoss und offene obere Galerie getrennt gegliedert; Galerie und Geschossboden bleiben frei und unverändert.')
            if tpl.name in {'hearthpine_workyard','highcourt_service_yard','kapok_drying_shed','kezamba_trade_shed','gor_drazhak_bazaar_tannery'}:
                spec['details'].append('Offene Arbeitsbereiche erhalten; freie Dachstützen durchgehend, keine doppelten Wandpfeiler.')
        if key in special_keys:
            spec['details'].append('Im Worktree umgesetzt. Nur Materialien geändert; belegte Positionen, Kollisionsformen, Durchgänge und Einrichtung erhalten.')
        floor=min((pos[1] for pos,k in tpl.cells.items() if tpl.legend.get(k,{}).get('name')=='floor'),default=0)
        before=current
        implemented=key in implemented_keys or tpl.name=='silverleaf_moon_shrine'
        status='done' if implemented else 'keep' if spec['priority']=='Beibehalten' else 'pending'
        if implemented: spec['priority']='Umgesetzt'
        if implemented:
            old=T.parse_template(tpl.path,text=I.source(I.BASE+'/templates/'+tpl.name+'.tpl'))
            before=original
        visible=[pos for pos,(n,p2) in current.items() if nodes[n]['drawtype']!='airlike']
        bounds=[min(p[i] for p in visible) for i in range(3)]+[max(p[i] for p in visible) for i in range(3)]
        title=tpl.name
        for town in sorted({l.town for l in layouts},key=len,reverse=True):
            if title.startswith(town+'_'): title=title[len(town)+1:];break
        title=title.replace('_',' ').title()
        doors=[p for p in tpl.points if p['group']=='doors']; front=int(doors[0].get('face') or 0) if doors else 0
        material_counts=Counter(n for n,p2 in current.values() if nodes[n]['drawtype']=='normal')
        planted=bool(tpl.meta.get('undergrowth') or any(p['group']=='trees' for p in tpl.points))
        # The actual loader adds trees and undergrowth before writing late cells.
        note=('Bäume und Unterwuchs werden vom echten Vorlagen-Loader erzeugt und sind hier enthalten. ' if planted else '')
        variant=' · '+p['main'] if p.get('main') else ''
        buildings[key]=dict(key=key,race=race,town=p['town'],title=title+variant,label=title+variant,
            template=tpl.name,template_races=tpl.races,pivot=tpl.pivot,size=tpl.size,origin=tpl.origin,
            floor=floor,max_y=bounds[4],inside_cut=floor+3,front=front,gable=(front+1)%4,bounds=bounds,
            description=spec['proposal'],details=spec['details'],profile=spec['category'],category=spec['category'],
            kind=spec['kind'],priority=spec['priority'],implemented=implemented,status=status,materials=[],
            material_names=spec['material_names'],attention=False,reference=None,
            placement=p,binding=job['binding'],source_sha256=sha(Path(tpl.path)),planted=planted,
            current_materials=[dict(node=n,count=c,label=nodes[n].get('description',n).split('\n')[0]) for n,c in material_counts.most_common(6)],
            preview_note=note+'Isolierter Gebäudeteil mit echten Spieltexturen; Stadtumgebung, NPCs und nachträgliche Stadtdekorationen sind nicht eingeblendet.',
            changed_cells=sum(before.get(q)!=current.get(q) for q in before.keys()|current.keys()) if implemented else 0)
        for variant,cells in [('before',before),('after',current)]:
            visible=[(*pos,*v) for pos,v in sorted(cells.items()) if nodes[v[0]]['drawtype']!='airlike']
            scenes[key+'_'+variant]=V.pack_cells({},visible,indices,names)
    textures,meshes=V.Textures(),{}
    common=Path(subprocess.check_output(['git','rev-parse','--git-common-dir'],cwd=ROOT,text=True).strip())
    textures.bank.index['blank.png']=str((ROOT/common).resolve().parent/'reference_projects/luanti/textures/base/pack/blank.png')
    types,report=V.build_types(names,nodes,registry.get('aliases',{}),textures,meshes)
    assert not report['skipped'] and not report['missing_mesh'] and not textures.missing,report
    for s in buildings.values():
        for node in s.pop('material_names'):
            tile=nodes[node]['tiles'][0];idx=textures.index(tile)
            s['materials'].append(dict(label=nodes[node].get('description',node).split('\n')[0],node=node,image=textures.images[idx]))
    assert not textures.missing and not textures.bank.warnings
    payload=dict(scenes=scenes,types=types,textures=textures.images,meshes=meshes,buildings=buildings,
        cultures={r:dict(label=LABELS[r],line=PALETTES[r][0]) for r in LABELS})
    page=V.inline_renderer((HERE/'page.html.in').read_text())
    page=page.replace('t.colorSpace = THREE.SRGBColorSpace;', 't.encoding = THREE.sRGBEncoding;').replace('renderer.outputColorSpace = THREE.SRGBColorSpace;', 'renderer.outputEncoding = THREE.sRGBEncoding;')
    for token,path in {'__THREE__':ROOT/'tools/r54_armor/vendor/three.min.js','__ORBIT__':ROOT/'tools/r69_camp_art/orbit.js','__LICENSE__':ROOT/'tools/r69_camp_art/THREE-LICENSE.txt'}.items():
        page=page.replace(token,path.read_text().replace('</','<\\/'))
    page=page.replace('__PAYLOAD__',json.dumps(payload,separators=(',',':')).replace('</','<\\/'))
    (HERE/'viewer.html').write_text(page)
    (HERE/'catalog.json').write_text(json.dumps(buildings,ensure_ascii=False,indent=2)+'\n')
    assert len(buildings)==len(excluded)==154
    (HERE/'build-report.json').write_text(json.dumps(dict(contexts=len(buildings),templates=len({s['template'] for s in buildings.values()}),
        historical_exclusions_sha256=sha(original_audit),shrine_sha256=sha(ROOT/'tools/r75_5_architecture/shrine.json'),
        services_sha256=sha(ROOT/'tools/r75_5_architecture/services.json'),
        specials_sha256=sha(ROOT/'tools/r75_5_architecture/specials.json'),
        status_counts=dict(Counter(s['status'] for s in buildings.values())),
        live_loader=True,planting_contexts=sum(s['planted'] for s in buildings.values()),
        missing_textures=sorted(textures.missing),viewer_sha256=sha(HERE/'viewer.html'),
        sources={str(Path(by_name[s['template']].path).relative_to(ROOT)):s['source_sha256'] for s in buildings.values()},
        layouts={str(Path(l.path).relative_to(ROOT)):sha(Path(l.path)) for l in layouts}),indent=2)+'\n')
    print(len(buildings),'contexts;',len(types),'node types;',len(textures.images),'textures;',sum(s['planted'] for s in buildings.values()),'planted contexts')

if __name__=='__main__':main()
