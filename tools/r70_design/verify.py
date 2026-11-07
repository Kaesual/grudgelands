#!/usr/bin/env python3
"""Check the delivered artifact and source-backed geometry, without a browser."""
import ast
import copy
import json
import re
import subprocess
from pathlib import Path
from lxml import html
import build

HERE = Path(__file__).resolve().parent


def rejected(key, edit, expected):
    old=copy.deepcopy(build.P[key])
    try:
        edit(build.P[key])
        errors=build.clearance_errors(key)
        assert any(expected==e[1] for e in errors),(key,expected,errors)
    finally:build.P[key]=old


def regressions():
    # The checker's real failures, through the same validation used to build.
    rejected('highcourt',lambda p:p['shifts'].update(chapel=[0,0]),'door opens into castle wall')
    rejected('highcourt',lambda p:p['shifts'].update(chapel=[0,0]),'road crosses footprint')
    rejected('highcourt',lambda p:p['socket_positions'].update(chapel_quest=[-22,27]),'socket in castle footprint')
    rejected('gor_drazhak',lambda p:p['socket_positions'].update(court_idle_wain=[37,31]),'socket in wall/fence')
    rejected('gor_drazhak',lambda p:p['socket_positions'].update(court_work_fire=[37,19]),'foreign socket in footprint')
    rejected('hearthpine',lambda p:p['watch'].__setitem__(2,(-18,0)),'socket in retained composition wall/fence')
    rejected('dur_brannoc',lambda p:p['castle_sockets'].update(king=[-22,20]),'socket in reserved castle wall')
    rejected('dawnmere',lambda p:p.setdefault('socket_positions',{}).update(hall_quest=[24,-6]),'socket in wall/fence')
    return 8


def main():
    for p in HERE.glob('*.py'):
        ast.parse(p.read_text(), filename=str(p))
    source=(HERE/'page.html').read_text()
    doc=html.fromstring(source)
    ids=doc.xpath('//@id')
    assert len(ids)==len(set(ids)), 'Duplicate HTML/SVG ids'
    assert len(doc.xpath('//section[@class="place"]'))==12
    assert len(doc.xpath('//svg[@class="plan"]'))==24
    assert not doc.xpath('//svg[@class="compact-plan"]')
    assert 'radius 56 for all six capitals' in doc.get_element_by_id('decision-record').text_content()
    assert len(doc.xpath('//div[@class="decision"]/span[text()="ACCEPTED"]'))==10
    for svg in doc.xpath('//svg[@class="plan"]'):
        assert svg.get('viewbox')=='-80 -80 160 160'
        assert len(svg.xpath('./title'))==1
        assert svg.xpath('.//text[contains(text(),"20 nodes")]')
    for attr in ['src','href','poster','action']:
        for value in doc.xpath('//@'+attr):
            assert value.startswith('#'), f'External asset/link in {attr}: {value}'
            if len(value)>1:assert value[1:] in ids, f'Broken internal anchor {value}'
    css=doc.xpath('//style/text()')[0]
    assert '@import' not in css
    assert all(u.strip('"\' ').startswith('#') for u in re.findall(r'url\((.*?)\)',css))
    js=(HERE/'page.js').read_text()
    assert not re.search(r'\b(fetch|XMLHttpRequest|WebSocket|EventSource)\b',js)
    subprocess.run(['node','--check',str(HERE/'page.js')],check=True)
    data=json.loads(doc.get_element_by_id('planner-data').text)
    assert set(data)==set(build.SEEDS)
    for seed in build.SEEDS:
        for variant in ['today','proposed']:
            assert len(data[seed][variant])==6
            raw=json.loads((HERE/f'data/{seed}-{variant}.json').read_text())
            if variant=='proposed':
                for key in build.LAKES:raw['capitals'][key]=build.LAKE_PLANS[seed]['lake_shift'][key]
            assert raw['ok'] and raw['seed']==seed
            for key,p in raw['capitals'].items():
                assert len(p['gates'])==4 and not p['missing_required']
                for subset in ['outline','streets','plots','gates','core','keep']:
                    assert data[seed][variant][key][subset]==p[subset]
    geometry=build.validate_geometry()
    lakes=build.validate_lakes()
    assert lakes==json.loads((HERE/'data/lake-metrics.json').read_text())
    for seed in build.SEEDS:
        for variant in ['lake0','lake_shift']:
            raw=json.loads((HERE/f'data/{seed}-{variant}.json').read_text())
            assert raw['ok'] and raw['seed']==seed and raw['variant']==variant
            assert len(raw['capitals'])==6
            assert all(not p['missing_required'] for p in raw['capitals'].values())
    negative=regressions()
    schedules=json.loads((HERE/'data/socket-schedules.json').read_text())
    for key in build.NAMES:
        today=build.sockets(key);after=build.sockets(key,True)
        assert schedules[key]==after
        assert {s['id'] for s in today}=={s['id'] for s in after}
        assert len(after)==len({s['id'] for s in after})
        shown=doc.xpath(f'//tr[starts-with(@data-socket,"{key}:")]')
        assert {r.get('data-socket').split(':')[1] for r in shown}=={s['id'] for s in today}
        for sid in ['quest_cook','cook_oven','trainer_cooking'] if key in build.TOWNS else []:
            a=next(s for s in today if s['id']==sid);b=next(s for s in after if s['id']==sid)
            assert (a['x'],a['z'])==(b['x'],b['z'])
    for key in build.CAPITALS:
        assert build.area(build.P[key]['room'])==805
        assert 805+304+120+346==build.area(build.P[key]['castle'])==1575
    fleet=build.FLEET
    assert len(fleet['rows'])==40 and len({r['seed'] for r in fleet['rows']})==40
    for key in build.CAPITALS:
        deltas=[r['civic112']['capitals'][key]['plots']-r['today']['capitals'][key]['plots'] for r in fleet['rows']]
        assert sum(deltas)/40==fleet['summary'][key]['mean_delta']
        assert min(deltas)==fleet['summary'][key]['worst_delta']
        for r in fleet['rows']:
            for v in ['today','civic112']:assert not r[v]['capitals'][key]['missing_required']
    claim_ids=re.findall(r'\*\*(C\d+) \[',(HERE/'claims.md').read_text())
    page_claims=doc.xpath('//article[starts-with(@id,"claim-")]')
    assert len(claim_ids)==len(page_claims)==93
    assert {p.get('id')[6:] for p in page_claims}==set(claim_ids)
    # Every cost card links back to the checker's ledger.
    for li in doc.xpath('//div[@class="cost-card"]/ul/li'):
        assert li.xpath('./a[@class="ref"]')
    print(f'PASS: 12 places, 24 equal-scale SVGs, {geometry} geometry schedules, {negative} collision regressions, 93 claim links.')
    print('PASS: paired shifted-water planner evidence on three seeds, exact dry-column counts, shore buffers, dry templates, moot-house landing and fishing reach.')
    print(f'PASS: all {sum(len(v) for v in schedules.values())} sockets scheduled, room/wall budgets and 40-seed aggregate evidence.')
    print('PASS: inline assets/data only, exact seed strings, no missing required plots, JavaScript syntax, Python syntax.')
    print('NOT VERIFIED: browser layout/events, final 3D/terrain/engine walking/combat; see REPORT.md.')


if __name__=='__main__':main()
