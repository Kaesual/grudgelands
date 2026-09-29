"""Cut a mountain-interior window out of the section dump and open a 1-wide
tunnel of 3 x 4 nodes along x in its front face (the -z side the sw camera
sees): the render shows the tunnel floor and its back wall in the fill.
Window: local x 70..170, world y 80..150 (the peak is at x ~120, y 220),
z 0..15; tunnel y 112..115, z 0..2."""
import sys
src, dst = sys.argv[1], sys.argv[2]
out = open(dst, "w")
for line in open(src):
    x, y, z, name, p2 = line.rstrip("\n").split("\t")
    x, y, z = int(x), int(y), int(z)
    if not (70 <= x <= 170 and 80 <= y <= 150):
        continue
    if 112 <= y <= 115 and z <= 2:
        continue
    out.write("%d\t%d\t%d\t%s\t%s\n" % (x - 70, y, z, name, p2))
out.close()
