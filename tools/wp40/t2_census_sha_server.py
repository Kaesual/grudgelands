#!/usr/bin/env python3
"""Persistent length-framed SHA-256 responder for the WP40 census worker.

Same framing as t2_sha256_batch.py, different transport.  The census cannot use
the batch script's shape: its SHA inputs are discovered inside a full R7
compile, so the extreme worker's discover-then-strict double pass would cost a
second ~24 s compile to save the ~1.3 s of fork overhead it is meant to remove.
One long-lived responder removes that overhead without a second pass, and the
digests are hashlib's either way.
"""

import hashlib
import pathlib
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: t2_census_sha_server.py REQUEST_FIFO RESPONSE_FIFO",
              file=sys.stderr)
        return 2
    request = pathlib.Path(sys.argv[1])
    response = pathlib.Path(sys.argv[2])
    # Opening the request side first matches the client's open order; the pair
    # of blocking opens is what rendezvouses the two processes.
    with request.open("rb") as incoming, response.open("wb") as outgoing:
        while True:
            line = incoming.readline()
            if line == b"":
                break
            if not line.endswith(b"\n") or not line[:-1].isdigit():
                raise ValueError("invalid SHA-256 request length")
            size = int(line[:-1])
            data = incoming.read(size)
            if len(data) != size:
                raise ValueError("truncated SHA-256 request")
            outgoing.write(hashlib.sha256(data).digest())
            outgoing.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
