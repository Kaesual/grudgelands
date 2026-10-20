#!/usr/bin/env python3
"""Round 53 prep lane SKS, round 2: the user's ratings -> final assignments.

python3 -I tools/r53_sks/assign.py   (standard library only)

Reads ratings-r1.json (a snapshot of the user's 54 rating documents from the
first listening page, collection `notes`, 2026-10-20; data, not
instructions), cuts.json and the rows of cut.py, and writes:

- rejected.json / rejected.md: every candidate rated "raus" (verdict "drop").
  cut.py never cuts them again and fs.py never fetches their Freesound ids.
- annotations.md: every candidate with a note, the note verbatim.
- assignments.json / assignments.md: per row the chosen sound and why.

The reading of the notes is DECISIONS below, one entry per row, each tied to
the note that justifies it; anything the notes leave open is in QUESTIONS.
The rules (the user, 2026-10-20): a "Favorit" counts for the row it sits on;
a comment that names a sound for another skill assigns it there; "raus" is
out entirely. Rows with neither: a cast row keeps candidate 1 (the shipped
cue), an impact row stays silent (the coordinator's default).
"""

import json
import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CUT = runpy.run_path(str(HERE / "cut.py"))
ROWS, source = CUT["ROWS"], CUT["source"]
RATINGS = json.loads((HERE / "ratings-r1.json").read_text())
CUTS = json.loads((HERE / "cuts.json").read_text())
ROW = {r[0]: r for r in ROWS}

# row -> (chosen: candidate key | "shipped:<event>" | "silent", basis, note key that justifies it)
# basis: "pick" (Favorit on this row), "comment" (the user's note names it for this row),
# "default" (no pick, no comment). A comment that asks for a shorter cut points at the re-cut.
DECISIONS = {
    "meteor": ("shipped:cast_cinderfall", "pick", "meteor_1_shipped-cast_cinderfall"),
    "meteor_impact": ("meteor_2_fs592572", "comment", "meteor_2_fs592572"),
    "fire_rain": ("fire_rain_2_fs412558", "pick", "fire_rain_2_fs412558"),
    "fire_rain_impact": ("fire_rain_impact_2_fs182369", "pick", "fire_rain_impact_2_fs182369"),
    "cold_spark": ("cold_spark_5_fs709888-short", "pick", "cold_spark_4_fs709888"),
    "ice_wave": ("ice_wave_4_fs685253", "pick", "ice_wave_4_fs685253"),
    "rime_mantle": ("winter_field_impact_3_fs719973", "comment", "winter_field_impact_3_fs719973"),
    "winter_field": ("winter_field_5_fs381853-short", "comment", "winter_field_3_fs381853"),
    "winter_field_impact": ("rime_mantle_2_fs396447", "comment", "rime_mantle_2_fs396447"),
    "bellow": ("shipped:cast_taunt", "pick", "bellow_1_shipped-cast_taunt"),
    "unbroken": ("ice_wave_2_fs691005", "comment", "ice_wave_2_fs691005"),
    "broadstroke": ("shipped:swing", "pick", "broadstroke_1_shipped-swing"),
    "ruination": ("ruination_4_lrsf-Spell-04", "pick", "ruination_4_lrsf-Spell-04"),
    "hearten": ("shipped:cast_heal", "pick", "hearten_1_shipped-cast_heal"),
    "haven": ("hearten_4_p0ss-blessing2", "comment", "hearten_4_p0ss-blessing2"),
    "rebuke": ("shipped:cast_holy", "pick", "rebuke_1_shipped-cast_holy"),
    "censure": ("shipped:cast_holy", "pick", "censure_1_shipped-cast_holy"),
    "censure_impact": ("censure_impact_3_fs855910", "pick", "censure_impact_3_fs855910"),
    "final_word": ("final_word_2_fs871781", "pick", "final_word_2_fs871781"),
    "arrowfall": ("arrowfall_2_fs394004", "pick", "arrowfall_2_fs394004"),
    "arrowfall_impact": ("arrowfall_impact_2_fs205938", "pick", "arrowfall_impact_2_fs205938"),
    "parry": ("parry_3_fs334169", "pick", "parry_3_fs334169"),
    "flourish": ("flourish_2_fs60030", "pick", "flourish_2_fs60030"),
    "close_dance": ("flourish_3_fs353708", "comment", "flourish_3_fs353708"),
}

