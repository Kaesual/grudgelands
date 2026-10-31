#!/usr/bin/env python3
"""Build the approved Round 63 mining-camp art and animated B3D meshes."""
import argparse
import io
import struct
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
MAP = ROOT / "mods/MAPGEN/grug_mapgen"
# Animated B3D node meshes use engine units: BS=10, unlike node boxes.
# reference_projects/luanti/src/client/node_visuals.cpp:507-520
ENGINE_UNITS_PER_NODE = 10.0


def chunk(tag, body):
    return tag.encode("ascii") + struct.pack("<i", len(body)) + body


def cloth_svg(color, trim=False):
    stripe = '<path d="M0 6H32M0 26H32" stroke="#b3a183" stroke-width="2"/>' if trim else ""
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><defs><pattern id="w" width="4" height="4" patternUnits="userSpaceOnUse"><path d="M0 0H4M0 2H4" stroke="#fff" opacity=".09"/><path d="M0 0V4M2 0V4" stroke="#000" opacity=".08"/></pattern></defs><path fill="%s" d="M0 0H32V32H0Z"/><path fill="url(#w)" d="M0 0H32V32H0Z"/>%s<path d="M1 0V32M31 0V32" stroke="#312f29" opacity=".3"/></svg>''' % (color, stripe)


def raster(svg):
    proc = __import__("subprocess").run(
        ["convert", "-background", "none", "svg:-", "png:-"], input=svg.encode("utf-8"),
        capture_output=True, check=True)
    image = Image.open(io.BytesIO(proc.stdout)).convert("RGBA")
    out = io.BytesIO()
    image.save(out, "PNG", optimize=False)
    return out.getvalue()


def normal(a, b, c):
    ux, uy, uz = (b[i] - a[i] for i in range(3))
    vx, vy, vz = (c[i] - a[i] for i in range(3))
    x, y, z = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    length = (x*x + y*y + z*z) ** 0.5 or 1.0
    return x/length, y/length, z/length


def buffer(vertices, triangles):
    return vertices, triangles


def flat_buffer(points, uvs):
    n = normal(points[0], points[1], points[2])
    vertices = [(p, uv, n) for p, uv in zip(points, uvs)]
    vertices.extend((p, uv, tuple(-value for value in n)) for p, uv in zip(points, uvs))
    # Separate back vertices preserve the UVs while giving lighting the
    # outward normal on each side.
    return buffer(vertices, ((0, 1, 2), (0, 2, 3), (6, 5, 4), (7, 6, 4)))


def boxes_buffer(boxes):
    vertices, triangles = [], []
    for box in boxes:
        x0,y0,z0,x1,y1,z1 = box
        corners = ((x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),
                   (x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1))
        faces = ((0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4))
        for face in faces:
            base = len(vertices)
            pts = [corners[i] for i in face]
            n = normal(pts[0], pts[1], pts[2])
            vertices.extend((p, uv, n) for p,uv in zip(pts, ((0,0),(1,0),(1,1),(0,1))))
            triangles.extend(((base,base+1,base+2),(base,base+2,base+3)))
    return buffer(vertices, triangles)


def b3d(buffers):
    # CB3DMeshFileLoader owns one vertex array per MESH. Each TRIS chunk
    # creates one mesh buffer, but its indices address that shared array.
    # Keep the buffers in node-tile order and offset every later index.
    all_vertices, triangle_chunks = [], []
    for vertices, triangles in buffers:
        offset = len(all_vertices)
        all_vertices.extend(vertices)
        triangle_chunks.append(chunk("TRIS", struct.pack("<i", -1) + b"".join(
            struct.pack("<3i", *(index + offset for index in tri)) for tri in triangles)))
    vrts = struct.pack("<3i", 1, 1, 2)
    for pos, uv, norm in all_vertices:
        engine_pos = tuple(value * ENGINE_UNITS_PER_NODE for value in pos)
        vrts += struct.pack("<8f", *(engine_pos + norm + uv))
    mesh = struct.pack("<i", -1) + chunk("VRTS", vrts) + b"".join(triangle_chunks)
    vertex_count = len(all_vertices)
    mesh_node = (b"Camp\0" + struct.pack("<10f", 0,0,0, 1,1,1, 1,0,0,0) +
                 chunk("MESH", mesh))
    weights = b"".join(struct.pack("<if", i, 1.0) for i in range(vertex_count))
    keys = struct.pack("<ii3f", 1, 1, 0, 0, 0)
    bone_node = (b"Rest\0" + struct.pack("<10f", 0,0,0, 1,1,1, 1,0,0,0) +
                 chunk("BONE", weights) + chunk("KEYS", keys))
    # The rest bone is a child of the mesh node. This gives the weights the
    # loader's current MESH vertex base and keeps bind/rest transforms equal.
    mesh_node += chunk("NODE", bone_node)
    root = (b"Root\0" + struct.pack("<10f", 0,0,0, 1,1,1, 1,0,0,0) +
            chunk("ANIM", struct.pack("<iif", 0, 1, 1.0)) + chunk("NODE", mesh_node))
    body = struct.pack("<i", 1) + chunk("NODE", root)
    return chunk("BB3D", body)


def chunks(data, start, end):
    pos = start
    while pos < end:
        assert pos + 8 <= end
        tag = data[pos:pos + 4]
        size = struct.unpack_from("<i", data, pos + 4)[0]
        assert size >= 0 and pos + 8 + size <= end
        yield tag, pos + 8, pos + 8 + size
        pos += 8 + size
    assert pos == end


def validate_b3d(data, expected_buffers, banner=False):
    """Structural checks for the constraints used by CB3DMeshFileLoader."""
    assert data[:4] == b"BB3D" and data.count(b"BRUS") == 0
    root_end = 8 + struct.unpack_from("<i", data, 4)[0]
    assert root_end == len(data)
    top = list(chunks(data, 12, root_end))
    assert [tag for tag, _, _ in top] == [b"NODE"]
    mesh_ranges, anim_depths = [], []
    def walk(start, end, depth):
        zero = data.index(b"\0", start)
        pos = zero + 1 + 40
        for tag, begin, finish in chunks(data, pos, end):
            if tag == b"NODE": walk(begin, finish, depth + 1)
            elif tag == b"MESH": mesh_ranges.append((begin, finish))
            elif tag == b"ANIM":
                anim_depths.append(depth)
                assert finish - begin == 12
    walk(top[0][1], top[0][2], 0)
    assert anim_depths == [0]
    assert len(mesh_ranges) == 1
    begin, end = mesh_ranges[0]
    children = list(chunks(data, begin + 4, end))
    vrts = [row for row in children if row[0] == b"VRTS"]
    tris = [row for row in children if row[0] == b"TRIS"]
    assert len(vrts) == 1 and len(tris) == expected_buffers
    vbegin, vend = vrts[0][1], vrts[0][2]
    flags, sets, size = struct.unpack_from("<3i", data, vbegin)
    assert (flags, sets, size) == (1, 1, 2)
    stride = 32
    count = (vend - vbegin - 12) // stride
    assert vbegin + 12 + count * stride == vend
    # A one-node canvas must span ten engine units. Check exported bounds,
    # independently of the conversion constant, so a missing scale fails.
    vertices = [struct.unpack_from("<8f", data, vbegin + 12 + i * stride)
                for i in range(count)]
    bounds = tuple(min(v[axis] for v in vertices) for axis in range(3)) + tuple(
        max(v[axis] for v in vertices) for axis in range(3))
    expected = (-6.5, -15.0, -6.1, 6.5, 7.2, 1.0) if banner else (-5.0, -5.0, -5.0, 5.0, 5.0, 5.0)
    assert all(abs(a-b) < 1e-5 for a,b in zip(bounds, expected)), (bounds, expected)
    used = []
    for _, tbegin, tend in tris:
        assert struct.unpack_from("<i", data, tbegin)[0] == -1
        assert (tend - tbegin - 4) % 12 == 0
        ids = struct.unpack_from("<%di" % ((tend - tbegin - 4) // 4), data, tbegin + 4)
        assert ids and min(ids) >= 0 and max(ids) < count
        used.append((min(ids), max(ids)))
    assert all(used[i][1] < used[i + 1][0] for i in range(len(used) - 1))
    if banner:
        # V is passed through directly: upper cloth vertices use 0, lower 1.
        values = [struct.unpack_from("<8f", data, vbegin + 12 + i * stride) for i in range(4)]
        assert [row[7] for row in values] == [0.0, 0.0, 1.0, 1.0]
    assert data.count(b"BONE") == 1 and data.count(b"KEYS") == 1


def outputs():
    canvas = flat_buffer(((-.5,-.5,-.5),(.5,.5,-.5),(.5,.5,.5),(-.5,-.5,.5)),
                         ((0,0),(1,0),(1,1),(0,1)))
    banner = flat_buffer(((-.48,.5,-.52),(.48,.5,-.52),(.48,-1.5,-.52),(-.48,-1.5,-.52)),
                         ((0,0),(1,0),(1,1),(0,1)))
    rod = boxes_buffer(((-.65,.43,-.59,.65,.56,-.45),))
    strap_boxes = []
    for x in (-.32,.32):
        strap_boxes.extend(((x-.045,.24,-.61,x+.045,.72,-.43),
                            (x-.045,.63,-.61,x+.045,.72,.10)))
    straps = boxes_buffer(strap_boxes)
    canvas_mesh = b3d((canvas,))
    banner_mesh = b3d((banner, rod, straps))
    validate_b3d(canvas_mesh, 1)
    validate_b3d(banner_mesh, 3, True)
    result = {
        MAP / "models/grug_mapgen_camp_canvas.b3d": canvas_mesh,
        MAP / "models/grug_mapgen_faction_banner.b3d": banner_mesh,
        MAP / "textures/grug_mapgen_camp_canvas.png": raster(cloth_svg("#99917b")),
        MAP / "textures/grug_mapgen_camp_ridge.png": raster(cloth_svg("#635a46")),
        MAP / "textures/grug_mapgen_camp_trim_accord.png": raster(cloth_svg("#465967", True)),
        MAP / "textures/grug_mapgen_camp_trim_throng.png": raster(cloth_svg("#754c45", True)),
    }
    # The faction heraldry (banner cloth and inventory emblem) comes from
    # tools/r67_emblem since Round 67 (the user's pick, hart and boar).
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    for path, data in outputs().items():
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    if stale:
        print("r63_camp_art: stale: " + ", ".join(stale))
        return 1
    print("r63_camp_art: %s" % ("OK" if args.check else "assets written"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
