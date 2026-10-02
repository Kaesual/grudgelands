#!/usr/bin/env python3
"""Round 28 Lane N1: validate the catalogue name proposal and render the
review page.

Reads the shipped catalogue (mods/ENTITIES/grug_mobs/data/{subtypes,items,
drops}.json, mods/ITEMS/grug_professions/data/enchants.json), the zone atlas
(docs/planning/round28/zones/*.json), the base mob and rare names
(docs/planning/round28/mobs/catalogue.json) and the proposal
(docs/planning/round28/mobs/names-proposal.json). Checks the naming rules
written in the proposal's `meta.rules` and writes one self-contained page,
docs/planning/round28/mobs/catalogue-review.html (icons as data URIs).

    python3 tools/r28_names/build_review.py          # check + write page
    python3 tools/r28_names/build_review.py --check  # check only

Exit status 1 when a rule is broken. Python 3 standard library only.
"""
import base64
import glob
import html
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MOB_DATA = REPO / "mods/ENTITIES/grug_mobs/data"
PROF_DATA = REPO / "mods/ITEMS/grug_professions/data"
PLAN = REPO / "docs/planning/round28"
PROPOSAL = PLAN / "mobs/names-proposal.json"
OUT = PLAN / "mobs/catalogue-review.html"

BANDS = [(1, 10), (11, 20), (21, 30), (31, 40), (41, 50), (51, 60)]
TRACKS = ["dwarf", "human", "elf", "undead", "orc", "troll"]
STATS = ["str", "dex", "int", "attack_speed_percent", "crit_percent",
         "max_hp_percent", "max_mana_percent", "dodge_percent", "armor_rating"]
STAT_LABEL = {"str": "Strength", "dex": "Dexterity", "int": "Intellect",
              "attack_speed_percent": "Attack speed %", "crit_percent": "Crit %",
              "max_hp_percent": "Max health %", "max_mana_percent": "Max mana %",
              "dodge_percent": "Dodge %", "armor_rating": "Armor"}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def band_of(level):
    return (level - 1) // 10 + 1


def words(name):
    return name.split()


def tokens(name):
    return [t for t in re.split(r"[\s\-']+", name) if t]


def pretty_id(item_id):
    return item_id.split(":", 1)[1].replace("_", " ").title()


# --- data -------------------------------------------------------------------

class Data:
    def __init__(self):
        self.subtypes = load(MOB_DATA / "subtypes.json")
        self.items = {i["id"]: i for i in load(MOB_DATA / "items.json")}
        self.drops = {d["family"]: d for d in load(MOB_DATA / "drops.json")}
        self.enchants = {e["tier"]: e for e in load(PROF_DATA / "enchants.json")}
        self.proposal = load(PROPOSAL)
        self.roles = {r["role"]: r for r in self.proposal["roles"]}
        self.item_names = {i["id"]: i for i in self.proposal["items"]}
        self.zones = {}
        for f in sorted(glob.glob(str(PLAN / "zones/*.json"))):
            z = load(f)
            self.zones[z["id"]] = z
        cat = load(PLAN / "mobs/catalogue.json")
        self.base_names = {m["display_name"] for m in cat["mobs"]}
        self.rare_names = {r["name"] for r in cat["meta"]["rares"]}
        self.signal = {}
        for kind, ws in self.proposal["signal_words"].items():
            for w in ws:
                self.signal[w.lower()] = kind

    def zone_name(self, zid):
        return self.zones[zid]["name"]

    def is_start_zone(self, zid):
        return self.zones[zid]["role"] == "start zone"

    def is_start_role(self, st):
        p = self.roles[st["role"]]
        return st["levels"][1] <= 10 and all(self.is_start_zone(z) for z in p["zones"])

    def item_name(self, item_id):
        if item_id in self.item_names:
            return self.item_names[item_id]["proposed"]
        return pretty_id(item_id)

    def effective_names(self, role):
        """[(zone or None, current, proposed)] for the default and variants."""
        p = self.roles[role]
        out = [(None, p["current"], p["proposed"])]
        for z, v in (p.get("by_zone") or {}).items():
            out.append((z, v["current"], v["proposed"]))
        return out

    def name_in_zone(self, role, zid):
        p = self.roles[role]
        v = (p.get("by_zone") or {}).get(zid)
        return v["proposed"] if v else p["proposed"]

    def track_zones(self, band, track):
        z = self.zones
        if band == 1:
            return [k for k in z if z[k]["role"] == "start zone" and z[k]["race_track"] == track]
        if band == 2:
            return [k for k in z if z[k]["role"] == "home zone 11-20" and z[k]["race_track"] == track]
        if band == 3:
            return [k for k in z if z[k]["role"] in ("capital zone", "home zone 21-30")
                    and z[k]["race_track"] == track]
        if band == 4:
            return [k for k in z if z[k]["role"].startswith("contested") and z[k]["race_track"] == track] \
                + ["front_broken_causeway"]
        if band == 5:
            return ["front_shattered_line"]
        return ["front_gravesalt_escarpment", "front_skyglass_canopy"]


