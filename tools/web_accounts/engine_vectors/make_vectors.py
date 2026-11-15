"""Writes tools/web_accounts/test_vectors.json. Every SRP verifier comes from the
engine's own util/srp.cpp (the `gen` binary of build.sh), never from
luanti_password.py, so the vectors test that file independently. Legacy entries
are base64(SHA-1(name + password)) without padding (util/auth.cpp
translate_password), checked once against entries the engine wrote.

    python3 -I tools/web_accounts/engine_vectors/make_vectors.py PATH_TO_GEN
"""
import base64
import hashlib
import json
import os
import subprocess
import sys
import unicodedata

GEN = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test_vectors.json")


def b64(data):
    return base64.b64encode(data).decode("ascii").rstrip("=")


def srp_entry(name, password, salt):
    hexv = subprocess.run([GEN, name, password, salt.hex()], check=True,
                          capture_output=True, text=True).stdout.strip()
    return "#1#%s#%s" % (b64(salt), b64(bytes.fromhex(hexv))), len(hexv) // 2


def legacy(name, password):
    if password == "":
        return ""
    return b64(hashlib.sha1((name + password).encode("utf-8")).digest())


def salt(tag):
    return hashlib.sha256(tag.encode()).digest()[:16]


vectors = []


def add(note, name, entry, password, match):
    vectors.append({"note": note, "name": name, "entry": entry,
                    "password": password, "match": match})


e, _ = srp_entry("Rowan", "correct horse", salt("rowan"))
add("SRP: right password", "Rowan", e, "correct horse", True)
add("SRP: wrong password", "Rowan", e, "wrong horse", False)
add("SRP: the password in another case", "Rowan", e, "Correct horse", False)

e, _ = srp_entry("BrightAxe", "secret", salt("brightaxe"))
add("SRP, mixed-case name: the stored name", "BrightAxe", e, "secret", True)
add("SRP, mixed-case name: the name typed in lower case (SRP lowers the name)",
    "brightaxe", e, "secret", True)

e = legacy("BrightAxe", "secret")
add("legacy, mixed-case name: the stored name", "BrightAxe", e, "secret", True)
add("legacy, mixed-case name: the name typed in lower case fails, so always use "
    "the stored name", "brightaxe", e, "secret", False)

e, _ = srp_entry("Quiet", "", salt("quiet"))
add("SRP: empty password", "Quiet", e, "", True)
add("SRP: empty password, a non-empty one given", "Quiet", e, "x", False)
add("legacy: empty entry, empty password", "Quiet", "", "", True)
add("legacy: empty entry, a non-empty password", "Quiet", "", "a", False)

pw = unicodedata.normalize("NFC", "Pässwörd-✓ дракон")
e, _ = srp_entry("Elara", pw, salt("elara"))
add("SRP: non-ASCII password (UTF-8, NFC)", "Elara", e, pw, True)
add("SRP: the same password decomposed (NFD) fails: compare the bytes as typed",
    "Elara", e, unicodedata.normalize("NFD", pw), False)
add("legacy: non-ASCII password", "Elara", legacy("Elara", pw), pw, True)

# A verifier shorter than 256 bytes: compare minimal bytes, never pad.
for i in range(5000):
    e, length = srp_entry("Short", "pw", salt("short%d" % i))
    if length < 256:
        add("SRP: a verifier of %d bytes (leading zero byte dropped)" % length,
            "Short", e, "pw", True)
        break

add("malformed: unknown format version", "Rowan", "#2#AAAA#AAAA", "correct horse", False)
add("malformed: missing part", "Rowan", "#1#AAAA", "correct horse", False)

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"source": "tools/web_accounts/engine_vectors/make_vectors.py; SRP "
               "verifiers from reference_projects/luanti/src/util/srp.cpp",
               "vectors": vectors}, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(len(vectors), "vectors written")
