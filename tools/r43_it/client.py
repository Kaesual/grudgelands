"""A minimal Luanti client for the Round 43 integration tests: one character
joins a headless server, stays a few seconds and leaves. A headless server
has no client of its own, and a real join is the only way the engine loads
a character's saved row (player meta, inventory) and runs the join
callbacks on it (grug_core's migration runner first).

It speaks just enough of the protocol (reference_projects/luanti, 5.17):
  transport  src/network/mtp/internal.h (header, CONTROL/ORIGINAL/SPLIT/
             RELIABLE, seqnums from 65500), threads.cpp:535-557 (the dummy
             reliable packet that makes the server create the peer);
  commands   src/network/networkprotocol.h (TOSERVER_INIT 0x02, INIT2 0x11,
             CLIENT_READY 0x43, FIRST_SRP 0x50, SRP_BYTES_A 0x51, SRP_BYTES_M
             0x52; TOCLIENT_HELLO 0x02, AUTH_ACCEPT 0x03, ACCESS_DENIED 0x0A,
             SRP_BYTES_S_B 0x60), the server side in
             network/serverpackethandler.cpp:43-411 and 1429-1700;
  auth       a new name registers with FIRST_SRP (salt and verifier of the
             password), a known one logs in with SRP-6a, SHA-256, the
             2048-bit group (src/util/srp.cpp calculate_x/calculate_M/
             srp_user_process_challenge, src/util/auth.cpp: the verifier's
             name is lower case).
Everything else the server sends (definitions, media, map blocks, HUD) is
only acknowledged. The standard library only.

Usage: python3 client.py PORT NAME [STAY_SECONDS]   (password "it-" + NAME)
"""

import hashlib
import os
import socket
import struct
import sys
import time

PROTOCOL_ID = 0x4F457403
SEQNUM_INITIAL = 65500
CONTROL, ORIGINAL, SPLIT, RELIABLE = 0, 1, 2, 3
ACK, SET_PEER_ID, PING, DISCO = 0, 1, 2, 3
TOSERVER_INIT, TOSERVER_INIT2, TOSERVER_CLIENT_READY = 0x02, 0x11, 0x43
TOSERVER_FIRST_SRP, TOSERVER_SRP_BYTES_A, TOSERVER_SRP_BYTES_M = 0x50, 0x51, 0x52
TOCLIENT_HELLO, TOCLIENT_AUTH_ACCEPT = 0x02, 0x03
TOCLIENT_ACCESS_DENIED, TOCLIENT_SRP_BYTES_S_B = 0x0A, 0x60
AUTH_SRP, AUTH_FIRST_SRP = 1 << 1, 1 << 2
SER_FMT_VER_HIGHEST_READ = 29
PROTOCOL_MIN, PROTOCOL_MAX = 37, 52
FORMSPEC_VERSION = 10

# SRP_NG_2048 (src/util/srp.cpp global_Ng_constants)
N = int(
    "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050A37329CB"
    "B4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50E8083969EDB767B0"
    "CF6095179A163AB3661A05FBD5FAAAE82918A9962F0B93B855F97993EC975EEAA80D740A"
    "DBF4FF747359D041D5C33EA71D281E446B14773BCA97B43A23FB801676BD207A436C6481"
    "F1D2B9078717461A5B9D32E688F87748544523B524B0D57D5EA77A2775D2ECFA032CFBDB"
    "F52FB3786160279004E57AE6AF874E7303CE53299CCC041C7BC308D82A5698F3A8D0C382"
    "71AE35F8E9DBFBB694B5C803D89F7AE435DE236D525F54759B65E372FCD68EF20FA7111F"
    "9E4AFF73", 16)
G = 2


class JoinError(Exception):
    pass


