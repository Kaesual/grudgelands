"""Round 84 scale models. Coordinates are node centres, +z north, +x east."""
from dataclasses import dataclass
from math import cos, sin

from PIL import Image, ImageDraw


BRICK = 'default:stonebrick'
STONE = 'default:stone_block'
PALE = 'default:silver_sandstone_block'
SLATE = 'grug_decor:darkage_slate_tile'
BASALT = 'grug_decor:darkage_basalt_brick'
RUBBLE = 'grug_decor:darkage_basalt_rubble'
LOG = 'default:pine_tree'
PLANK = 'default:acacia_wood'
OAK = 'default:wood'
GOLD = 'grug_materials:bronze_block'
BONE = 'grug_decor:darkage_marble'
BLUE = 'wool:blue'
RED = 'wool:red'
LAMP = 'grug_materials:emberglass_lamp'
DIRT = 'default:dry_dirt'
SOIL = 'default:dirt'
FOREST = 'grug_nodes:dirt_with_forest_litter'
LITTER = 'default:dirt_with_coniferous_litter'
CLAY = 'grug_nodes:mesa_clay'
ROCK = 'grug_materials:basalt'
GRAVEL = 'default:gravel'
COBBLE = 'default:cobble'
STAIR = 'stairs:stair_sandstonebrick'
SLAB = 'stairs:slab_stone_block'
APPLE = 'default:tree'


@dataclass(frozen=True)
class Site:
    key: str
    name: str
    rx: int
    rz: int
    back: int
    summary: str
    rationale: str
    field_note: str

    def place(self, faction, u, y, v):
        sign = 1 if faction == 'accord' else -1
        return sign * (self.back - u), y + 6, -sign * v


SITE = Site('breach', 'Breach Road', 49, 45, 42,
            'The road below the ruined galleries',
            'The middle road cuts between two broken stone galleries. Ride straight through beneath the standards, or turn up the broad stairs and fight from pier to pier.',
            'Each high spur looks across a road entrance. Its broken breastwork shelters a ranged fighter, while stairs beside the arcade bring melee onto the same ledge.')
FIRST = Site('first', 'First pass', 49, 43, 42, 'The original level field',
             'The two faction halls, bronze sills and broken arcade as first proposed.',
             'The road, the arcade and both halls share one level. Six nodes at the shoulder were reserved for grading.')
FACTIONS = ('accord', 'throng')


class Model(dict):
    """Sparse solids. Empty cells in a building stamp are explicit air."""

    def box(self, x1, y1, z1, x2, y2, z2, material):
        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                for z in range(z1, z2 + 1):
                    self[x, y, z] = material

    def post(self, x, z, low, high, material):
        self.box(x, low, z, x, high, z, material)


def crest(m, accord, u, bottom, width=0):
    """Woven, fork-tailed colours. The stag and tusks follow the opening standards."""
    field, thread = (BLUE, PALE) if accord else (RED, BONE)
    rows = (['x.....x','x.x.x.x','.xx.xx.','..x.x..','..xxx..','...xxx.','...x...'] if accord else
            ['.......','..xxx..','x.x.x.x','x.xxx.x','.xxxxx.','..x.x..','...x...'])
    for i,row in enumerate(rows):
        for j,ch in enumerate(row):
            m[u,bottom+7-i,width+j-3] = thread if ch=='x' else field
    for z in (-3,-2,0,2,3): m[u,bottom,width+z] = field
    m.box(u,bottom+8,width-4,u,bottom+8,width+4,GOLD if accord else LOG)


def crenels(m, x1, x2, z1, z2, y, material):
    for x in range(x1, x2+1):
        for z in range(z1, z2+1):
            if ((x in (x1,x2) and (z-z1)%4 < 2) or
                    (z in (z1,z2) and (x-x1)%4 < 2)):
                m.post(x,z,y,y+1,material)


