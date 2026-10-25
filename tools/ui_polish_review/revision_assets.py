"""Restore native affordance art and exact recipe rows for revision two."""
from pathlib import Path
from PIL import Image
import re,json,shutil
R=Path(__file__).resolve().parent/'dist';G=Path(__file__).resolve().parents[2]
textures={p.name:p for p in G.glob('mods/**/textures/*.png')}
for t in ['grug_materials_anthracite_lump.png','default_copper_ingot.png','default_tin_ingot.png','default_bronze_ingot.png','grug_class_warrior.png','grug_class_priest.png','grug_mail_admin_badge.png','grug_mail_npc_seal.png','grug_money_bag_of_coins.png','default_bookshelf_slot.png','vessels_shelf_slot.png','grug_inventory_bag_large.png','grug_inventory_ghost_offhand.png','grug_inventory_ghost_trinket.png','grug_inventory_quiver.png','grug_gear_item_head_metal.png','grug_gear_item_chest_metal.png','grug_gear_item_legs_metal.png','grug_gear_item_feet_metal.png','grug_gear_shield_steel.png','grug_cooking_raw_stew_pot.png','grug_cooking_carrot.png','grug_cooking_wild_grain.png','mobs_meat_raw.png','default_furnace_fire_bg.png','gui_furnace_arrow_bg.png']:
 if t not in textures:raise ValueError(t)
 shutil.copyfile(textures[t],R/'assets'/t)
for kind in ['ore_sense','treasure_hunt']:
 for tier in range(1,7):
  t=f'grug_guild_{kind}_t{tier}.png';shutil.copyfile(textures[t],R/'assets'/t)
arts={};rows={}
def clean(s):return re.sub('\x1b\\([^)]*\\)','',s).replace('\\,',',').replace('\\;', ';')
for key in ['crafting','craft_details','craft_group','craft_queue','craft_enchant','craft_upgrade']:
 s=(R/'evidence'/f'{key}.txt').read_text();im=Image.open(R/'shots/1600x900'/f'{key}-focus.webp')
 labels=[(float(x),float(y),clean(t))for x,y,t in re.findall(r'label\[([\d.]+),([\d.]+);((?:\\.|[^\]])*)\]',s)]
 items=[(float(x),float(y),float(w),float(h),name) for x,y,w,h,name in re.findall(r'item_image\[([\d.]+),([\d.]+);([\d.]+),([\d.]+);([^\]]+)\]',s)]
 rows[key]=[]
 for x,y,w,h,name in items:
  if name not in arts:
   fn='native-item-'+str(len(arts))+'.webp';scale=52.8
   # The frozen medium inventory frame has 8px outer padding and a 1.5-unit header.
   box=(round(8+x*scale),round(8+(1.5+y)*scale),round(8+(x+w)*scale),round(8+(1.5+y+h)*scale))
   im.crop(box).save(R/'assets'/fn,lossless=True);arts[name]=fn
  if x<1:
   label=next((t for lx,ly,t in labels if abs(lx-.9)<.01 and abs(ly-y-.22)<.02),name)
   amount=next((t for lx,ly,t in labels if abs(lx-4.45)<.01 and abs(ly-y-.22)<.02),'×0')
   rows[key].append({'name':label,'count':amount,'item':name,'icon':arts[name]})
im=Image.open(R/'shots/1600x900/vendor_sell-focus.webp')
for name,box in [('default:wood',(45,141,81,178)),('default:cobble',(45,184,81,221))]:
 fn='native-'+name.split(':')[1]+'.webp';im.crop(box).save(R/'assets'/fn,lossless=True);arts[name]=fn
im=Image.open(R/'shots/1600x900/map-focus.webp');im.crop((22,160,572,648)).save(R/'assets/map-world.webp',lossless=True)
fix=Path('/home/jan/projects/grudgelands-orchestration/ui-modernization/dialog-review-fixes-2026-10-25/1035x696/dark_map_zones_1x.png')
if fix.is_file():Image.open(fix).crop((94,190,480,534)).save(R/'assets/map-zones-world.webp',lossless=True)
else:raise ValueError('Missing single-line map label capture: '+str(fix))
(R/'revision-data.js').write_text('window.ITEM_ART='+json.dumps(arts)+';\nwindow.CRAFT_ROWS='+json.dumps(rows,ensure_ascii=False)+';')
print('Revision art:',len(arts),'native item images; recipe rows:',sum(map(len,rows.values())))

# Archived native base art, with independent browser text labels (not scaled pixels).
base=Path('/home/jan/projects/grudgelands-orchestration/r53/worlds/r53_ms_0.52.1')
im=Image.new('RGBA',(1215,1080))
for x in range(3):
 for y in range(3):im.paste(Image.open(base/f'grug_map_base_{x}_{y}.png'),(x*512,y*512))
im.save(R/'assets/map-base-example.webp',lossless=True)
s=fix.with_name('ui_capture_dark_map_zones_1x.txt').read_text()
s=s[s.index('scroll_container['):s.index('scroll_container_end[]')]
labels=[{'x':float(x)/7.301*100,'y':float(y)/6.490*100,'text':t} for x,y,t in re.findall(r'label\[([\d.]+),([\d.]+);([^\]]+)\]',s)]
with (R/'revision-data.js').open('a') as f:f.write('\nwindow.ZONE_LABELS='+json.dumps(labels,ensure_ascii=False)+';')
