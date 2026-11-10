#!/usr/bin/env python3
"""Build an offline discussion page from recorded, read-only blueprint exports."""
import collections
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools/building_templates/viewer'))
import templates as T
from content import ITEMS, PROFILES, CITY_STYLE, CORE_NOTES

CAPS = ['highcourt','dur_brannoc','lethariel','gor_drazhak','kezamba','nhal_veyr']
STARTS = ['dawnmere','hearthpine','silverleaf','sunscar','kapok','stillgrave']
RACES = dict(zip(STARTS, ['human','dwarf','elf','orc','troll','undead']))
RACES.update(dict(zip(CAPS, ['human','dwarf','elf','orc','troll','undead'])))
TITLES = {'dur_brannoc':'Dur Brannoc','gor_drazhak':'Gor Drazhak','nhal_veyr':'Nhal Veyr',
 'dawnmere':'Dawnmere','hearthpine':'Hearthpine','silverleaf':'Silverleaf','sunscar':'Sunscar','kapok':'Kapok','stillgrave':'Stillgrave'}
DISTRICTS = {'market_professions':'Handel & Berufe','martial_garrison':'Militär',
 'lore_spiritual':'Wissen & Kult','residential_cultural':'Wohnen & Gemeinschaft'}
SERVICES = {'forge':'smith','tailor':'tailor','alchemist':'alchemy','leatherworker':'leather',
 'woodcarver':'carver','goldsmith':'jewel','cooking':'kitchen','riding':'stable',
 'weaponsmith':'smith','armorsmith':'smith'}
INNS = {'highcourt':'homes_tavern','dur_brannoc':'terrace_alehouse','lethariel':'homes_longhouse',
 'nhal_veyr':'homes_lane_house','gor_drazhak':'warren_clan_house','kezamba':'vine_longhouse'}
SERVICE_TITLES = {'smith':'Schmiede','tailor':'Schneiderei','alchemy':'Alchemie','leather':'Lederhandwerk',
 'carver':'Schnitzerei','jewel':'Goldschmiede','kitchen':'Küche','stable':'Reit-/Stallbereich'}
SPECIAL = {
 'dawnmere/harvest_inn':'tavern', 'hearthpine/lagerhouse':'brew',
 'silverleaf/lore_hall':'library', 'kapok/spirit_lodge':'shrine',
 'stillgrave/bone_works':'smith', 'sunscar/warlord_hall':'council',
 'highcourt/market_counting_house':'tailor','highcourt/lore_almonry':'alchemy',
 'nhal_veyr/mausoleum':'royal','nhal_veyr/bone_works':'smith',
 'dur_brannoc/ancestor_hall':'shrine','dur_brannoc/deep_memory_hall':'shrine',
 'lethariel/star_hall':'shrine','gor_drazhak/skull_hall':'shrine',
 'kezamba/cauldron_court':'kitchen','kezamba/moot_house':'council',
 'kezamba/gate_house_south':'home', # A dwelling name; inner gate totems are separate.
 'nhal_veyr/homes_gate_house':'home',
 'dawnmere/tollhouse':'watch', 'silverleaf/gate_lookout':'watch',
 'lethariel/mere_mourning':'green', 'lethariel/martial_mess':'kitchen',
 'lethariel/martial_butts':'drill','lethariel/martial_hall':'command',
 'kezamba/canopy_hall':'command', 'gor_drazhak/war_arena':'drill',
 'gor_drazhak/bone_barrow':'green','gor_drazhak/bone_quarry':'workshop',
 'gor_drazhak/warren_story_fire':'shelter','gor_drazhak/war_guard_fire':'shelter',
 'gor_drazhak/bone_ancestor_field':'green','gor_drazhak/bone_totem_court':'statue',
 'gor_drazhak/bone_ash_court':'green','gor_drazhak/bone_shaman_house':'shrine',
 'kezamba/vine_kitchen':'garden','kezamba/vine_terraces':'garden',
 'kezamba/totem_hall':'shrine','kezamba/canopy_muster':'drill',
 'kezamba/shore_vineyard':'garden','nhal_veyr/vigil_embalmer':'embalmer',
 'nhal_veyr/vigil_cloister':'colonnade','nhal_veyr/market_grave_field':'green',
 'nhal_veyr/watch_bone_rampart':'green','nhal_veyr/watch_pyre_court':'green',
 'nhal_veyr/watch_close':'green','dur_brannoc/forge_quench_court':'smith',
 'dur_brannoc/forge_ore_court':'yard','dur_brannoc/forge_slag_yard':'green',
 'dur_brannoc/forge_charcoal_field':'yard','dur_brannoc/deep_markers_yard':'green',
 'dur_brannoc/deep_keeper':'scribe', 'lethariel/mere_stages':'fish','highcourt/lore_chapter_house':'council',
}

