"""Geometric checks in hall coordinates, using the same registered shapes as the plates."""
from collections import deque
from itertools import product
from math import dist, floor

from arena import poses
from halls import BARRIER, BARRIER_BOX, GOLD, LAMP, RAIL, bounds, flights, place
from plates import Camera

CUBE = [[-.5, -.5, -.5, .5, .5, .5]]


def boxes_for(node, registry):
    if node == BARRIER:
        return CUBE  # The proposed collision and combat-ray shape.
    shape = registry[node].get('collision_box') or registry[node].get('node_box', {})
    boxes = shape.get('fixed', CUBE)
    return [boxes] if isinstance(boxes[0], (int, float)) else boxes


def check_hall(faction, before, after, registry):
    territory = bounds(faction)
    runs = flights()

    def friendly(u, y, v):
        cell = [floor(n + .5) for n in place(faction, u, y, v)]
        return any(all(a <= n <= b for a, n, b in zip(lo, cell, hi))
                   for lo, hi in territory.values())

    # Walk every lane of each flight. Include the turn, both landings and the
    # transitions across cell edges with a 0.6-wide player and two nodes clear.
    def walk(u, v):
        x0, x1 = u - .3, u + .3
        z0, z1 = v - .3, v + .3
        # The designed walking level gives a search window; support and clearance
        # below come from intersections with the actual template's collision boxes.
        surfaces = []
        for x in range(floor(x0+.5), floor(x1+.5)+1):
            for z in range(floor(z0+.5), floor(z1+.5)+1):
                expected = .5 + (runs.get((x, z), 16 if x >= 13 else 0)) / 2
                for y in range(max(0, floor(expected)-1), 14):
                    node = after.get((x, y, z))
                    if not node:
                        continue
                    for a, b, c, d, e, f in boxes_for(node, registry):
                        if x+a < x1 and x+d > x0 and z+c < z1 and z+f > z0:
                            surfaces.append((y+b, y+e, expected))
        support = max(hi for _, hi, expected in surfaces if hi <= expected + .001)
        assert all(hi <= support or lo >= support+2 for lo, hi, _ in surfaces), (u, v, support)
        assert friendly(u, support, v), (u, support, v)
        return support

    for lane in (2, 3, 4):
        heights = [walk(lane, 3+i/8) for i in range(81)]
        assert heights[0] == .5 and heights[-1] == 4.5
        assert all(b-a in (0, .5) for a, b in zip(heights, heights[1:]))
    for lane in (12, 13, 14):
        heights = [walk(3+i/8, lane) for i in range(113)]
        assert heights[0] == 4.5 and heights[-1] == 8.5
        assert all(b-a in (0, .5) for a, b in zip(heights, heights[1:]))
    # Room and portal approaches at ground level, including one full gathering aisle.
    for u, y, v in product(range(1, 21), range(5), range(-14, 15)):
        if (abs(v) <= 3 or 6 <= u <= 11 and abs(v) <= 11 or 12 <= u):
            assert after.get((u, y, v)) == before.get((u, y, v))
    assert after[4, 2, 0] == LAMP
    assert all(after[12, 0, v*s] == GOLD for s in (-1, 1) for v in range(6, 10))
    for u, v in product(range(13, 19), range(6, 15)):
        assert all((u, y, v) not in after for y in range(9, 13))
    # Solid ceiling and side cheeks around each new box.
    for u, v in product(range(4, 21), range(5, 16)):
        if u >= 12 or v >= 11:
            assert boxes_for(after[u, 13, v], registry) == CUBE
            assert not friendly(u, 13.5, v)
    for u, y, v in product(range(4, 21), range(8, 13), range(5, 16)):
        wall = (u <= 12 and (v in (11, 15) or (u == 4 and v >= 11))) or (
            u >= 12 and y >= 9 and (v in (5, 15) or (u == 12 and v < 12)))
        if wall:
            assert boxes_for(after[u, y, v], registry) == CUBE
    for u, v in product(range(13), range(-15, 16)):
        top = max(y for y in range(19) if (u, y, v) in after)
        assert not friendly(u, top+.5, v)
    assert all(not friendly(u, 1, v) for u in range(12, 21) for v in range(-15, 16))
    assert all(not friendly(20.51, y, v) for v in range(5, 16) for y in range(9, 13))
    assert all(after[19, 9, v] == RAIL for v in range(6, 15))
    assert all((19, y, v) not in after for y in range(10, 13) for v in range(6, 15))
    assert all(friendly(19, 9.5, v) and not friendly(20, 9.5, v) for v in range(6, 15))
    check_enclosure(after, registry)
    # Two separate flat five-square landing patches with open sky.
    for u0, v0, y in ((3, -2, 8), (14, 7, 13)):
        for u, v in product(range(u0, u0+5), range(v0, v0+5)):
            assert boxes_for(after[u, y, v], registry) == CUBE
            assert all((u, roof, v) not in after for roof in range(y+1, 19))
            assert not friendly(u, y+.5, v)


