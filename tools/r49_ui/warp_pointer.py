#!/usr/bin/env python3
"""Move the X pointer onto a formspec position (Round 49 lane UI capture).

Usage: warp_pointer.py DISPLAY SCREEN_W SCREEN_H GUI_SCALE FORM_W FORM_H X Y

FORM_W/FORM_H is the form's size[] and X/Y the target in form units (real
coordinates). The pixel position follows the engine's rule for a centred form
without padding[] (reference_projects/luanti/src/gui/guiFormSpecMenu.cpp
calculateImgsize and getImgsize, regenerateGui's DesiredRect) at 96 DPI. Only
the standard library: ctypes with the host's libX11.
"""
import ctypes
import ctypes.util
import sys


def form_pixel(screen_w, screen_h, scale, form_w, form_h, x, y):
    padded_w, padded_h = screen_w * 0.9, screen_h * 0.9
    fixed = 0.5555 * 96 * scale
    prefer = max(int(min(padded_w, padded_h)) // 15 * scale, fixed)
    imgsize = int(min(prefer, padded_w / form_w, padded_h / form_h))
    size_w, size_h = form_w * imgsize, form_h * imgsize
    left = int(screen_w * 0.5) - int(0.5 * size_w)
    top = int(screen_h * 0.5) - int(0.5 * size_h)
    return int(left + x * imgsize), int(top + y * imgsize), imgsize


def main(argv):
    display = argv[1].encode()
    screen_w, screen_h = int(argv[2]), int(argv[3])
    scale = float(argv[4])
    form_w, form_h, x, y = (float(value) for value in argv[5:9])
    px, py, imgsize = form_pixel(screen_w, screen_h, scale, form_w, form_h, x, y)
    x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XDefaultRootWindow.restype = ctypes.c_ulong
    x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x11.XWarpPointer.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong,
                                 ctypes.c_int, ctypes.c_int, ctypes.c_uint,
                                 ctypes.c_uint, ctypes.c_int, ctypes.c_int]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    handle = x11.XOpenDisplay(display)
    if not handle:
        print("warp_pointer: cannot open display", argv[1], file=sys.stderr)
        return 1
    root = x11.XDefaultRootWindow(handle)
    # A small step first: some toolkits ignore a single warp to where the
    # pointer already is.
    x11.XWarpPointer(handle, 0, root, 0, 0, 0, 0, px - 2, py - 2)
    x11.XFlush(handle)
    x11.XWarpPointer(handle, 0, root, 0, 0, 0, 0, px, py)
    x11.XFlush(handle)
    x11.XCloseDisplay(handle)
    print(f"warp_pointer: {argv[1]} -> {px},{py} (imgsize {imgsize})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
