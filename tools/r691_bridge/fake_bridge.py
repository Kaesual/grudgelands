#!/usr/bin/env python3
"""A small bridge that speaks /v1/sync (docs/technical/web-bridge.md), for the
0.69.1 engine scenario. It records every request and answers from what its
caller queued. Alone it serves a realm by hand:

    python3 tools/r691_bridge/fake_bridge.py PORT TOKEN

prints each request as one JSON line and sends no commands."""

import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


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
                print(json.dumps(request), flush=True)
            for result in request.get("results") or []:
                self.results.append(result)
            ack = 0
            for event in request.get("events") or []:
                key = (request["boot"], event["seq"])
                if key in self.events:
                    self.repeated_events += 1
                self.events[key] = event
                ack = max(ack, event["seq"])
            if "online" in request:
                self.online = request["online"] or []
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
            return self.answer(handler, 200, reply)


if __name__ == "__main__":
    server = Bridge(int(sys.argv[1]), sys.argv[2])
    server.echo = True
    server.start()
    server.thread.join()
