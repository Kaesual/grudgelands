"""A steady-state sample of two bounded smoke spawners, in site coordinates."""
from math import cos, sin

TEXTURE = 'default_item_smoke.png'
RATE = 2
LIFE = 5.5
VELOCITY = (.55, 2.2, .15)
SIZE = (.9, 3.4)  # Sprite width in nodes, equivalent to Luanti sizes 9..34.
EMITTERS = ((7, .75, 16), (-7, .75, -16))


def particles():
    sample = []
    for n, emitter in enumerate(EMITTERS):
        for i in range(round(RATE * LIFE)):
            age = (i + .45 + n*.28) / RATE
            t = age / LIFE
            dx, dz = sin(i*5.4+n), cos(i*3.8+n)
            origin = [emitter[0]+.13*dx, emitter[1], emitter[2]+.13*dz]
            drift = [VELOCITY[0]+.5*dx/LIFE, VELOCITY[1], VELOCITY[2]+.5*dz/LIFE]
            position = [o+age*v for o,v in zip(origin,drift)]
            sample.append(dict(origin=origin, drift=drift, age=age, at=position,
                               size=SIZE[0]+t*(SIZE[1]-SIZE[0]), alpha=.64*(1-t*t)))
    return sample


def effect():
    return dict(opacity=.64, life=LIFE, sizes=SIZE, tint=[185,180,174], puffs=particles())
