#!/usr/bin/env python3
"""The 0.69.1 engine scenario: grug_bridge in a real headless server, one real
client on a private Xvfb display, the fake bridge on the other side.

Boot 1: the token is missing, so the mod stays inert.
Boot 2: every command type with success and refusal, a repeated id, dropped
        responses, the chat hook, kick, a ban online, at pre-join and expiring.
Boot 3: the same world with the bridge failing: the stored ban holds; then the
        bridge answers and sees a new boot and the held list's version.

Called by run.sh, which holds the temp directories. Isolation as in
tools/luanti_headless.sh: every engine process has a fresh temp dir as its user
path and XDG dirs, a timeout, and none of them outlives this run."""

import json
import os
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

from fake_bridge import Bridge

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
OUT = Path(sys.argv[1])
ROOT = Path(sys.argv[2])
CAP = Path(sys.argv[3])
XVFB = os.environ["XVFB"]
DISPLAY = sys.argv[4]
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "420"))
TOKEN = secrets.token_hex(32)
WORLD = ROOT / "world"
PLAYER = "Rowan"

checks = []


def check(ok, label, detail=""):
    checks.append({"ok": bool(ok), "label": label, "detail": str(detail)[:300]})
    print(("ok   " if ok else "FAIL ") + label + (f"  [{detail}]" if not ok else ""), flush=True)


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
    def __init__(self, conf, label):
        self.port = free_port(socket.SOCK_DGRAM)
        self.label = label
        lines = (REPO / "minetest.conf").read_text()
        lines += f"\nport = {self.port}\nbind_address = 127.0.0.1\nserver_announce = false\n"
        lines += "fixed_map_seed = 42\nmobs_spawn = false\n"
        lines += "".join(f"{key} = {value}\n" for key, value in conf.items())
        # The launcher's own config lacks these and secure.* cannot come from
        # the game's minetest.conf, so a second --config replaces it.
        path = ROOT / "bridge.conf"
        path.write_text(lines)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port),
                   PROBE=str(HERE / "grug_probe_r691_bridge"), LC_ALL="C")
        self.logfile = self.next_log()
        self.output = open(OUT / f"headless-{label}.txt", "w")
        self.process = subprocess.Popen(
            [str(REPO / "tools/luanti_headless.sh"), str(SERVER_TIMEOUT),
             "--config", str(path)],
            env=env, stdout=self.output, stderr=subprocess.STDOUT)
        self.request_id = 0
        for name in ("r691_in", "r691_out"):
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
        temp = WORLD / "r691_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r691_in")

        def answer():
            try:
                row = json.loads((WORLD / "r691_out").read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                return None
            return row if row.get("id") == self.request_id else None
        return wait("the probe: " + op, answer, 30)["result"]

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

    def __init__(self, server, name=PLAYER):
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
        subprocess.run(["pkill", "-TERM", "-f", f"luanti.bin --go .*--logfile {self.log}"],
                       check=False)
        try:
            self.process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            subprocess.run(["pkill", "-KILL", "-f", f"luanti.bin --go .*--logfile {self.log}"],
                           check=False)
            self.process.wait(timeout=15)
        shutil.copy(self.log, OUT / self.log.name) if self.log.exists() else None


class Driver:
    def __init__(self, bridge):
        self.bridge = bridge
        self.next_id = 0

    def send(self, kind, args, expires=None, command_id=None):
        """Queues a command and waits for a result beyond those seen so far."""
        self.next_id += 1
        command_id = command_id or f"cmd{self.next_id:04d}"
        with self.bridge.lock:
            seen = sum(1 for row in self.bridge.results if row["id"] == command_id)
            self.bridge.commands.append({"id": command_id, "type": kind, "args": args,
                                         "expires_at": expires or int(time.time()) + 120})

        def result():
            with self.bridge.lock:
                rows = [row for row in self.bridge.results if row["id"] == command_id]
            return rows[-1] if len(rows) > seen else None
        return wait("the result of " + kind, result, 40, 0.1)

    def expect(self, kind, args, code, label, **more):
        row = self.send(kind, args, **more)
        check(row["code"] == code and row["status"] == ("done" if code == "ok" else "failed"),
              f"{kind}: {label}", row)
        return row

    def events(self, kind):
        with self.bridge.lock:
            rows = [self.bridge.events[key] for key in sorted(self.bridge.events)]
        return [row for row in rows if row["type"] == kind]

    def event(self, kind, test, label):
        try:
            found = wait("the event " + kind, lambda: [e for e in self.events(kind) if test(e)], 15)
        except TimeoutError:
            found = []
        check(found, label, kind)
        return found[-1] if found else None

    def online(self, test, label):
        try:
            wait(label, lambda: self.bridge.online is not None and test(self.bridge.online), 30)
            check(True, label)
        except TimeoutError:
            check(False, label, self.bridge.online)


def join(server, driver, ready=True):
    client = Client(server)
    driver.online(lambda rows: any(r["name"] == PLAYER for r in rows), "the client is online")
    if ready:
        def arrived():
            return server.probe("ready", name=PLAYER).get("done")
        wait("the arrival", arrived, 180, 1)
        core_state = server.probe("state", name=PLAYER)
        check(core_state.get("online"), "the character arrived", core_state)
    return client


def boot_inert(bridge):
    server = Server({"secure.http_mods": "grug_bridge",
                     "grug_bridge.url": f"http://127.0.0.1:{bridge.port}"}, "inert")
    server.wait_listening()
    time.sleep(8)
    check(server.probe("status")["active"] is False, "inert: the mod says so")
    check(not bridge.requests, "inert: no request at all", len(bridge.requests))
    check("[grug_bridge] inert, missing: grug_bridge.token" in server.log_text(),
          "inert: one line names the token")
    check(server.stop() == 0, "inert: a clean boot")


def boot_main(bridge):
    server = Server({"secure.http_mods": "grug_bridge",
                     "grug_bridge.url": f"http://127.0.0.1:{bridge.port}/",
                     "grug_bridge.token": TOKEN}, "main")
    server.wait_listening()
    driver = Driver(bridge)
    wait("the first request", lambda: bridge.requests, 30)
    first = bridge.requests[0]
    check(first["protocol"] == 1, "request: protocol", first)
    check(re.fullmatch(r"[0-9a-f]{16}", first["boot"]), "request: boot", first["boot"])
    check(first["game_version"] == VERSION, "request: the game's version", first["game_version"])
    check(len(first["capabilities"]) == 10, "request: capabilities", first["capabilities"])
    check(first["banlist_version"] == 0, "request: no list yet")
    check(first.get("online") == [], "request: the first online list, empty", first.get("online"))
    check(bridge.bad_auth == 0, "request: the token")
    boot = first["boot"]

    bridge.resync = True
    driver.event("mail.snapshot_end", lambda e: True, "resync: an empty snapshot")

    # A character still being created.
    client = join(server, driver, ready=False)
    row = [r for r in bridge.online if r["name"] == PLAYER][0]
    check("class" not in row and "faction" not in row and "race" not in row,
          "online: no class, race or faction in creation", row)
    check(row.get("address"), "online: the address", row)
    check(row.get("joined_at"), "online: the join time", row)
    driver.expect("action.give_money", {"name": PLAYER, "copper": 5}, "refused", "in creation")
    driver.expect("action.give_xp", {"name": PLAYER, "amount": 5}, "refused", "in creation")
    driver.expect("action.give_item", {"name": PLAYER, "item": "default:dirt", "count": 1},
                  "refused", "in creation")
    wait("the arrival", lambda: server.probe("ready", name=PLAYER).get("done"), 180, 1)
    driver.online(lambda rows: [r for r in rows if r["name"] == PLAYER and
                                r.get("faction") == "accord" and r.get("race") == "human" and
                                r.get("class") == "warrior"],
                  "online: faction, race and class after creation")

    before = server.probe("state", name=PLAYER)
    # The two money grants of the at-most-once checks follow.
    row = driver.expect("action.give_money", {"name": PLAYER, "copper": 1000}, "ok", "success")
    state = server.probe("state", name=PLAYER)
    check(state["money"] == before["money"] + 1000, "the money arrived", state)
    check(any("An administrator gave you" in line for line in server.probe("lines")["feed"]),
          "the feed names the gift")
    driver.expect("action.give_money", {"name": PLAYER, "copper": 0}, "invalid_args", "bound")
    driver.expect("action.give_money", {"name": "Nobody", "copper": 5}, "unknown_target", "unknown")
    driver.expect("action.give_xp", {"name": PLAYER, "amount": 500}, "ok", "success")
    state = server.probe("state", name=PLAYER)
    check(state["xp"] == before["xp"] + 500, "the XP arrived, no race bonus", state)
    check(state["level"] > before["level"], "a level", state)
    driver.online(lambda rows: rows and rows[0]["level"] == state["level"],
                  "online: the new level")
    driver.expect("action.give_xp", {"name": PLAYER, "amount": 1000001}, "invalid_args", "bound")
    driver.expect("action.give_item", {"name": PLAYER, "item": "default:dirt", "count": 7},
                  "ok", "success")
    check(server.probe("state", name=PLAYER)["dirt"] == before["dirt"] + 7, "the item arrived")
    driver.expect("action.give_item", {"name": PLAYER, "item": "air", "count": 1},
                  "unknown_target", "air")
    driver.expect("action.give_item", {"name": PLAYER, "item": "grug_money:bag_of_coins", "count": 1},
                  "refused", "an empty bag")
    driver.expect("action.give_item", {"name": PLAYER, "item": "default:dirt", "count": 100},
                  "invalid_args", "over the stack")
    driver.expect("action.give_item", {"name": PLAYER, "item": "no:such", "count": 1},
                  "unknown_target", "unknown")
    driver.expect("action.grant_priv", {"name": PLAYER, "priv": "fly"}, "ok", "success")
    check("fly" in server.probe("state", name=PLAYER)["privs"], "the privilege arrived")
    driver.expect("action.grant_priv", {"name": PLAYER, "priv": "nope"}, "unknown_target", "unknown")
    driver.expect("action.revoke_priv", {"name": PLAYER, "priv": "fly"}, "ok", "success")
    check("fly" not in server.probe("state", name=PLAYER)["privs"], "the privilege went")
    driver.expect("action.revoke_priv", {"name": PLAYER, "priv": "nope"}, "unknown_target", "unknown")

    # Chat, both ways.
    driver.expect("chat.send", {"admin": "Jan", "text": "Hello\n\x1b(c@#ff0000)world"}, "ok", "success")
    lines = server.probe("lines")["chat"]
    check("[Admin]<Jan> Hello world" in lines, "chat.send: one clean line", lines)
    driver.expect("chat.send", {"admin": "Jan", "text": ""}, "invalid_args", "empty")
    answer = server.probe("chat", name=PLAYER, message="hello from the game")
    check(not answer["eaten"], "chat: the line stays the game's", answer)
    driver.event("chat", lambda e: e["name"] == PLAYER and e["text"] == "hello from the game",
                 "chat: a public line goes out")
    server.probe("chat", name=PLAYER, message="/msg Bob secret")
    driver.expect("action.revoke_priv", {"name": PLAYER, "priv": "shout"}, "ok", "no shout")
    answer = server.probe("chat", name=PLAYER, message="unheard")
    check(not answer["eaten"], "chat: without shout the engine still answers", answer)
    driver.expect("action.grant_priv", {"name": PLAYER, "priv": "shout"}, "ok", "shout again")
    server.probe("chat", name=PLAYER, message="heard again")
    driver.event("chat", lambda e: e["text"] == "heard again", "chat: shout is back")
    texts = [e["text"] for e in driver.events("chat")]
    check("unheard" not in texts, "chat: nothing from a player without shout", texts)
    check(not [t for t in texts if t.startswith("/") or "secret" in t],
          "chat: no command", texts)

    # Mail through the real grug_mail.
    server.probe("ticket", name=PLAYER, subject="First")
    first_ticket = driver.event("mail.ticket", lambda e: e["ticket"]["subject"] == "First",
                                "mail: a new ticket")["ticket"]
    check(first_ticket["faction"] == "accord", "mail: the stored record", first_ticket)
    tid = first_ticket["id"]
    letters = server.probe("state", name=PLAYER)["letters"]
    driver.expect("mail.answer", {"ticket_id": tid, "admin": "Jan", "body": "x" * 4001},
                  "invalid_args", "too long")
    driver.expect("mail.answer", {"ticket_id": 99999, "admin": "Jan", "body": "x"},
                  "unknown_target", "gone")
    driver.expect("mail.answer", {"ticket_id": tid, "admin": "Jan", "body": "Thanks"}, "ok", "success")
    driver.event("mail.ticket", lambda e: e["ticket"]["id"] == tid and e["ticket"]["answered"],
                 "mail: the answered ticket")
    check(server.probe("state", name=PLAYER)["letters"] == letters + 1, "mail: the answer arrived")
    driver.expect("mail.close", {"ticket_id": tid, "admin": "Jan"}, "refused", "already closed")
    server.probe("ticket", name=PLAYER, subject="Second")
    second = driver.event("mail.ticket", lambda e: e["ticket"]["subject"] == "Second",
                          "mail: a second ticket")["ticket"]["id"]
    driver.expect("mail.close", {"ticket_id": second, "admin": "Jan"}, "ok", "success")
    driver.event("mail.ticket", lambda e: e["ticket"]["id"] == second and
                 e["ticket"]["state"] == "closed", "mail: the closed ticket")
    driver.expect("mail.delete", {"ticket_id": second, "admin": "Jan"}, "ok", "success")
    driver.event("mail.ticket_removed", lambda e: e["id"] == second, "mail: the removal")
    driver.expect("mail.delete", {"ticket_id": second, "admin": "Jan"}, "unknown_target", "gone")
    driver.expect("mail.send", {"to": PLAYER, "subject": "S" * 61, "body": "B", "admin": "Jan"},
                  "invalid_args", "a long subject")
    driver.expect("mail.send", {"to": "Nobody", "subject": "S", "body": "B", "admin": "Jan"},
                  "unknown_target", "unknown")
    driver.expect("mail.send", {"to": PLAYER, "subject": "S", "body": "B", "admin": "Jan"}, "ok", "success")
    driver.expect("mail.broadcast", {"subject": "News", "body": "x" * 4001, "admin": "Jan"},
                  "invalid_args", "too long")
    driver.expect("mail.broadcast", {"subject": "News", "body": "Text", "admin": "Jan"}, "ok", "success")
    news = driver.event("mail.broadcast", lambda e: e["broadcast"]["subject"] == "News",
                        "mail: the announcement")["broadcast"]["id"]
    driver.expect("mail.broadcast_delete", {"broadcast_id": news, "admin": "Jan"}, "ok", "success")
    driver.event("mail.broadcast_removed", lambda e: e["id"] == news, "mail: its removal")
    driver.expect("mail.broadcast_delete", {"broadcast_id": news, "admin": "Jan"},
                  "unknown_target", "gone")
    with bridge.lock:
        for key in [k for k, e in bridge.events.items() if e["type"] == "mail.snapshot_end"]:
            del bridge.events[key]
    bridge.resync = True
    end = driver.event("mail.snapshot_end", lambda e: True, "resync: the end")
    check(end["ticket_ids"] == [tid], "resync: the ticket ids", end)
    check(end.get("broadcast_ids") in (None, []), "resync: no announcements left", end)

    # Refusals of the frame.
    driver.expect("no.such", {}, "unsupported", "unknown type")
    driver.expect("action.give_money", {"name": PLAYER, "copper": 5}, "expired", "past its time",
                  expires=int(time.time()) - 1)

    # A repeated id: the stored result, no second action.
    money = server.probe("state", name=PLAYER)["money"]
    first_run = driver.send("action.give_money", {"name": PLAYER, "copper": 111}, command_id="repeat")
    again = driver.send("action.give_money", {"name": PLAYER, "copper": 111}, command_id="repeat")
    check(again == first_run, "at most once: the stored result repeats", again)
    check(server.probe("state", name=PLAYER)["money"] == money + 111,
          "at most once: paid once")

    # A dropped response. The bridge has the request that carries the result,
    # the mod never hears so: it waits, then sends the same result again.
    money += 111
    bridge.drop_if = lambda request: any(r["id"] == "dropped" for r in request.get("results") or [])
    with bridge.lock:
        bridge.commands.append({"id": "dropped", "type": "action.give_money",
                                "args": {"name": PLAYER, "copper": 222},
                                "expires_at": int(time.time()) + 120})
    wait("two copies of the result",
         lambda: sum(1 for r in bridge.results if r["id"] == "dropped") >= 2, 30, 0.1)
    check(True, "dropped response: the result goes again")
    check(server.probe("state", name=PLAYER)["money"] == money + 222,
          "dropped response: paid once")
    money += 222

    # The same for an event: it comes again under its seq.
    bridge.drop_if = lambda request: any(e.get("text") == "before the drop"
                                         for e in request.get("events") or [])
    server.probe("chat", name=PLAYER, message="before the drop")
    wait("the event again", lambda: bridge.repeated_events > 0, 30)
    check(True, "dropped response: the event goes again under its seq")

    # A reply lost with a command in it: nothing ran, the command comes again
    # and runs once.
    bridge.drop_if = lambda request: True
    bridge.commands.append({"id": "lost", "type": "action.give_money",
                            "args": {"name": PLAYER, "copper": 333},
                            "expires_at": int(time.time()) + 120})
    wait("the result", lambda: [r for r in bridge.results if r["id"] == "lost"], 30, 0.1)
    check(server.probe("state", name=PLAYER)["money"] == money + 333,
          "a command in a lost reply runs once, when it comes again")
    check(bridge.most_in_flight == 1, "one request at a time", bridge.most_in_flight)

    # Kick: the leave path saves the character.
    money = server.probe("state", name=PLAYER)["money"]
    driver.expect("kick", {"name": "Nobody"}, "unknown_target", "unknown")
    driver.expect("kick", {"name": PLAYER, "reason": "Please read the rules."}, "ok", "success")
    driver.online(lambda rows: not rows, "kick: gone from the online list")
    check(wait("the reason at the client", lambda: "Kicked: Please read the rules." in
               client.log_text() or None, 15, 0.5), "kick: the client saw the reason")
    client.stop()
    driver.expect("kick", {"name": PLAYER}, "not_online", "offline")
    driver.expect("action.give_money", {"name": PLAYER, "copper": 5}, "not_online", "offline")

    client = join(server, driver)
    check(server.probe("state", name=PLAYER)["money"] == money, "kick: the character was saved")

    # A ban while online.
    bridge.banlist = {"version": 1, "entries": [{"name": PLAYER.lower(), "expires_at": None}]}
    driver.online(lambda rows: not rows, "ban: gone from the online list")
    check(wait("the ban at the client", lambda: "You are banned from this server." in
               client.log_text() or None, 15, 0.5), "ban: the client saw the exact text")
    check("Kicked: You are banned" not in client.log_text(), "ban: no Kicked: before it")
    client.stop()
    wait("the held version", lambda: bridge.requests[-1]["banlist_version"] == 1, 10)
    check(True, "ban: the mod holds version 1")

    # Refused at pre-join, with and without an end.
    client = Client(server)
    check(wait("the refusal", lambda: "You are banned from this server." in client.log_text()
               or None, 60, 0.5), "ban: refused at pre-join")
    client.stop()
    ends = int(time.time()) + 45
    bridge.banlist = {"version": 2, "entries": [{"name": PLAYER, "expires_at": ends}]}
    wait("version 2", lambda: bridge.requests[-1]["banlist_version"] == 2, 10)
    client = Client(server)
    stamp = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(ends))
    text = f"You are banned from this server. Ban ends: {stamp}."
    check(wait("the refusal", lambda: text in client.log_text() or None, 40, 0.5),
          "ban: the end date", text)
    client.stop()
    wait("the ban's end", lambda: time.time() > ends + 1, 60)
    client = join(server, driver)
    check(True, "ban: expired, the character joins")
    # The list that boot 3 must keep.
    bridge.banlist = {"version": 3, "entries": [{"name": PLAYER, "expires_at": None}]}
    driver.online(lambda rows: not rows, "ban: version 3")
    client.stop()
    check(bridge.bad_auth == 0, "every request carried the token")
    check(server.stop() == 0, "main: a clean boot")
    return boot


