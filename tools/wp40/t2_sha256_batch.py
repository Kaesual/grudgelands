#!/usr/bin/env python3
"""Hash a length-framed binary batch for the private WP40 offline oracle."""

import hashlib
import pathlib
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: t2_sha256_batch.py INPUT OUTPUT", file=sys.stderr)
        return 2
    source = pathlib.Path(sys.argv[1])
    target = pathlib.Path(sys.argv[2])
    with source.open("rb") as incoming, target.open("wb") as outgoing:
        while True:
            line = incoming.readline()
            if line == b"":
                break
            if not line.endswith(b"\n") or not line[:-1].isdigit():
                raise ValueError("invalid SHA-256 batch length")
            size = int(line[:-1])
            data = incoming.read(size)
            if len(data) != size:
                raise ValueError("truncated SHA-256 batch input")
            outgoing.write(hashlib.sha256(data).digest())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