def bastion(m, cx, cz, radius, top):
    for x in range(cx-radius,cx+radius+1):
        for z in range(cz-radius,cz+radius+1):
            a,b = abs(x-cx),abs(z-cz)
            if a+b > radius*2-2:
                continue
            m.post(x,z,8,top,BRICK)
            edge = max(a,b)==radius or a+b==radius*2-2
            if edge:
                m[x,top-1,z] = PALE
                if (x+z)%4 in (0,1):
                    m.post(x,z,top+1,top+2,STONE)
                if a*b==0:
                    m.post(x,z,top-5,top-3,BASALT)


def timber_crown(m, cx, cz, radius, top):
    """An open upper storey with cross-braces, projecting ring beams and split tips."""
    for dx in (-radius,radius):
        for dz in (-radius,radius):
            x,z = cx+dx,cz+dz
            m.post(x,z,8,top+2+(dx==dz),LOG)
            m[x,top-1,z] = BASALT
    for y in (9,top):
        for face in (-radius,radius):
            m.box(cx-radius-1,y,cz+face,cx+radius+1,y,cz+face,PLANK)
            m.box(cx+face,y,cz-radius-1,cx+face,y,cz+radius+1,PLANK)
    for i in range(2*radius+1):
        y = 10 + min(i,2*radius-i)
        for face in (-radius,radius):
            m[cx-radius+i,y,cz+face] = LOG
            m[cx+face,y,cz-radius+i] = LOG
    m.box(cx-radius,top,cz-radius,cx+radius,top,cz+radius,PLANK)


def hall(faction):
    """u increases toward the road. Only the enclosed hall, behind u=12, is friendly."""
    m = Model()
    accord = faction=='accord'
    wall,trim,floor,cloth = (BRICK,PALE,STONE,BLUE) if accord else (OAK,LOG,PLANK,RED)
    m.box(0,0,-15,20,0,15,floor)
    # Hall perimeter, cordons and structural bays. Leave its entire interior clear.
    for x in range(13):
        for z in range(-15,16):
            if x in (0,12) or abs(z)==15:
                for y in range(1,8):
                    face = wall
                    if y in (1,7): face = STONE if accord else BASALT
                    if (x in (0,12) and z%6==0) or (abs(z)==15 and x%6==0):
                        face = STONE if accord else trim
                    if not accord and y in (3,6): face = PLANK
                    m[x,y,z] = face
    m.box(0,8,-15,12,8,15,SLATE if accord else OAK)
    # Roof beams, paired benches, inlaid aisle and the cold waystone plinth.
    for z in (-12,-6,0,6,12):
        m.box(1,7,z,11,7,z,trim)
        for x in (1,11): m.post(x,z,1,6,trim)
        if abs(z)==6:
            for x in (1,11): m[x,5,z] = LAMP
    for z in range(-13,14):
        for x in (3,9): m[x,0,z] = cloth
    for x in range(2,10):
        for z in (-13,13): m[x,1,z] = floor if accord else LOG
    for x in range(1,8):
        for z in range(-4,5):
            d = abs(x-4)+abs(z)
            if d<=3: m[x,0,z] = GOLD if d==3 else trim
    # A short dais and a woven recess set the one touchstone apart from the wall lights.
    for z in (-1,0,1): m.box(3,1,z,4,1,z,STONE if accord else BASALT)
    m[4,1,0],m[4,2,0],m[4,3,0] = BASALT,LAMP,BASALT
    for z in range(-3,4):
        for y in range(2,7):
            m[0,y,z] = trim if abs(z)+abs(y-4)==2 else cloth
    m.box(1,6,-3,1,6,3,GOLD if accord else PLANK)
    for side in (-1,1):
        for z in range(6,10):
            for y in range(1,5): m.pop((12,y,z*side),None)
            m[12,0,z*side] = GOLD
            m[11,0,z*side] = cloth
        # Open-air return court. A full-height traverse between the two gates
        # blocks all straight segments between their coplanar openings.
        for v in range(1,16):
            z = side*v
            m[16,0,z] = COBBLE
            if v>=5: m.post(16,z,1,6,wall if accord else LOG)
            if v not in range(8,12): m.post(20,z,1,5,wall if accord else LOG)
            if v in (7,12): m.post(20,z,1,6,STONE if accord else trim)
            if v in range(7,13): m[20,5,z] = STONE if accord else trim
        m.box(12,1,side*15,20,6,side*15,wall)
        for x in (13,16,19): m.post(x,side*15,1,7,STONE if accord else trim)
    m.box(12,1,-1,20,7,1,wall)
    m.box(16,6,-4,20,9,4,wall)
    if accord:
        bastion(m,5,-10,4,16)
        bastion(m,5,10,4,13)
        crenels(m,0,12,-15,15,9,BRICK)
        m.box(16,10,-4,20,11,4,STONE)
        crenels(m,16,20,-4,4,12,BRICK)
    else:
        timber_crown(m,5,10,4,15)
        timber_crown(m,5,-10,3,13)
        for z in range(-14,15,2): m.post(12,z,8,9+abs(z*5)%3,LOG)
        for v in (-4,4): m.post(20,v,6,13,LOG)
        m.box(16,10,-5,20,10,5,PLANK)
    crest(m,accord,20,4)
    # A matching colour panel on each short approach elevation, at riding distance.
    for end in (-15,15):
        for x in range(4,9):
            for y in range(3,7): m[x,y,end] = trim if (x==6 or y==6) else cloth
    return m


