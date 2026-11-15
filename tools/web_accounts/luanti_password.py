"""Check a plain password against a Luanti auth entry: the reference for the
website (docs/technical/web-accounts.md, "Direct binding by password").

Standard library only. It agrees with core.check_password_entry
(reference_projects/luanti/src/script/lua_api/l_util.cpp) on every entry the engine
writes. It differs only on malformed entries the engine never writes: it refuses a
trailing '#' and a non-empty first part, which the engine's parser lets through,
and accepts non-canonical trailing base64 bits, which the engine refuses:

- An entry without '#' is the legacy format, base64(SHA-1(name + password))
  without '=' padding, the name exactly as stored (util/auth.cpp
  translate_password); an empty password gives the empty entry.
- An entry "#1#<salt>#<verifier>" is SRP-6a (util/auth.cpp, util/srp.cpp):
  base64 without padding; x = SHA-256(salt || SHA-256(lower(name) ":" password))
  as a big-endian integer; v = 2^x mod N with the RFC 5054 2048-bit prime;
  v as minimal big-endian bytes equals the verifier.

`name` must be the name as the auth table stores it, not as a player typed it:
the legacy format depends on its case.

    python3 -I luanti_password.py --test     runs test_vectors.json and the
                                             make_entry checks
"""
import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import sys

N = int(
    "AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC319294"
    "3DB56050A37329CBB4A099ED8193E0757767A13DD52312AB4B03310D"
    "CD7F48A9DA04FD50E8083969EDB767B0CF6095179A163AB3661A05FB"
    "D5FAAAE82918A9962F0B93B855F97993EC975EEAA80D740ADBF4FF74"
    "7359D041D5C33EA71D281E446B14773BCA97B43A23FB801676BD207A"
    "436C6481F1D2B9078717461A5B9D32E688F87748544523B524B0D57D"
    "5EA77A2775D2ECFA032CFBDBF52FB3786160279004E57AE6AF874E73"
    "03CE53299CCC041C7BC308D82A5698F3A8D0C38271AE35F8E9DBFBB6"
    "94B5C803D89F7AE435DE236D525F54759B65E372FCD68EF20FA7111F"
    "9E4AFF73", 16)
G = 2


def _b64decode(text):
    return base64.b64decode(text + "=" * (-len(text) % 4), validate=True)


def legacy_entry(name, password):
    """The legacy entry for name and password (util/auth.cpp translate_password)."""
    if password == "":
        return ""
    digest = hashlib.sha1((name + password).encode("utf-8")).digest()
    return base64.b64encode(digest).decode("ascii").rstrip("=")


def srp_verifier(name, password, salt):
    """The SRP verifier bytes for name, password and salt (util/srp.cpp)."""
    # ASCII-only lowering, as util/string.h lowercase(); Luanti names are
    # [A-Za-z0-9_-] anyway.
    lowered = "".join(c.lower() if "A" <= c <= "Z" else c for c in name)
    inner = hashlib.sha256(lowered.encode("utf-8") + b":" +
                           password.encode("utf-8")).digest()
    x = int.from_bytes(hashlib.sha256(salt + inner).digest(), "big")
    v = pow(G, x, N)
    return v.to_bytes((v.bit_length() + 7) // 8, "big")


ENTRY_FORM = re.compile(r"^#1#[A-Za-z0-9+/]+#[A-Za-z0-9+/]+$")


def valid_entry(entry):
    """True when `account.set_password` takes the entry (web-accounts.md §6b):
    "#1#<salt>#<verifier>", each part non-empty canonical base64 without padding
    (decoding and re-encoding gives the same text, which is what the engine's
    base64_is_valid needs: no length of 1 mod 4, a canonical last character), and a
    verifier of 1 to 256 bytes. An entry that passes can be used for a login."""
    if not ENTRY_FORM.match(entry):
        return False
    decoded = []
    for text in entry.split("#")[2:]:
        try:
            data = _b64decode(text)
        except ValueError:
            return False
        if base64.b64encode(data).decode("ascii").rstrip("=") != text:
            return False
        decoded.append(data)
    return len(decoded[0]) > 0 and 1 <= len(decoded[1]) <= 256


def make_entry(name, password, salt=None):
    """A new SRP entry for name and password, as `account.set_password` takes it
    (web-accounts.md §6b): a fresh 16-byte salt from a secure source, base64
    without padding; valid_entry is true for it. `salt` is for tests only."""
    salt = secrets.token_bytes(16) if salt is None else salt
    b64 = lambda data: base64.b64encode(data).decode("ascii").rstrip("=")
    return "#1#%s#%s" % (b64(salt), b64(srp_verifier(name, password, salt)))


def check(name, entry, password):
    """True when password matches the stored entry of the character name."""
    if "#" not in entry:
        return hmac.compare_digest(legacy_entry(name, password), entry)
    parts = entry.split("#")
    if len(parts) != 4 or parts[0] != "" or parts[1] != "1":
        return False
    try:
        salt, verifier = _b64decode(parts[2]), _b64decode(parts[3])
    except ValueError:
        return False
    return hmac.compare_digest(srp_verifier(name, password, salt), verifier)


def _test():
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "test_vectors.json"), encoding="utf-8") as f:
        vectors = json.load(f)["vectors"]
    failed = 0
    for vector in vectors:
        got = check(vector["name"], vector["entry"], vector["password"])
        if got != vector["match"]:
            failed += 1
            print("FAIL", vector["note"])
    # make_entry: the vectors' own salts reproduce their SRP entries, and fresh
    # entries pass check and the form the game accepts.
    made = 0
    for vector in vectors:
        entry = vector["entry"]
        if vector["match"] and entry.startswith("#1#") and ENTRY_FORM.match(entry):
            salt = _b64decode(entry.split("#")[2])
            if make_entry(vector["name"], vector["password"], salt) != entry:
                failed += 1
                print("FAIL make_entry", vector["note"])
            made += 1
    for name, password in (("Rowan", "correct horse"), ("Elara", "Pässwörd-✓ дракон"),
                           ("BrightAxe", "")):
        entry = make_entry(name, password)
        if not (valid_entry(entry) and check(name, entry, password)
                and not check(name, entry, password + "x")):
            failed += 1
            print("FAIL fresh make_entry for", name)
        made += 1
    # valid_entry refuses what the engine could not decode at a login.
    good = make_entry("Rowan", "correct horse", bytes(range(16)))
    salt, verifier = good.split("#")[2:]
    over = base64.b64encode(b"\x01" * 258).decode("ascii").rstrip("=")
    bad = {
        "a verifier cut by one character": "#1#%s#%s" % (salt, verifier[:-1]),
        "a length of 1 mod 4": "#1#%s#%s" % (salt, verifier + "AAAAA"),
        "a non-canonical last character": "#1#%s#%s" % (salt[:-1] + "R", verifier),
        "padding": "#1#%s==#%s" % (salt, verifier),
        "a legacy entry": legacy_entry("Rowan", "correct horse"),
        "a plain password": "correct horse",
        "an empty salt": "#1##%s" % verifier,
        "a verifier over 256 bytes": "#1#%s#%s" % (salt, over),
    }
    if not valid_entry(good):
        failed += 1
        print("FAIL valid_entry refuses a good entry")
    for note, entry in bad.items():
        made += 1
        if valid_entry(entry):
            failed += 1
            print("FAIL valid_entry accepts", note)
    print("%d vectors, %d make_entry and valid_entry cases, %d failed" % (
        len(vectors), made, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        sys.exit(_test())
    print(__doc__)