def title(key):
    return TITLES.get(key, key.replace('_',' ').title())

def profile(city, key, sockets=(), spec=None, district=None):
    full = city+'/'+key
    if full in SPECIAL: return SPECIAL[full]
    if key == INNS.get(city): return 'tavern'
    if key == 'miners_guild': return 'guild'
    for s in sockets:
        if s.get('role') == 'riding_trainer': return 'stable'
        if s.get('role') == 'trainer' and s.get('profession') in SERVICES:
            return SERVICES[s['profession']]
    s = key.lower().replace(' ', '_')
    if district and district.startswith(city+'_'): district=district[len(city)+1:]
    if district and s.startswith(district+'_'): s=s[len(district)+1:]
    if s in ('orchard_cottage','field_cottage','orchard_house','chapel_house',
             'grove_house_tall','grove_house_short','tall_grove_house','short_grove_house'):
        return 'home'
    rules = [
     ('gate_south|gate_north|gate_east|gate_west','gate'),
     ('fallen|ruin|broken','ruin'), ('colonnade|cloister_walk','colonnade'),
     ('statue|monument','statue'), ('drill|muster_field|fighting','drill'),
     ('kings_hall|warlord_hall','royal'),
     ('graveyard|burial|cemetery|pasture|paddock|green$|pond|grove|copse|thicket|reedbed','green'),
     ('orchard|garden|gardens|field|allotment','garden'), ('well|cistern|fountain','well'),
     ('scriptorium|ledger|record','scribe'), ('library|lore_hall|reader_hall','library'),
     ('archive','archive'), ('mausoleum|shrine|chapel|ossuary|spirit|memory|vigil_hall','shrine'),
     ('tavern|alehouse|feast|inn$','tavern'), ('brew|brewhouse|brew_house|lager|lagerhouse','brew'),
     ('butcher','butcher'), ('bake|bakehouse|bakery|cook|cooking|oven|cauldron','kitchen'), ('herb|herbalist|physic|alchemy|alchemist','alchemy'),
     ('candle|candlemaker|wax','candle'), ('tannery|tanner|charnel|leather','leather'),
     ('tailor|weaver|shroud|cloth','tailor'), ('goldsmith|jewel','jewel'),
     ('carver|carvers|bowyer|wain','carver'), ('smith|smithy|bonesmith|forge|bone_works','smith'),
     ('armoury|armourer','armoury'), ('barracks','barracks'),
     ('captain|serjeant|quartermaster|muster_hall|martial_hall','command'),
     ('gatewatch|watch|watchtower|watchpost|tower|guard_house','watch'), ('stable|stables|pack_stable|beast_pen|beast_shed','stable'),
     ('boat|hull','boat'), ('fish|fisher|smoke|smokehouse|drying','fish'),
     ('store|stores|storehouse|granary|barn|charcoal','store'), ('workshop|guild|workyard','workshop'),
     ('council|meeting|community|moot|rainhouse','council'),
     ('market$|bazaar$|bazaar_square|trade_shed|covered_market','market'),
     ('court|yard|woodyard|logyard|cart_shed','yard'), ('house|houses|home|dwelling|cottage|cottages|lodge|stilt|annex|tenement|longhouse','home'),
     ('canopy|veranda|communal_walk|shelter','shelter'), ('shed','workshop'),
    ]
    for pattern, p in rules:
        if re.search(r'(?:^|_)(?:'+pattern+r')(?:_|$)',s): return p
    if spec:
        return {'forge':'smith','oven':'kitchen','boat':'boat','canopy':'shelter',
         'shed':'workshop','flat':'store','gable':'home'}.get(spec.get('kind'),'home')
    return 'home'

