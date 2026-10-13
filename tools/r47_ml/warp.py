#!/usr/bin/env python3
"""Round 47 lane ML: put the X pointer at a pixel of a display (the capture's
private Xvfb), so the screenshot shows the tooltip of the marker under it.
Standard library only (ctypes on the host's libX11 and libXtst).

Usage: python3 -I tools/r47_ml/warp.py :DISPLAY X Y
"""
import ctypes
import sys


def main():
    display_name, x, y = sys.argv[1].encode(), int(sys.argv[2]), int(sys.argv[3])
    x11 = ctypes.CDLL("libX11.so.6")
    xtst = ctypes.CDLL("libXtst.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int,
                                          ctypes.c_int, ctypes.c_ulong]
    display = x11.XOpenDisplay(display_name)
    if not display:
        sys.exit("cannot open display " + sys.argv[1])
    # Two moves: the client reacts to motion, not to a pointer already there.
    xtst.XTestFakeMotionEvent(display, -1, x - 3, y - 3, 0)
    x11.XFlush(display)
    xtst.XTestFakeMotionEvent(display, -1, x, y, 0)
    x11.XFlush(display)
    x11.XCloseDisplay(display)


if __name__ == "__main__":
    main()