# East wing, local x/z. The west wing turns through 180 degrees, including
# the stairs and their approaches. The road and its two entrances stay level.
GALLERY = [(9,-17),(13,-24),(14,-27),(22,-27),(25,-31),(35,-26),(45,-18),
           (45,17),(35,25),(28,33),(17,33),(11,27),(9,19)]
UPPER = [(21,-16),(24,-20),(36,-21),(43,-16),(43,16),(34,22),
         (28,29),(18,29),(14,25),(14,20),(21,20)]
RIM = [(0,-45),(6,-45),(9,-38),(17,-36),(25,-39),(37,-32),
       (40,-24),(48,-21),(49,-15),(49,16),(46,21),(38,29),
       (30,38),(18,40),(10,35),(6,45),(0,45)]
# An axial route through both courts and a second way up around the spur.
# First stair, uphill vector, half-width, lower landing level, number of rises.
FLIGHTS = ((7, -9, 1, 0, 2, 0, 3), (7, 9, 1, 0, 2, 0, 3),
           (18, -9, 1, 0, 2, 3, 3), (18, 9, 1, 0, 2, 3, 3),
           (16, 18, 0, 1, 2, 3, 3), (17, -30, 0, 1, 2, 0, 3))


def polygon(points):
    mask = Image.new('1', (SITE.rx + 1, 2 * SITE.rz + 1))
    ImageDraw.Draw(mask).polygon([(x, z + SITE.rz) for x, z in points], fill=1)
    return {(x, z - SITE.rz) for z in range(mask.height) for x in range(mask.width)
            if mask.getpixel((x, z))}


def mirrored(x, z):
    return ((x, z), (-x, -z))


