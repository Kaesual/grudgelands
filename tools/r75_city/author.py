#!/usr/bin/env python3
"""Author fixed Round 75 city decoration coordinates from finished blueprints."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STUDY = json.loads((ROOT / "tools/decoration_study/inventory.json").read_text())
EVIDENCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools/r75_city/evidence"
OUT = ROOT / "mods/MAPGEN/grug_mapgen/wp40/city_decor_catalog.lua"
NODE_DEFS = json.loads((ROOT / "tools/building_templates/nodes.json").read_text())["nodes"]

TABLES = {"grug_decor:xdecor_table", "grug_decor:cottages_table"}
RECIPES = {
    "royal": [("wall", "painting"), ("floor", "display_armor"), ("floor", "display_weapon")],
    "guild": [("table", "material_ore"), ("table", "writing_set"), ("wall", "painting_stilled_seam")],
    "tavern": [("table", "plate_ceramic"), ("table", "mug"), ("wall", "painting_tavern")],
    "kitchen": [("table", "bread_board"), ("table", "fruit_basket"), ("wall", "wall_shelf_filled")],
    "brew": [("table", "jug"), ("table", "writing_set")],
    "smith": [("wall", "tool_board"), ("table", "material_metal")],
    "carver": [("wall", "tool_board")],
    "tailor": [("table", "cloth_rolls")], "leather": [("table", "leather_bundle"), ("wall", "tool_board")],
    "jewel": [("table", "material_gems")],
    "alchemy": [("table", "alchemy_set"), ("table", "book_open"), ("wall", "herb_bundle")],
    "candle": [("table", "candle_bundle"), ("table", "wax_bowl")],
    "library": [("table", "book_open"), ("table", "book_stack"), ("table", "candle_group")],
    "scribe": [("table", "writing_set"), ("table", "scroll_bundle")],
    "archive": [("table", "scroll_bundle"), ("table", "writing_set")],
    "shrine": [("table", "candle_group")],
    "council": [("table", "writing_set"), ("wall", "painting_trade_map")],
    "barracks": [("floor", "display_armor"), ("floor", "display_weapon")],
    "armoury": [("floor", "display_armor"), ("floor", "display_weapon"), ("wall", "tool_board")],
    "command": [("table", "map_sheet"), ("table", "scroll")],
    "watch": [("table", "writing_set"), ("floor", "display_weapon")],
    "stable": [("floor_soft", "rope_coil")],
    "store": [("floor", "sack_closed"), ("floor", "crate_vegetables")],
    "market": [("table", "fruit_basket"), ("floor", "crate_vegetables")],
    "fish": [("floor", "crate_fish"), ("floor_soft", "rope_coil"), ("wall", "herb_bundle")],
    "boat": [("floor_soft", "rope_coil"), ("wall", "oar")],
    "workshop": [("wall", "tool_board"), ("table", "material_ore")],
    "yard": [("wall", "tool_board")],
    "butcher": [("floor", "crate_meat"), ("wall", "tool_board")],
    "embalmer": [("table", "wax_bowl"), ("table", "scroll")],
    "home": [("table", "plate_wood"), ("table", "book_stack"), ("wall", "painting")],
    "shelter": [("floor", "wicker_basket")],
    "garden": [("floor_soft", "fruit_basket")],
}
TRAINER_EXTRAS = {
    "smith": [("floor", "trainer_rug"), ("table", "material_ore"), ("wall", "sconce_iron")],
    "tailor": [("floor", "trainer_rug"), ("table", "yarn"), ("wall", "wall_shelf_filled")],
    "leather": [("floor", "trainer_rug"), ("table", "fur_bundle"), ("wall", "wall_shelf_filled")],
    "jewel": [("floor", "trainer_rug"), ("table", "writing_set"), ("wall", "sconce_iron")],
    "alchemy": [("floor", "trainer_rug"), ("table", "scroll_bundle"), ("wall", "wall_shelf_filled")],
    "carver": [("floor", "trainer_rug"), ("table", "writing_set"), ("wall", "wall_shelf_filled")],
    "kitchen": [("floor", "trainer_rug"), ("table", "plate_ceramic"), ("table", "jug")],
}
PAINTING = {
    "highcourt":"highcourt", "dur_brannoc":"dur_brannoc", "lethariel":"lethariel",
    "gor_drazhak":"gor_drazhak", "kezamba":"kezamba", "nhal_veyr":"nhal_veyr",
    "dawnmere":"still_life", "hearthpine":"charter", "silverleaf":"silverwood",
    "stillgrave":"marsh", "sunscar":"savanna", "kapok":"trade_map",
}

def scope_and_region(item, exported):
    city, context, key = item["id"].split("/", 2)
    rows = {r["id"]: r for r in exported["rows"]}
    if item["cityKind"] == "Startstadt":
        row = rows[city]
        coords = set()
        for cap in row["captures"]:
            if cap["id"] == key:
                coords.update((c["x"], c["y"], c["z"]) for c in cap["cells"])
        return "blueprint", row, coords
    if item["cityKind"] == "Hauptstadt":
        if context == "core":
            row = rows["core"]
            coords = set()
            for cap in row["captures"]:
                if cap["id"] == key:
                    coords.update((c["x"], c["y"], c["z"]) for c in cap["cells"])
            return "core", row, coords
        row = rows[key]
        return key, row, {(c["x"],c["y"],c["z"]) for c in row["cells"]}
    row = rows[city]
    index = int(key.rsplit("_", 1)[1]) - 1
    structure = row["landmarks"]["structures"][index]
    coords = {(c["x"],c["y"],c["z"]) for c in row["cells"]
              if structure["x"]-structure["w"] <= c["x"] <= structure["x"]+structure["w"]
              and structure["z"]-structure["d"] <= c["z"] <= structure["z"]+structure["d"]}
    return "blueprint", row, coords

def reserve(row):
    out=set()
    lm=row.get("landmarks") or {}
    for s in lm.get("sockets") or []:
        x,y,z=s["x"],s["y"],s["z"]
        for dy in (0,1): out.add((x,y+dy,z))
        d=s.get("dir") or {"x":0,"z":0}
        for step in (1,2):
            for dy in (0,1): out.add((x+d["x"]*step,y+dy,z+d["z"]*step))
    a=lm.get("arrival")
    if a:
        for dx in range(-2,3):
            for dz in range(-2,3):
                for dy in (0,1): out.add((a["x"]+dx,a["y"]+dy,a["z"]+dz))
    return out

def author(item, row, region, occupied, enriched=True):
    if item["stance"] == "Bewusst frei lassen" or item.get("isFill"):
        return [], "quiet " + ("fill space" if item.get("isFill") else item["profile"]), None
    recipe = list(RECIPES.get(item["profile"], ()))
    base_count = len(recipe)
    enrichment = None
    sockets = (row.get("landmarks") or {}).get("sockets") or []
    trainers = [s for s in sockets if s.get("role") == "trainer" and
                (s["x"], s["y"], s["z"]) in region]
    if enriched and item["profile"] == "royal":
        faction = "accord" if item["city"] in {
            "highcourt", "dur_brannoc", "lethariel"} else "throng"
        recipe = [("wall", "painting"), ("wall", "painting_charter"),
                  ("wall", "painting_trade_map"), ("wall", "tapestry_" + faction)]
        base_count = 1
        enrichment = "royal wall-only enrichment"
    elif enriched and trainers:
        if item["profile"] not in TRAINER_EXTRAS:
            raise AssertionError(item["id"] + ": trainer profile has no enrichment")
        recipe.extend(TRAINER_EXTRAS.get(item["profile"], ()))
        enrichment = "profession trainer enrichment"
    elif enriched and item["profile"] == "home" and len(region) >= 2500:
        recipe.extend([("table", "mug"), ("wall", "wall_shelf_filled")])
        enrichment = "large house enrichment"
    if item["profile"] == "well":
        has_bench = any("bench" in name for name in item.get("nodeEvidence", {}))
        recipe = [] if has_bench else [("floor", "cottages_bench")]
        if has_bench: return [], "existing well seating", None
    if not recipe:
        return [], "no approved fitting family for " + item["profile"], None
    cells={(c["x"],c["y"],c["z"]):(c["name"],c.get("param2",0)) for c in row["cells"]}
    blocked=reserve(row)
    additions=[]
    tables=[]
    for p,(name,_) in cells.items():
        above=(p[0],p[1]+1,p[2])
        if p in region and name in TABLES and cells.get(above,(None,))[0]=="air" and above not in blocked:
            tables.append((p,above,name))
    tables.sort(key=lambda q:(q[0][2],q[0][1],q[0][0]))
    def add(pos, suffix, face, support_pos, support_name):
        additions.append({"x":pos[0],"y":pos[1],"z":pos[2],"node":"grug_decor:city_"+suffix,
                          "param2":face,"expect":"air","support":support_name,
                          "support_dx":support_pos[0]-pos[0],"support_dy":support_pos[1]-pos[1],
                          "support_dz":support_pos[2]-pos[2]})
        occupied.add(pos)

    def full_wall(name):
        definition=NODE_DEFS.get(name) or {}
        groups=definition.get("groups") or {}
        excluded=("barrel","cauldron","shelf","straw","wool","dirt","litter")
        return (definition.get("drawtype") == "normal" and
                definition.get("walkable") is True and
                (definition.get("selection_box") or {}).get("type") == "regular" and
                not any(word in name for word in excluded) and
                not groups.get("leaves") and not groups.get("tree") and
                not groups.get("flora") and not groups.get("flower"))

    def full_floor(name, param2):
        definition=NODE_DEFS.get(name) or {}
        groups=definition.get("groups") or {}
        excluded=("barrel","cauldron","shelf","fence","plant","flower",
                  "leaves","tree","torch","candle","lantern")
        # Normal drawtype plus the regular selection cube proves a full top
        # face for every param2. Nodeboxes (including every slab and stair)
        # are deliberately outside this authoring seam.
        return (definition.get("drawtype") == "normal" and
                definition.get("walkable") is True and
                (definition.get("selection_box") or {}).get("type") == "regular" and
                not any(word in name for word in excluded) and
                not groups.get("leaves") and not groups.get("tree") and
                not groups.get("flora") and not groups.get("flower"))

    dirs=[(0,1,0),(1,0,1),(0,-1,2),(-1,0,3)] # rear wall delta and facedir
    candidates=[]
    for pos,(name,_) in cells.items():
        if pos not in region or name!="air" or pos in blocked or pos in occupied: continue
        x,y,z=pos
        if y<2 or cells.get((x,y-1,z),(None,))[0]!="air": continue
        # A floor two nodes below makes this an occupied room rather than roof air.
        if cells.get((x,y-2,z),("air",))[0]=="air": continue
        for dx,dz,face in dirs:
            wall=(x+dx,y,z+dz); front=(x-dx,y,z-dz)
            wn=cells.get(wall,("air",))[0]
            if not full_wall(wn): continue
            if cells.get(front,(None,))[0]!="air" or front in blocked: continue
            candidates.append((z,y,x,face,wall,wn,pos));break
    def floor_candidates():
        stand={p for p,(name,_) in cells.items() if p in region and name=="air" and
               cells.get((p[0],p[1]+1,p[2]),("x",))[0]=="air" and
               full_floor(*cells.get((p[0],p[1]-1,p[2]),("air",0))) and
               p not in blocked}
        out=[]
        for p in sorted(stand,key=lambda q:(q[2],q[1],q[0])):
            if p in occupied: continue
            neighbours={(p[0]+dx,p[1],p[2]+dz) for dx,dz in ((1,0),(-1,0),(0,1),(0,-1))}
            neighbours &= stand
            if len(neighbours)<2: continue
            # Removing p must not split its local walkable component.
            seen=set();todo=[next(iter(neighbours))]
            while todo:
                q=todo.pop()
                if q in seen or q==p: continue
                seen.add(q)
                for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
                    n=(q[0]+dx,q[1],q[2]+dz)
                    if n in stand and n not in seen and n!=p: todo.append(n)
            if neighbours <= seen:
                out.append((p,(p[0],p[1]-1,p[2]),cells[(p[0],p[1]-1,p[2])][0]))
        return out

    def spaced(pos):
        return all(max(abs(pos[0]-a["x"]), abs(pos[1]-a["y"]),
                       abs(pos[2]-a["z"])) >= 2 for a in additions)

    table_index=wall_index=floor_index=0
    floors=floor_candidates()
    for recipe_index,(mount,suffix) in enumerate(recipe):
        extra = recipe_index >= base_count
        if suffix=="painting": suffix="painting_"+PAINTING.get(item["city"],"still_life")
        if suffix=="trainer_rug":
            suffix = "rug_blue" if item["city"] in {
                "highcourt", "dur_brannoc", "lethariel"} else "rug_red"
        if mount=="table":
            while table_index<len(tables) and (tables[table_index][1] in occupied or
                    (extra and not spaced(tables[table_index][1]))): table_index+=1
            if table_index<len(tables):
                support,pos,name=tables[table_index];table_index+=1;add(pos,suffix,0,support,name)
        elif mount=="wall":
            while wall_index<len(candidates) and (candidates[wall_index][6] in occupied or
                    (extra and not spaced(candidates[wall_index][6]))): wall_index+=1
            if wall_index<len(candidates):
                _,_,_,face,wall,wn,pos=candidates[wall_index];wall_index+=1;add(pos,suffix,face,wall,wn)
        else:
            while floor_index<len(floors) and (floors[floor_index][0] in occupied or
                    (extra and not spaced(floors[floor_index][0]))): floor_index+=1
            if floor_index<len(floors):
                pos,support,name=floors[floor_index];floor_index+=1;add(pos,suffix,0,support,name)
    if not additions:
        return [], "no safe approved mount", enrichment
    if enriched and item["profile"] == "royal":
        for placement in additions:
            definition = NODE_DEFS.get(placement["node"]) or {}
            if definition.get("walkable") is not False or definition.get("collision_box"):
                raise AssertionError(item["id"] + ": royal decoration has collision")
    return additions, None, enrichment

def lua_string(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'

def main():
    by_city={}
    for item in STUDY["buildings"]: by_city.setdefault(item["city"],[]).append(item)
    catalog={}; report=[]; samples={}
    for city,items in by_city.items():
        exported=json.loads((EVIDENCE/(city+".json")).read_text())
        scopes={}; occupied_by_scope={}; before_occupied_by_scope={}
        for item in items:
            scope,row,region=scope_and_region(item,exported)
            occupied=occupied_by_scope.setdefault(scope,set())
            before_occupied=before_occupied_by_scope.setdefault(scope,set())
            before,_,_=author(item,row,region,before_occupied,False)
            additions,reason,enrichment=author(item,row,region,occupied,True)
            scopes.setdefault(scope,[]).append((item["id"],item["profile"],additions,reason))
            report.append({"id":item["id"],"profile":item["profile"],"scope":scope,
                           "before_additions":len(before), "additions":len(additions),
                           "delta":len(additions)-len(before), "enrichment":enrichment,
                           "reason":reason})
            current=samples.get(item["profile"])
            if current is None or (not current["placements"] and additions):
                samples[item["profile"]]={"id":item["id"],"scope":scope,
                    "placements":additions,"reason":reason}
        catalog[city]=scopes
    enriched_rows = [r for r in report if r["enrichment"]]
    kinds = {kind: [r for r in enriched_rows if r["enrichment"] == kind] for kind in (
        "large house enrichment", "profession trainer enrichment",
        "royal wall-only enrichment")}
    expected = {"large house enrichment": 29, "profession trainer enrichment": 42,
                "royal wall-only enrichment": 6}
    for kind, count in expected.items():
        if len(kinds[kind]) != count or any(r["delta"] < 1 for r in kinds[kind]):
            raise AssertionError(kind + ": enrichment coverage differs")

    lines=["-- Generated by tools/r75_city/author.py from finished Round 75 blueprints.",
           "-- Every surveyed space has one explicit row; runtime performs no room inference.","return {"]
    for city in sorted(catalog):
        lines.append("\t["+lua_string(city)+"] = {")
        for scope in sorted(catalog[city]):
            lines.append("\t\t["+lua_string(scope)+"] = {")
            for ident,profile,adds,reason in catalog[city][scope]:
                lines.append("\t\t\t{id="+lua_string(ident)+", profile="+lua_string(profile)+( ", reason="+lua_string(reason) if reason else "")+", placements={")
                for a in adds:
                    lines.append("\t\t\t\t{x=%d,y=%d,z=%d,node=%s,param2=%d,expect=%s,support=%s,support_dx=%d,support_dy=%d,support_dz=%d}," %
                        (a["x"],a["y"],a["z"],lua_string(a["node"]),a["param2"],lua_string(a["expect"]),lua_string(a["support"]),a["support_dx"],a["support_dy"],a["support_dz"]))
                lines.append("\t\t\t}},")
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    OUT.write_text("\n".join(lines)+"\n")
    (ROOT/"tools/r75_city/report.json").write_text(json.dumps(report,indent=2)+"\n")
    (ROOT/"tools/r75_city/scene_samples.json").write_text(
        json.dumps(samples,indent=2,sort_keys=True)+"\n")
    counts={}
    for r in report: counts[r["reason"] or "decorated"]=counts.get(r["reason"] or "decorated",0)+1
    print(len(report),sum(r["additions"] for r in report),counts)

if __name__ == "__main__": main()
