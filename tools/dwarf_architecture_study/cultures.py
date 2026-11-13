"""Hand-scoped facade proposals and presentation copy for the five added cultures.

Existing materials; reed stair shapes are explicitly preview-only. These functions return replacement materials for existing
shell cells; they never add cells, move openings or write game templates.
"""

LOAM = 'grug_decor:cottages_loam'
DARK = 'grug_trees:gravewood_wood'
OAK = 'default:wood'
JUNGLE = 'default:junglewood'
STONE = 'default:stone_block'
BRICK = 'default:brick'
MOSS = 'default:mossycobble'
SLATE_TILE = 'grug_decor:darkage_slate_tile'
PALE = 'default:silver_sandstone_block'
SILVER = 'grug_trees:silverwood_wood'
MARBLE = 'grug_decor:darkage_marble'
GREEN = 'grug_decor:darkage_serpentine'
ADOBE = 'grug_decor:darkage_adobe'
RED_STONE = 'default:desert_stonebrick'
RED_BLOCK = 'grug_decor:darkage_ors_block'
SAND = 'default:desert_sandstone'
STRAW = 'grug_decor:darkage_straw_bale'
BARK = 'default:jungletree'
REED = 'study:reed'
DUNGEON = 'grug_decor:castle_dungeon_stone'
BASALT_FRAME = 'grug_decor:darkage_basalt_block'
OBSIDIAN = 'default:obsidianbrick'
BASALT = 'grug_decor:darkage_basalt_brick'
SLATE = 'grug_decor:darkage_slate'
SLATE_BRICK = 'grug_decor:darkage_slate_brick'


CULTURES = {
    'dwarf': {'label': 'Zwerge', 'line': 'Stein trägt. Holz wärmt.'},
    'human': {'label': 'Menschen', 'line': 'Warmer Lehm, geordnetes Fachwerk.'},
    'elf': {'label': 'Elfen', 'line': 'Helle Rahmen, ruhige Wandfelder.'},
    'orc': {'label': 'Orks', 'line': 'Erde, roter Stein und kräftige Stützen.'},
    'troll': {'label': 'Trolle', 'line': 'Dschungelrinde unter braunem Schilf.'},
    'undead': {'label': 'Untote', 'line': 'Modriges Mauerwerk unter Obsidian.'},
}

