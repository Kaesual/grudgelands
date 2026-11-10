#!/usr/bin/env python3
"""Draw actual exported core plans with candidate registrar positions."""
import json
import math
from pathlib import Path
HERE=Path(__file__).resolve().parent
D=json.loads((HERE/'cores.json').read_text())
colors={'built':'#59636a','paving':'#9b967d','ground':'#3b6447','tree':'#284b37','water':'#254b69','empty':'#18212a'}
picks={'dur_brannoc':(10,7),'highcourt':(10,7),'lethariel':(-15,-19),'gor_drazhak':(-10,7),'nhal_veyr':(10,7),'kezamba':(17,-14)}
results={}
for city,(rx,rz) in picks.items():
 v=D[city];b=v['bounds'];x0,z0=b['min']['x'],b['min']['z'];x1,z1=b['max']['x'],b['max']['z']
 # A conservative three-by-three patch: existing paving at y=0 and no taller
 # nodes, including overhangs; no world-path or aggro simulation is implied.
 assert all(v['raster'][rz-z0+dz][rx-x0+dx]==['paving',0,0] for dz in (-1,0,1) for dx in (-1,0,1)),city
 sockets=v['landmarks']['sockets']
 assert all(math.hypot(s['x']-rx,s['z']-rz)>1.5 for s in sockets),city
 w=next(s for s in sockets if s['id']=='travel_waypoint')
 hall=next(h for h in v['buildings'] if h['template'].endswith(('kings_hall','warlord_hall','mausoleum')))
 e=next(d for d in hall['doors'] if d['id']=='approach')
 rows=[]
 def pos(x,z):return (x-x0,z1-z)
 for iz,row in enumerate(v['raster']):
  for ix,(kind,*_) in enumerate(row):rows.append(f'<rect x="{ix}" y="{z1-z0-iz}" width="1.02" height="1.02" fill="{colors[kind]}"/>')
 hx,hz=pos(hall['x']-.5,hall['z']+hall['d']-.5)
 rows.append(f'<rect x="{hx}" y="{hz}" width="{hall["w"]}" height="{hall["d"]}" fill="none" stroke="#f6e0ba" stroke-width=".5"/>')
 wx,wz=pos(w['x'],w['z']);px,pz=pos(rx,rz)
 rows.append(f'<path d="M{wx},{wz} L{px},{pz}" stroke="#f6e0ba" stroke-width=".4" stroke-dasharray="1 1"/>')
 for label,x,z,col in [('W',w['x'],w['z'],'#83e3ef'),('E',e['x'],e['z'],'#ffffff'),('R',rx,rz,'#f0c275')]:
  x,z=pos(x,z)
  rows.append(f'<circle cx="{x}" cy="{z}" r="2.4" fill="{col}" stroke="#101820" stroke-width=".35"/><text x="{x}" y="{z+1.2}" text-anchor="middle" font-family="sans-serif" font-weight="bold" font-size="3.4" fill="#101820">{label}</text>')
 (HERE/(city+'-map.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-2 -2 {x1-x0+5} {z1-z0+5}">'+''.join(rows)+'</svg>')
 results[city]={'waystone':[w['x'],w['y'],w['z']],'castle_entrance':[e['x'],e['y'],e['z']], 'registrar_candidate':[rx,1,rz], 'straight_distance_waystone_to_candidate':round(math.hypot(w['x']-rx,w['z']-rz),1),'clear_patch':'3x3 existing paving, top y=0, no socket within1.5 nodes','note':'Proposal only. Distance is a straight line, not a verified walking route. Guild placement depends on seed.'}
(HERE/'registrar-candidates.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps({k:v['straight_distance_waystone_to_candidate'] for k,v in results.items()}))
