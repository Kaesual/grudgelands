#!/usr/bin/env python3
"""Round 83's end-to-end scenario of character.delete (round83-plan.md §4 DEL
goal 6, ruling 6): a real headless server, one real client on a private Xvfb
display, the fake bridge of tools/r691_bridge (imported) in accounts mode,
and the disposable probe grug_probe_r83_del.

Boot 1 (setup): Vexa83, Tolm47 and Holder5 (the server's admin name) are
        created through the client; Vexa83 is bound to a website account;
        the probe seeds Vexa83 into every store of plan §3.2 and the
        references to it into Holder5's data; Tolm47 gets a letter and a
        right in Holder5's claim. Between the boots the clan (Vexa83 leads,
        Tolm47, Holder5 captain) and the party (Vexa83 leads, Holder5) are
        written into the world's mod storage.
Boot 2 (delete): a wrong character id, the admin's character, too little
        time; Vexa83 deleted online (a repeated delivery stays silent, the
        disconnect text, the timing of each step), again (unknown_target);
        Tolm47 deleted offline; a clean shutdown; then every world database
        and file is searched for both names in any case and both ids against
        an explicit allow-list (plan §3.2 "Stays").
Boot 3 (rejoin): Tolm47 again in a later boot (unknown_target); a client
        joins as Vexa83: a new character with a new id that adopts nothing.

Called by run.sh, which holds the temp directories. Isolation as in
tools/luanti_headless.sh."""

import json
import os
import shutil
import signal
import socket
import sqlite3
import subprocess
import sys
import time
from compression import zstd
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "r691_bridge"))
from fake_bridge import Accounts, Bridge  # noqa: E402

REPO = HERE.parent.parent
OUT = Path(sys.argv[1])
ROOT = Path(sys.argv[2])
CAP = Path(sys.argv[3])
DISPLAY = sys.argv[4]
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "420"))
TOKEN = os.urandom(32).hex()
WORLD = ROOT / "world"
VEXA, TOLM, HOLD = "Vexa83", "Tolm47", "Holder5"
PROBE_FILES = {"r83_in", "r83_in.tmp", "r83_out"}

checks = []
notes = {}


def check(ok, label, detail=""):
    checks.append({"ok": bool(ok), "label": label, "detail": str(detail)[:600]})
    print(("ok   " if ok else "FAIL ") + label + (f"  [{detail}]" if not ok else ""), flush=True)
    return ok


def free_port(kind):
    with socket.socket(socket.AF_INET, kind) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait(what, test, limit=120.0, step=0.2):
    end = time.time() + limit
    while time.time() < end:
        value = test()
        if value:
            return value
        time.sleep(step)
    raise TimeoutError("waited for " + what)