# --- validation -------------------------------------------------------------

def validate(d):
    errors = []
    data_roles = {s["role"]: s for s in d.subtypes}
    if set(data_roles) != set(d.roles):
        errors.append("proposal roles differ from subtypes.json: %s" %
                      sorted(set(data_roles) ^ set(d.roles)))
    if set(d.items) != set(d.item_names):
        errors.append("proposal items differ from items.json: %s" %
                      sorted(set(d.items) ^ set(d.item_names)))
    ladder = d.proposal["ladder"]["columns"]
    owner = {}  # proposed name -> role

    for st in d.subtypes:
        role = st["role"]
        p = d.roles.get(role)
        if not p:
            continue
        for z in p["zones"]:
            if z not in d.zones:
                errors.append("%s: unknown zone %s" % (role, z))
        if st["display"] not in (p["current"], p["proposed"]):
            errors.append("%s: data display %r is neither current nor proposed" % (role, st["display"]))
        for z, v in (p.get("by_zone") or {}).items():
            have = (st.get("display_by_zone") or {}).get(z)
            if have not in (v["current"], v["proposed"]):
                errors.append("%s/%s: data variant %r is neither current nor proposed" % (role, z, have))
        start = d.is_start_role(st)
        leader = bool(st.get("leader"))
        for z, _, name in d.effective_names(role):
            where = role + ("/" + z if z else "")
            sig = [t for t in tokens(name) if t.lower() in d.signal]
            if not start and sig:
                errors.append("%s: signal word %s outside the start zones (%r)" % (where, sig, name))
            if not leader and len(words(name)) > 3:
                errors.append("%s: %r has more than three words" % (where, name))
            if name in d.base_names:
                errors.append("%s: %r is a base mob's own name" % (where, name))
            for rare in d.rare_names:
                if name == rare or name.startswith(rare + " "):
                    errors.append("%s: %r can be mistaken for the rare %r" % (where, name, rare))
            if owner.setdefault(name, role) != role:
                errors.append("%s: %r is also used by %s" % (where, name, owner[name]))
            if start:
                col = ("outlaw" if st["family"] == "outlaw" else
                       "undead" if st["family"] == "zombie" else
                       "neutral" if st["disposition"] == "neutral" else "beast")
                want = ladder[col].get(str(st["levels"][0]))
                if want is None:
                    errors.append("%s: no ladder rung for %s at L%d" % (where, col, st["levels"][0]))
                elif words(name)[0] != want or len(sig) != 1:
                    errors.append("%s: %r should carry the ladder word %r and no other signal word"
                                  % (where, name, want))

    # Siblings: roles of one family sharing a zone (outside the start band)
    # must differ in more than their first word.
    for zid in d.zones:
        here = [s for s in d.subtypes if s["role"] in d.roles and zid in d.roles[s["role"]]["zones"]
                and not d.is_start_role(s)]
        for i, a in enumerate(here):
            for b in here[i + 1:]:
                if a["family"] != b["family"]:
                    continue
                na, nb = d.name_in_zone(a["role"], zid), d.name_in_zone(b["role"], zid)
                if words(na)[1:] == words(nb)[1:]:
                    errors.append("%s: siblings %r (%s) and %r (%s) differ only in the first word"
                                  % (d.zone_name(zid), na, a["role"], nb, b["role"]))

    item_owner = {}
    mob_names = set(owner)
    for iid, p in d.item_names.items():
        name = p["proposed"]
        tier = d.items.get(iid, {}).get("tier", 1)
        sig = [t for t in tokens(name) if t.lower() in d.signal]
        if sig and tier > 1:
            errors.append("item %s: signal word %s on a T%d item" % (iid, sig, tier))
        if item_owner.setdefault(name, iid) != iid:
            errors.append("item %s: %r is also item %s" % (iid, name, item_owner[name]))
        if name in mob_names:
            errors.append("item %s: %r is also a mob name" % (iid, name))
    return errors


