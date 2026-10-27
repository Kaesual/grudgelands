#!/usr/bin/env python3
"""Round 59 lane STORYQUESTS: write chapter 1's story quests in the capitals.

The chapter's four story quests (round59-plan.md §4 STORYQUESTS, the user's
picks K1-K16 "A"; quests.md "Chapter 1 in the capitals") with placeholder
texts ("[PH] ..."):

  * `story_accord_01` "A Hearing for the Absent" and `story_throng_01` "Our
    Word, Our Witness" (level 19, no prerequisite): one shared quest per
    faction, a variant per capital given by its envoy, a travel quest to the
    guild leader of the giver's own capital;
  * `story_accord_02` "What a Seal Allows" and `story_throng_02` "Whose Word
    Is This?" (level 20, requiring the first): a variant per capital given
    and turned in by its guild leader, one use objective at the capital's
    town place (its `quest_place` socket in a service plot's
    `extra_sockets`, grug_mapgen/wp13), the same object and label in every
    variant, only `place` differs.

Each faction's quests live in the file of their first variant's capital
(Highcourt, Gor Drazhak). Every capital file gets a hub `<capital>_guild` for
its guild leader (line `guild`), and its envoy's own line is renamed to the
shared `envoy`, so the three envoys of a faction have the line their shared
quest needs (a line is only a label, loader.lua); the envoys keep their two
lines (`envoy`, `front`). The capital files were unflagged until Round 60
reworked them (tools/r60_capitals/build_structure.py writes the rest of
each file and copies these four quests).

The structure was written once with placeholder texts; the texts are lane
BANDTEXT's (Round 59), and the JSON files are their source. Rerunning the
script without --check replaces the four quests and the six hubs it wrote
(leaving the rest of each file as it is) and so writes the placeholders
back over the real texts.

    python3 tools/r59_storyquests/build_structure.py [--check]

--check exits 1 when the files' structure differs from what the script
would write: everything but the texts (titles, texts, completions, a
variant's text and completion), so it holds once the real texts are in.
Python 3 standard library only.
"""
import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"

PH = "[PH] "
TBD = " Real text to follow."
LINE_ENVOY = "envoy"
LINE_GUILD = "guild"

# capital key -> zone, envoy, its old line, the leader, the town place's
# socket (plot/socket id, wp13 district rows), the building in words.
CAPITALS = {
    "highcourt": ("elandor_highcourt", "r20_human_capital_envoy", "accounts",
                  "market_store/market_store_dispatch_yard"),
    "dur_brannoc": ("elandor_dur_brannoc", "r20_dwarf_capital_envoy", "gate",
                    "forge_ore_yard/forge_ore_yard_loading_apron"),
    "lethariel": ("elandor_lethariel", "r20_elf_capital_envoy", "wardens",
                  "market_bowyer/market_bowyer_timber_check"),
    "gor_drazhak": ("kragmar_gor_drazhak", "r20_orc_capital_envoy", "muster",
                    "warren_cook_court/warren_cook_court_water_depot"),
    "kezamba": ("kragmar_kezamba", "r20_troll_capital_envoy", "offerings",
                "shore_store/shore_store_witness_landing"),
    "nhal_veyr": ("kragmar_nhal_veyr", "r20_undead_capital_envoy", "vigil",
                  "homes_mourners_hall/homes_mourners_hall_receiving_court"),
}
ORDER = {"accord": ("highcourt", "dur_brannoc", "lethariel"),
         "throng": ("gor_drazhak", "kezamba", "nhal_veyr")}


def leader(capital):
    return "r58_guild_leader_" + capital


def place(capital):
    return "socket:%s/%s" % (capital, CAPITALS[capital][3])


def ph(text):
    return PH + text + TBD