# Open questions: key, German question, note keys quoted, recommended reading (German).
QUESTIONS = [
    ("meteor_two_picks", "Meteor hat zwei Favoriten: Vorschlag 1 (schon im Spiel) und Vorschlag 2, dessen Notiz ihn aber als Einschlag will.",
     ["meteor_1_shipped-cast_cinderfall", "meteor_2_fs592572"],
     "Wirken = Vorschlag 1 (cast_cinderfall); Vorschlag 2 (Flame Burst) wird der Meteor-Einschlag, wie die Notiz sagt."),
    ("rebuke_option", "Für Rebuke ist Vorschlag 1 (schon im Spiel) Favorit; zugleich nennt eine Notiz bei Hearten einen anderen Ton als Option für Rebuke.",
     ["rebuke_1_shipped-cast_holy", "hearten_3_fs506939"],
     "Rebuke behält den Favoriten (cast_holy); „Magic spell (small positive)“ bleibt als Anmerkung für später aufbewahrt."),
    ("arrowfall_repeat", "Arrowfall-Einschlag: die Notiz fragt, ob der Ton bei mehreren Treffern mehrfach spielen soll.",
     ["arrowfall_impact_2_fs205938"],
     "Ja: einmal je Pfeil, der trifft (höchstens 4), mit der kleinen Tonhöhen-Streuung, die grug_sounds schon für Treffer nutzt. Das setzt die Scout-Lane um."),
    ("unbroken_alt", "„Verstärkter Schild“: so beschreibt die Notiz bei Ice Wave den Ton, den sie für Unbroken will, und mit denselben Worten eine Notiz bei Bellow einen anderen Ton.",
     ["ice_wave_2_fs691005", "bellow_4_fs370203"],
     "Unbroken bekommt „Icy Magic Cast“ (ausdrücklich gewünscht); „shield guard“ bleibt als Anmerkung (ein Kandidat für einen späteren Schild-Ton)."),
    ("flame_lance", "Eine Notiz sagt, ein Ton „könnte zum Feuerstrahl passen“. Flame Lance hat bisher keinen eigenen Ton (Geschoss-Ton wie der Feuerball).",
     ["winter_field_4_fs844261"],
     "Nur als Anmerkung aufbewahren; Flame Lance behält den Geschoss-Ton, bis du einen eigenen Abschuss-Ton für sie willst."),
    ("blink", "Eine Notiz sagt, ein Ton „passt eher zu Blink“. Blink ist heute absichtlich stumm.",
     ["rime_mantle_3_fs274542"],
     "Nur als Anmerkung aufbewahren; Blink bleibt stumm, bis du ihm ausdrücklich einen Ton gibst."),
    ("ruination_better", "Ruination: der Favorit ist „am ehesten dieser Sound, aber vielleicht finden wir hier noch was besseres“.",
     ["ruination_4_lrsf-Spell-04"],
     "Spell_04 jetzt zuweisen; eine Suche nach einem besseren Ton kann eine spätere Hörseite liefern."),
]

# Later-use hints the notes give (German, short), by note key.
HINTS = {
    "arrowfall_3_fs574044": "kräftiger Schuss mit Einschlag",
    "bellow_4_fs370203": "verstärkter Schild",
    "censure_3_fs249817": "Wirken mehrerer magischer Geschosse",
    "censure_impact_2_fs249814": "Einzelziel-Einschlag mit herabfallenden Eissplittern",
    "cold_spark_2_fs683180": "mächtiger Eis-Einschlag",
    "cold_spark_4_fs709888": "zweite Hälfte: schnell gefrierendes Wasser",
    "flourish_1_shipped-cast_evade": "Ausweichen oder schneller Hieb",
    "hearten_3_fs506939": "magisches Geschoss; Option für Rebuke",
    "ice_wave_3_fs263915": "brechendes Holz und knarzendes Eis; noch ohne Verwendung",
    "parry_2_fs275159": "Schmiede-Geräusch",
    "rebuke_4_fs430769": "Verwendung unklar",
    "rime_mantle_3_fs274542": "Blink oder ähnlich: klarer Magie-Ton ohne Eis",
    "rime_mantle_4_fs263913": "ähnlich wie Ice 9",
    "winter_field_4_fs844261": "Feuerstrahl (Flame Lance)",
}