# --- icons and prices ---------------------------------------------------------

class Icons:
    def __init__(self):
        self.files = {}
        for f in glob.glob(str(REPO / "mods/*/*/textures/*.png")):
            self.files.setdefault(Path(f).name, f)
        self.lua = {}
        for f in glob.glob(str(REPO / "mods/*/*/*.lua")):
            self.lua[f] = Path(f).read_text(encoding="utf-8", errors="replace")
        self.cache = {}

    def _registration(self, item_id):
        mod, name = item_id.split(":", 1)
        image, price = None, None
        reg = re.compile(r'register_craftitem\(\s*":?' + re.escape(item_id) + r'"\s*,\s*\{(.*?)\n\}\)', re.S)
        mat = re.compile(r'material\(\s*"' + re.escape(name) + r'"\s*,\s*"[^"]*"\s*,\s*(\d+)')
        for path, text in self.lua.items():
            m = reg.search(text)
            if m:
                im = re.search(r'inventory_image\s*=\s*"([^"^]+)', m.group(1))
                pr = re.search(r'_grug_sell_price\s*=\s*(\d+)', m.group(1))
                image = im.group(1) if im else image
                price = int(pr.group(1)) if pr else price
                break
            if mod == "grug_mobs" and path.endswith("grug_mobs/items.lua"):
                m = mat.search(text)
                if m:
                    return "grug_mobs_item_%s.png" % name, int(m.group(1))
        return image, price

    def lookup(self, d, item_id):
        """(data URI or None, price in copper or None)."""
        if item_id in self.cache:
            return self.cache[item_id]
        row = d.items.get(item_id)
        existing = row is not None and "Existing" in (row.get("notes") or "")
        if row is not None and not existing:
            image = item_id.replace(":", "_") + ".png"
            price = row["tier"] if row["kind"] == "signature" else None
        else:
            image, price = self._registration(item_id)
            if image is None:
                guess = item_id.replace(":", "_") + ".png"
                image = guess if guess in self.files else None
        uri = None
        if image and image in self.files:
            uri = "data:image/png;base64," + base64.b64encode(Path(self.files[image]).read_bytes()).decode()
        self.cache[item_id] = (uri, price)
        return self.cache[item_id]


# --- page ---------------------------------------------------------------------

def esc(s):
    return html.escape(str(s), quote=True)


def icon_html(uri, label):
    if not uri:
        return '<span class="ico ico-none" title="no icon"></span>'
    return '<img class="ico" src="%s" alt="%s" width="32" height="32">' % (uri, esc(label))


def name_html(cur, prop, reason):
    if cur == prop:
        return '<span class="nm">%s</span>' % esc(prop)
    out = '<span class="old">%s</span> <span class="arrow">&rarr;</span> <span class="nm new">%s</span>' % (
        esc(cur), esc(prop))
    if reason:
        out += '<div class="why">%s</div>' % esc(reason)
    return out


def drop_rows(d, family, band):
    fam = d.drops.get(family)
    return (fam or {}).get("bands", {}).get(str(band), []) if fam else []


def drop_text(d, row):
    qty = ""
    lo, hi = row.get("min", 1), row.get("max", 1)
    if hi > 1:
        qty = " &times;%d&ndash;%d" % (lo, hi) if lo != hi else " &times;%d" % lo
    chance = "always" if row["chance"] == 1 else "1/%d" % row["chance"]
    return '<span class="drop">%s%s <em>%s</em></span>' % (esc(d.item_name(row["item"])), qty, chance)