def boot_stored(bridge, old_boot):
    bridge.refuse = 503
    requests = len(bridge.requests)
    server = Server({"secure.http_mods": "grug_bridge",
                     "grug_bridge.url": f"http://127.0.0.1:{bridge.port}",
                     "grug_bridge.token": TOKEN}, "stored")
    server.wait_listening()
    client = Client(server)
    check(wait("the refusal", lambda: "You are banned from this server." in client.log_text()
               or None, 60, 0.5), "restart: the stored ban holds with the bridge down")
    client.stop()
    bridge.refuse = None
    wait("a request", lambda: len(bridge.requests) > requests, 80, 0.5)
    request = bridge.requests[requests]
    check(request["boot"] != old_boot, "restart: a new boot", request["boot"])
    check(request["banlist_version"] == 3, "restart: the held version", request["banlist_version"])
    check(request.get("online") == [], "restart: the first list", request.get("online"))
    check(server.stop() == 0, "stored: a clean boot")


def main():
    bridge = Bridge(free_port(socket.SOCK_STREAM), TOKEN)
    bridge.start()
    failure = None
    try:
        boot_inert(bridge)
        boot_stored(bridge, boot_main(bridge))
    except Exception as error:  # the report names it; cleanup stays with run.sh
        failure = repr(error)
        check(False, "the scenario ran to its end", failure)
    finally:
        bridge.stop()
    (OUT / "results.json").write_text(json.dumps(checks, indent=1))
    (OUT / "requests.json").write_text(json.dumps(bridge.requests[:200], indent=1))
    failed = [row for row in checks if not row["ok"]]
    print(f"r691 scenario: {len(checks) - len(failed)} of {len(checks)} checks passed")
    return 1 if failed else 0


VERSION = next(line.split("=")[1].strip() for line in (REPO / "game.conf").read_text().splitlines()
               if line.startswith("version"))

if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(2))
    sys.exit(main())
