# Evidence: Highcourt, the pilot capital (2026-09-14)

The increment record is
[docs/research/wp13-highcourt.md](../../../../docs/research/wp13-highcourt.md).
Everything here was produced by the scripts beside it, from the repository
root, with `LC_ALL=C`.

| Script | Product |
| --- | --- |
| `kat.sh` | `kat-luajit.txt`, `kat-puc51.txt` -- library_kat + blueprint_kat + highcourt_kat + integration_fixture in one process under each interpreter; the two must be byte-identical |
| `timing.sh` | `timing.txt` -- three builds of the core, the district and one avenue run under each interpreter, against the contract's section 2.3 budget |
| `renders.sh` | `renders/` (32 PNGs) and `sockets.txt` -- the review loop the pictures come out of |
| `static.sh` | `static.txt` -- parser, SETGLOBAL, the five plain-5.1 sweeps, the fresh-server audit |
| `final-micro.sh` | `final-micro/` -- the single bounded final-byte pair over the frozen inputs |
| `files.sha256.sh` | `files.sha256` -- the frozen-byte manifest of every input and artefact |

`start-identity.txt` is the identity digest of all six start blueprints,
computed with `../20260914-capital-parts/start_identity.lua`; it is identical
to the capital-parts lane's, which is what "the six start palettes stay
byte-identical" means for a lane that added three files and touched no shared
module.

There is **no engine run**: nothing in this increment is wired into the WP40
seam, so there is no mapchunk to generate. The first package that binds a
capital owes it.