def prop_category(name):
    if any(s in name for s in ['xdecor_table','cottages_table','capital_counter']): return 'Tisch-/Thekenzellen'
    if 'painting' in name or 'itemframe' in name: return 'Bilder / Rahmen'
    if any(s in name for s in ['potted','capital_herbs']): return 'Topf-/Arbeitsgrün'
    if any(s in name for s in ['lantern','candle','torch','lamp']): return 'Leuchtobjekt-Zellen'
    if 'barrel' in name: return 'Fasszellen'
    if 'shelf' in name or 'bookshelf' in name: return 'Regalzellen'
    if any(s in name for s in ['xdecor_chair','cottages_bench']): return 'Stuhl-/Bankzellen'
    if 'beds:' in name and '_bottom' in name: return 'Betten'
    if any(s in name for s in ['cauldron','furnace','anvil','workbench','grug_jobs:',
                               'grug_brewing:','capital_']): return 'Arbeits-/Serviceobjekt-Zellen'
    if any(s in name for s in ['straw_mat','cushion','curtain','wagon_wheel','washing','cottages_tub']): return 'Weitere Einrichtungszellen'
    return None

def summarize(inv):
    out = collections.Counter()
    for n,v in inv['nodes'].items():
        c = prop_category(n)
        if c: out[c] += v
    return dict(out)

TPL_BASE = ROOT/'mods/MAPGEN/grug_mapgen/building_templates/templates'
template_cache = {}
maps = {}
def template_info(name):
    if name not in template_cache:
        template_cache[name] = T.parse_template(str(TPL_BASE/(name+'.tpl')))
    return template_cache[name]

def make_map(name):
    if name in maps: return
    t = template_info(name)
    furniture = {'seat','bench_seat','board_table','table_leg','table_top','shelf','shelf_vessels',
                 'storage','bed','hearth','workbench','mat','rug_accent','throne'}
    def char(k):
        if k in ('air','unchanged'): return ' '
        e = t.legend[k]; n = e.get('name',''); kind = e['kind']
        if kind == 'role':
            if n.startswith('light'): return 'L'
            if n in ['flower','flower_alt','undergrowth']: return 'P'
            if n in ['table_leg','table_top','board_table']: return 'T'
            if n in furniture: return 'F'
            if n.startswith('window'): return 'W'
            if n.startswith('door'): return 'D'
            if n in ['floor','path','ground','plaza','foundation']: return '.'
            return '#'
        c = prop_category(n)
        if c == 'Tisch-/Thekenzellen': return 'T'
        if c == 'Leuchtobjekt-Zellen': return 'L'
        if c == 'Topf-/Arbeitsgrün': return 'P'
        if c: return 'F'
        return '#'
    x0,y0,z0=t.origin; w,h,d=t.size
    heights=collections.Counter()
    for (x,y,z), k in t.cells.items():
        if char(k) in 'TFLP' and char(k) != ' ': heights[y]+=1
    y=max(heights,key=lambda v:heights[v]) if heights else max(1,y0)
    layers={str(level):[''.join(char(t.cells.get((x,level,z),'unchanged')) for x in range(x0,x0+w))
                        for z in range(z0,z0+d)] for level in sorted({0,1,y}) if y0<=level<y0+h}
    maps[name]={'layers':layers,'default':str(y),'width':w,'depth':d}