# The draft's intent per variant (chapter1-draft.md §4, §5; K13 A: at the
# turn-in the leader decides the capital's case, where the abused papers come
# from stays open). Who speaks, what happens, the leader's stance.
TEXTS = {
    "story_accord_01": {
        "title": "A Hearing for the Absent",
        "text": "Chapter 1 (The Accord): the capital's envoy has a reported case of people and "
                "loads entered in the wrong ledger and sends the player to The Charter of Stone's "
                "leader at the Miner's Guild house of this capital.",
        "highcourt": ("Mariel Waybook: word from Goldmead says people and supplies are being claimed "
                      "under a capital toll mark; Alis Cartwright at the Miner's Guild house can check "
                      "the transport pledges. A reported case: Mariel does not claim the player "
                      "helped Pella.",
                      "Alis Cartwright: she asks who really needs a load and who drives it, and takes "
                      "up the case."),
        "dur_brannoc": ("Dorrin Gateledger: a Counting House stamp turns up on stolen ore bags; Hadrin "
                        "Beamset at the Miner's Guild house checks how it ties to the workings and the "
                        "supply. A reported case: Dorrin does not claim the player helped Tovin.",
                        "Hadrin Beamset: he asks which work stands still without the material and "
                        "whether everybody came back, and takes up the case."),
        "lethariel": ("Eriath Boughwarden: the Bough Seal is passed off as leave to take; Caelir "
                      "Veinward at the Miner's Guild house knows the limits of the releases it "
                      "covers. A reported case: Eriath does not claim the player helped Nima.",
                      "Caelir Veinward: she asks exactly what a release allows, and takes up the "
                      "case."),
    },
    "story_accord_02": {
        "title": "What a Seal Allows",
        "text": "Chapter 1 (The Accord): the guild has halted a suspect delivery in the capital; the "
                "player secures its record at the spot and brings it back, and the leader decides "
                "the case.",
        "highcourt": ("Alis Cartwright: a delivery for the joint supply waits in the yard beside the "
                      "butcher's shop. Its covering record stretches the drivers' duty as if the "
                      "workers could be put under another order along with the load. Alis has halted "
                      "it; secure the record there and bring it back.",
                      "Alis Cartwright: she compares the record with the agreed delivery, rejects the "
                      "extension and releases the load to its right recipient. A confirmed load gives "
                      "nobody a say over the people beside it. Where the papers came from stays open; "
                      "a like case waits at Frostbarrow Shelf."),
        "dur_brannoc": ("Hadrin Beamset: tool material stands on the loading apron of the ore yard. "
                        "Its acceptance was tied to a claimed transfer of the crew it was meant for, "
                        "so their own supply would count as delivered. Hadrin never approved it; "
                        "secure the load record there and bring it back.",
                        "Hadrin Beamset: with the supply he sets out which crew the material was "
                        "meant for and has it issued to them. A clean stamp replaces neither a sound "
                        "order nor safe working. Where the papers came from stays open; a like case "
                        "waits at Frostbarrow Shelf."),
        "lethariel": ("Caelir Veinward: material for a limited tending and repair job waits at the "
                      "timber check beside the bowyer's workshop. A covering sheet turns the release "
                      "into a wider claim on timber and on the tenders' labour. Secure the sheet "
                      "there and bring it back.",
                      "Caelir Veinward: she confirms the true purpose and strikes the extension. "
                      "Leave to tend is no leave to clear-cut, nor a say over the tenders. Where the "
                      "papers came from stays open; a like case waits at Frostbarrow Shelf."),
    },
    "story_throng_01": {
        "title": "Our Word, Our Witness",
        "text": "Chapter 1 (The Throng): the capital's envoy has a reported case of true records "
                "turned to a false claim and sends the player to The Oathdelvers' leader at the "
                "Miner's Guild house of this capital.",
        "gor_drazhak": ("Thorga Roadspeaker: stolen supplies are billed again to the very people "
                        "they were meant for; Drava Flintshoulder at the Miner's Guild house knows "
                        "the pledges behind them. A reported case: Thorga does not claim the player "
                        "helped Rokka.",
                        "Drava Flintshoulder: she stands by a pledge kept and will not let it become "
                        "the receivers' debt, and takes up the case."),
        "kezamba": ("Nalo Pathdrum: an extorted levy is treated as if the community had pledged it; "
                    "Ombali Ropekeeper at the Miner's Guild house tests the claimed witness. A "
                    "reported case: Nalo does not claim the player helped Veko.",
                    "Ombali Ropekeeper: she keeps what someone witnessed apart from what is slipped "
                    "under their name later, and takes up the case."),
        "nhal_veyr": ("Ossa Quietregister: remains and names are parted and used for strangers' "
                      "claims; Iven Lastshift at the Miner's Guild house checks the register "
                      "entries. A reported case: Ossa does not claim the player freed Hollis.",
                      "Iven Lastshift: he keeps a name on the register apart from any claim about the "
                      "person who bears it, and takes up the case."),
    },
    "story_throng_02": {
        "title": "Whose Word Is This?",
        "text": "Chapter 1 (The Throng): a handover in the capital is disputed; the player secures "
                "its original record at the spot and brings it back, and the leader refuses the "
                "false claim.",
        "gor_drazhak": ("Drava Flintshoulder: a confirmed water delivery is to be issued at the "
                        "depot on the rim of the cook court. The receivers' names and the "
                        "handover's witnesses were moved onto a new claim, so those supplied would "
                        "owe more service or pay. Secure the original handover record there and "
                        "bring it back.",
                        "Drava Flintshoulder: she refuses the new claim and has the water issued as "
                        "pledged. The Oathdelvers stand by the delivery; the receivers owe nothing "
                        "for it. Where the papers came from stays open; a like case waits at "
                        "Ossuary Reach."),
        "kezamba": ("Ombali Ropekeeper: supplies for porters are held at the landing beside the "
                    "shore store. A witnessed help with the unloading is made to prove a standing "
                    "pledge of the same helpers. Secure the original witnessed record there and "
                    "bring it back.",
                    "Ombali Ropekeeper: she names which act was witnessed and which claim goes "
                    "beyond it. A name under a handover witnesses that handover, nothing later. "
                    "Where the papers came from stays open; a like case waits at Ossuary Reach."),
        "nhal_veyr": ("Iven Lastshift: personal belongings wait in the receiving court outside the "
                      "mourners' hall for their rightful receivers. True register entries were "
                      "used to claim a debt on them, or a right to hold them back. Secure the "
                      "original record there and bring it back.",
                      "Iven Lastshift: he keeps the names and their right order and strikes the "
                      "attached claim. A kept name gives no stranger's clerk a say over the person "
                      "or their belongings. Where the papers came from stays open; a like case "
                      "waits at Ossuary Reach."),
    },
}