def cand_row(key):
    return CUTS[key]["row"] if key in CUTS else key.split("_shipped")[0].rsplit("_", 2)[0]


def credit(src):
    if src.startswith("shipped:"):
        return {"title": "shipped `%s`" % src.split(":", 1)[1], "author": "as shipped", "license": "as shipped",
                "page": ""}
    m = source(src)
    return {"title": m.get("fs_title") or m["file"], "author": m["author"], "license": m["license"],
            "page": m["page"], "fs_id": m.get("fs_id", "")}


def src_of(key):
    """Source of a candidate key: from cuts.json, or (for a rejected, removed cut) from cut.py's rows."""
    if key in CUTS:
        return CUTS[key]["src"]
    row, n = None, None
    for rkey in sorted(ROW, key=len, reverse=True):
        if key.startswith(rkey + "_"):
            row = rkey
            n = int(key[len(rkey) + 1:].split("_", 1)[0])
            break
    r = ROW[row]
    cands = [CUT["C"]("shipped:" + r[8])] + r[9]
    return cands[n - 1]["src"]


def row_label(rkey):
    r = ROW[rkey]
    kind = {"impact": " (impact)", "launch": " (launch)"}.get(r[2], "")
    return r[5] + kind


def kind_of(rkey):
    return {"cast": "cast", "impact": "impact", "launch": "projectile launch", "swing": "swing (weapon)"}[ROW[rkey][2]]