class Ground:
    def __init__(self):
        rim, gallery, upper = map(polygon, (RIM, GALLERY, UPPER))
        self.heights = {}
        self.stairs = {}
        self.rim = set()
        distances = dict.fromkeys(rim, 0)
        inside = rim
        # The fringe follows this illustrative surveyed edge, ±3 nodes.
        # Ignore the centre seam and keep the road mouths flat.
        for dist in range(1, 7):
            inside = {(x, z) for x, z in inside
                      if all((abs(x+dx), z+dz) in inside for dx, dz in
                             ((1,0),(-1,0),(0,1),(0,-1)))}
            distances.update(dict.fromkeys(inside, dist))
        for (x, z), dist in distances.items():
            height = 6 if (x,z) in upper else 3 if (x,z) in gallery else 0
            for wx,wz in mirrored(x,z):
                h = height
                if dist < 6 and not height and x > 5:
                    self.rim.add((wx,wz))
                    # Cut bank to the east and a fill toe to the west. Local
                    # cut/fill ends at the road mouth, which retains its grade.
                    residual = 3*sin(.045*wx + .043*wz)
                    h = round(residual * (1 - dist/6) * min(1, (x-5)/5))
                self.heights[wx,wz] = h
        # The low return from each road mouth is graded before its stair.
        self.flank_paths = {p for x in range(4,20) for z in range(-33,-30)
                            for p in mirrored(x,z)}
        for p in self.flank_paths:
            self.heights[p] = 0
            self.rim.discard(p)
        for x,z,dx,dz,width,base,rise in FLIGHTS:
            for w in range(-width, width+1):
                for i in range(-1, rise+1):
                    xx,zz = x + dx*i + dz*w, z + dz*i + dx*w
                    for sign in (-1,1):
                        p = sign*xx,sign*zz
                        assert p in self.heights
                        self.heights[p] = base + min(rise, max(0,i+1))
                        if 0 <= i < rise:
                            fd = (1 if dx else 0) + (2 if sign < 0 else 0)
                            self.stairs[p] = fd

    @staticmethod
    def local_ground(x, z):
        noise = sin(x*.21 + sin(z*.12)*1.9) + cos(z*.18-x*.07)
        if x < 0:
            return FOREST if noise > 1 else SOIL if noise < -.6 else LITTER
        return CLAY if noise > -.7 else DIRT

    @staticmethod
    def road(x, z):
        wear = sin(z*.21+x*.38) + .6*cos(z*.37-x*.9)
        if abs(x) == 3 and wear > .45: return STONE
        if wear > .64: return COBBLE
        if abs(x) == 2 and wear > -.65: return SOIL
        return DIRT if wear < -.3 else GRAVEL

    def surface(self, x, z):
        h = self.heights[x,z]
        if (x,z) in self.stairs:
            return STAIR
        noise = sin(x*.29 + sin(z*.14)*2) + .8*cos(z*.22-x*.09)
        if abs(x) <= 3:
            return self.road(x,z)
        if (x,z) in self.flank_paths:
            return GRAVEL if noise > .45 else DIRT
        if (x,z) in self.rim:
            return self.local_ground(x,z)
        if h in (3,6):
            if any(self.heights.get((x+dx,z+dz),h) < h for dx,dz in ((1,0),(-1,0),(0,1),(0,-1))):
                return STONE
            if 7 <= abs(z) <= 11 or (h == 6 and abs(x) < 21):
                return BRICK if noise > -.6 else COBBLE
            return GRAVEL if noise > 1 else (COBBLE if noise < -.7 else DIRT)
        if abs(x) < 8 or noise < -.75: return GRAVEL if noise < -.2 else DIRT
        return (FOREST if x < 0 else CLAY) if noise > .6 else (SOIL if x < 0 else DIRT)


def surroundings(ground):
    """Illustrative natural cut/fill beyond the survey, never part of its stamp."""
    m = Model()
    heights = ground.heights.copy()
    apron = set(heights)
    for _ in range(5):
        apron |= {(x+dx,z+dz) for x,z in apron for dx,dz in ((1,0),(-1,0),(0,1),(0,-1))}
    for z in range(45,61):
        width = 4+(60-z)//4
        apron.update((x,sign*z) for x in range(-width,width+1) for sign in (-1,1))
    for x,z in sorted(apron - heights.keys()):
        factor = min(1, max(0,(abs(x)-5)/5))
        heights[x,z] = round(3*sin(.045*x+.043*z)*factor)
    for (x,z), h in heights.items():
        if (x,z) in ground.heights: continue
        low = min(heights.get((x+dx,z+dz),h-1) for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)))
        m.post(x,z,min(low,h-1),h-1,SOIL if x<0 else CLAY)
        m[x,h,z] = ground.road(x,z) if abs(x)<=3 else ground.local_ground(x,z)
    return m