OBJECT = {"accord": ("dispatch_record", "Secure the dispatch record"),
          "throng": ("witness_record", "Secure the witness record")}
HOLD = 3


def quest_one(faction):
    """The envoys' travel quest to their own capital's guild leader."""
    qid = "story_%s_01" % faction
    t = TEXTS[qid]
    first = ORDER[faction][0]
    variants = []
    for capital in ORDER[faction]:
        zone, envoy = CAPITALS[capital][0], CAPITALS[capital][1]
        text, completion = t[capital]
        variants.append({"zone": zone, "givers": [envoy], "turnins": [leader(capital)],
                         "objectives": [{"npc": leader(capital)}],
                         "text": ph(text), "completion": ph(completion)})
    return {
        "id": qid, "line": LINE_ENVOY, "story": True, "min_level": 19, "level": 19, "requires": [],
        "title": t["title"], "text": ph(t["text"]), "completion": variants[0]["completion"],
        "objectives": [{"type": "talk", "npc": leader(first)}],
        "variants": variants,
        "rewards": {"weight": 1, "items": []},
        "lesson": "Chapter 1 opens at the envoy at 19 with no prerequisite; a walk to the capital's "
                  "Miner's Guild house.",
        "duration_min": 4,
    }


def quest_two(faction):
    """The leaders' use quest at the capital's town place and back."""
    qid = "story_%s_02" % faction
    t = TEXTS[qid]
    first = ORDER[faction][0]
    obj, label = OBJECT[faction]
    variants = []
    for capital in ORDER[faction]:
        zone = CAPITALS[capital][0]
        text, completion = t[capital]
        variants.append({"zone": zone, "givers": [leader(capital)], "turnins": [leader(capital)],
                         "objectives": [{"place": place(capital)}],
                         "text": ph(text), "completion": ph(completion)})
    return {
        "id": qid, "line": LINE_GUILD, "story": True, "min_level": 20, "level": 20,
        "requires": ["story_%s_01" % faction],
        "title": t["title"], "text": ph(t["text"]), "completion": variants[0]["completion"],
        "objectives": [{"type": "use", "place": place(first), "object": obj, "label": label,
                        "hold": HOLD}],
        "variants": variants,
        "rewards": {"weight": 3, "choices": [
            {"item": "grug_alchemy:potion_healing_t2", "count": 2},
            {"item": "grug_alchemy:potion_mana_t2", "count": 2}]},
        "lesson": "A spot in the capital town (a town place) and back; the leader decides the "
                  "capital's case, the papers' source stays open.",
        "duration_min": 6,
    }


