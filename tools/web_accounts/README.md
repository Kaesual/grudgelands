# Website accounts: the password check reference

For the website side of [web-accounts.md](../../docs/technical/web-accounts.md)
("Direct binding by password"): how to check a plain password against a
character's Luanti auth entry without the game.

| File | What |
|---|---|
| `luanti_password.py` | the reference, Python standard library only: `check(name, entry, password)` for the password check, `make_entry(name, password)` for a new entry for `account.set_password` and `valid_entry(entry)` for the form that command accepts (web-accounts.md §6b); `python3 -I luanti_password.py --test` runs the vectors and the `make_entry` checks |
| `test_vectors.json` | 17 synthetic vectors: SRP and legacy entries, a mixed-case name, empty passwords, a non-ASCII password (NFC and NFD), a 255-byte verifier, malformed entries |
| `engine_vectors/` | how the vectors were made: `build.sh` compiles `gen.cpp` against the engine's unchanged `util/srp.cpp` (with its bundled mini-gmp and sha256) from `reference_projects/luanti`; `make_vectors.py` writes the JSON. Every SRP verifier comes from the engine code, never from the Python check |

Checked on 2026-11-15:

- The engine-built `gen` reproduces the SRP entries that the engine itself wrote in a
  test world of Round 53 (6 characters, password `it-<name>`).
- `luanti_password.py` accepts those, and the legacy entries of the Round 43 test
  world (password `secret`), and refuses wrong passwords and a password typed in
  another case.
- All 17 vectors pass.

Rules the vectors pin down:

- Use the name **as the auth table stores it**. The legacy format depends on its case;
  SRP lowers it (ASCII letters only, as the engine does).
- The password is compared as the bytes typed (UTF-8). There is no Unicode
  normalization.
- Base64 has no `=` padding.
- The verifier is the minimal big-endian bytes of `v`. Never pad it.

The check agrees with the engine's `core.check_password_entry` on every entry the
engine writes. It differs only on malformed entries the engine never writes: a
trailing `#`, a non-empty part before the first `#`, and non-canonical base64 bits.