def signature_of(d, family, band):
    for row in drop_rows(d, family, band):
        it = d.items.get(row["item"])
        if it and it["kind"] == "signature":
            return row["item"]
    return None


def droppers(d, item_id):
    """Sub-type names (proposed default) whose band drops include the item."""
    out = []
    for st in d.subtypes:
        if st.get("leader"):
            continue
        lo, hi = st["levels"]
        for b in range(band_of(lo), band_of(hi) + 1):
            if any(r["item"] == item_id for r in drop_rows(d, st["drops"], b)):
                out.append(d.roles[st["role"]]["proposed"])
                break
    return out


def zone_list(d, zids):
    return ", ".join(esc(d.zone_name(z)) for z in zids)


def subtype_row(d, icons, st, band):
    p = d.roles[st["role"]]
    changed = p["current"] != p["proposed"] or any(
        v["current"] != v["proposed"] for v in (p.get("by_zone") or {}).values())
    sig = signature_of(d, st["drops"], band)
    uri = icons.lookup(d, sig)[0] if sig else None
    name = name_html(p["current"], p["proposed"], p.get("reason"))
    for z, v in (p.get("by_zone") or {}).items():
        name += '<div class="var"><span class="vz">%s:</span> %s</div>' % (
            esc(d.zone_name(z)), name_html(v["current"], v["proposed"], v.get("reason")))
    lo, hi = st["levels"]
    drops = " ".join(drop_text(d, r) for r in drop_rows(d, st["drops"], band)) or "&mdash;"
    disp = st["disposition"]
    return ('<tr data-changed="%d"><td>%s</td><td class="name">%s<div class="id">%s</div></td>'
            '<td>%s</td><td class="num">%s</td><td><span class="tag tag-%s">%s</span></td>'
            '<td>%s</td><td class="num">%s</td><td class="zones">%s</td><td class="drops">%s</td></tr>') % (
        1 if changed else 0, icon_html(uri, d.item_name(sig) if sig else ""), name, esc(st["role"]),
        esc(st["base"].split(":")[1].replace("_", " ")), "%d&ndash;%d" % (lo, hi) if lo != hi else lo,
        esc(disp), esc(disp), esc(st["tier"]), esc(st["size"]), zone_list(d, p["zones"]), drops)


def band_section(d, icons, bi):
    lo, hi = BANDS[bi - 1]
    subs = [s for s in d.subtypes if not s.get("leader")
            and band_of(s["levels"][0]) <= bi <= band_of(s["levels"][1])]
    subs.sort(key=lambda s: (s["family"], s["levels"][0], s["role"]))
    leaders = [s for s in d.subtypes if s.get("leader") and band_of(s["levels"][0]) == bi]
    leaders.sort(key=lambda s: (s["levels"][0], s["role"]))
    items = [i for i in d.items.values() if i["tier"] == bi and "Existing" not in (i.get("notes") or "")]
    items.sort(key=lambda i: (i.get("family") or "", i["id"]))
    n_changed = sum(1 for s in subs + leaders if d.roles[s["role"]]["current"] != d.roles[s["role"]]["proposed"])
    h = ['<section class="band" id="band%d"><h2>Levels %d&ndash;%d <span class="sub">Tier %d &middot; %d sub-types &middot; '
         '%d leaders &middot; %d new items &middot; %d names change</span></h2>' % (
             bi, lo, hi, bi, len(subs), len(leaders), len(items), n_changed)]
    h.append('<h3>Sub-types</h3><div class="scroll"><table class="subs"><thead><tr><th></th><th>Name</th>'
             '<th>Base</th><th>Levels</th><th>Disposition</th><th>Tier</th><th>Size</th><th>Zones</th>'
             '<th>Drops in this band</th></tr></thead><tbody>')
    h.extend(subtype_row(d, icons, s, bi) for s in subs)
    h.append('</tbody></table></div>')
    if leaders:
        h.append('<h3>Named leaders</h3><div class="scroll"><table class="leaders"><thead><tr><th>Name</th>'
                 '<th>Zone</th><th>Level</th><th>Tier</th><th>Base</th></tr></thead><tbody>')
        for s in leaders:
            p = d.roles[s["role"]]
            h.append('<tr data-changed="%d"><td class="name">%s<div class="id">%s</div></td><td>%s</td>'
                     '<td class="num">%d</td><td>%s</td><td>%s</td></tr>' % (
                         1 if p["current"] != p["proposed"] else 0, name_html(p["current"], p["proposed"], p.get("reason")),
                         esc(s["role"]), zone_list(d, p["zones"]), s["levels"][0], esc(s["tier"]),
                         esc(s["base"].split(":")[1].replace("_", " "))))
        h.append('</tbody></table></div>')
    if items:
        h.append('<h3>New items</h3><div class="scroll"><table class="items"><thead><tr><th></th><th>Name</th>'
                 '<th>Kind</th><th>Family</th><th>Price</th><th>Dropped by</th></tr></thead><tbody>')
        for i in items:
            p = d.item_names[i["id"]]
            uri, price = icons.lookup(d, i["id"])
            h.append('<tr data-changed="%d"><td>%s</td><td class="name">%s<div class="desc">%s</div></td><td>%s</td>'
                     '<td>%s</td><td class="num">%s</td><td class="zones">%s</td></tr>' % (
                         1 if p["current"] != p["proposed"] else 0, icon_html(uri, p["proposed"]),
                         name_html(p["current"], p["proposed"], p.get("reason")), esc(i.get("description", "")),
                         esc(i["kind"]), esc(i.get("family", "")), "%d c" % price if price else "&mdash;",
                         ", ".join(esc(n) for n in droppers(d, i["id"])) or "&mdash;"))
        h.append('</tbody></table></div>')
    h.append(stat_section(d, icons, bi))
    h.append('</section>')
    return "".join(h)