# The text fields (lane BANDTEXT's since Round 59): --check compares the rest,
# the structure.
TEXT_FIELDS = ("title", "text", "texts", "completion")
VARIANT_TEXT_FIELDS = ("text", "completion")


def structure(text):
    """A quest file's JSON without its texts (titles, texts, a giver's or
    race's texts, completions, a variant's text and completion): ids, hubs,
    givers and turn-ins, lines, levels, requirements, story, objectives,
    places, rewards and the design notes."""
    data = json.loads(text)
    for quest in data.get("quests") or []:
        for key in TEXT_FIELDS:
            quest.pop(key, None)
        for variant in quest.get("variants") or []:
            for key in VARIANT_TEXT_FIELDS:
                variant.pop(key, None)
    return data


OURS = {"story_accord_01", "story_accord_02", "story_throng_01", "story_throng_02"}


def build():
    """{path: text} of the six capital files as the script writes them."""
    home = {"highcourt": [quest_one("accord"), quest_two("accord")],
            "gor_drazhak": [quest_one("throng"), quest_two("throng")]}
    out = {}
    for capital, (zone, envoy, old_line, _socket) in CAPITALS.items():
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text(encoding="utf-8"))
        # Round 60 CAPITALS flagged the six files reworked; chapter 1 stays as
        # this script wrote it (their own generator, tools/r60_capitals).
        hub_id = capital + "_guild"
        hubs = [h for h in data["hubs"] if h.get("id") != hub_id]
        for hub in hubs:
            for giver in hub["givers"]:
                if giver["npc"] == envoy:
                    giver["lines"] = [LINE_ENVOY if line == old_line else line for line in giver["lines"]]
                    assert giver["lines"] == [LINE_ENVOY, "front"], (zone, giver["lines"])
        # Anchored at the zone, as the camps' foreman hubs are: the atlas
        # knows a guild NPC by its settlement key, not the anchor id a
        # settlement anchor resolves to (validate.py --atlas E-giver-hub).
        hubs.append({"id": hub_id, "anchor": "zone",
                     "givers": [{"npc": leader(capital), "lines": [LINE_GUILD]}]})
        data["hubs"] = hubs
        quests = [q for q in data["quests"] if q["id"] not in OURS]
        for quest in quests:
            if quest["line"] == old_line:
                quest["line"] = LINE_ENVOY
        data["quests"] = home.get(capital, []) + quests
        # Round 65 ruling 3: a quest names only its level (accepted from
        # level - 2); the minimum levels written above are history.
        for quest in data["quests"]:
            quest.pop("min_level", None)
        out[path] = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="exit 1 when a file would change")
    args = parser.parse_args()
    differ = 0
    for path, text in build().items():
        shipped = path.read_text(encoding="utf-8")
        if args.check:
            differ += structure(shipped) != structure(text)
        elif shipped != text:
            differ += 1
            path.write_text(text, encoding="utf-8")
    print("%d of %d capital files %s" % (differ, len(CAPITALS), "differ" if args.check else "written"))
    return 1 if args.check and differ else 0


if __name__ == "__main__":
    sys.exit(main())
