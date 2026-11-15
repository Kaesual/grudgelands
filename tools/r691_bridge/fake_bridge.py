#!/usr/bin/env python3
"""A small bridge that speaks /v1/sync (docs/technical/web-bridge.md), for the
0.69.1 engine scenario. It records every request and answers from what its
caller queued. Alone it serves a realm by hand:

    python3 tools/r691_bridge/fake_bridge.py PORT TOKEN

prints each request as one JSON line and sends no commands.

With --accounts it also plays the website's part of
docs/technical/web-accounts.md (Round 79): two test accounts, a_test1 "Test One"
and a_test2 "Test Two", the list (version 1, empty, at once), link codes, the
answers to the link events with every refusal, the reservation, direct
bindings and account.set_password. It prints what happens instead of the
requests (--echo prints those as well, link codes masked) and reads commands
on stdin:

    code <account>              a new code for the account (printed here: this
                                terminal is the website's screen)
    grant <account> <reward>    revoke <account> <reward>
    unlink <name>               rename <account> <new name ...>
    delete <account>            the account and its bindings
    bind <name> <account>       a direct binding, as after a password check
                                (web-accounts.md §6a); the character must have
                                been online, for its character_id
    setpw <name> <password> [<account>]
                                account.set_password with an entry from
                                tools/web_accounts/luanti_password.py make_entry;
                                the account defaults to the name's binding
    send                        send the list (after --hold-list)
    state                       print accounts, bindings and codes
    help

Options for the test: --delay S (handle each link event S seconds after it
arrived, so the waiting states show), --code-minutes M (a code's validity,
10; 1 reaches expired_code quickly), --limit N (characters per account, 10;
1 reaches account_full), --already-linked NAME (the website holds a binding
for NAME that the game does not: already_linked; repeatable), --hold-list (no
list until `send`: the game shows no Account tab before its first list).

Example session (the game on the same machine, grug_bridge.url =
http://127.0.0.1:8080, grug_bridge.token = the token below):

    $ python3 tools/r691_bridge/fake_bridge.py 8080 $(printf 'a%.0s' {1..64}) --accounts --delay 3
    accounts: list version 1 sent
    code a_test1
    code for a_test1 (Test One): ABCDE-FGH23, valid 10 min
    event: link request from Rowan
    answer to Rowan: offer (Test One)
    event: link confirmation from Rowan
    bound Rowan to a_test1; list version 2
    grant a_test1 cloak:supporter
    list version 3
    setpw Rowan new-secret
    setpw Rowan: sent
    result of setpw Rowan: ok
"""

import argparse
import importlib.util
import json
import secrets
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Bridge:
    def __init__(self, port, token):
        self.port, self.token = port, token
        self.lock = threading.Lock()
        self.requests = []       # every parsed request, in arrival order
        self.results = []        # every result seen, duplicates included
        self.events = {}         # (boot, seq) -> event, as a real bridge stores
        self.repeated_events = 0 # events that arrived a second time
        self.online = None       # the newest complete list
        self.commands = []       # waiting to be delivered
        self.banlist = None      # the list to offer
        self.resync = False
        self.drop_if = None      # test(request): record it, then hang up
        self.refuse = None       # an HTTP status to answer with instead
        self.in_flight = 0
        self.most_in_flight = 0
        self.bad_auth = 0
        self.echo = False
        self.accounts = None     # an Accounts: the website's part of accounts
        bridge = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                bridge.handle(self)

        self.server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def start(self):
        self.thread.start()

    def stop(self):
        self.server.shutdown()
        self.server.server_close()

    def answer(self, handler, status, payload):
        data = json.dumps(payload).encode()
        handler.send_response(status)
        handler.send_header("Content-Type", "application/json")
        handler.send_header("Content-Length", str(len(data)))
        handler.end_headers()
        handler.wfile.write(data)

    def handle(self, handler):
        with self.lock:
            self.in_flight += 1
            self.most_in_flight = max(self.most_in_flight, self.in_flight)
        try:
            self.serve(handler)
        finally:
            with self.lock:
                self.in_flight -= 1

    def serve(self, handler):
        body = handler.rfile.read(int(handler.headers.get("Content-Length", 0)))
        with self.lock:
            if handler.headers.get("Authorization") != "Bearer " + self.token:
                self.bad_auth += 1
                return self.answer(handler, 401, {})
            if handler.path != "/v1/sync":
                return self.answer(handler, 404, {})
            if self.refuse:
                return self.answer(handler, self.refuse, {})
            request = json.loads(body)
            request["_bytes"] = len(body)
            request["_time"] = time.time()
            self.requests.append(request)
            if self.echo:
                print(json.dumps(masked(request)), flush=True)
            for result in request.get("results") or []:
                self.results.append(result)
            ack, fresh = 0, []
            for event in request.get("events") or []:
                key = (request["boot"], event["seq"])
                if key in self.events:
                    self.repeated_events += 1
                else:
                    fresh.append(event)
                self.events[key] = event
                ack = max(ack, event["seq"])
            if "online" in request:
                self.online = request["online"] or []
            if self.accounts:
                self.accounts.receive(request, fresh)
            if self.drop_if and self.drop_if(request):
                self.drop_if = None
                handler.close_connection = True
                handler.connection.close()
                return None
            reply = {"protocol": 1, "next_ms": 1000, "ack_seq": ack}
            if self.commands:
                reply["commands"], self.commands = self.commands, []
            if self.resync:
                reply["resync"], self.resync = ["mail"], False
            if self.banlist and self.banlist["version"] != request.get("banlist_version"):
                reply["banlist"] = self.banlist
            if self.accounts:
                self.accounts.answer(request, reply)
            return self.answer(handler, 200, reply)