def stat_section(d, icons, bi):
    ench = d.enchants.get(bi)
    if not ench:
        return ""
    lo, hi = BANDS[bi - 1]
    track_zones = {t: d.track_zones(bi, t) for t in TRACKS}
    h = ['<h3>Stat loot (Tier %d enchant inputs)</h3><div class="scroll"><table class="stat"><thead><tr>'
         '<th>Stat</th><th>Input</th><th>Drops from</th>%s</tr></thead><tbody>' % (
             bi, "".join('<th class="trk">%s</th>' % t.title() for t in TRACKS))]
    missing = 0
    for stat in STATS:
        iid = ench["stat_loot"].get(stat)
        if not iid:
            continue
        fams = sorted(f for f, fam in d.drops.items()
                      if any(r["item"] == iid for r in fam.get("bands", {}).get(str(bi), [])))
        sources = [s for s in d.subtypes if s["drops"] in fams and not s.get("leader")
                   and s["levels"][0] <= hi and s["levels"][1] >= lo]
        cells = []
        for t in TRACKS:
            hit = [s for s in sources if set(d.roles[s["role"]]["zones"]) & set(track_zones[t])]
            if hit:
                cells.append('<td class="ok" title="%s">&#10003;</td>' % esc(", ".join(
                    sorted({d.roles[s["role"]]["proposed"] for s in hit}))))
            else:
                missing += 1
                cells.append('<td class="miss">&ndash;</td>')
        uri = icons.lookup(d, iid)[0]
        h.append('<tr><td>%s</td><td class="name">%s %s</td><td>%s</td>%s</tr>' % (
            esc(STAT_LABEL[stat]), icon_html(uri, d.item_name(iid)), esc(d.item_name(iid)),
            esc(", ".join(fams)), "".join(cells)))
    h.append('</tbody></table></div>')
    h.append('<p class="note">A tick means a sub-type of that drop family lives at this band&rsquo;s levels in '
             'the track&rsquo;s zones for the band (%s). Hover a tick for the mobs.%s</p>' % (
                 {1: "start zone", 2: "home zone", 3: "own capital and heartlands",
                  4: "own contested zone and The Broken Causeway", 5: "The Shattered Line",
                  6: "Gravesalt Escarpment and The Skyglass Canopy"}[bi],
                 "" if not missing else " <strong>%d gaps.</strong>" % missing))
    fi = ench.get("family_input", {})
    if fi:
        h.append('<p class="fi"><span class="lbl">Family inputs (mining, gathering):</span> %s</p>' % " &middot; ".join(
            "%s <b>%s</b>" % (esc(k.replace("_", " ")), esc(d.item_name(v))) for k, v in fi.items()))
    return "".join(h)


