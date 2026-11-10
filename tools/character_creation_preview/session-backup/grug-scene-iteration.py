import json, shutil, subprocess
from pathlib import Path
base=Path('tools/character_creation_preview')
before=base/'trees-before'
before.mkdir(exist_ok=True)
for f in (base/'scenes').glob('*.json'):
 if not (before/f.name).exists(): shutil.copyfile(f,before/f.name)
if not (before/'contact-sheet.png').exists(): shutil.copyfile(base/'renders/contact-sheet.png',before/'contact-sheet.png')
def node(name,x,y,z,p=0): return dict(kind='node',node=name,at=[x,y,z],param2=p)
def box(name,a,b,p=0): return dict(kind='blocks',node=name,**{'from':a,'to':b},param2=p)
def patch(name,x,z,rx,rz): return dict(kind='patch',node=name,at=[x,z],radius=[rx,rz])
D='grug_decor:'; N='grug_nodes:'
for f in sorted((base/'scenes').glob('*.json')):
 old=f.read_text(); s=json.loads(old); r=s['race']
 for i,t in enumerate(s['trees']):
  kind=t.pop('kind'); t.pop('height'); t.pop('radius')
  t['species']='apple' if kind=='oak' else 'silverwood' if r=='elf' and i in [0,1,3] else kind
  t['seed']=s['seed']*100+i*137+19
 p=s['props']
 if r=='dwarf':
  # A working stone/metal yard with a broken, stepped rock shoulder.
  s['description']='A pine-sheltered forge yard with stone stock, coal, a quenching tub and stacked timber. Layered rock and ground-cover pockets meet the working pavement.'
  p[:3]=[box('default:stone',[9,1,18],[13,2,23]),box('default:stone',[10,3,19],[12,3,22]),box('stairs:slab_stone',[10,4,20],[11,4,21]),box('stairs:stair_stone',[8,1,18],[8,1,21],1),box(D+'darkage_slate_rubble_slab',[7,1,20],[8,1,23])]
  p += [patch('default:gravel',6,8,3,6),patch(N+'dirt_with_forest_litter',10,28,6,7),node(D+'capital_quench',-4,1,6),node(D+'cottages_anvil',-6,1,4),box('default:pine_tree',[5,1,12],[7,1,13],12),box('default:pine_tree',[6,2,12],[6,2,13],12),box('default:stonebrick',[5,1,3],[6,1,4]),node('stairs:slab_stonebrick',5,2,4),node('default:stone_with_coal',8,1,16),node('default:stone_with_iron',9,1,17),node(D+'cottages_barrel_open',-5,1,10),node(D+'capital_product_weaponsmith',-7,2,10),node(D+'cottages_table',-7,1,10)]
  p += [node(N+'alpine_cushion',x,1,z) for x,z in [(7,2),(9,5),(10,12),(7,24)]]
 elif r=='elf':
  s['description']='A silverwood grove garden with pale winding paving, a reflecting pool, planted borders, fern beds and quiet seating. Slender aspen groups frame the taller forked silverwood crowns.'
  p += [patch(N+'dirt_with_silver_litter',-9,17,5,7),patch(N+'dirt_with_moss',15,25,5,7),box('stairs:slab_silver_sandstone_brick',[4,1,10],[11,1,10]),box('stairs:slab_silver_sandstone_brick',[12,1,11],[12,1,12]),box('stairs:slab_silver_sandstone_brick',[4,1,17],[4,1,20]),node(D+'cottages_bench',-5,1,8,1),node(D+'xdecor_potted_viola',-7,2,8),node(D+'xdecor_potted_dandelion_white',-7,2,13),node(D+'xdecor_table',5,1,6),node(D+'xdecor_potted_geranium',5,2,6)]
  p += [node(N+'flower_lilac_bells' if i%2 else N+'flower_cream_cups',x,1,z) for i,(x,z) in enumerate([(-5,0),(-6,2),(-5,3),(-7,5),(-6,6),(4,4),(6,3),(7,5),(9,7),(11,8),(13,9),(14,12),(14,16),(13,20),(11,22),(8,22)])]
  p += [node('default:fern_3',x,1,z) for x,z in [(-8,6),(-11,11),(15,14),(14,21),(-11,20)]]
 elif r=='orc':
  s['description']='An acacia-shaded lodge yard with hide drying, a cooking corner, low log seating and stores of straw and timber. Dry earth and ochre stone break up the grass around the paved approach.'
  p += [patch(N+'mud_dry',-6,7,5,7),patch(N+'clay_band_ochre',8,8,3,5),node(N+'camp_fire',-5,1,5),node(D+'xdecor_cauldron',-5,1,6),node(D+'cottages_bench',-4,1,7,1),node(D+'capital_hides',-7,1,10),node(D+'capital_hides',-8,1,10),node(D+'cottages_table',5,1,4),node(D+'cottages_tub',6,1,4),node(D+'cottages_straw_mat',4,1,8),node(N+'skull_horned',-6,2,3),node(D+'cottages_barrel_lying',7,1,10,1),node(D+'cottages_straw_bale',-8,1,8),node(D+'cottages_straw_bale',-7,2,8),node(D+'cottages_straw_mat',-4,1,3)]
  s['trees'].append(dict(at=[9,0,37],species='acacia',seed=62019))
 elif r=='troll':
  s['description']='A working river landing under branching jungle trees and a distant kapok. Mooring posts, hanging rope, stacked stores and reed islands give the stilt village a lived-in waterfront.'
  s['trees'][0]['at']=[-10,0,35]
  s['trees'][4]['species']='kapok';s['trees'][4]['at']=[-16,0,49]
  p += [box('default:jungletree',[5,2,4],[5,4,4]),node(D+'xdecor_lantern_hanging',5,3,3),box(D+'xdecor_rope',[5,1,5],[5,4,5]),node(D+'cottages_barrel_lying',-4,2,7,1),node(D+'cottages_barrel',-3,2,6),node(D+'cottages_straw_mat',-3,2,4),node(D+'cottages_tub',3,2,2),node(D+'cottages_bench',4,2,12,1),node(D+'capital_hides',-4,2,11),node(D+'capital_hides',-4,2,12)]
  for x,z in [(-10,4),(10,8),(-9,24),(12,20)]:
   p += [box(N+'mud_with_reeds',[x,0,z],[x+1,0,z+2])]
   p += [node(N+'cattails' if dz%2 else N+'reeds',x+dx,1,z+dz) for dx,dz in [(0,0),(1,1),(0,2)]]
  p += [node(N+'driftwood_log',-11,1,6,1),node(N+'driftwood_fork',11,1,10),node('default:fern_3',20,1,7),node(N+'jungle_bush_leaves',21,1,8),node(N+'jungle_bush_leaves',20,1,9)]
 elif r=='undead':
  s['description']='A neglected cemetery with bent, claw-branched gravewood, a kneeling mourner, low broken grave enclosures and sparse candles. Ash, moss and bone litter interrupt the blighted ground around the slate walk.'
  p += [node(N+'statue_mourner_base',5,1,7),node(N+'statue_mourner_upper',5,2,7),node(D+'xdecor_candle',4,1,7),node(D+'xdecor_candle',6,1,8),box(D+'darkage_slate_rubble_wall',[-8,1,8],[-8,1,13]),node(D+'darkage_slate_rubble_slab',-8,1,14),node(N+'statue_veiled_head',-7,1,4,1),node(N+'bones_fragments',7,1,11),node(N+'ribcage_human',9,1,10,3),node(N+'gravestone_fallen',-5,1,18,1),node(N+'gravestone_stele',8,1,17),node(D+'xdecor_candle',7,1,17),node(N+'swamp_moss',6,1,5),node(N+'swamp_moss',-7,1,12),node(N+'bones_fragments',-4,1,8)]
  s['trees'].append(dict(at=[7,0,46],species='gravewood',seed=78118))
 new=json.dumps(s,indent=2)+'\n'
 patchtext='*** Begin Patch\n*** Update File: '+str(f)+'\n@@\n'+''.join('-'+l+'\n' for l in old.splitlines())+''.join('+'+l+'\n' for l in new.splitlines())+'*** End Patch\n'
 subprocess.run(['apply_patch'],input=patchtext,text=True,check=True)