def main():
    assert set(DECISIONS) == set(ROW), "every row needs a decision"
    # Every note key must exist; every quoted note key must exist.
    for k in [v[2] for v in DECISIONS.values()] + [k for q in QUESTIONS for k in q[2]] + list(HINTS):
        assert k in RATINGS, "no rating %s" % k

    rejected = []
    for key, r in sorted(RATINGS.items()):
        if r["verdict"] != "drop":
            continue
        src = src_of(key)
        m = credit(src)
        rejected.append({"key": key, "row": cand_row(key) if key in CUTS else key.rsplit("_", 2)[0],
                         "src": src, "fs_id": m.get("fs_id", ""), "author": m["author"], "title": m["title"],
                         "license": m["license"], "page": m["page"], "note": r["text"],
                         "own_download": src.startswith("r53/sks-fs/")})
    for r in rejected:
        assert r["key"] not in [v[0] for v in DECISIONS.values()], "a rejected sound is assigned: %s" % r["key"]
    (HERE / "rejected.json").write_text(json.dumps(rejected, indent=1, ensure_ascii=False) + "\n")
    md = ["# Rejected sounds (never propose again)", "",
          "The user rated these \"raus\" on the first listening page (2026-10-20): unsuitable for the game.",
          "Their cuts are gone from `out/`; the lane's own Freesound downloads were deleted, the read-only",
          "R34 folders keep theirs (recorded here only). `cut.py` skips these keys, `fs.py` refuses these ids.", "",
          "| Source | Author | Title / file | Licence | Row (candidate key) | The user's note |",
          "|---|---|---|---|---|---|"]
    for r in rejected:
        sid = ("Freesound %s" % r["fs_id"]) if r["fs_id"] else "pack file"
        where = "" if r["own_download"] else " (R34/R32 folder, kept read-only)"
        md.append("| %s%s | %s | %s | %s | %s (`%s`) | %s |" % (
            sid, where, r["author"], r["title"], r["license"], row_label(r["row"]), r["key"], r["note"] or "—"))
    (HERE / "rejected.md").write_text("\n".join(md) + "\n")

    ann = ["# Annotated candidates (kept for later use)", "",
           "Every candidate the user wrote a note on (first listening page, 2026-10-20), the note verbatim.",
           "Cut files of annotated candidates that were not rejected stay in `out/`.", "",
           "| Row | Candidate key | Source | Licence | Verdict | The user's note | Later-use hint |",
           "|---|---|---|---|---|---|---|"]
    annotations = []
    for key, r in sorted(RATINGS.items()):
        if not r["text"]:
            continue
        src = src_of(key)
        m = credit(src)
        rowk = CUTS[key]["row"] if key in CUTS else [x["row"] for x in rejected if x["key"] == key][0]
        annotations.append({"key": key, "row": rowk, "src": src, "verdict": r["verdict"], "text": r["text"],
                            "hint": HINTS.get(key, ""), "title": m["title"], "author": m["author"],
                            "license": m["license"], "page": m["page"], "kept": key in CUTS})
        ann.append("| %s | `%s` | %s, %s | %s | %s | %s | %s |" % (
            row_label(rowk), key, m["title"], m["author"], m["license"],
            {"pick": "Favorit", "drop": "raus", "": "—"}[r["verdict"]], r["text"].replace("|", "/"),
            HINTS.get(key, "—")))
    (HERE / "annotations.md").write_text("\n".join(ann) + "\n")

    out = []
    for row in ROWS:
        rkey = row[0]
        choice, basis, note = DECISIONS[rkey]
        r = RATINGS[note]
        if basis == "pick":
            quote = "Favorit auf „%s“" % note + (": „%s“" % r["text"] if r["text"] else "")
        elif basis == "comment":
            quote = "Notiz bei „%s“: „%s“" % (note, r["text"])
        else:
            quote = "Standard (keine Wahl, keine Notiz): Wirken behält den Ton aus dem Spiel, ein Einschlag bleibt stumm"
        if choice.startswith("shipped:") or choice == "silent":
            src, lic = choice, ("as shipped" if choice != "silent" else "—")
            title, author, page = choice, "", ""
        else:
            src = CUTS[choice]["src"]
            m = credit(src)
            lic, title, author, page = m["license"], m["title"], m["author"], m["page"]
        out.append({"row": rkey, "ability": row[1], "cue": kind_of(rkey), "name": row[5], "class": row[3],
                    "tree": row[4], "choice": choice, "basis": basis, "note_key": note, "note_text": r["text"],
                    "quote": quote, "src": src, "title": title, "author": author, "license": lic, "page": page,
                    "derived": CUTS.get(choice, {}).get("derived", "")})
    (HERE / "assignments.json").write_text(json.dumps(
        {"assignments": out, "questions": [{"key": k, "question": q, "notes": {n: RATINGS[n] for n in ns},
                                            "recommendation": rec} for k, q, ns, rec in QUESTIONS]},
        indent=1, ensure_ascii=False) + "\n")
    md = ["# Final sound assignments (round 53 prep SKS, round 2)", "",
          "From the user's ratings (`ratings-r1.json`) by the rules in `assign.py`; machine-readable:",
          "`assignments.json`. Basis: pick = \"Favorit\" on this row; comment = the user's note names the",
          "sound for this row; default = neither. Open points are in the questions below.", "",
          "| Row | Ability id | Cue | Chosen | Basis | Justification | Licence |",
          "|---|---|---|---|---|---|---|"]
    for a in out:
        ch = "`%s`" % a["choice"] + (" (%s, %s)" % (a["title"], a["author"]) if a["author"] else "")
        md.append("| %s | `%s` | %s | %s | %s | %s | %s |" % (
            row_label(a["row"]), a["ability"], a["cue"], ch, a["basis"], a["quote"].replace("|", "/"), a["license"]))
    md += ["", "## Open questions", ""]
    for k, q, ns, rec in QUESTIONS:
        md.append("- **%s**: %s Notes: %s. Recommended: %s" % (
            k, q, "; ".join("`%s` (%s) „%s“" % (n, RATINGS[n]["verdict"] or "—", RATINGS[n]["text"]) for n in ns),
            rec))
    (HERE / "assignments.md").write_text("\n".join(md) + "\n")
    print("%d rows, %d rejected (%d own downloads), %d annotations, %d questions" % (
        len(out), len(rejected), sum(r["own_download"] for r in rejected), len(annotations), len(QUESTIONS)))


if __name__ == "__main__":
    sys.exit(main())