def _bytes(n):
    return n.to_bytes((n.bit_length() + 7) // 8, "big")


def _h(*parts):
    return hashlib.sha256(b"".join(parts)).digest()


def _h_nn(a, b):
    size = len(_bytes(N))
    return int.from_bytes(_h(a.to_bytes(size, "big"), b.to_bytes(size, "big")), "big")


def _x(salt, name, password):
    inner = _h(name.lower().encode(), b":", password.encode())
    return int.from_bytes(_h(salt, inner), "big")


def _string(text):
    data = text.encode() if isinstance(text, str) else text
    return struct.pack(">H", len(data)) + data


def _read_string(data, pos):
    (size,) = struct.unpack_from(">H", data, pos)
    return data[pos + 2:pos + 2 + size], pos + 2 + size


class Client:
    def __init__(self, port, name, password=None, host="127.0.0.1", log=print):
        self.addr = (host, port)
        self.name = name
        self.password = password if password is not None else "it-" + name
        self.log = log
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(0.05)
        self.peer_id = 0
        self.out_seq = [SEQNUM_INITIAL] * 3
        self.unacked = {}  # (channel, seq) -> (body, last sent)
        self.splits = {}
        self.inbox = []
        self.denied = None
        self.closed = False

    # -- transport --------------------------------------------------------

    def _raw(self, channel, body):
        header = struct.pack(">IHB", PROTOCOL_ID, self.peer_id, channel)
        self.sock.sendto(header + body, self.addr)

    def send(self, command, payload=b"", channel=1, reliable=True):
        body = bytes([ORIGINAL]) + struct.pack(">H", command) + payload
        if reliable:
            seq = self.out_seq[channel]
            self.out_seq[channel] = (seq + 1) & 0xFFFF
            body = bytes([RELIABLE]) + struct.pack(">H", seq) + body
            self.unacked[(channel, seq)] = (body, time.monotonic())
        self._raw(channel, body)

    def _packet(self, channel, body):
        kind = body[0]
        if kind == RELIABLE:
            (seq,) = struct.unpack_from(">H", body, 1)
            self._raw(channel, bytes([CONTROL, ACK]) + struct.pack(">H", seq))
            self._packet(channel, body[3:])
        elif kind == CONTROL:
            control = body[1]
            if control == ACK:
                (seq,) = struct.unpack_from(">H", body, 2)
                self.unacked.pop((channel, seq), None)
            elif control == SET_PEER_ID:
                (self.peer_id,) = struct.unpack_from(">H", body, 2)
            elif control == DISCO:
                self.closed = True
        elif kind == ORIGINAL:
            self._command(body[1:])
        elif kind == SPLIT:
            seq, count, number = struct.unpack_from(">HHH", body, 1)
            parts = self.splits.setdefault((channel, seq), {})
            parts[number] = body[7:]
            if len(parts) == count:
                del self.splits[(channel, seq)]
                self._command(b"".join(parts[i] for i in range(count)))

    def _command(self, data):
        if len(data) < 2:
            return
        (command,) = struct.unpack_from(">H", data, 0)
        payload = data[2:]
        if command == TOCLIENT_ACCESS_DENIED:
            reason = payload[0] if payload else -1
            custom = _read_string(payload, 1)[0].decode("utf-8", "replace") \
                if len(payload) >= 3 else ""
            self.denied = "access denied (reason %d) %s" % (reason, custom)
        self.inbox.append((command, payload))

    def pump(self, seconds):
        """Receives (and acknowledges) for `seconds`, resending what the
        server has not acknowledged."""
        end = time.monotonic() + seconds
        while True:
            now = time.monotonic()
            for (channel, _), (body, sent) in list(self.unacked.items()):
                if now - sent > 0.5:
                    self._raw(channel, body)
                    self.unacked[(channel, _)] = (body, now)
            try:
                data, _addr = self.sock.recvfrom(65536)
            except socket.timeout:
                data = None
            if data and len(data) >= 8 and struct.unpack_from(">I", data)[0] == PROTOCOL_ID:
                self._packet(data[6], data[7:])
            if time.monotonic() >= end:
                return

    def wait_for(self, commands, timeout):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            for index, (command, payload) in enumerate(self.inbox):
                if command in commands:
                    del self.inbox[index]
                    return command, payload
            if self.denied:
                raise JoinError("%s: %s" % (self.name, self.denied))
            self.pump(0.05)
        raise JoinError("%s: no answer %s within %d s" % (
            self.name, "/".join("0x%02x" % c for c in commands), timeout))

    # -- the join -----------------------------------------------------------

    def _authenticate(self, mechs):
        if mechs & AUTH_FIRST_SRP:
            salt = os.urandom(16)
            verifier = pow(G, _x(salt, self.name, self.password), N)
            self.send(TOSERVER_FIRST_SRP, _string(salt) + _string(_bytes(verifier)) + b"\x00")
            return "registered"
        if not mechs & AUTH_SRP:
            raise JoinError("%s: no SRP login offered (mechanisms %d)" % (self.name, mechs))
        a = int.from_bytes(os.urandom(32), "big")
        big_a = pow(G, a, N)
        self.send(TOSERVER_SRP_BYTES_A, _string(_bytes(big_a)) + b"\x01")
        _, payload = self.wait_for((TOCLIENT_SRP_BYTES_S_B,), 10)
        salt, pos = _read_string(payload, 0)
        b_bytes, _ = _read_string(payload, pos)
        big_b = int.from_bytes(b_bytes, "big")
        u = _h_nn(big_a, big_b)
        k = _h_nn(N, G)
        x = _x(salt, self.name, self.password)
        s = pow((big_b - k * pow(G, x, N)) % N, a + u * x, N)
        key = _h(_bytes(s))
        h_xor = bytes(p ^ q for p, q in zip(_h(_bytes(N)), _h(_bytes(G))))
        m = _h(h_xor, _h(self.name.encode()), salt, _bytes(big_a), _bytes(big_b), key)
        self.send(TOSERVER_SRP_BYTES_M, _string(m))
        return "logged in"

    def join(self, stay=4.0):
        """Joins, stays `stay` seconds, leaves. Returns a short report."""
        self.send(0, b"", channel=0)  # the dummy packet: the server creates the peer
        end = time.monotonic() + 10
        while self.peer_id == 0:
            if time.monotonic() > end:
                raise JoinError("%s: the server gave no peer id" % self.name)
            self.pump(0.05)
        init = struct.pack(">BHHH", SER_FMT_VER_HIGHEST_READ, 0, PROTOCOL_MIN,
                           PROTOCOL_MAX) + _string(self.name)
        hello = None
        for _ in range(10):
            self.send(TOSERVER_INIT, init, channel=1, reliable=False)
            try:
                hello = self.wait_for((TOCLIENT_HELLO,), 1)
                break
            except JoinError:
                if self.denied:
                    raise
        if hello is None:
            raise JoinError("%s: no TOCLIENT_HELLO" % self.name)
        payload = hello[1]
        _ser, _unused, proto, mechs = struct.unpack_from(">BHHI", payload, 0)
        how = self._authenticate(mechs)
        self.wait_for((TOCLIENT_AUTH_ACCEPT,), 10)
        self.send(TOSERVER_INIT2, _string(""))
        self.send(TOSERVER_CLIENT_READY, struct.pack(">BBBB", 5, 17, 0, 0) +
                  _string("5.17.0-r43-it") + struct.pack(">H", FORMSPEC_VERSION))
        self.pump(stay)
        if self.denied:
            raise JoinError("%s: %s" % (self.name, self.denied))
        report = "%s %s (protocol %d), stayed %.1f s" % (self.name, how, proto, stay)
        self.leave()
        return report

    def leave(self):
        for _ in range(2):
            self._raw(0, bytes([CONTROL, DISCO]))
            self.pump(0.2)
        self.sock.close()


def join(port, name, stay=4.0, log=print):
    return Client(port, name, log=log).join(stay)


if __name__ == "__main__":
    print(join(int(sys.argv[1]), sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 4.0))
