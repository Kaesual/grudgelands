"""The study reads placed claims from the same stopped-world records as the reset."""
import hashlib
import sqlite3
import tempfile
import unittest
from pathlib import Path

from export_claims import snapshot


class ClaimsExportTest(unittest.TestCase):
    def test_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            world = Path(tmp)
            (world / "world.mt").write_text(
                "player_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n")
            seed = "17713522922938657774"
            (world / "map_meta.txt").write_text(f"seed = {seed}\nnoise = {{\n seed = 3\n}}\n")
            with sqlite3.connect(world / "mod_storage.sqlite") as db:
                db.execute("CREATE TABLE entries(modname TEXT, key BLOB, value BLOB)")
                empty = snapshot(world)
                self.assertIn(f"seed {seed}\ncount 0\n".encode(), empty)
                for row, claim in enumerate((
                        "v3|Alice|-33|10|-32|1|0|0|0||personal|",
                        "v3|account:test:accord|48|15|47|1|2|3|0||account|home")):
                    db.execute("INSERT INTO entries VALUES (?,?,?)",
                               ("grug_housing", f"claim:{row + 1}".encode(), claim.encode()))
                db.commit()
                expected = f"grug_claim_chunks_v1\nseed {seed}\ncount 2\n-1 0\n1 0\n".encode()
                self.assertEqual(snapshot(world), expected + b"end " +
                                 hashlib.sha256(expected).hexdigest().encode() + b"\n")
                db.execute("UPDATE entries SET value = ? WHERE key = ?", (b"malformed", b"claim:1"))
                db.commit()
                with self.assertRaises(ValueError):
                    snapshot(world)


if __name__ == "__main__":
    unittest.main()