class Server:
    """As tools/r691_bridge/scenario.py's, with this probe."""

    def __init__(self, conf, label):
        self.port = free_port(socket.SOCK_DGRAM)
        self.label = label
        lines = (REPO / "minetest.conf").read_text()
        lines += f"\nport = {self.port}\nbind_address = 127.0.0.1\nserver_announce = false\n"
        lines += "fixed_map_seed = 42\nmobs_spawn = false\n"
        lines += "".join(f"{key} = {value}\n" for key, value in conf.items())
        path = ROOT / "bridge.conf"
        path.write_text(lines)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port),
                   PROBE=str(HERE / "grug_probe_r83_del"), LC_ALL="C")
        self.logfile = self.next_log()
        self.output = open(OUT / f"headless-{label}.txt", "w")
        self.process = subprocess.Popen(
            [str(REPO / "tools/luanti_headless.sh"), str(SERVER_TIMEOUT), "--config", str(path)],
            env=env, stdout=self.output, stderr=subprocess.STDOUT)
        self.request_id = 0
        for name in PROBE_FILES:
            (WORLD / name).unlink(missing_ok=True)

    @staticmethod
    def next_log():
        log, index = ROOT / "server.log", 2
        while log.exists():
            log, index = ROOT / f"server.{index}.log", index + 1
        return log

    def log_text(self):
        try:
            return self.logfile.read_text(errors="replace")
        except FileNotFoundError:
            return ""

    def wait_listening(self):
        wait("the server", lambda: "listening on" in self.log_text(), 240, 0.5)

    def probe(self, op, **fields):
        self.request_id += 1
        fields.update(id=self.request_id, op=op)
        temp = WORLD / "r83_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r83_in")

        def answer():
            try:
                row = json.loads((WORLD / "r83_out").read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                return None
            return row if row.get("id") == self.request_id else None
        # core.write_json writes an empty table as null.
        result = wait("the probe: " + op, answer, 30)["result"] or {}
        if "probe_error" in result:
            raise RuntimeError(op + ": " + result["probe_error"])
        return result

    def stop(self):
        try:
            self.probe("shutdown")
        except TimeoutError:
            pass
        status = self.process.wait(timeout=60)
        self.output.close()
        shutil.copy(self.logfile, OUT / f"server-{self.label}.log")
        return status


class Client:
    """One real client process; the media cache stays between joins."""
    count = 0

    def __init__(self, server, name):
        Client.count += 1
        self.log = CAP / f"client{Client.count}.log"
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        env["DISPLAY"] = DISPLAY
        self.process = subprocess.Popen(
            ["timeout", "--kill-after=5", "200", "flatpak", "run", "--command=luanti",
             "--socket=x11", "--nosocket=wayland", f"--filesystem={CAP}",
             f"--env=DISPLAY={DISPLAY}", "--env=SDL_VIDEODRIVER=x11",
             "--env=__GLX_VENDOR_LIBRARY_NAME=mesa", "--env=LIBGL_ALWAYS_SOFTWARE=1",
             f"--env=LUANTI_USER_PATH={CAP}/user", f"--env=XDG_CACHE_HOME={CAP}/xdg/cache",
             f"--env=XDG_DATA_HOME={CAP}/xdg/data", f"--env=XDG_CONFIG_HOME={CAP}/xdg/config",
             "--env=LC_ALL=C", "org.luanti.luanti", "--go", "--address", "127.0.0.1",
             "--port", str(server.port), "--name", name, "--config", str(CAP / "client.conf"),
             "--logfile", str(self.log)],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def log_text(self):
        try:
            return self.log.read_text(errors="replace")
        except FileNotFoundError:
            return ""

    def stop(self):
        subprocess.run(["pkill", "-TERM", "-f", f"luanti.bin --go .*--logfile {self.log}"], check=False)
        try:
            self.process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            subprocess.run(["pkill", "-KILL", "-f", f"luanti.bin --go .*--logfile {self.log}"],
                           check=False)
            self.process.wait(timeout=15)
        if self.log.exists():
            shutil.copy(self.log, OUT / self.log.name)


class Driver:
    """Command ids carry the boot's label: the fake bridge keeps every result
    of every boot, so an id used again in a later boot would find an old one."""

    def __init__(self, bridge, label):
        self.bridge = bridge
        self.label = label
        self.next_id = 0

    def queue(self, kind, args, expires=None, command_id=None):
        self.next_id += 1
        command_id = command_id or f"{self.label}-{self.next_id:04d}"
        with self.bridge.lock:
            self.bridge.commands.append({"id": command_id, "type": kind, "args": args,
                                         "expires_at": expires or int(time.time()) + 60})
        return command_id

    def results_of(self, command_id):
        with self.bridge.lock:
            return [row for row in self.bridge.results if row["id"] == command_id]

    def result(self, command_id, limit=60):
        return wait("the result of " + command_id, lambda: (self.results_of(command_id) or [None])[-1],
                    limit, 0.1)

    def expect(self, args, code, label, **more):
        row = self.result(self.queue("character.delete", args, **more))
        check(row["code"] == code and row["status"] == ("done" if code == "ok" else "failed"),
              f"character.delete: {label}", row)
        return row

    def online(self, test, label):
        try:
            wait(label, lambda: self.bridge.online is not None and test(self.bridge.online), 60)
            return check(True, label)
        except TimeoutError:
            return check(False, label, self.bridge.online)


def join(server, driver, name, ready=True):
    client = Client(server, name)
    driver.online(lambda rows: any(r["name"] == name for r in rows), f"{name} is online")
    if not ready:
        return client, None
    row = wait("the arrival of " + name, lambda: (lambda r: r if r.get("done") else None)(
        server.probe("ready", name=name)), 180, 1)
    return client, row


def leave(driver, client, name):
    client.stop()
    driver.online(lambda rows: not any(r["name"] == name for r in rows), f"{name} left")


def bridge_conf(bridge):
    return {"secure.http_mods": "grug_bridge", "grug_bridge.url": f"http://127.0.0.1:{bridge.port}",
            "grug_bridge.token": TOKEN, "name": HOLD}


def wait_list(bridge):
    wait("the account list", lambda: bridge.requests and
         bridge.requests[-1].get("accounts_version") == bridge.accounts.version, 30)


#
# Boot 1
#

def boot_setup(bridge):
    server = Server(bridge_conf(bridge), "setup")
    server.wait_listening()
    driver = Driver(bridge, "setup")
    ids, pos = {}, None
    for name in (VEXA, TOLM, HOLD):
        client, row = join(server, driver, name)
        ids[name] = row["id"]
        pos = pos or row["pos"]
        if name == VEXA:
            with bridge.lock:
                bridge.accounts.do_bind(VEXA, "a_test1")
            wait_list(bridge)
            check(server.probe("report", name=VEXA).get("account") == "a_test1", "setup: Vexa83 is bound")
        if name == HOLD:
            server.probe("favourite", name=HOLD, other=VEXA)
        leave(driver, client, name)
    seeded = server.probe("seed", victim=VEXA, other=HOLD, third=TOLM, at=pos)
    report = server.probe("report", name=VEXA)
    # Its letters: the gift, Holder5's letter and the game's own welcome.
    check(report.get("letters", 0) >= 2 and report.get("sent") == 1 and report.get("tickets") == 1 and
          report.get("claims") == 1 and report.get("rights") == 1 and report.get("recovered") == 1 and
          report.get("mail_index") == VEXA and report.get("index") == ids[VEXA],
          "setup: Vexa83 is in every store", report)
    check(server.probe("node", pos=seeded["stone"])["name"] == "grug_housing:claim_stone",
          "setup: its Claim Stone stands")
    check(server.stop() == 0, "setup: a clean boot")
    return ids, seeded


def lua_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def seed_groups():
    """The clan and the party, as their mods store them (core.serialize's
    format, a Lua table constructor), into the world's mod storage. The
    launcher's world.mt names no mod_storage_backend, so the engine keeps
    the "files" backend: one JSON object per mod in world/mod_storage/."""
    clans = ("return {next_id = 1, clans = {[\"1\"] = {faction = \"accord\", members = {"
             f"{{name = {lua_string(VEXA)}, role = \"leader\", level = 1}}, "
             f"{{name = {lua_string(TOLM)}, role = \"member\", level = 1}}, "
             f"{{name = {lua_string(HOLD)}, role = \"captain\", level = 1}}}}}}}}}}")
    parties = ("return {next_id = 1, groups = {[1] = {faction = \"accord\", "
               f"leader = {lua_string(VEXA)}, members = {{{lua_string(VEXA)}, {lua_string(HOLD)}}}, "
               f"levels = {{[{lua_string(VEXA)}] = 1, [{lua_string(HOLD)}] = 1}}}}}}}}")
    folder = WORLD / "mod_storage"
    folder.mkdir(exist_ok=True)
    for mod, key, value in (("grug_clans", "clans", clans), ("grug_parties", "parties", parties)):
        path = folder / mod
        entries = json.loads(path.read_text()) if path.exists() else {}
        entries[key] = value
        path.write_text(json.dumps(entries))


#
# Boot 2
#

def boot_delete(bridge, ids, seeded):
    server = Server(bridge_conf(bridge), "delete")
    server.wait_listening()
    driver = Driver(bridge, "delete")
    wait("the first request", lambda: bridge.requests and
         "characters.delete" in (bridge.requests[-1].get("capabilities") or []), 30)
    check(True, "the capability characters.delete")
    hold = server.probe("report", name=HOLD)
    check(hold.get("clan_role") == "captain" and hold.get("party") == 2, "delete: the clan and party loaded", hold)
    vexa = server.probe("report", name=VEXA)
    check(vexa.get("clan_role") == "leader", "delete: Vexa83 leads the clan", vexa)

    driver.expect({"name": VEXA, "admin": "jan", "character_id": "f" * 32}, "unknown_target",
                  "a wrong character id")
    check(server.probe("report", name=VEXA) == vexa, "a wrong character id changes nothing")
    driver.expect({"name": VEXA.lower(), "admin": "jan"}, "unknown_target", "another letter case")
    row = driver.expect({"name": HOLD, "admin": "jan"}, "refused", "the server admin's character")
    check(row["message"] == f"{HOLD} is the server administrator's character.", "the refusal's message",
          row["message"])
    driver.expect({"name": VEXA, "admin": "jan"}, "expired", "too little time",
                  expires=int(time.time()) + 5)
    check(server.probe("report", name=VEXA) == vexa, "the refusals change nothing")

    # Online.
    client, _ = join(server, driver, VEXA)
    server.probe("watch", name=VEXA)
    log_mark = len(server.log_text())
    sent_at = time.time()
    command = driver.queue("character.delete", {"name": VEXA, "admin": "jan", "character_id": ids[VEXA]})
    time.sleep(1.0)
    with bridge.lock:  # delivered again while it runs
        bridge.commands.append({"id": command, "type": "character.delete",
                                "args": {"name": VEXA, "admin": "jan", "character_id": ids[VEXA]},
                                "expires_at": int(time.time()) + 60})
    row = driver.result(command)
    notes["online_answer_seconds"] = round(time.time() - sent_at, 2)
    check(row["code"] == "ok" and row["message"] ==
          f"{VEXA} (character {ids[VEXA]}) deleted by admin jan.", "online: ok with its message", row)
    time.sleep(3)
    check(len(driver.results_of(command)) == 1, "online: the repeated delivery stayed silent",
          driver.results_of(command))
    text = "This character was deleted on the website."
    check(wait("the text at the client", lambda: text in client.log_text() or None, 15, 0.5),
          "online: the client read the disconnect text")
    check("Kicked:" not in client.log_text(), "online: no Kicked: before it")
    client.stop()
    times = server.probe("timing", name=VEXA).get("times") or []
    base = next((t["us"] for t in times if t["what"] == "disconnect"), None)
    notes["online_timing_ms"] = [(t["what"], round((t["us"] - base) / 1000)) for t in times] if base else times
    order = [t["what"] for t in times]
    check(order[:1] == ["watch"] and "disconnect" in order and "on_leaveplayer" in order and
          "objects_by_guid=nil" in order and order.count("clear") == 2 and
          order.index("disconnect") < order.index("on_leaveplayer") < order.index("objects_by_guid=nil")
          < order.index("clear") and order[-1].startswith("remove_player=0"),
          "online: disconnect, leave, gone from objects_by_guid, clear, clear, removal", order)
    log = server.log_text()[log_mark:]
    lines = [line for line in log.splitlines() if VEXA.lower() in line.lower()]
    notes["online_log_lines_naming_it"] = lines
    deletion = [line for line in lines if "deleted by admin" in line]
    check(len(deletion) == 1 and "action" in deletion[0].lower() and ids[VEXA] in deletion[0]
          and "jan" in deletion[0], "online: one action line with name, id and admin", deletion)
    check(sum(ids[VEXA] in line for line in log.splitlines()) == 1, "online: the id in no other line")
    after = server.probe("report", name=VEXA)
    check(not after.get("auth") and after.get("index") == "tombstone" and after.get("account") is None and
          after.get("letters") == 0 and after.get("sent") == 0 and after.get("tickets") == 0 and
          after.get("mail_index") is None and after.get("clan_role") is None and after.get("party") == 0 and
          after.get("claim_state") == "never" and after.get("claims") == 0 and after.get("rights") == 0 and
          after.get("recovered") == 0, "online: nothing of Vexa83 is left", after)
    check(server.probe("node", pos=seeded["stone"])["name"] != "grug_housing:claim_stone",
          "online: its Claim Stone is gone")
    check(server.probe("node", pos=seeded["chest"])["name"] == "default:chest_locked",
          "online: its locked chest stands (ruling 9)")
    hold = server.probe("report", name=HOLD)
    check(hold.get("clan_role") == "leader" and hold.get("party") == 0, "online: Holder5 leads the clan, "
          "the party of two dissolved (rulings 2, 19)", hold)
    driver.expect({"name": VEXA, "admin": "jan"}, "unknown_target", "deleted: unknown_target")
    # The website removes its row on ok: the list version rises as at an unlink.
    with bridge.lock:
        bridge.accounts.do_unlink(VEXA)
    wait_list(bridge)

    # Offline.
    server.probe("watch", name=TOLM)
    sent_at = time.time()
    row = driver.expect({"name": TOLM, "admin": "jan", "character_id": ids[TOLM]}, "ok", "offline")
    notes["offline_answer_seconds"] = round(time.time() - sent_at, 2)
    times = server.probe("timing", name=TOLM).get("times") or []
    notes["offline_timing_ms"] = [(t["what"], round((t["us"] - times[0]["us"]) / 1000)) for t in times]
    check([t["what"] for t in times][-3:] == ["clear", "clear", "remove_player=0"],
          "offline: clear, clear, removal", times)
    after = server.probe("report", name=TOLM)
    check(not after.get("auth") and after.get("index") == "tombstone" and after.get("letters") == 0 and
          after.get("clan_role") is None and after.get("rights") == 0, "offline: nothing of Tolm47 is left", after)
    check(server.probe("report", name=HOLD).get("clan_role") is None, "offline: the clan of two dissolved")
    driver.expect({"name": TOLM, "admin": "jan"}, "unknown_target", "offline: again")
    check(server.stop() == 0, "delete: a clean boot (no ERROR line)")


#
# The world search
#

KEYS = {"entries": ("modname", "key"), "player_metadata": ("player", "metadata"),
        "blocks": ("x", "y", "z"), "player": ("name",), "auth": ("name",),
        "user_privileges": ("id", "privilege"), "player_inventories": ("player", "inv_id"),
        "player_inventory_items": ("player", "inv_id", "slot_id")}


def as_bytes(value):
    if value is None:
        return b""
    if isinstance(value, bytes):
        return value
    return str(value).encode()


def block_bytes(data):
    # Map format 29 and later: the version byte, then one zstd stream.
    if data and data[0] >= 29:
        return data[:1] + zstd.decompress(data[1:])
    return data


def search_world(terms):
    """Every hit of every term: (file, table, row identity, term, count)."""
    hits, raw = [], []
    for path in sorted(WORLD.rglob("*")):
        if path.is_dir() or path.name in PROBE_FILES:
            continue
        rel = str(path.relative_to(WORLD))
        data = path.read_bytes()
        if path.parent.name == "mod_storage" and path.parent.parent == WORLD:
            try:
                entries = json.loads(data)
            except ValueError:
                entries = None
            if isinstance(entries, dict):
                for key, value in entries.items():
                    blob = (key + "\0" + str(value)).encode().lower()
                    for term in terms:
                        if term in blob:
                            hits.append(("mod_storage", "entries", (path.name, key), term.decode(),
                                         blob.count(term)))
                continue
        if path.suffix == ".sqlite":
            raw.append((rel, {t.decode(): data.lower().count(t) for t in terms}))
            db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")]
            for table in tables:
                cursor = db.execute(f"SELECT * FROM `{table}`")
                columns = [c[0] for c in cursor.description]
                for row in cursor:
                    record = dict(zip(columns, row))
                    if table == "blocks":
                        record["data"] = block_bytes(record["data"])
                    blob = b"\0".join(as_bytes(v) for v in record.values()).lower()
                    ident = tuple(as_bytes(record[k]).decode(errors="replace")
                                  for k in KEYS.get(table, columns[:1]))
                    for term in terms:
                        if term in blob:
                            hits.append((rel, table, ident, term.decode(), blob.count(term)))
            db.close()
        else:
            for term in terms:
                if term in data.lower():
                    hits.append((rel, "", (), term.decode(), data.lower().count(term)))
    return hits, raw


def block_of(pos):
    return tuple(str(v // 16) for v in (pos["x"], pos["y"], pos["z"]))


def world_search(ids, seeded):
    terms = [VEXA.lower().encode(), TOLM.lower().encode(), ids[VEXA].encode(), ids[TOLM].encode()]
    hits, raw = search_world(terms)
    chest = block_of(seeded["chest"])
    vexa = VEXA.lower()
    # Plan §3.2 "Stays", each with its ruling; nothing else may name either
    # character or carry either id.
    allowed = [
        ("mod_storage", "entries", ("grug_accounts", f"id:{vexa}"), vexa,
         "the id index entry of the name, now the tombstone (web-accounts.md §2)"),
        ("mod_storage", "entries", ("grug_accounts", f"id:{TOLM.lower()}"), TOLM.lower(),
         "the id index entry of the name, now the tombstone (web-accounts.md §2)"),
        ("mod_storage", "entries", ("grug_mail", f"box:{HOLD}"), vexa,
         "Holder5's letter from Vexa83 (ruling 1)"),
        ("mod_storage", "entries", ("grug_mail", f"sent:{HOLD}"), vexa,
         "Holder5's sent copy to Vexa83 (ruling 1)"),
        ("mod_storage", "entries", ("grug_mail", "tickets"), vexa,
         "Holder5's report of Vexa83's letter (ruling 1)"),
        ("players.sqlite", "player_metadata", (HOLD, "grug_parties:favorites"), vexa,
         "Holder5's party favourites (ruling 18)"),
        ("map.sqlite", "blocks", (chest[0], chest[1], chest[2]), vexa,
         "the locked chest's owner and infotext (rulings 4, 9)"),
    ]
    found, unexpected = set(), []
    for hit in hits:
        rule = next((r for r in allowed if r[:4] == hit[:4]), None)
        if rule:
            found.add(rule)
        else:
            unexpected.append(hit)
    notes["search_hits"] = [list(h[:3]) + [h[3], h[4]] for h in hits]
    notes["search_raw_bytes_sqlite"] = raw
    check(not unexpected, "search: no name or id outside the allow-list", unexpected)
    for rule in allowed:
        check(rule in found, f"search: found as allowed: {rule[4]} (the search sees that store)")
    tickets = [h for h in hits if h[2] == ("grug_mail", "tickets")]
    # The report: its subject, the reported letter's sender and subject.
    check(tickets and tickets[0][4] == 3, "search: the tickets name Vexa83 only in Holder5's report", tickets)


#
# Boot 3
#

def boot_rejoin(bridge, ids):
    server = Server(bridge_conf(bridge), "rejoin")
    server.wait_listening()
    driver = Driver(bridge, "rejoin")
    row = driver.expect({"name": TOLM, "admin": "jan"}, "unknown_target", "a later boot: unknown_target")
    check(row["message"] == f"There is no character called {TOLM}.", "a later boot: the answer about Tolm47",
          row["message"])
    client, _ = join(server, driver, VEXA, ready=False)
    report = wait("the new character's id", lambda: (lambda r: r if r.get("character_id") else None)(
        server.probe("report", name=VEXA)), 60, 1)
    check(report.get("character_id") != ids[VEXA] and report.get("index") == report.get("character_id"),
          "rejoin: a new character id", report)
    check(report.get("account") is None and report.get("letters") == 0 and report.get("clan_role") is None and
          report.get("party") == 0 and report.get("claim_state") == "never" and report.get("rights") == 0 and
          report.get("recovered") == 0 and report.get("class") is None, "rejoin: it adopts nothing", report)
    client.stop()
    check(server.stop() == 0, "rejoin: a clean boot")


def main():
    bridge = Bridge(free_port(socket.SOCK_STREAM), TOKEN)
    account_lines = []
    bridge.accounts = Accounts(out=account_lines.append)
    bridge.start()
    try:
        ids, seeded = boot_setup(bridge)
        seed_groups()
        boot_delete(bridge, ids, seeded)
        world_search(ids, seeded)
        boot_rejoin(bridge, ids)
    except Exception as error:  # the report names it; cleanup stays with run.sh
        check(False, "the scenario ran to its end", repr(error))
    finally:
        bridge.stop()
    (OUT / "results.json").write_text(json.dumps(checks, indent=1))
    (OUT / "notes.json").write_text(json.dumps(notes, indent=1))
    (OUT / "accounts.txt").write_text("\n".join(account_lines) + "\n")
    failed = [row for row in checks if not row["ok"]]
    print(f"r83 scenario: {len(checks) - len(failed)} of {len(checks)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(2))
    sys.exit(main())