def check_enclosure(cells, registry):
    def volume(lo, hi):
        return set(product(*(range(a, b+1) for a, b in zip(lo, hi))))

    assert {p for p, node in cells.items() if node == BARRIER} == volume(*BARRIER_BOX)
    # Partial shapes are deliberately traversable here, including the rail.
    # Proving closure for a point in this larger space also covers a body in
    # flight and every eye or cast origin over the deck and fence.
    solid = {p for p, n in cells.items() if
             (n == BARRIER or registry[n]['walkable']) and boxes_for(n, registry) == CUBE}
    # In the composed arena the three-cell marker becomes one partial
    # waystone. Leave this whole stack open in the conservative search.
    solid.difference_update((4, y, 0) for y in (1, 2, 3))
    gallery = volume((13, 9, 6), (19, 12, 14))
    portal = volume((12, 9, 12), (12, 12, 14))
    assert not portal & solid

    def flood(starts, allowed, stops, offsets):
        reached = set(starts)
        todo = deque(starts)
        while todo:
            u, y, v = todo.popleft()
            for du, dy, dv in offsets:
                p = (u+du, y+dy, v+dv)
                if p in reached or p in solid or p in stops:
                    continue
                assert p in allowed, f'balcony enclosure leaks at {p}'
                reached.add(p)
                todo.append(p)
        return reached

    faces = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    # Plug only the stair mouth. Every other face must close even to a flyer.
    # Below the rail the full deck must also meet the barrier heel.
    assert not gallery & solid
    flood(gallery, gallery, portal, faces)
    assert all((u, 8, v) in solid for u in range(13, 21) for v in range(6, 15))

    # Any unobstructed ray leaving the gallery must cross the rear portal
    # toward decreasing u. A straight line cannot later turn toward +u to
    # leave via a lower sill. Explore even *bending* non-increasing-u paths
    # from the whole portal, and require all of them to stay inside the hall
    # or stair hood. Full closed cubes include their edges and corners.
    hall = volume((1, 1, -14), (11, 7, 14))
    hood = volume((5, 8, 12), (12, 12, 14))
    reached = flood(portal, hall | hood, set(), [step for step in faces if step[0] <= 0])
    assert reached & hall, 'stair mouth is disconnected from the hall'


def check_sightlines(artist, faction):
    sign = 1 if faction == 'accord' else -1
    views = poses(faction)
    # First solid on the camera's centre ray, with the actual stair, rail
    # and waystone shapes. Targets are at a standing player's eye height.
    for view, x, y, z, visible in (
            ('balcony', 0, 1.97, 0, True),          # Road crossing.
            ('balcony', -17, 7.97, -22, True),     # Opposite spur.
            ('rail', 0, 1.97, 0, True),             # Standing on the rail.
            ('flank', 0, 1.97, -45, True),         # Nearer road mouth.
            ('balcony', 22, 7.97, -10, False),     # Gate under the balcony.
            ('balcony', 0, 1.97, -10, False)):     # Behind the arcade.
        eye = views[view][0]
        target = (x*sign, y, z*sign)
        depth, _, _ = artist.geometry(Camera((eye, target, 60), 1, 1))
        assert bool(depth[0, 0] > dist(eye, target)) == visible, (faction, view, target)