CSS = """
:root{--bg:#f3f5f2;--panel:#ffffff;--ink:#1d2621;--muted:#5d6b63;--line:#d6ddd8;--accent:#3c6e57;
--chg:#fdf0c9;--chg-ink:#7a5200;--old:#8a948e;--neu:#e9c43b;--agg:#d2463a;--crit:#e9ece9;--ok:#2f7a4f;--miss:#b23a2e;
--bar:rgba(243,245,242,.94)}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#161b18;--panel:#1e2521;--ink:#e3e9e5;
--muted:#9aa8a0;--line:#2f3a34;--accent:#7fbf9d;--chg:#3d3417;--chg-ink:#f2d27a;--old:#76817b;--crit:#3a423d;
--ok:#7fd3a0;--miss:#ff8a7d;--bar:rgba(22,27,24,.94);color-scheme:dark}}
:root[data-theme="dark"]{--bg:#161b18;--panel:#1e2521;--ink:#e3e9e5;--muted:#9aa8a0;--line:#2f3a34;--accent:#7fbf9d;
--chg:#3d3417;--chg-ink:#f2d27a;--old:#76817b;--crit:#3a423d;--ok:#7fd3a0;--miss:#ff8a7d;--bar:rgba(22,27,24,.94);
color-scheme:dark}
body{background:var(--bg);color:var(--ink);font:14px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
padding-inline:16px;padding-block:0 48px}
.wrap{max-width:1180px;margin:0 auto}
h1{font-size:1.6rem;margin:24px 0 4px;text-wrap:balance}
h2{font-size:1.25rem;margin:0 0 8px;text-wrap:balance}
h2 .sub{display:block;font-size:.8rem;font-weight:500;color:var(--muted)}
h3{font-size:.78rem;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:20px 0 6px}
p{max-width:72ch}
.lede{color:var(--muted);margin:0 0 16px}
.bar{position:sticky;top:env(safe-area-inset-top,0px);z-index:5;background:var(--bar);backdrop-filter:blur(6px);
border-bottom:1px solid var(--line);display:flex;flex-wrap:wrap;gap:6px 14px;align-items:center;padding-block:8px;
margin-inline:-16px;padding-inline:16px}
.bar a{color:var(--accent);text-decoration:none;font-weight:600;font-variant-numeric:tabular-nums}
.bar a:hover,.bar a:focus-visible{text-decoration:underline}
.bar label{margin-left:auto;display:flex;gap:6px;align-items:center;cursor:pointer}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:8px;margin:16px 0}
.fact{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:8px 10px}
.fact b{display:block;font-size:1.3rem;font-variant-numeric:tabular-nums}
.fact span{color:var(--muted);font-size:.8rem}
.rules{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px;margin:8px 0 16px}
.rules div{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:10px 12px}
.rules h4{margin:0 0 4px;font-size:.9rem}
.rules p{margin:0;color:var(--muted)}
.words{display:flex;flex-wrap:wrap;gap:4px 6px;margin:4px 0 0;padding:0;list-style:none}
.words li{background:var(--panel);border:1px solid var(--line);border-radius:4px;padding:0 6px;font-size:.85rem}
.words li.lad{border-color:var(--accent);color:var(--accent);font-weight:600}
.words li.ret{text-decoration:line-through;color:var(--old)}
.band{margin-top:32px;scroll-margin-top:56px}
.scroll{overflow-x:auto;background:var(--panel);border:1px solid var(--line);border-radius:6px}
table{border-collapse:collapse;width:100%;font-size:.86rem}
th{text-align:left;font-weight:600;font-size:.75rem;color:var(--muted);padding:6px 8px;border-bottom:1px solid var(--line);
white-space:nowrap}
td{padding:6px 8px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
td.num{font-variant-numeric:tabular-nums;white-space:nowrap}
td.name{min-width:200px}
td.zones{min-width:160px;color:var(--muted)}
td.drops{min-width:220px}
.ico{width:32px;height:32px;image-rendering:pixelated;display:block}
.ico-none{width:32px;height:32px;display:block;border:1px dashed var(--line);border-radius:4px}
td.name .ico{display:inline-block;vertical-align:middle;width:24px;height:24px}
.nm{font-weight:600}
.nm.new{background:var(--chg);color:var(--chg-ink);padding:0 4px;border-radius:3px}
.old{color:var(--old);text-decoration:line-through}
.arrow{color:var(--muted)}
.why{color:var(--muted);font-size:.78rem;margin-top:2px}
.var{font-size:.82rem;margin-top:3px}
.vz{color:var(--muted)}
.id{color:var(--muted);font:11px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace}
.desc{color:var(--muted);font-size:.78rem}
.tag{display:inline-block;padding:0 6px;border-radius:3px;font-size:.78rem;font-weight:600;color:#1d1d1d}
.tag-neutral{background:var(--neu)}.tag-aggressive{background:var(--agg);color:#fff}.tag-critter{background:var(--crit);color:var(--ink)}
.drop{display:inline-block;margin-right:8px;white-space:nowrap}
.drop em{color:var(--muted);font-style:normal;font-variant-numeric:tabular-nums}
td.ok{color:var(--ok);font-weight:700;text-align:center}
td.miss{color:var(--miss);font-weight:700;text-align:center}
th.trk{text-align:center}
.note,.fi{color:var(--muted);font-size:.82rem;margin:6px 0}
.fi .lbl{font-weight:600}
.checks{padding:8px 12px;border-radius:6px;border:1px solid var(--line);background:var(--panel)}
.checks.bad{border-color:var(--miss)}
body.only-changed tr[data-changed="0"]{display:none}
a:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
"""