EXAMPLES = [
    dict(key='human_home', race='human', layout='dawnmere.layout', template='dawnmere_lane_cottage',
         title='Das Fachwerkhaus', label='Wohnhaus', town='Dawnmere', floor=0, eave=5,
         roof=OAK, front=2, gable=1,
         description='Ein roter Ziegelsockel trägt dunkle Holzstützen und helle Lehmfelder. Ein gemeinsamer Fensterabschluss macht aus den breiten Baumstammflächen ein lesbares Fachwerk.',
         details=['Rote Ziegel bilden wieder den Sockel des Wohnhauses.',
                  'Zwischen den Fensterpaaren ersetzt Lehm die einzelne Holzstütze; die Ecken bleiben gefasst.',
                  'Die übrigen Wandfelder erhalten warmen Lehm statt heller Planken.',
                  'Das Wohnhaus erhält wieder genau das Holzdach der ursprünglichen Spielvorlage.'],
         swatches=[('Roter Ziegelsockel', BRICK), ('Lehmfelder', LOAM), ('Holzrahmen', DARK), ('Ursprüngliches Holzdach', OAK)]),
    dict(key='human_hall', race='human', layout='dawnmere.layout', template='dawnmere_meeting_hall',
         title='Das Versammlungshaus', label='Versammlungshaus', town='Dawnmere', floor=0, eave=6,
         roof="default:brick", front=0, gable=1,
         description='Dieselbe Fachwerkbauweise wird zum öffentlichen Gebäude: ruhige Lehmfelder, kräftige Eckstützen und das ursprüngliche rote Ziegeldach. Der offene Dachaufsatz bleibt erhalten.',
         details=['Sockel, Fensterabschluss und Dachabschluss laufen auf gemeinsamen Höhen.',
                  'Lehm ersetzt die großen Plankenflächen zwischen den Holzstützen.',
                  'Die Stützen und Querbalken des Dachaufsatzes bleiben als Tragwerk sichtbar.',
                  'Das rote Ziegeldach bleibt exakt wie in der ursprünglichen Spielvorlage.'],
         swatches=[('Sockel', STONE), ('Lehmfelder', LOAM), ('Holzrahmen', DARK), ('Rotes Ziegeldach', 'default:brick')]),
    dict(key='elf_home', race='elf', layout='lethariel.roster', template='dur_brannoc_lane_house',
         title='Das Haus am Platz', label='Wohnhaus', town='Lethariel', floor=0, eave=5,
         roof=SLATE_TILE, front=0, gable=1,
         description='Heller Stein fasst silbrige Holzfelder ein. Ein schmaler grüner Abschluss verbindet die Fassade. Die versetzten Giebel behalten ihre Form und bekommen eine gemeinsame Materialordnung.',
         details=['Die Vorlage wird auch von einem Zwergenhaus verwendet; hier ist ihre tatsächliche Elfenpalette die Ausgangslage.',
                  'Helle Steinrahmen ersetzen die breiten Stammflächen.',
                  'Silberholz bleibt als ruhige Wand- und Giebelfüllung erhalten.',
                  'Der grüne Fensterabschluss und das Schieferdach setzen gezielte Akzente.'],
         swatches=[('Heller Sockel', PALE), ('Steinrahmen', MARBLE), ('Silberholz', SILVER), ('Grüner Abschluss', GREEN), ('Schiefer', SLATE_TILE)]),
    dict(key='elf_hall', race='elf', layout='silverleaf.layout', template='silverleaf_lore_hall',
         title='Die Halle des Wissens', label='Wissenshalle', town='Silverleaf Glade', floor=0, eave=6,
         roof="default:silver_sandstone_brick", front=0, gable=1,
         description='Ein heller steinerner Unterbau und geordnete Rahmen geben der Halle Ruhe. Silberholz füllt die größeren Wandfelder; der grüne Abschluss verbindet Fenster und Ecken.',
         details=['Der Sockel besteht aus zusammenhängenden hellen Steinflächen.',
                  'Marmorrahmen und Silberholzfelder bekommen unterschiedliche Aufgaben.',
                  'Ein grünes Band verbindet die Fassade über den Fenstern.',
                  'Das ursprüngliche Dach aus hellen Silbersandstein-Ziegeln ist wiederhergestellt.'],
         swatches=[('Heller Sockel', PALE), ('Steinrahmen', MARBLE), ('Silberholz', SILVER), ('Grüner Abschluss', GREEN), ('Silbersandstein-Ziegeldach', 'default:silver_sandstone_brick')]),
    dict(key='orc_home', race='orc', layout='sunscar.layout', template='sunscar_chief_lodge',
         title='Das Haus des Häuptlings', label='Wohnhaus', town='Sunscar', floor=0, eave=6,
         roof=SAND, front=0, gable=1,
         description='Lehmfelder sitzen zwischen kräftigen roten Sandsteinstützen. Roter Stein schützt den Sockel; eine helle, erdige Dachfläche liegt innerhalb eines klar abgegrenzten Dachrands.',
         details=['Die achteckigen Ecken und das flache Dach bleiben erhalten.',
                  'Warmer Lehm ersetzt die verstreuten roten Mauerblöcke in den Wandfeldern.',
                  'Lehm ersetzt jetzt auch die verbliebenen Sandsteinblöcke direkt neben den drei Fenstern.',
                  'Der Dachrand ist aus rotem Stein, die innere Dachfläche aus hellem Sandstein.'],
         swatches=[('Roter Sockel & Dachrand', RED_STONE), ('Lehmfelder', ADOBE), ('Rote Sandsteinblöcke', RED_BLOCK), ('Erdige Dachfläche', SAND)]),
    dict(key='orc_hall', race='orc', layout='sunscar.layout', template='sunscar_armoury',
         title='Die Waffenkammer', label='Waffenkammer', town='Sunscar', floor=0, eave=5,
         roof=SAND, front=1, gable=0,
         description='Die Waffenkammer übernimmt die warme Lehm-Sandstein-Bauweise und bekommt einen stärkeren gemauerten Fensterabschluss. Die breite Dachfläche erhält einen zusammenhängenden roten Rand.',
         details=['Sockel und Sturzlage bestehen aus demselben roten Stein.',
                  'Die alten roten Sandsteinblöcke gliedern größere ruhige Lehmflächen.',
                  'Der Anbau bleibt Teil derselben Konstruktion.',
                  'Zugänge, Arbeitsplätze und vergitterte Öffnungen bleiben unverändert.'],
         swatches=[('Sockel & Sturzlage', RED_STONE), ('Lehmfelder', ADOBE), ('Rote Sandsteinblöcke', RED_BLOCK), ('Dachfläche', SAND)]),
    dict(key='troll_home', race='troll', layout='kapok.layout', template='kapok_river_stilt',
         title='Das Haus am Fluss', label='Stelzenhaus', town='Kapok Cradle', floor=4, eave=9,
         roof=REED, front=2, gable=1,
         description='Dunkle Holzstützen tragen eine leichte Hülle aus rotbraunen Rindenfeldern. Das braune Schilfdach setzt sich klar von Wänden und Plattform ab. Der freie Raum unter dem Haus bleibt vollständig offen.',
         details=['Die Stelzen und die Eingangstreppe bleiben unverändert.',
                  'Holz ersetzt die schweren Steinsockelfelder auf der erhöhten Plattform.',
                  'Raue Rindenfelder wechseln mit gezielten dunklen Stützen und einem gemeinsamen Abschluss.',
                  'Graubraunes Schilf ersetzt das leuchtend gelbe Stroh.'],
         swatches=[('Plattform & Rahmen', JUNGLE), ('Dschungelrinde', BARK), ('Braunes Schilf', 'grug_decor:cottages_reet')]),
    dict(key='troll_hall', race='troll', layout='kapok.layout', template='kapok_spirit_lodge',
         title='Das Geisterhaus', label='Geisterhaus', town='Kapok Cradle', floor=0, eave=7,
         roof=REED, front=0, gable=1,
         description='Das Gemeinschaftshaus steht auf einem dunklen Steinsockel. Darüber tragen dunkle Holzstützen rotbraune Rindenfelder und ein ausladendes Schilfdach. Die offenen Holzgitter bleiben erhalten.',
         details=['Basalt bildet einen zusammenhängenden Sockel am Boden.',
                  'Rinde gibt den Wandfeldern einen raueren, natürlichen Charakter.',
                  'Die Stützen bleiben an den Ecken und zwischen Fenstergruppen erkennbar.',
                  'Das braune Schilfdach verbindet das Geisterhaus gestalterisch mit dem Stelzenhaus.'],
         swatches=[('Steinsockel', BASALT), ('Holzrahmen', JUNGLE), ('Dschungelrinde', BARK), ('Braunes Schilf', 'grug_decor:cottages_reet')]),
    dict(key='undead_home', race='undead', layout='stillgrave.layout', template='stillgrave_keepers_house',
         title='Das Haus des Hüters', label='Wohnhaus', town='Stillgrave Hollow', floor=0, eave=5,
         roof=OBSIDIAN, front=0, gable=1,
         description='Grünlich modriger Stein ersetzt die hellen Wandflächen. Dunkle Basaltrahmen, Gravewood-Giebel und das ursprüngliche Obsidianziegeldach halten das Haus düster.',
         details=['Moosiger Bruchstein bildet wieder den Sockel; Sturzlage und Rahmen bleiben aus dunklem Basalt.',
                  'Sehr dunkler, grünlich fleckiger Stein übernimmt die Wandflächen.',
                  'Dunkle Basaltrahmen ersetzen die zu hellen steinernen Einfassungen.',
                  'Das ursprüngliche Dach aus Obsidianziegeln kehrt zurück.'],
         swatches=[('Modriges Mauerwerk', DUNGEON), ('Moosiger Sockel', MOSS), ('Sturzlage & Rahmen', BASALT_FRAME), ('Gravewood-Giebel', DARK), ('Obsidianziegeldach', OBSIDIAN)]),
    dict(key='undead_hall', race='undead', layout='stillgrave.layout', template='stillgrave_bone_works',
         title='Die Knochenwerkstatt', label='Knochenwerkstatt', town='Stillgrave Hollow', floor=0, eave=5,
         roof=OBSIDIAN, front=1, gable=0,
         description='Modriges dunkelgrünes Mauerwerk und raue Basaltrahmen geben der Werkstatt ihren düsteren Charakter zurück. Moosiger Bruchstein bildet wieder den Sockel; darüber liegt wieder das ursprüngliche Obsidianziegeldach.',
         details=['Hauptbau und Anbau erhalten einen moosigen Sockel; Sturzlagen und Rahmen bleiben aus dunklem Basalt.',
                  'Grünlich fleckiges Mauerwerk ersetzt die zu hellen Wandfelder.',
                  'Die oberen Wandfelder bleiben ebenfalls dunkel und gemauert.',
                  'Das ursprüngliche Obsidianziegeldach bleibt in seiner gesamten Form erhalten.'],
         swatches=[('Modriges Mauerwerk', DUNGEON), ('Moosiger Sockel', MOSS), ('Sturzlage & Rahmen', BASALT_FRAME), ('Obsidianziegeldach', OBSIDIAN)]),
]