def field(ground):
    m = Model()
    for (x,z), h in ground.heights.items():
        below = min(ground.heights.get((x+dx,z+dz),h-2) for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)))
        for y in range(min(below,h-1),h):
            if y >= 0 and h > 0 and (x,z) not in ground.rim:
                material = BRICK if y % 3 == 2 else (RUBBLE if (x+z)%9 < 2 else COBBLE)
            else:
                material = SOIL if x < 0 else CLAY
            m[x,y,z] = material
        m[x,h,z] = ground.surface(x,z)

    for s in (-1,1):
        # The original four piers and surviving arch on each gallery.
        for cz,h in ((-12,4),(-5,6),(4,4),(12,2)):
            cx = 15 if abs(cz)<10 else 12
            for dx in (-1,0,1):
                for dz in (-1,0,1):
                    x,z = s*(cx+dx),s*(cz+dz)
                    m[x,4,z] = STONE
                    if dx==0 or dz==0: m.post(x,z,5,h+3,BRICK)
                    if h>=4: m[x,h+3,z] = PALE
        for z in range(-12,-4):
            x = 12+min(3,(z+12)//2)
            h = 8 if z in (-12,-11,-6,-5) else 9
            for dx in (0,1):
                m[s*(x+dx),h,s*z] = STONE
                m[s*(x+dx),h+1,s*z] = BRICK
            if z in (-12,-11,-6,-5): m[s*x,h-1,s*z] = BRICK
        # A broken breastwork turns the spur. Missing panels open the view.
        for x,z in ((15,22),(15,23),(15,24),(17,26),(18,27),(19,27),(20,27)):
            m[s*x,7,s*z] = BRICK
            m[s*x,8,s*z] = STONE if z in (22,27) and x%2 else SLAB
        for x,z in ((12,-19),(13,-19),(13,-20),(14,-20),(24,-24),(25,-24)):
            h = ground.heights[s*x,s*z]
            m[s*x,h+1,s*z] = RUBBLE if x%2 else SLAB
        # The footing of a fallen wall shelters the back route round the hall.
        for x,z in ((25,-18),(26,-18),(27,-18),(28,-18),(28,-19),(29,-19)):
            h = ground.heights[s*x,s*z]
            m[s*x,h+1,s*z] = BRICK if x in (25,26,29) else SLAB
            if x==25: m[s*x,h+2,s*z] = RUBBLE
        # An old road marker at the level approach, broken below rider height.
        x,z = s*5,s*32
        m[x,1,z],m[x,2,z] = COBBLE,SLAB
        # Cold hearths below the outer piers.
        for u,v in ((-1,-1),(0,-1),(1,-1),(-1,0),(1,0),(-1,1),(0,1)):
            m[s*(7+u),1,s*(16+v)] = RUBBLE if (u+v)%2 else SLAB
        m[s*7,0,s*16] = BASALT
        # Left standing on the woodland margin, or exposed in the clay cut.
        for cx,cz in ((37,25),(30,-31)):
            for dx,dz,high in ((0,0,4),(1,0,1),(-1,0,1),(0,1,1)):
                x,z = s*(cx+dx),s*(cz+dz)
                y = ground.heights[x,z]
                mat = APPLE if x < 0 else ROCK
                m.post(x,z,y+1,y+(high if x < 0 else min(high,2)),mat)
            if s < 0:
                y = ground.heights[-cx,-cz]
                m[-cx-1,y+3,-cz] = APPLE
                m[-cx-1,y+4,-cz] = APPLE
    return m


def poses():
    return {
        'arrival': ([0,4.0,52],[0,7,0],66),
        'aerial': ([42,86,84],[0,2,9],46),
        'accord': ([-5,4.1,25],[29,12,0],59),
        'throng': ([5,4.1,-25],[-29,12,0],59),
        'inside': ([32,8.3,10],[39,8.6,-2],67),
        'eastExit': ([29.75,8.13,-7.5],[20,8.13,-4],60),
        'westExit': ([-29.75,8.13,7.5],[-20,8.13,4],60),
        'eastMouth': ([22,8.13,-10],[-12,6,2],65),
        'westMouth': ([-22,8.13,10],[12,6,-2],65),
        'crossing': ([-2,2.15,1],[16,7,-8],70),
        'side': ([2,14,62],[2,4,2],56),
        'high': ([23,9.5,27],[-17,4,1],72),
    }