JS = """
(function(){var cb=document.getElementById('only-changed');function apply(){document.body.classList.toggle('only-changed',cb.checked);
try{localStorage.setItem('n1-only-changed',cb.checked?'1':'0')}catch(e){}}
try{cb.checked=localStorage.getItem('n1-only-changed')==='1'}catch(e){}cb.addEventListener('change',apply);apply();})();
"""


def header(d, errors):
    p = d.proposal
    roles = p["roles"]
    leaders = [s for s in d.subtypes if s.get("leader")]
    ch_roles = sum(1 for r in roles if r["current"] != r["proposed"])
    ch_vars = sum(1 for r in roles for v in (r.get("by_zone") or {}).values() if v["current"] != v["proposed"])
    ch_items = sum(1 for i in p["items"] if i["current"] != i["proposed"])
    new_items = sum(1 for i in d.items.values() if "Existing" not in (i.get("notes") or ""))
    facts = [(len(d.subtypes), "sub-types"), (len(leaders), "named leaders"), (len(d.items), "catalogue items"),
             (new_items, "new items with icons"), (ch_roles, "role names change"),
             (ch_vars, "zone variants change"), (ch_items, "item names change")]
    ladder = p["ladder"]["columns"]
    lad_words = {w for col in ladder.values() for w in col.values()}
    h = ['<h1>Catalogue Name Review</h1>',
         '<p class="lede">Round 28 mob sub-types, leaders and loot as shipped. The name pass was approved on '
         '2026-10-02 and is applied; struck-through names are the names before it. '
         'Role and item ids never change; only display names. Generated by tools/r28_names/build_review.py '
         'from the game data and docs/planning/round28/mobs/names-proposal.json.</p>',
         '<div class="facts">%s</div>' % "".join(
             '<div class="fact"><b>%d</b><span>%s</span></div>' % (n, esc(t)) for n, t in facts)]
    h.append('<div class="rules">'
             '<div><h4>Signal words only in start zones</h4><p>Words for size, age, strength or temper teach the '
             'mechanic in the six start zones (levels 1&ndash;10) and appear nowhere else. There they form one '
             'ladder, the same in all six starts.</p></div>'
             '<div><h4>Unique names everywhere else</h4><p>Each name belongs to one role, is at most three words and '
             'describes the creature in its place. Siblings that share a zone differ in more than one adjective.</p></div>'
             '<div><h4>Kill quests name the exact sub-type</h4><p>A quest names one sub-type and its place, so every '
             'name has to be unmistakable on its own. Disposition is shown by the yellow or red name tag.</p></div>'
             '<div><h4>Named leaders keep &ldquo;Title Name&rdquo;</h4><p>Start-zone chiefs carry the ladder word '
             '&ldquo;Confused&rdquo;, like Confused Bandit Chief Crumb. Leaders elsewhere follow the no-signal-word '
             'rule.</p></div></div>')
    h.append('<h3>Start-zone ladder</h3><div class="scroll"><table class="stat"><thead><tr><th>Column</th>'
             '<th>L1&ndash;3</th><th>L3&ndash;5</th><th>L5&ndash;7</th><th>L7&ndash;9</th><th>L9&ndash;10</th>'
             '</tr></thead><tbody>')
    for col, label in (("neutral", "Neutral animals (yellow)"), ("beast", "Hostile animals (red)"),
                       ("undead", "Zombies and husks"), ("outlaw", "Bandits, poachers, chiefs")):
        cells = []
        for rung, alt in (("1", None), ("3", None), ("5", None), ("7", None), ("9", "10")):
            w = ladder[col].get(rung) or (ladder[col].get(alt) if alt else None)
            cells.append("<td>%s</td>" % (esc(w) if w else "&mdash;"))
        h.append("<tr><td>%s</td>%s</tr>" % (esc(label), "".join(cells)))
    h.append('</tbody></table></div>')
    h.append('<h3>Signal words found in the data</h3><p class="note">Framed in green: ladder words kept for the start zones. '
             'Struck through: retired everywhere.</p>')
    for kind, ws in p["signal_words"].items():
        h.append('<p class="fi"><span class="lbl">%s:</span></p><ul class="words">%s</ul>' % (
            esc(kind.title()), "".join('<li class="%s">%s</li>' % (
                "lad" if w in lad_words else "ret", esc(w)) for w in ws)))
    h.append('<p class="note">Checked and kept (place, look, lore or activity): %s.</p>' % esc(
        ", ".join(p["not_signal"]["words"])))
    if errors:
        h.append('<div class="checks bad"><b>%d rule violations</b><ul>%s</ul></div>' % (
            len(errors), "".join("<li>%s</li>" % esc(e) for e in errors)))
    else:
        h.append('<div class="checks">Checks pass: no signal word outside the start zones, start names follow the '
                 'ladder, no name used by two roles or taken from a base mob or rare, at most three words '
                 '(leaders excepted), siblings in a zone differ in more than their first word, item names '
                 'unique.</div>')
    return "".join(h)