def source_for(city,key,template=None):
    if template: return 'mods/MAPGEN/grug_mapgen/building_templates/templates/'+template+'.tpl'
    return 'mods/MAPGEN/grug_mapgen/wp13/'+city+'_districts.lua'

rows=[]; cities=[]; totals=collections.Counter(); clear=table_count=0; runtime_plots=0
used_templates=set(); aggregate_rows=[]
evidence_files=sorted((HERE/'evidence').glob('*.json'),key=lambda p:
    (0,STARTS.index(p.stem)) if p.stem in STARTS else ((1,CAPS.index(p.stem)) if p.stem in CAPS else (2,p.stem)))

for path in evidence_files:
    export=json.loads(path.read_text()); city=export['city']; race=export.get('race',RACES.get(city))
    city_title=export.get('label') or title(city)
    if city in CAPS+STARTS: city_title=title(city)
    kind='Startstadt' if city in STARTS else ('Hauptstadt' if city in CAPS else 'Regionaldorf')
    cities.append({'id':city,'name':city_title,'race':race,'kind':kind,'style':CITY_STYLE[race]})
    for runtime in export['rows']:
        inv=runtime['inventory']; totals.update(inv['nodes']);table_count+=inv['table_cells'];clear+=inv['clear_above_tables']
        aggregate_rows.append((city,runtime['id']))
        if kind=='Regionaldorf':
            candidates=[]
            for i,b in enumerate(runtime['buildings']):
                spec=b['spec']; key=b['id']; label=spec['label']
                if city.startswith('r20_'): label='Gebäude '+str(i+1)+' · '+spec.get('kind','Haus')
                candidates.append(dict(key=key,label=label,inv=b['inventory'],templates=[],sockets=[],spec=spec,
                 context='Regionaldorf',scope='Ausschnitt der gebauten Dorfkomposition',
                 source='mods/MAPGEN/grug_mapgen/wp40/'+('r20_poi_catalog.lua' if city.startswith('r20_') else 'r14_poi_blueprint.lua')))
        elif runtime['kind'] in ('core','start'):
            candidates=[]
            for part in runtime['templates']:
                candidates.append(dict(key=part['id'],label=title(part['id']),inv=part['inventory'],
                    templates=[part['template']],sockets=[],context='Hauptstadtkern' if kind=='Hauptstadt' else 'Startstadt',
                    scope='Gebäudevorlage vor zusätzlicher Außendekoration',source=source_for(city,part['id'],part['template'])))
        else:
            runtime_plots+=1
            ts=[x['template'] for x in runtime['templates']]
            candidates=[dict(key=runtime['id'],label=title(runtime['id']),inv=inv,templates=ts,
                 sockets=runtime.get('sockets') or [],district=runtime['district'],context=DISTRICTS.get(runtime['role'],runtime['district']),
                 scope='Gebauter Distriktentwurf inklusive Service- und Außendekoration',
                 source=source_for(city,runtime['id'],ts[0] if ts else None),
                 is_fill=runtime['kind']=='fill')]
        for c in candidates:
            key=c['key']; label=c['label']; spec=c.get('spec')
            p=profile(city,spec['label'] if spec and not city.startswith('r20_') else key,c['sockets'],spec,c.get('district'))
            stance,old,new,advice=PROFILES[p]
            if c.get('is_fill') and p=='home':
                p='green';stance,old,new,advice=PROFILES[p]
            # Actual service sockets take precedence over historic building names.
            services=[SERVICE_TITLES[SERVICES[s['profession']]] for s in c['sockets']
                if s.get('role')=='trainer' and s.get('profession') in SERVICES]
            if any(s.get('role')=='riding_trainer' for s in c['sockets']):
                services.append(SERVICE_TITLES['stable'])
            if services: label += ' · '+', '.join(dict.fromkeys(services))
            if key==INNS.get(city): label += ' · Gasthaus'
            if spec:
                advice += ' Auswahl an die kleine Grundfläche anpassen: höchstens zwei bis drei Ergänzungen.'
            for t in c['templates']: used_templates.add(t);make_map(t)
            props=summarize(c['inv'])
            current='; '.join(f'{v} {k}' for k,v in props.items()) or 'Keine durch den einfachen Node-Filter erkannten Einrichtungsobjekte; Bauteile können trotzdem Bänke oder Ablagen bilden.'
            context_key = 'core' if c['context']=='Hauptstadtkern' else ('district' if kind=='Hauptstadt' else 'building')
            ident=city+'/'+context_key+'/'+key
            # R14 generated names are editorial descriptions rather than saved IDs.
            rows.append({'id':ident,'city':city,'cityName':city_title,'cityKind':kind,'race':race,'name':label,
             'context':c['context'],'profile':p,'stance':stance,'old':old,'new':new,'advice':advice,
             'current':current,'counts':props,'tableCells':c['inv']['table_cells'],
             'clearTables':c['inv']['clear_above_tables'],'scope':c['scope'],'templates':c['templates'],
             'source':c['source'],'evidence':'../evidence/'+path.name,'spec':spec,
             'isFill':c.get('is_fill',False),
             'nodeEvidence':{n:v for n,v in c['inv']['nodes'].items() if prop_category(n)},
             'services':services})

