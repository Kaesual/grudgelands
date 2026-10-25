"""Keep exact native artwork and catalogue data in the browser study."""
from pathlib import Path
from PIL import Image, ImageChops
import re,json
R=Path(__file__).resolve().parent/'dist'
# Opaque arrival screens use a uniform full-screen backdrop, unlike other forms.
for res in ['1035x696','1600x900','2560x1440']:
 for key in ['creation','preparing']:
  im=Image.open(R/'shots'/res/(key+'.webp')).convert('RGB')
  bg=Image.new('RGB',im.size,im.getpixel((0,0))); box=ImageChops.difference(im,bg).getbbox()
  if box: im.crop(box).save(R/'shots'/res/(key+'-focus.webp'),lossless=True)
for key,box in {'talents':(20,136,710,427),'stats':(108,175,269,405),'creative_all':(72,160,572,406),'creative_nodes':(72,160,572,406),'creative_tools':(72,160,572,406),'creative_craftitems':(72,160,572,406),'creative_food':(72,160,572,406)}.items():
 im=Image.open(R/'shots/1600x900'/(key+'-focus.webp'));im.crop(box).save(R/'assets'/('native-'+key+'.webp'),lossless=True)
im=Image.open(R/'shots/1600x900/creation.webp');im.crop((610,412,780,657)).save(R/'assets/native-creation.webp',lossless=True)
# Skill slots and real hotbar examples are artwork, not a replacement list mechanism.
im=Image.open(R/'shots/1600x900/talents-focus.webp')
for n,box in {'skill1':(94,490,146,539),'skill2':(159,490,210,539)}.items():im.crop(box).save(R/'assets'/(n+'.webp'),lossless=True)
# Item icons already baked in the previous Atlas, when available.
G=Path(__file__).resolve().parents[2]
textures={p.name:p for p in G.glob('mods/**/textures/*.png')}
data={}
for key in ['vendor','vendor_gear']:
 s=(R/'evidence'/(key+'.txt')).read_text()
 names=re.findall(r'textarea\[[^\]]*?;;;([^\]]+)\]',s)
 prices=re.findall(r'label\[[^\]]*?\x1b\(c@#d4b77d\)(\d+c)',s)
 itemids=re.findall(r'item_image\[[^;]+;[^;]+;([^\]]+)\]',s)
 data[key]=[{'name':n,'price':prices[i], 'item':itemids[i] if i<len(itemids) else ''}for i,n in enumerate(names)]
(R/'catalogue.js').write_text('window.CATALOGUE='+json.dumps(data,ensure_ascii=False)+';')
print('Native regions and captured vendor prices packaged.')
import shutil
special={'grug_gear:bow_bronze':'grug_gear_bow_lebethron.png','grug_professions:thread':'default_paper.png','grug_professions:parchment':'default_paper.png','default:torch':'default_torch_on_floor.png','grug_inventory:bag_small':'grug_inventory_bag_small.png','grug_traders:potion_healing_weak':'grug_traders_item_potion_healing_weak.png','grug_gear:arrow':'grug_gear_arrow.png','vessels:glass_bottle':'vessels_glass_bottle.png'}
for offers in data.values():
 for offer in offers:
  mod,item=offer['item'].split(':')
  family,_,tier=item.partition('_')
  options=[f'grug_materials_tool_{tier}{family}.png' if mod=='grug_materials' else '',special.get(offer['item'],''),f'{mod}_item_{item}.png',f'{mod}_{item}.png',f'default_tool_{tier}{family}.png']
  found=next((t for t in options if t in textures),None)
  if found:
   offer['icon']=found;shutil.copyfile(textures[found],R/'assets'/found)
for t in ['default_iron_lump.png','grug_gear_item_wand_bronze.png','grug_gear_bow_lebethron.png','grug_gear_item_sword_bronze.png']:
 shutil.copyfile(textures[t],R/'assets'/t)
(R/'catalogue.js').write_text('window.CATALOGUE='+json.dumps(data,ensure_ascii=False)+';')
