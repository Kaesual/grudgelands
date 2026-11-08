#!/usr/bin/env python3
"""Press a jump on a client in an Xvfb display (Round 72 lane MINT's engine run).

Usage: keys.py DISPLAY jump

`jump`: the pointer to the screen's middle (keyboard focus follows it without a window
manager), forward held, jump tapped after 0.15 s at walking speed, forward released 1.0 s
after it was pressed: an ordinary walking jump, no sprint. XTest through the host's libX11
and libXtst (ctypes, standard library only), as tools/r49_ui/warp_pointer.py moves the
pointer.
"""
import ctypes
import ctypes.util
import sys
import time


def main(argv):
    if len(argv) != 3 or argv[2] != "jump":
        print(__doc__, file=sys.stderr)
        return 2
    x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
    xtst = ctypes.cdll.LoadLibrary(ctypes.util.find_library("Xtst") or "libXtst.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x11.XWarpPointer.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_int, ctypes.c_int,
                                 ctypes.c_uint, ctypes.c_uint, ctypes.c_int, ctypes.c_int]
    x11.XStringToKeysym.restype = ctypes.c_ulong
    x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
    x11.XKeysymToKeycode.restype = ctypes.c_ubyte
    x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    handle = x11.XOpenDisplay(argv[1].encode())
    if not handle:
        print("keys: cannot open display", argv[1], file=sys.stderr)
        return 1
    root = x11.XDefaultRootWindow(handle)
    x11.XWarpPointer(handle, 0, root, 0, 0, 0, 0, 480, 270)
    x11.XFlush(handle)
    forward = x11.XKeysymToKeycode(handle, x11.XStringToKeysym(b"w"))
    jump = x11.XKeysymToKeycode(handle, x11.XStringToKeysym(b"space"))

    def key(code, down):
        xtst.XTestFakeKeyEvent(handle, code, 1 if down else 0, 0)
        x11.XFlush(handle)

    key(forward, True)
    time.sleep(0.15)
    key(jump, True)
    time.sleep(0.2)
    key(jump, False)
    time.sleep(0.65)
    key(forward, False)
    x11.XCloseDisplay(handle)
    print("keys: jump on", argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