# The three window-bearing walls; preserve corner piers and the entrance wall.
HUMAN_HOME_MIDDLE = {(0, 4), (8, 4), (4, 0)}
# Both window jambs, plus the formerly isolated upper cell beside each window.
ORC_HOME_WINDOW_INFILL = ({(x, y, 5) for x in (0, 8) for y in (2, 3, 4)} |
                          {(x, 4, 4) for x in (0, 8)} |
                          {(5, y, 8) for y in (2, 3, 4)} | {(4, 4, 8)} |
                          {(x, y, 2) for x in (0, 8) for y in (2, 3, 4)} |
                          {(2, y, 8) for y in (2, 3, 4)})


def roof_node(material, role):
    if role == 'roof_ridge':
        return material
    suffix = role.removeprefix('roof_')
    if material.startswith('default:'):
        # Existing stairs families put the shape before the material name.
        return 'stairs:' + suffix + '_' + material.split(':', 1)[1]
    return material + '_' + suffix


def narrow_support(tpl, pos):
    """Single-cell piers at ends and four-node bay intervals, inside wall cells only."""
    x, _, z = pos
    w, d = tpl.pivot
    return (x in (0, w - 1) and (z in (0, d - 1) or z % 4 == 0)) or (
        z in (0, d - 1) and (x in (0, w - 1) or x % 4 == 0))