assert len({r['id'] for r in rows})==len(rows), 'duplicate building identity'
assert len(cities)==24
assert all(len(r['advice'])>30 for r in rows)
assert all(i in {x['id'] for x in ITEMS} for r in rows for i in r['old']+r['new'])

counts=collections.Counter(r['cityKind'] for r in rows)
report={'base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'cities':cities,'items':ITEMS,'buildings':rows,'maps':maps,'cores':CORE_NOTES,
 'stats':{'rows':len(rows),'templates':len(used_templates),'runtimePlots':runtime_plots,'byKind':dict(counts),
 'tableCells':table_count,'clearTables':clear,'paintings':sum(v for n,v in totals.items() if 'painting' in n),
 'frames':sum(v for n,v in totals.items() if 'itemframe' in n),'barrels':sum(v for n,v in totals.items() if 'barrel' in n),
 'plants':sum(v for n,v in totals.items() if 'potted' in n)},
 'sources':{'mods/MAPGEN/grug_mapgen/wp13/'+p.name:hashlib.sha256(p.read_bytes()).hexdigest()
  for p in sorted((ROOT/'mods/MAPGEN/grug_mapgen/wp13').glob('*.lua'))},
 'templateHashes':{t:hashlib.sha256((TPL_BASE/(t+'.tpl')).read_bytes()).hexdigest() for t in sorted(used_templates)}}
for pattern in ('mods/MAPGEN/grug_mapgen/wp40/*.lua', 'tools/decoration_study/*.py',
                'tools/decoration_study/*.lua', 'tools/decoration_study/page.html',
                'tools/decoration_study/evidence/*.json',
                'tools/building_templates/viewer/templates.py',
                'mods/ENTITIES/grug_traders/stock.lua', 'mods/ITEMS/grug_decor/*.lua',
                'mods/PLAYER/grug_jobs/basic_recipes.lua'):
    for p in sorted(ROOT.glob(pattern)):
        report['sources'][str(p.relative_to(ROOT))] = hashlib.sha256(p.read_bytes()).hexdigest()
out=HERE/'dist';out.mkdir(exist_ok=True)
payload=json.dumps(report,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
page=(HERE/'page.html').read_text().replace('__DATA__',payload)
(out/'index.html').write_text(page)
(HERE/'inventory.json').write_text(json.dumps({k:v for k,v in report.items() if k not in ['maps','items']},ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report['stats'],ensure_ascii=False,indent=2))
print('Page:',out/'index.html')
