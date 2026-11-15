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

    python3 -I luanti_password.py --test     runs test_vectors.json
"""
import base64
import hashlib
import hmac
import json
import os
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
    inner = hashlib.sha256(name.lower().encode("utf-8") + b":" +
                           password.encode("utf-8")).digest()
    x = int.from_bytes(hashlib.sha256(salt + inner).digest(), "big")
    v = pow(G, x, N)
    return v.to_bytes((v.bit_length() + 7) // 8, "big")


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
    print("%d vectors, %d failed" % (len(vectors), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        sys.exit(_test())
    print(__doc__)
