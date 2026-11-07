#!/usr/bin/env python3
"""Check the delivered artifact and source-backed geometry, without a browser."""
import ast
import json
import re
import subprocess
from pathlib import Path
from lxml import html
import build

HERE = Path(__file__).resolve().parent


def main():
    for p in HERE.glob('*.py'):
        ast.parse(p.read_text(), filename=str(p))
    source=(HERE/'page.html').read_text()
    doc=html.fromstring(source)
    ids=doc.xpath('//@id')
    assert len(ids)==len(set(ids)), 'Duplicate HTML/SVG ids'
    assert len(doc.xpath('//section[@class="place"]'))==12
    assert len(doc.xpath('//svg[@class="plan"]'))==24
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
            assert raw['ok'] and raw['seed']==seed
            for key,p in raw['capitals'].items():
                assert len(p['gates'])==4 and not p['missing_required']
                for subset in ['outline','streets','plots','gates','core','keep']:
                    assert data[seed][variant][key][subset]==p[subset]
    geometry=build.validate_geometry()
    claim_ids=re.findall(r'\*\*(C\d+) \[',(HERE/'claims.md').read_text())
    page_claims=doc.xpath('//article[starts-with(@id,"claim-")]')
    assert len(claim_ids)==len(page_claims)==86
    assert {p.get('id')[6:] for p in page_claims}==set(claim_ids)
    # Every cost card links back to the checker's ledger.
    for li in doc.xpath('//div[@class="cost-card"]/ul/li'):
        assert li.xpath('./a[@class="ref"]')
    print(f'PASS: 12 places, 24 equal-scale SVGs, {geometry} geometry schedules, 36 real city plans, 86 claim links.')
    print('PASS: inline assets/data only, exact seed strings, no missing required plots, JavaScript syntax, Python syntax.')
    print('NOT VERIFIED: browser layout/events, final 3D/terrain/engine walking/combat; see REPORT.md.')


if __name__=='__main__':main()