def replacement(spec, tpl, pos, role):
    x, y, z = pos
    race, key = spec['race'], spec['key']
    floor, eave = spec['floor'], spec['eave']
    if role.startswith('roof_'):
        # Some templates reuse roof-shaped roles for entrance steps/low ledges.
        if y < eave:
            return None
        if race == 'orc' and role == 'roof_ridge':
            roof_cells = {p for p, k in tpl.cells.items()
                          if tpl.legend.get(k, {}).get('name') == 'roof_ridge'}
            if any((x + dx, y, z + dz) not in roof_cells
                   for dx, dz in [(1, 0), (-1, 0), (0, 1), (0, -1)]):
                return RED_STONE
        return roof_node(spec['roof'], role)

    if race == 'troll' and y < floor:
        return None  # Preserve the actual stilts below the raised platform.
    if role == 'foundation':
        if key == 'human_home':
            return BRICK
        return {'human': STONE, 'elf': PALE, 'orc': RED_STONE,
                'troll': JUNGLE if floor else BASALT, 'undead': MOSS}[race]

    if role not in {'wall', 'wall_accent', 'wall_infill', 'window_frame', 'post', 'beam'}:
        return None
    if race == 'human':
        if y == 1:
            return BRICK if key == 'human_home' else STONE
        if key == 'human_home' and y in (2, 3) and (x, z) in HUMAN_HOME_MIDDLE:
            return LOAM
        if y in (4, eave) or role == 'beam':
            return DARK
        if role == 'post' or narrow_support(tpl, pos):
            return DARK
        return LOAM
    if race == 'elf':
        if y == 1:
            return PALE
        if y == 4:
            return GREEN
        if role in ('post', 'beam') or narrow_support(tpl, pos):
            return MARBLE
        return SILVER
    if race == 'orc':
        if key == 'orc_home' and pos in ORC_HOME_WINDOW_INFILL:
            return ADOBE
        if y == 1 or (key == 'orc_hall' and y == 4):
            return RED_STONE
        if y == eave - 1 or role in ('post', 'window_frame', 'beam'):
            return RED_BLOCK
        return ADOBE
    if race == 'troll':
        if y == floor + 1:
            return JUNGLE if floor else BASALT
        if y in (floor + 4, eave) or role in ('post', 'beam') or narrow_support(tpl, pos):
            return JUNGLE
        return BARK
    if race == 'undead':
        if y == 1:
            return MOSS
        if y == 4:
            return BASALT_FRAME
        if role == 'post' or narrow_support(tpl, pos):
            return BASALT_FRAME
        if key == 'undead_home' and y >= 5:
            return DARK
        return DUNGEON
    raise ValueError(race)