def masked(request):
    """The request with every link code replaced, for printing."""
    copy = dict(request)
    copy["events"] = [dict(e, code="<code>") if "code" in e else e for e in request.get("events") or []]
    return copy


def load_password_reference():
    """tools/web_accounts/luanti_password.py, imported by its path."""
    path = Path(__file__).resolve().parent.parent / "web_accounts" / "luanti_password.py"
    spec = importlib.util.spec_from_file_location("luanti_password", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Accounts:
    """The website's part of web-accounts.md for one realm. Its methods run
    under the bridge's lock (the scenario and the stdin reader take it)."""

    ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    RESERVATION = 300  # seconds, §4

    def __init__(self, code_minutes=10, limit=10, delay=0, already_linked=(), hold_list=False,
                 out=print):
        self.accounts = {"a_test1": {"name": "Test One", "rewards": []},
                         "a_test2": {"name": "Test Two", "rewards": []}}
        self.bindings = {}         # lower name -> {name, character_id, account_id}
        self.version = 1
        self.sending = not hold_list
        self.code_seconds = code_minutes * 60
        self.limit = limit
        self.delay = delay
        self.already_linked = {name.lower() for name in already_linked}
        self.codes = {}            # code -> {account, created, used, replaced, reserved, reserved_at}
        self.requests = {}         # (boot, request_id) -> the link_request event
        self.cancelled = set()     # (boot, request_id)
        self.attempts = {}         # lower name -> request times, for too_many_attempts
        self.ids = {}              # lower name -> character_id, from online rows and events
        self.catalog = None        # the newest reward_catalog
        self.boot = None
        self.waiting = []          # (due time, boot, event)
        self.outbox = []           # commands to deliver
        self.mine = {}             # command id -> label
        self.results = {}          # command id -> result
        self.answers = []          # every link answer sent, for the scenario
        self.next_id = 0
        self.sent_version = None
        self.out = out

    # -- the protocol ------------------------------------------------------

    def receive(self, request, fresh):
        boot = request.get("boot")
        if boot != self.boot:
            self.boot = boot  # reservations of an older boot lapse (§4)
        if "reward_catalog" in request:
            self.catalog = request["reward_catalog"] or []
        for row in request.get("online") or []:
            if row.get("character_id"):
                self.ids[row["name"].lower()] = row["character_id"]
        for result in request.get("results") or []:
            label = self.mine.get(result.get("id"))
            if label and result["id"] not in self.results:
                self.results[result["id"]] = result
                self.out(f"result of {label}: {result.get('code')} {result.get('message') or ''}".rstrip())
        for event in sorted(fresh, key=lambda e: e["seq"]):
            if event.get("type", "").startswith("account."):
                self.waiting.append((time.time() + self.delay, boot, event))

    def answer(self, request, reply):
        now = time.time()
        due = [entry for entry in self.waiting if entry[0] <= now]
        self.waiting = [entry for entry in self.waiting if entry[0] > now]
        for _, boot, event in due:
            self.handle_event(boot, event, now)
        if ("accounts" in (request.get("capabilities") or []) and self.sending
                and request.get("accounts_version") != self.version):
            reply["accounts"] = self.list()
            if self.sent_version != self.version:
                self.sent_version = self.version
                self.out(f"accounts: list version {self.version} sent")
        if self.outbox:
            reply["commands"] = (reply.get("commands") or []) + self.outbox
            self.outbox = []

    def list(self):
        characters = sorted(self.bindings.values(), key=lambda b: b["name"].lower())
        owners = {b["account_id"] for b in characters}
        return {"version": self.version,
                "characters": [dict(b) for b in characters],
                "accounts": [{"id": account_id, "name": self.accounts[account_id]["name"],
                              "rewards": list(self.accounts[account_id]["rewards"])}
                             for account_id in sorted(owners)]}

    def command(self, kind, args, label):
        self.next_id += 1
        command_id = f"acc{self.next_id:04d}"
        self.mine[command_id] = label
        self.outbox.append({"id": command_id, "type": kind, "args": args,
                            "expires_at": int(time.time()) + 60})
        return command_id

    def link_answer(self, event, outcome, **fields):
        args = {"request_id": event["request_id"], "name": event["name"], "outcome": outcome}
        args.update(fields)
        self.answers.append(args)
        self.out(f"answer to {event['name']}: {outcome} ({fields.get('account_name') or fields.get('reason')})")
        return self.command("account.link_answer", args, f"the {outcome} answer to {event['name']}")

    def changed(self):
        self.version += 1
        self.out(f"list version {self.version}")

    def count(self, account_id):
        return sum(1 for b in self.bindings.values() if b["account_id"] == account_id)

    def linked(self, name, character_id):
        return (name.lower() in self.bindings or name.lower() in self.already_linked or
                any(b["character_id"] == character_id for b in self.bindings.values()))

    def reservation(self, entry, now):
        """The (boot, request_id) the code is reserved for, or None. A new code
        for the account and a new boot end it (§4)."""
        key = entry.get("reserved")
        if (key and not entry["replaced"] and key[0] == self.boot
                and now - entry["reserved_at"] < self.RESERVATION):
            return key
        return None

    def handle_event(self, boot, event, now):
        kind, key = event["type"], (boot, event.get("request_id"))
        if event.get("character_id"):
            self.ids[event["name"].lower()] = event["character_id"]
        if kind == "account.link_request":
            self.out(f"event: link request from {event['name']}")
            self.requests[key] = event
            times = [t for t in self.attempts.get(event["name"].lower(), []) if now - t < 3600]
            times.append(now)
            self.attempts[event["name"].lower()] = times
            entry = self.codes.get(event.get("code"))
            if len(times) > 10:
                return self.link_answer(event, "refused", reason="too_many_attempts")
            if not entry:
                return self.link_answer(event, "refused", reason="unknown_code")
            held = self.reservation(entry, now)
            if entry["used"] or entry["replaced"] or (held and held != key):
                return self.link_answer(event, "refused", reason="used_code")
            if now - entry["created"] > self.code_seconds:
                return self.link_answer(event, "refused", reason="expired_code")
            if self.linked(event["name"], event["character_id"]):
                return self.link_answer(event, "refused", reason="already_linked")
            if self.count(entry["account"]) >= self.limit:
                return self.link_answer(event, "refused", reason="account_full")
            entry["reserved"], entry["reserved_at"] = key, now
            return self.link_answer(event, "offer",
                                    account_name=self.accounts[entry["account"]]["name"])
        if kind == "account.link_cancel":
            self.out(f"event: link cancelled for {event['name']}")
            self.cancelled.add(key)
            request = self.requests.get(key)
            entry = request and self.codes.get(request.get("code"))
            if entry and entry.get("reserved") == key:
                entry["reserved"] = None
            return None
        if kind == "account.link_confirm":
            self.out(f"event: link confirmation from {event['name']}")
            request = self.requests.get(key)
            if not request or key in self.cancelled:
                self.out("  (no open request: not bound)")
                return None
            entry = self.codes[request["code"]]
            held = self.reservation(entry, now)
            if held != key:
                if entry["used"] or entry["replaced"] or held:
                    return self.link_answer(event, "refused", reason="used_code")
                if now - entry["created"] > self.code_seconds:
                    return self.link_answer(event, "refused", reason="expired_code")
            # Re-checked with storing the binding (§4).
            if self.linked(event["name"], event["character_id"]):
                return self.link_answer(event, "refused", reason="already_linked")
            if self.count(entry["account"]) >= self.limit:
                return self.link_answer(event, "refused", reason="account_full")
            self.bindings[event["name"].lower()] = {"name": event["name"],
                                                     "character_id": event["character_id"],
                                                     "account_id": entry["account"]}
            entry["used"], entry["reserved"] = True, None
            self.out(f"bound {event['name']} to {entry['account']}")
            self.changed()
            # The same response as the list (§6).
            return self.link_answer(event, "linked",
                                    account_name=self.accounts[entry["account"]]["name"])
        return None

    # -- what the website's pages and administrators do --------------------

    def new_code(self, account_id):
        for entry in self.codes.values():
            if entry["account"] == account_id:
                entry["replaced"] = True
        code = "".join(secrets.choice(self.ALPHABET) for _ in range(10))
        self.codes[code] = {"account": account_id, "created": time.time(), "used": False,
                            "replaced": False, "reserved": None, "reserved_at": 0}
        return code

    def run(self, line):
        """One stdin command. Answers what to print."""
        words = line.split()
        if not words:
            return ""
        verb, rest = words[0], words[1:]
        try:
            return getattr(self, "do_" + verb)(*rest)
        except (AttributeError, TypeError):
            return "unknown command; try help"
        except KeyError as error:
            return f"unknown: {error}"

    def do_help(self):
        return __doc__.split("on stdin:")[1].split("Options for")[0].rstrip()

    def do_code(self, account_id):
        self.accounts[account_id]
        code = self.new_code(account_id)
        minutes = self.code_seconds / 60
        return (f"code for {account_id} ({self.accounts[account_id]['name']}): "
                f"{code[:5]}-{code[5:]}, valid {minutes:g} min")

    def do_grant(self, account_id, reward):
        rewards = self.accounts[account_id]["rewards"]
        if reward not in rewards:
            rewards.append(reward)
            self.changed()
        return ""

    def do_revoke(self, account_id, reward):
        rewards = self.accounts[account_id]["rewards"]
        if reward in rewards:
            rewards.remove(reward)
            self.changed()
        return ""

    def do_unlink(self, name):
        self.bindings.pop(name.lower())
        self.changed()
        return ""

    def do_rename(self, account_id, *name):
        self.accounts[account_id]["name"] = " ".join(name)
        self.changed()
        return ""

    def do_delete(self, account_id):
        del self.accounts[account_id]
        self.bindings = {k: b for k, b in self.bindings.items() if b["account_id"] != account_id}
        self.changed()
        return ""

    def do_bind(self, name, account_id):
        self.accounts[account_id]
        character_id = self.ids.get(name.lower())
        if not character_id:
            return f"no character_id for {name} yet: it must be online once"
        if self.linked(name, character_id):
            return f"{name} is already linked"
        if self.count(account_id) >= self.limit:
            return f"{account_id} is full"
        self.bindings[name.lower()] = {"name": name, "character_id": character_id,
                                        "account_id": account_id}
        self.out(f"bound {name} to {account_id} directly")
        self.changed()
        return ""

    def do_setpw(self, name, password, account_id=None):
        binding = self.bindings.get(name.lower())
        account_id = account_id or (binding and binding["account_id"]) or "a_test1"
        entry = load_password_reference().make_entry(name, password)
        self.command("account.set_password", {"name": name, "account_id": account_id,
                                               "entry": entry}, f"setpw {name}")
        return f"setpw {name}: sent"

    def do_send(self):
        self.sending = True
        return "the list goes with the next request"

    def do_state(self):
        lines = [f"list version {self.version}" + ("" if self.sending else " (held)")]
        for account_id, account in sorted(self.accounts.items()):
            lines.append(f"  {account_id} {account['name']!r} rewards {account['rewards']}")
        for binding in sorted(self.bindings.values(), key=lambda b: b["name"].lower()):
            lines.append(f"  {binding['name']} -> {binding['account_id']} ({binding['character_id']})")
        lines.append(f"  catalogue: {self.catalog}")
        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="A fake bridge for /v1/sync.")
    parser.add_argument("port", type=int)
    parser.add_argument("token")
    parser.add_argument("--accounts", action="store_true", help="play the website's part of accounts")
    parser.add_argument("--echo", action="store_true", help="print every request in accounts mode too")
    parser.add_argument("--delay", type=float, default=0)
    parser.add_argument("--code-minutes", type=float, default=10)
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--already-linked", action="append", default=[])
    parser.add_argument("--hold-list", action="store_true")
    options = parser.parse_args()
    server = Bridge(options.port, options.token)
    server.echo = options.echo or not options.accounts
    if options.accounts:
        server.accounts = Accounts(options.code_minutes, options.limit, options.delay,
                                   options.already_linked, options.hold_list,
                                   out=lambda text: print(text, flush=True))
    server.start()
    if not options.accounts:
        server.thread.join()
        return
    for line in sys.stdin:
        with server.lock:
            text = server.accounts.run(line)
        if text:
            print(text, flush=True)
    server.thread.join()


if __name__ == "__main__":
    main()
