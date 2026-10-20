#!/usr/bin/env python3
"""Z-fighting check, rest pose, all bones together (mirrored copies included):
no two boxes may have same-facing faces closer than 0.25 px where they overlap.
Exit 1 on a problem."""
import itertools
import sys

sys.dont_write_bytecode = True
import catalog  # noqa: E402

BODY = [("head", "head", [-4, 24, -4, 4, 32, 4]), ("hat", "head", [-4.5, 23.5, -4.5, 4.5, 32.5, 4.5]),
        ("torso", "body", [-4, 12, -2, 4, 24, 2]), ("arm", "arm_r", [-8, 12, -2, -4, 24, 2]),
        ("leg", "leg_r", [-4, 0, -2, 0, 12, 2])]


def mirrored(b):
    return [-b[3], b[1], b[2], -b[0], b[4], b[5]]


def main():
    items = [(n, b, box) for n, b, box in BODY] + [(s["id"], s["bone"], s["box"]) for s in catalog.boxes() if not s["rot"]]
    items += [(n + "_l", b.replace("_r", "_l"), mirrored(box)) for n, b, box in list(items) if b.endswith("_r")]
    items += [(s["id"] + "_l", "body", mirrored(s["box"])) for s in catalog.boxes()
              if s["mirror"] and s["bone"] == "body" and not s["rot"]]
    bad = 0
    # all bones together, in the rest pose: boxes on different bones touch at rest too
    for (na, ba, A), (nb, bb, B) in itertools.combinations(items, 2):
        for ax in range(3):
            o = [i for i in range(3) if i != ax]
            if not all(min(A[i + 3], B[i + 3]) - max(A[i], B[i]) > 0 for i in o):
                continue
            for side in (0, 3):
                if abs(A[ax + side] - B[ax + side]) < 0.25 - 1e-9:
                    bad += 1
                    print(f"Z-FIGHT {na} / {nb}: axis {'xyz'[ax]} {'min' if side == 0 else 'max'} faces "
                          f"{A[ax + side]} vs {B[ax + side]}")
    print("boxes in the model:", catalog.box_count(), "vertices:", catalog.box_count() * 24 + catalog.BODY_VERTICES,
          "| problems:", bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
