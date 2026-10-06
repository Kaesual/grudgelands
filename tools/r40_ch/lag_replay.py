#!/usr/bin/env python3
"""Round 40 CH follow-up: replay of the client's drawn carrier behind a Charge dash.

The client draws a non-physical entity through SmoothTranslator: every frame
it extrapolates m_position with the entity's velocity and acceleration and
closes 0.8 x frame_dt / update_interval of the gap to it
(reference_projects/luanti/src/client/content_cao.cpp:62-93, 1121-1125;
packets every dedicated_server_step, 0.09 s, set m_position and the interval,
content_cao.cpp:1640-1655). An attached local player copies the drawn position
and keeps it on detach (localplayer.cpp:229-233), so the gap at the release is
the forward snap the final set_pos makes. Prints that gap at several holds,
at constant speed and with the speed eased down over the last metres.
Stdlib only: python3 tools/r40_ch/lag_replay.py
"""
def run(L, v=24.0, server_dt=0.09, send=0.09, fps=60, decel=0.0):
    # server path: constant v, or decelerate over the last `decel` metres to 0
    if decel > 0:
        tc = (L - decel) / v; td = 2 * decel / v; T = tc + td; a = v / td
        def s(t):
            if t <= tc: return v * t, v
            if t <= T: u = t - tc; return v*tc + v*u - 0.5*a*u*u, v - a*u
            return L, 0.0
    else:
        T = L / v
        def s(t): return (v * t, v) if t < T else (L, 0.0)
    fdt = 1.0 / fps
    t = 0.0; next_send = 0.0
    mpos, mvel = 0.0, v
    cur = old = tgt = 0.0; anim = send; cnt = 0.0
    out = {}
    marks = [0, 0.1, 0.17, 0.2, 0.23, 0.26, 0.3, 0.34]
    while t < T + 0.6:
        # packet (server sends at its step boundaries every `send` s)
        if t >= next_send - 1e-9:
            st = round(t / server_dt) * server_dt
            mpos, mvel = s(st)
            old, tgt, anim, cnt = cur, mpos, send, 0.0
            next_send += send
        mpos += mvel * fdt
        if t >= T: mpos = min(mpos, L) if mvel == 0 else mpos
        old, tgt, cnt = cur, mpos, 0.0  # per-frame update(m_position, aim, anim_time)
        cnt += fdt
        ratio = min(cnt / anim * 0.8, 1.5)
        cur = old + (tgt - old) * ratio
        t += fdt
        for m in marks:
            if m not in out and t >= T + m: out[m] = L - cur
    return T, out
for L, dec in ((10.7, 0), (4.0, 0), (10.7, 3.0), (10.7, 1.5)):
    T, o = run(L, decel=dec)
    print(f"dash {L} m decel {dec} m: dash {T:.3f} s; drawn gap after stop: " +
          ", ".join(f"{k:.2f}s {g:.2f}m" for k, g in sorted(o.items())))