def render(d, errors):
    icons = Icons()
    nav = "".join('<a href="#band%d">%d&ndash;%d</a>' % (i, lo, hi) for i, (lo, hi) in enumerate(BANDS, 1))
    body = ['<title>Catalogue Name Review</title>', '<style>%s</style>' % CSS, '<div class="wrap">',
            header(d, errors),
            '<nav class="bar" aria-label="Level bands">%s<label for="only-changed"><input type="checkbox" '
            'id="only-changed"> Only changed names</label></nav>' % nav]
    body.extend(band_section(d, icons, i) for i in range(1, len(BANDS) + 1))
    body.append('</div><script>%s</script>' % JS)
    return "\n".join(body) + "\n"


def main(argv):
    d = Data()
    errors = validate(d)
    for e in errors:
        print("RULE:", e)
    roles = d.proposal["roles"]
    print("roles %d, renamed %d; zone variants renamed %d; items renamed %d; violations %d" % (
        len(roles), sum(1 for r in roles if r["current"] != r["proposed"]),
        sum(1 for r in roles for v in (r.get("by_zone") or {}).values() if v["current"] != v["proposed"]),
        sum(1 for i in d.proposal["items"] if i["current"] != i["proposed"]), len(errors)))
    if "--check" not in argv:
        OUT.write_text(render(d, errors), encoding="utf-8")
        print("wrote", OUT.relative_to(REPO), "(%d bytes)" % OUT.stat().st_size)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
