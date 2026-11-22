"""Export occupied chunk coordinates from a stopped world to standard output."""
import argparse
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from migration import pack, world


def snapshot(world_dir):
    seed = world.read_world_mt(world_dir / "map_meta.txt").get("seed", "")
    if not re.fullmatch(r"-?[0-9]+", seed):
        raise ValueError("map_meta.txt has no numeric full seed")
    backends = world.open_world(world_dir)
    try:
        claims, skipped = pack.read_claims(backends["mod_storage"])
    finally:
        world.close_world(backends)
    if any(skipped.values()) or any(c.version != "v3" for c in claims):
        raise ValueError("use chunk-aligned, decodable claim records for this study")
    chunks = set()
    for claim in claims:
        x0, _, z0, _ = claim.area()
        chunks.add((int((x0 - pack.CHUNK_OFFSET) // pack.CHUNK),
                    int((z0 - pack.CHUNK_OFFSET) // pack.CHUNK)))
    rows = ["grug_claim_chunks_v1", "seed " + seed, "count " + str(len(chunks))]
    rows.extend(f"{cx} {cz}" for cx, cz in sorted(chunks))
    body = ("\n".join(rows) + "\n").encode("ascii")
    return body + b"end " + hashlib.sha256(body).hexdigest().encode("ascii") + b"\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stopped_world", type=Path)
    args = parser.parse_args()
    sys.stdout.buffer.write(snapshot(args.stopped_world))
