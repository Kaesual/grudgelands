(function () {
  "use strict";
  var D = JSON.parse(document.getElementById("names-data").textContent);
  var app = document.getElementById("app");
  var TIERS = ["T1", "T2", "T3", "T4", "T5", "T6"];
  var HAB_LETTER = {shore: "S", belt: "B", freshwater: "L", channel: "C", bay_deep: "D", open_sea: "O", cave_water: "W"};
  var VERDICTS = [["pick", "Pick"], ["rework", "Rework"], ["drop", "Drop"]];
  var TAB_KEY = "r51-names-tab";
  var ZONE_KEY = "r51-names-zone";

  // ---- small helpers -------------------------------------------------------
  function el(tag, attrs, kids) {
    var e = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        var v = attrs[k];
        if (v === null || v === undefined || v === false) return;
        if (k === "text") e.textContent = v;
        else if (k === "cls") e.className = v;
        else if (k.slice(0, 2) === "on") e.addEventListener(k.slice(2), v);
        else e.setAttribute(k, v === true ? "" : v);
      });
    }
    (kids || []).forEach(function (c) {
      if (c === null || c === undefined || c === false) return;
      e.appendChild(typeof c === "string" ? document.createTextNode(c) : c);
    });
    return e;
  }
  function from(text) { return el("p", {cls: "from", text: "from " + text}); }
  function tierOf(level) { return Math.max(1, Math.min(6, Math.floor((level - 1) / 10) + 1)); }
  function band(lv) { return lv[0] === lv[1] ? "L" + lv[0] : "L" + lv[0] + "-" + lv[1]; }
  function habChip(h) {
    var label = D.habitats[h] ? D.habitats[h].label : h;
    return el("span", {cls: "hab " + h, title: label, "aria-label": label, text: HAB_LETTER[h] || "?"});
  }
  function store(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* per-viewer convenience only */ } }
  function recall(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  var zoneById = {};
  D.zones.forEach(function (z) { zoneById[z.id] = z; });
  var famById = {};
  D.families.forEach(function (f) { famById[f.id] = f; });
  function seedList() {
    return D.seeds.map(function (s, i) { return i === 0 ? s + " (production)" : s; }).join(", ");
  }

  // ---- notes (the db capability) -------------------------------------------
  // Collection `notes`, one document per element key; the document id is the
  // key with every "/" written as "~" (the store allows letters, digits and
  // _ - . ~ : @ + in ids; our keys use only letters, digits, _ . - and /).
  var notes = {};          // key -> {verdict, text, updatedAt}
  var widgets = {};        // key -> [judge records]
  var written = {};        // key -> {verdict, text} last known in the store
  var wanted = {};         // key -> {verdict, text} the viewer's latest
  var busy = {};
  var db = null;
  var mode = "wait";       // wait | live | readonly
  var modeText = "Connecting the notes…";
  function docId(key) { return key.replace(/\//g, "~"); }
  function keyOf(id) { return id.replace(/~/g, "/"); }

  function setMode(m, text) {
    mode = m;
    modeText = text;
    var line = document.getElementById("notes-status");
    if (line) {
      line.textContent = text;
      line.className = "status-line" + (m === "readonly" ? " bad" : "");
    }
    Object.keys(widgets).forEach(function (k) { widgets[k].forEach(refreshWidget); });
  }

  function errText(e) {
    var code = e && e.code ? e.code : "unavailable";
    var msg = {
      invalid_argument: "the store refused this note (invalid_argument)",
      resource_exhausted: "too many saves at once; wait a moment and change the note again",
      quota_exceeded: "the notes store is full" + (e && e.message ? " (" + e.message + ")" : ""),
      unavailable: "the notes store did not answer; change the note again in a moment",
      revoked: "access to the notes ended for this visit",
      not_granted: "this view cannot save notes",
      capability_disabled: "this view cannot save notes",
      capability_removed: "this view cannot save notes",
      transform_error: "the note could not be prepared (transform_error)"
    }[code];
    return msg || ("the save failed (" + code + ")");
  }
  var FATAL = {invalid_argument: 1, revoked: 1, not_granted: 1, capability_disabled: 1, capability_removed: 1, transform_error: 1};

  function same(a, b) { return (a.verdict || "") === (b.verdict || "") && (a.text || "") === (b.text || ""); }

  function writeOnce(key, want) {
    var ref = db.collection("notes").doc(docId(key));
    if (!want.text.trim() && !want.verdict) return ref.delete();
    return ref.set({key: key, verdict: want.verdict, text: want.text, updatedAt: new Date().toISOString()});
  }

  function flush(key) {
    if (busy[key] || mode !== "live") return;
    var want = wanted[key];
    var have = written[key] || {verdict: "", text: ""};
    if (!want || same(want, have)) return;
    busy[key] = true;
    var snapshot = {verdict: want.verdict, text: want.text};
    setStatus(key, "Saving…", false);
    var attempt = function (retry) {
      return writeOnce(key, snapshot).catch(function (e) {
        if (retry && e && e.code === "unavailable") {
          return new Promise(function (res) { setTimeout(res, 300 + Math.random() * 700); })
            .then(function () { return attempt(false); });
        }
        throw e;
      });
    };
    attempt(true).then(function () {
      written[key] = snapshot;
      busy[key] = false;
      setStatus(key, "Saved", false);
      flush(key);
    }, function (e) {
      busy[key] = false;
      setStatus(key, "Not saved: " + errText(e), true);
      if (e && FATAL[e.code]) {
        setMode("readonly", "Notes are read-only in this view (" + errText(e) + "). Notes can be left on the published page.");
      }
    });
  }

  function save(key, verdict, text) {
    var want = {verdict: verdict, text: text};
    wanted[key] = want;
    var cur = written[key] || {verdict: "", text: ""};
    if (same(want, cur)) return;
    flush(key);
  }

  function setStatus(key, text, isErr) {
    (widgets[key] || []).forEach(function (w) {
      w.st.textContent = text;
      w.st.className = "st" + (isErr ? " err" : "");
    });
  }

  function refreshWidget(w) {
    var n = notes[w.key] || {verdict: "", text: ""};
    var editable = mode === "live";
    var verdict = wanted[w.key] && busy[w.key] ? wanted[w.key].verdict : n.verdict;
    w.buttons.forEach(function (b) {
      b.setAttribute("aria-pressed", b.getAttribute("data-v") === verdict ? "true" : "false");
      b.disabled = !editable;
    });
    if (document.activeElement !== w.ta && !busy[w.key]) w.ta.value = n.text || "";
    w.ta.disabled = !editable;
    if (w.toggle) w.toggle.className = "note-toggle" + ((n.text || n.verdict) ? " has" : "");
    if (w.toggle && (n.text || n.verdict)) w.toggle.textContent = n.verdict ? "Note: " + n.verdict : "Note ✓";
  }

  function pressed(rec) {
    var v = "";
    rec.buttons.forEach(function (b) { if (b.getAttribute("aria-pressed") === "true") v = b.getAttribute("data-v"); });
    return v;
  }

  // A verdict and a note for one element; `compact` hides it behind a button.
  // `where` keeps the control ids unique when one key shows in two views.
  function judge(key, compact, where) {
    var sfx = where ? "@" + where : "";
    var st = el("span", {cls: "st", "aria-live": "polite"});
    var ta = el("textarea", {id: "t:" + key + sfx, rows: 2, placeholder: "Note for " + key + "…",
      "aria-label": "Note for " + key});
    var buttons = VERDICTS.map(function (v) {
      return el("button", {type: "button", id: "v:" + key + ":" + v[0] + sfx, "data-v": v[0], "aria-pressed": "false",
        text: v[1]});
    });
    var rec = {key: key, ta: ta, buttons: buttons, st: st, toggle: null};
    buttons.forEach(function (b) {
      b.addEventListener("click", function () {
        var v = b.getAttribute("data-v");
        var next = pressed(rec) === v ? "" : v;
        (widgets[key] || []).forEach(function (w) {
          w.buttons.forEach(function (x) { x.setAttribute("aria-pressed", x.getAttribute("data-v") === next ? "true" : "false"); });
        });
        save(key, next, ta.value);
      });
    });
    ta.addEventListener("blur", function () { save(key, pressed(rec), ta.value); });
    var body = el("div", {cls: "judge" + (compact ? " compact" : "")}, [
      el("div", {cls: "row"}, [
        el("span", {cls: "verdicts", role: "group", "aria-label": "Verdict for " + key}, buttons),
        el("span", {cls: "key", text: key}), st
      ]),
      ta
    ]);
    (widgets[key] = widgets[key] || []).push(rec);
    if (!compact) { refreshWidget(rec); return body; }
    body.hidden = true;
    var toggle = el("button", {type: "button", cls: "note-toggle", id: "n:" + key + sfx, "aria-expanded": "false",
      text: "Note"});
    toggle.addEventListener("click", function () {
      body.hidden = !body.hidden;
      toggle.setAttribute("aria-expanded", body.hidden ? "false" : "true");
      if (!body.hidden && mode === "live") ta.focus();
    });
    rec.toggle = toggle;
    refreshWidget(rec);
    return el("div", null, [toggle, body]);
  }

  function onNotes(snap) {
    var next = {};
    snap.docs.forEach(function (doc) {
      var d = doc.data() || {};
      var key = typeof d.key === "string" ? d.key : keyOf(doc.id);
      next[key] = {verdict: typeof d.verdict === "string" ? d.verdict : "",
        text: typeof d.text === "string" ? d.text : "",
        updatedAt: typeof d.updatedAt === "string" ? d.updatedAt : ""};
    });
    notes = next;
    Object.keys(notes).forEach(function (k) { if (!busy[k]) written[k] = {verdict: notes[k].verdict, text: notes[k].text}; });
    Object.keys(written).forEach(function (k) { if (!notes[k] && !busy[k]) written[k] = {verdict: "", text: ""}; });
    Object.keys(widgets).forEach(function (k) { widgets[k].forEach(refreshWidget); });
    renderNotesList();
  }

  function connect() {
    var c = window.claude;
    if (!c || typeof c.use !== "function") {
      setMode("readonly", "Opened outside the published page: notes are read-only here. Notes can be left on the published page.");
      return;
    }
    Promise.resolve().then(function () { return c.use("db"); }).then(function (ns) {
      if (!ns) {
        setMode("readonly", "Notes are read-only in this view. Notes can be left on the published page.");
        return;
      }
      db = ns;
      setMode("live", "Notes are saved for the coordinator: a verdict saves on click, a note when you leave its box.");
      db.collection("notes").onSnapshot(onNotes, function (e) {
        setMode("readonly", "The notes stopped loading (" + errText(e) + "). Reload the page; notes can be left on the published page.");
      });
    }, function (e) {
      setMode("readonly", "Notes are read-only in this view (" + errText(e) + "). Notes can be left on the published page.");
    });
  }

  // ---- views ---------------------------------------------------------------
  function header() {
    var c = D.counts;
    var g = D.gates;
    return el("div", null, [
      el("h1", {text: "Water mob families and names"}),
      el("p", {cls: "lead", text: "Round 51 draft for the sea and the lakes: which water families live where, " +
        "their level ladders per zone and a name for every slot. Water is a complement, not a second land (S18): " +
        "few families, each at its zone's level. Give each family and each name a verdict and a note; " +
        "the MOBS lane builds what you accept."}),
      el("ul", {cls: "counts"}, [
        el("li", null, [el("b", {text: String(c.families_new)}), " new families"]),
        el("li", null, [el("b", {text: String(c.families_kept)}), " kept as they are"]),
        el("li", null, [el("b", {text: String(c.left_out)}), " candidates left out"]),
        el("li", null, [el("b", {text: String(c.new_names)}), " new names"]),
        el("li", null, [el("b", {text: String(c.new_slots)}), " new zone slots"]),
        el("li", null, [el("b", {text: String(c.new_world)}), " new world slots"]),
        el("li", null, [el("b", {text: String(c.subtypes)}), " new sub-types"])
      ]),
      el("p", {cls: "from", text: "from tools/r51_names/draft.json (built by tools/r51_names/build.py from design.json and the water survey); land for comparison: " +
        c.land_families + " sub-type families, " + c.land_subtypes + " sub-types (" + D.sources.subtypes + ")"}),
      el("p", null, [el("span", {cls: g.ok ? "gate-ok" : "gate-bad", text: "Name gates: "}), g.summary]),
      el("p", {cls: "from", text: "from tools/r51_names/check_draft.py: tools/r38_names/check_rules.py and guarantee.py over today's names plus the draft"}),
      el("div", {id: "notes-status", cls: "status-line", role: "status", text: modeText})
    ]);
  }

  function legend() {
    return el("div", {cls: "legend"}, Object.keys(D.habitats).map(function (h) {
      return el("span", null, [habChip(h), " " + D.habitats[h].label]);
    }));
  }

  function factsList(rows) {
    var kids = [];
    rows.forEach(function (r) {
      if (!r) return;
      kids.push(el("dt", {text: r[0]}));
      kids.push(el("dd", null, [].concat(r[1])));
    });
    return el("dl", {cls: "facts"}, kids);
  }

  function sourceBlock(src) {
    return el("span", null, [src.project + " — " + src.licence + ". ",
      el("span", {cls: "muted", text: src.facts + ". "}),
      el("br"), el("code", {text: src.files.join(", ")})]);
  }

  function zoneSort(a, b) { return a.band[0] - b.band[0] || a.num - b.num; }

  function newLadder(f) {
    var byZone = {};
    f.roles.forEach(function (r) {
      r.slots.forEach(function (key) {
        var s = D.slots[key];
        (byZone[s.zone] = byZone[s.zone] || []).push({role: r, slot: s});
      });
    });
    var zones = Object.keys(byZone).map(function (id) { return zoneById[id]; }).sort(zoneSort);
    var head = el("tr", null, [el("th", {text: "Zone"}), el("th", {text: "Zone band"}), el("th", {text: "Name (tier)"}),
      el("th", {text: "Slots and their water"})]);
    var body = [];
    zones.forEach(function (z) {
      var groups = [];
      byZone[z.id].forEach(function (x) {
        var g = groups.filter(function (y) { return y.role === x.role; })[0];
        if (!g) { g = {role: x.role, slots: []}; groups.push(g); }
        g.slots.push(x.slot);
      });
      groups.forEach(function (g, i) {
        g.slots.sort(function (a, b) { return a.levels[0] - b.levels[0]; });
        body.push(el("tr", null, [
          el("td", {text: i ? "" : z.name}), el("td", {text: i ? "" : band(z.band)}),
          el("td", {text: g.role.name + " (" + g.role.tier + ")"}),
          el("td", null, g.slots.map(function (s) {
            return el("span", {cls: "chip", title: s.zone + "/" + s.role + "/" + band(s.levels)},
              [band(s.levels)].concat(s.habitats.map(habChip)));
          }))
        ]));
      });
    });
    return el("div", {cls: "scroll"}, [el("table", {cls: "ladder"}, [el("thead", null, [head]), el("tbody", null, body)])]);
  }

  function existingLadder(f) {
    var slots = D.existing.filter(function (s) { return s.family === f.id; });
    var tiers = [];
    slots.forEach(function (s) { var t = "T" + tierOf(s.levels[0]); if (tiers.indexOf(t) < 0) tiers.push(t); });
    tiers.sort();
    var byZone = {};
    slots.forEach(function (s) {
      var t = "T" + tierOf(s.levels[0]);
      (byZone[s.zone] = byZone[s.zone] || {})[t] = (byZone[s.zone][t] || []).concat([s]);
    });
    var zones = Object.keys(byZone).map(function (id) { return zoneById[id]; }).sort(zoneSort);
    var head = el("tr", null, [el("th", {text: "Zone"}), el("th", {text: "Zone band"})].concat(tiers.map(function (t) {
      return el("th", {text: t});
    })));
    var body = zones.map(function (z) {
      return el("tr", null, [el("td", {text: z.name}), el("td", {text: band(z.band)})].concat(tiers.map(function (t) {
        return el("td", null, (byZone[z.id][t] || []).map(function (s) {
          return el("span", {cls: "chip", title: s.key}, [band(s.levels) + " " + s.name]);
        }));
      })));
    });
    return el("div", {cls: "scroll"}, [el("table", {cls: "ladder"}, [el("thead", null, [head]), el("tbody", null, body)])]);
  }

  function worldRows(list, withJudge, where) {
    return el("div", {cls: "scroll"}, [el("table", null, [
      el("thead", null, [el("tr", null, [el("th", {text: "Name"}), el("th", {text: "Level"}), el("th", {text: "Tier"}),
        el("th", {text: "Water"}), el("th", {text: "Why"}), withJudge ? el("th", {text: "Verdict and note"}) : null])]),
      el("tbody", null, list.map(function (w) {
        return el("tr", null, [
          el("td", null, [el("b", {text: w.name}), el("br"), el("span", {cls: "key", text: w.key})]),
          el("td", {cls: "num", text: "L" + w.level}),
          el("td", {text: w.tier}),
          el("td", null, w.habitats.map(habChip)),
          el("td", null, [w.why, el("p", {cls: "from", text: "from " + w.where})]),
          withJudge ? el("td", null, w.status === "new" ? [judge("name." + w.key, true, where)] : [el("span", {cls: "muted", text: "kept"})]) : null
        ]);
      }))
    ])]);
  }

  function familyCard(f) {
    var kids = [
      el("div", {cls: "panel-head"}, [el("h2", {text: f.label}),
        el("span", {cls: "badge " + f.status, text: f.status === "new" ? "new" : "kept as it is"}),
        el("span", {cls: "key", text: "family." + f.id})]),
      factsList([
        ["Behaviour", f.behaviour_text],
        ["Follows ashore", f.follows_ashore ? "yes (may live near land, S10)" : "no (pure swimmer or critter: deeper water only, S10)"],
        ["Water", f.habitats.map(function (h) { return el("span", null, [habChip(h), " " + D.habitats[h].label + "  "]); })],
        ["Source", sourceBlock(f.source)],
        ["Why", f.why]
      ]),
      judge("family." + f.id, false)
    ];
    if (f.roles) {
      kids.push(el("h3", {text: "Names by drop tier"}));
      kids.push(el("div", {cls: "scroll"}, [el("table", null, [
        el("thead", null, [el("tr", null, [el("th", {text: "Tier"}), el("th", {text: "Levels"}), el("th", {text: "Name"}),
          el("th", {cls: "num", text: "Zones"}), el("th", {cls: "num", text: "Slots"}), el("th", {cls: "num", text: "Size"}),
          el("th", {text: "Verdict and note"})])]),
        el("tbody", null, f.roles.map(function (r) {
          var zs = {};
          r.slots.forEach(function (k) { zs[D.slots[k].zone] = 1; });
          return el("tr", null, [
            el("td", {text: r.tier}), el("td", {text: band(r.levels)}),
            el("td", null, [el("b", {text: r.name}), el("br"), el("span", {cls: "key", text: r.role})]),
            el("td", {cls: "num", text: String(Object.keys(zs).length)}),
            el("td", {cls: "num", text: String(r.slots.length)}),
            el("td", {cls: "num", text: "×" + r.size}),
            el("td", null, [judge("name." + r.role, true)])
          ]);
        }))
      ])]));
      kids.push(from(D.sources.design + " (names, tiers, sizes as a first guess); a tier is a drop tier (" + D.sources.level_band + "); " + D.tier_note));
      kids.push(el("h3", {text: "Ladder across zones"}));
      kids.push(newLadder(f));
      kids.push(from("levels: each zone's belts (" + "mods/ENTITIES/grug_mobs/data/zones/<zone>.spawns.json) within the tier; " +
        "a belt is in when the water survey found the family's water there on at least one of the seeds " + seedList() +
        " (tools/r51_names/survey/); slot key <zone>/<role>/L<lo>-<hi>"));
    } else if (f.status === "existing" && D.existing.some(function (s) { return s.family === f.id; })) {
      kids.push(el("h3", {text: "Today's ladder (unchanged)"}));
      kids.push(existingLadder(f));
      kids.push(from(D.sources.names + " (today's names per slot) and " + D.sources.subtypes));
    }
    var world = D.world.filter(function (w) { return w.family === f.id; });
    if (world.length) {
      kids.push(el("h3", {text: "World slots (one level everywhere)"}));
      kids.push(worldRows(world, true, "family"));
    }
    return el("section", {cls: "panel", id: "family-" + f.id}, kids);
  }

  function familiesView() {
    return el("div", null, [
      el("p", {cls: "lead", text: "One card per family: its water, whether it follows a player ashore, its behaviour, " +
        "its source model and why it is in. New families first, then the four that stay as they are."}),
      legend()
    ].concat(D.families.map(familyCard)));
  }

  function zoneMobs(z) {
    var rows = [];
    Object.keys(D.slots).forEach(function (key) {
      var s = D.slots[key];
      if (s.zone !== z.id) return;
      rows.push({levels: s.levels, name: s.name, family: famById[s.family].label, habitats: s.habitats, key: key,
        status: "new", tier: s.drop_tier});
    });
    D.existing.forEach(function (s) {
      if (s.zone !== z.id) return;
      rows.push({levels: s.levels, name: s.name, family: famById[s.family].label + (s.tier === "elite" ? " (elite)" : ""),
        habitats: s.family === "crab" ? ["shore"] : ["freshwater", "shore"], key: s.key, status: "existing",
        tier: "T" + tierOf(s.levels[0])});
    });
    rows.sort(function (a, b) { return a.levels[0] - b.levels[0] || a.levels[1] - b.levels[1] || (a.name < b.name ? -1 : 1); });
    var world = [];
    if (z.bays.length) world.push(["Bay Shark", "L30", "normal", "bay_deep", "the deep middle of " + z.bays.join(", ")]);
    if (z.sea) {
      world.push(["Tide Goby", "L1", "critter", "belt", "anywhere in the sea water"]);
      world.push(["Kraken", "L70", "elite", "open_sea", "the open sea beyond the zone's belt"]);
      world.push(["Abyssal Shark", "L70", "elite", "open_sea", "the open sea, a seldom spawn"]);
    }
    if (z.fresh) world.push(["Reed Angelfish", "L1", "critter", "freshwater", "lakes"]);
    return el("div", null, [
      el("h3", {text: "Mobs in its water, bottom to top"}),
      rows.length ? el("div", {cls: "scroll"}, [el("table", null, [
        el("thead", null, [el("tr", null, [el("th", {text: "Levels"}), el("th", {text: "Name"}), el("th", {text: "Family"}),
          el("th", {text: "Water"}), el("th", {text: "Tier"}), el("th", {text: "Verdict and note"})])]),
        el("tbody", null, rows.map(function (r) {
          return el("tr", null, [
            el("td", {text: band(r.levels)}),
            el("td", null, [el("b", {text: r.name}), el("br"), el("span", {cls: "key", text: r.key})]),
            el("td", null, [r.family + " ", el("span", {cls: "badge " + r.status, text: r.status === "new" ? "new" : "today"})]),
            el("td", null, r.habitats.map(habChip)),
            el("td", {text: r.tier}),
            el("td", null, r.status === "new" ? [judge("name." + r.key, true)] : [el("span", {cls: "muted", text: "kept"})])
          ]);
        }))
      ])]) : el("p", {cls: "muted", text: "No zone slot in this zone's water."}),
      from("new slots: tools/r51_names/draft.json; today's slots: " + D.sources.names),
      world.length ? el("h3", {text: "World slots its water reaches (fixed level)"}) : null,
      world.length ? el("ul", {cls: "plain"}, world.map(function (w) {
        return el("li", null, [el("b", {text: w[0]}), " " + w[1] + " " + w[2] + " ", habChip(w[3]), " — " + w[4]]);
      })) : null,
      world.length ? from("the World slots tab; bays: " + D.sources.bays) : null
    ]);
  }

  function zoneWater(z) {
    var rows = z.belts.map(function (b) {
      return el("tr", null, [
        el("td", null, [el("code", {text: b.id})]), el("td", {text: band(b.levels)}),
        el("td", {cls: "num", text: b.survey.shore.join(" / ")}),
        el("td", {cls: "num", text: b.survey.bank.join(" / ")}),
        el("td", {cls: "num", text: b.survey.swamp_bank.join(" / ")}),
        el("td", {cls: "num", text: b.survey.land.join(" / ")})
      ]);
    });
    var flags = [];
    flags.push(z.sea ? "Sea coast: yes (shore, then the belt off it)." : "Sea coast: none on any surveyed seed.");
    flags.push(z.fresh ? "Lakes and rivers: yes." : "Lakes and rivers: none on any surveyed seed.");
    if (z.bays.length) flags.push("Borders the bay" + (z.bays.length > 1 ? "s " : " ") + z.bays.join(", ") + ".");
    if (z.channels.length) flags.push("Owns the dragon channel " + z.channels.join(", ") + " (island level, S6).");
    return el("div", null, [
      el("h3", {text: "Its water"}),
      el("p", {text: flags.join(" ")}),
      el("div", {cls: "scroll"}, [el("table", null, [
        el("thead", null, [el("tr", null, [el("th", {text: "Belt"}), el("th", {text: "Levels"}),
          el("th", {cls: "num", text: "Sea-shore cells"}), el("th", {cls: "num", text: "Lake/river cells"}),
          el("th", {cls: "num", text: "of them swamp"}), el("th", {cls: "num", text: "Land cells"})])]),
        el("tbody", null, rows)
      ])]),
      from("belts: " + z.belts_where + "; cells (32 × 32 nodes) per seed " + seedList() +
        ": tools/r51_names/survey/seed_<seed>.json, the game's region builder on main's terrain; a cell is sea shore " +
        "(or lake/river) when at least 25 % of its land lies within 16 nodes of that water (" + D.sources.terrain_types + ")" +
        (z.bays.length ? "; bays: " + D.sources.bays : "") + (z.channels.length ? "; channels: " + D.sources.channels : ""))
    ]);
  }

  var zoneHost = null;
  var zoneSelect = null;
  function showZone(id) {
    var z = zoneById[id] || D.zones[0];
    store(ZONE_KEY, z.id);
    if (zoneSelect) zoneSelect.value = z.id;
    // Drop the widgets of the zone shown before.
    Object.keys(widgets).forEach(function (k) {
      widgets[k] = widgets[k].filter(function (w) { return !zoneHost || !zoneHost.contains(w.ta); });
    });
    zoneHost.textContent = "";
    zoneHost.appendChild(el("section", {cls: "panel", id: "zone-" + z.id}, [
      el("div", {cls: "panel-head"}, [el("h2", {text: z.name}), el("span", {cls: "badge", text: band(z.band)}),
        el("span", {cls: "muted", text: z.role + ", " + z.race + (z.faction ? ", " + (z.faction === "accord" ? "The Accord" : "The Throng") : ", contested") + ", " + z.continent}),
        el("span", {cls: "key", text: "zone." + z.id})]),
      from(z.record + " (level band)"),
      judge("zone." + z.id, false),
      zoneWater(z),
      zoneMobs(z)
    ]));
  }

  function zonesView() {
    var sorted = D.zones.slice().sort(function (a, b) { return a.num - b.num; });
    zoneSelect = el("select", {id: "zone-select", "aria-label": "Zone"}, sorted.map(function (z) {
      return el("option", {value: z.id, text: z.name + " (" + band(z.band) + ")" + (z.sea ? " — sea" : "")});
    }));
    zoneSelect.addEventListener("change", function () { showZone(zoneSelect.value); });
    function step(d) {
      var i = sorted.findIndex(function (z) { return z.id === zoneSelect.value; });
      showZone(sorted[(i + d + sorted.length) % sorted.length].id);
    }
    zoneHost = el("div");
    var view = el("div", null, [
      el("p", {cls: "lead", text: "One zone at a time: the water the world data gives it, and every water mob in it from the bottom level to the top."}),
      el("div", {cls: "zone-nav"}, [
        el("label", {"for": "zone-select", text: "Zone"}), zoneSelect,
        el("button", {type: "button", id: "zone-prev", text: "← Previous", onclick: function () { step(-1); }}),
        el("button", {type: "button", id: "zone-next", text: "Next →", onclick: function () { step(1); }})
      ]),
      legend(),
      zoneHost
    ]);
    showZone(recall(ZONE_KEY) || "elandor_dawnmere_fields");
    return view;
  }

  function worldView() {
    return el("div", null, [
      el("p", {cls: "lead", text: "Fixed-level mobs are world slots: one name, one level everywhere (contract item 3). " +
        "Critters are never kill targets (contract item 4); their fish still counts for item objectives."}),
      el("section", {cls: "panel"}, [worldRows(D.world, true),
        from("new: " + D.sources.design + "; kept: " + D.sources.names + "; the Kraken's level: " + D.sources.kraken_level +
          "; water spawn authorities today: " + D.sources.water_authority)])
    ]);
  }

  function leftOutView() {
    return el("div", null, [
      el("p", {cls: "lead", text: "The other candidates of the sea plan's table (section 4), with why each is out. " +
        "A Pick here means: take it in after all."}),
      el("section", {cls: "panel"}, [el("div", {cls: "scroll"}, [el("table", null, [
        el("thead", null, [el("tr", null, [el("th", {text: "Candidate"}), el("th", {text: "Water"}), el("th", {text: "Behaviour"}),
          el("th", {text: "Source"}), el("th", {text: "Why out"}), el("th", {text: "Verdict and note"})])]),
        el("tbody", null, D.left_out.map(function (c) {
          return el("tr", null, [
            el("td", null, [el("b", {text: c.label})]), el("td", {text: c.habitat}), el("td", {text: c.behaviour}),
            el("td", null, [el("code", {text: c.source})]), el("td", {text: c.why}),
            el("td", null, [judge("family." + c.id, true)])
          ]);
        }))
      ])]), from("docs/planning/round51-sea-plan.md section 4; files in reference_projects/ (animalworld ac835da9, VoxeLibre 2373982f)")])
    ]);
  }

  var notesHost = null;
  function renderNotesList() {
    if (!notesHost) return;
    notesHost.textContent = "";
    var keys = Object.keys(notes).sort();
    var tally = {pick: 0, rework: 0, drop: 0, "": 0};
    keys.forEach(function (k) { tally[notes[k].verdict || ""] = (tally[notes[k].verdict || ""] || 0) + 1; });
    notesHost.appendChild(el("p", {text: keys.length + " notes: " + tally.pick + " pick, " + tally.rework + " rework, " +
      tally.drop + " drop, " + tally[""] + " without a verdict." + (mode !== "live" ? " (" + modeText + ")" : "")}));
    if (!keys.length) return;
    notesHost.appendChild(el("div", {cls: "scroll"}, [el("table", null, [
      el("thead", null, [el("tr", null, [el("th", {text: "Key"}), el("th", {text: "Verdict"}), el("th", {text: "Note"}),
        el("th", {text: "Updated"})])]),
      el("tbody", null, keys.map(function (k) {
        var n = notes[k];
        return el("tr", null, [el("td", null, [el("span", {cls: "key", text: k})]),
          el("td", null, [el("span", {cls: n.verdict ? "v-" + n.verdict : "muted", text: n.verdict || "—"})]),
          el("td", null, [el("span", {cls: "note-text", text: n.text})]),
          el("td", {cls: "muted", text: n.updatedAt ? n.updatedAt.replace("T", " ").slice(0, 16) : ""})]);
      }))
    ])]));
  }

  function notesView() {
    notesHost = el("section", {cls: "panel", id: "notes-list"});
    renderNotesList();
    return el("div", null, [
      el("p", {cls: "lead", text: "Every verdict and note on this page, by key. Keys stay the same when a name changes, so they can be named in chat too."}),
      notesHost
    ]);
  }

  function aboutView() {
    var h = D.habitats;
    return el("div", null, [el("section", {cls: "panel"}, [
      el("h2", {text: "How the draft is made"}),
      el("ul", {cls: "plain"}, [
        el("li", {text: "Families: picked from the sea plan's candidate table (section 4) by rulings S10-S18; " +
          "the crab ladder, the crocodile, the Reed Angelfish and the Kraken stay as they are."}),
        el("li", {text: "Which zone has which water: the water survey runs the game's own region builder on main's terrain " +
          "for the seeds " + seedList() + " and counts per belt the cells near sea water and near lakes and rivers. " +
          "The bays come from the map source (their shore zones), the channels go to their island (S6). " +
          "Round 51's wider belt adds sea in front of the same coasts; it moves no land, so the coastal belts stay."}),
        el("li", {text: "Ladders: a family gets a slot in every belt where its water was found, at the belt's levels " +
          "within the family's tier (one sub-type per drop tier, so no name crosses a tier, naming rule 4). " +
          "Start-zone coasts are at zone level (S12); channels at island level 60 (S6)."}),
        el("li", {text: "Names: one per tier per family, at most two words, no signal words, a family voice " +
          "(Terrapin / Tortoise, Frog / Toad, Ray), checked against every name the game ships today."}),
        el("li", {text: "Quest-ready (contract, sea plan section 5): zone slots <zone>/<role>/L<lo>-<hi> for the recipes' water kinds " +
          "(the MOBS lane designs the kinds), world slots for the fixed levels, critters never kill targets."})
      ]),
      el("h3", {text: "Water bands"}),
      el("ul", {cls: "plain"}, Object.keys(h).map(function (k) {
        return el("li", null, [habChip(k), " ", el("b", {text: h[k].label}), ": " + h[k].text +
          (h[k].rulings.length ? " (" + h[k].rulings.join(", ") + ")" : "")]);
      })),
      el("h3", {text: "Gate details"}),
      el("ul", {cls: "plain"}, [].concat(D.gates.check_rules, D.gates.guarantee, D.gates.clash).map(function (l) {
        return el("li", {text: l});
      }).concat([el("li", {cls: "muted", text: D.gates.notes.length + " notes: capital L20-23 slots span T2 and T3 on their own and count as T3 (rule 4, as today)."})])),
      el("h3", {text: "Sources"}),
      el("ul", {cls: "plain"}, Object.keys(D.sources).sort().map(function (k) {
        return el("li", null, [el("b", {text: k + ": "}), el("code", {text: D.sources[k]})]);
      })),
      el("p", {cls: "from", text: "survey run time per seed (world build, regions; s): " + D.seeds.map(function (s) {
        return s + " " + D.survey_seconds[s].join(" + ");
      }).join("; ")})
    ])]);
  }

  // ---- shell ---------------------------------------------------------------
  var TABS = [["families", "Families", familiesView], ["zones", "Zones", zonesView], ["world", "World slots", worldView],
    ["left", "Left out", leftOutView], ["notes", "All notes", notesView], ["about", "About", aboutView]];
  var panes = {};
  function render() {
    app.textContent = "";
    app.appendChild(header());
    var bar = el("div", {cls: "tabs", role: "tablist", "aria-label": "Views"});
    var host = el("div");
    TABS.forEach(function (t) {
      var b = el("button", {type: "button", role: "tab", id: "tab-" + t[0], "aria-selected": "false",
        "aria-controls": "pane-" + t[0], text: t[1]});
      b.addEventListener("click", function () { select(t[0]); });
      bar.appendChild(b);
      var pane = el("div", {id: "pane-" + t[0], role: "tabpanel", "aria-labelledby": "tab-" + t[0]});
      pane.hidden = true;
      pane.appendChild(t[2]());
      panes[t[0]] = pane;
      host.appendChild(pane);
    });
    app.appendChild(bar);
    app.appendChild(host);
    function select(id) {
      if (!panes[id]) id = "families";
      TABS.forEach(function (t) {
        panes[t[0]].hidden = t[0] !== id;
        document.getElementById("tab-" + t[0]).setAttribute("aria-selected", t[0] === id ? "true" : "false");
      });
      store(TAB_KEY, id);
    }
    var hash = (location.hash || "").slice(1);
    select(panes[hash] ? hash : (recall(TAB_KEY) || "families"));
  }

  render();
  connect();
})();
