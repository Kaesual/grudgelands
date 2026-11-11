"""Editorial proposals for deferred town structures; no game transformation."""
import re
LABELS = {'human':'Menschen','dwarf':'Zwerge','elf':'Elfen','orc':'Orks','troll':'Trolle','undead':'Untote'}
PALETTES = {
 'human':('Steinsockel, dunkles Gravewood als ein Block breite Stützen und Riegel; geschlossene Felder aus hellem Lehm.', ['default:stone_block','grug_trees:gravewood_wood','grug_decor:cottages_loam']),
 'dwarf':('Steinblöcke für Sockel, Ecken und Stürze; dunkles Steinmauerwerk in den Wandfeldern. Warmes Holz nur oberhalb der Traufe im echten Giebel.', ['default:stone_block','grug_decor:darkage_stone_brick','default:wood']),
 'elf':('Heller Sandsteinsockel, schlanke Marmorpfeiler, ruhige Silberholzfelder und ein einziges durchgehendes Serpentinenband unter der Traufe.', ['default:silver_sandstone_block','grug_decor:darkage_marble','grug_trees:silverwood_wood','grug_decor:darkage_serpentine']),
 'orc':('Roter Steinsockel und ein roter oberer Abschluss; klare Stützen aus dunklem ORS-Stein, dazwischen zusammenhängende erdige Lehmfelder.', ['default:desert_stonebrick','grug_decor:darkage_ors_block','grug_decor:darkage_adobe']),
 'troll':('Dunkles Dschungelholz bildet Stützen und Riegel; geschlossene Felder werden umbrabrauner Lehm. Erhöhte Plattformen bleiben aus Holz, bodennahe Fundamente aus dunklem Basalt.', ['default:junglewood','grug_nodes:clay_band_umber','grug_decor:darkage_basalt_brick']),
 'undead':('Moosiger Steinsockel, dunkle Basaltrahmen und düsterer Gewölbestein in geschlossenen Feldern; Gravewood im Giebel. Keine hellen Steinflächen.', ['default:mossycobble','grug_decor:darkage_basalt_block','grug_decor:castle_dungeon_stone','grug_trees:gravewood_wood']),
}
ROOFS = {
 'human':'Bei öffentlichen geschlossenen Häusern ein rotes Ziegeldach; kleine Wohnbauten erhalten die normale Holzdeckung. Sonderdächer separat bewerten.',
 'dwarf':'Vorhandene geneigte Dachflächen auf dunklen Schiefer abstimmen; massive Gewölbe und Zinnen bleiben Stein.',
 'elf':'Das helle Dach öffentlicher Hallen erhalten. Offene Steindächer nicht in blaue Wohnhausdeckung umwandeln.',
 'orc':'Flache Dächer mit erdiger Fläche und rotem Rand; geneigte Dächer behalten ihre rote Ziegeldeckung.',
 'troll':'Leichte Hausdächer aus braunem Schilf; bei großen Zeremonialbauten vorhandene dunkle Holzdeckung als bewusste Sonderform erhalten.',
 'undead':'Obsidianziegel auf geneigten Dächern; vorhandene dunkle Kryptengewölbe erhalten.',
}

def classify(name, roles):
    # Explicit cultural monuments take precedence over broad name fragments.
    if re.search(r'kings_hall|warlord_hall|^nhal_veyr_mausoleum$', name): return 'royal','Königs- und Herrscherhalle'
    if re.search(r'ruin|fallen',name): return 'ruin','Ruine'
    if name in ('highcourt_chapel_house','highcourt_lore_chapel_yard'): return 'utility','Kapellen-Nebenhaus'
    if 'candle_court' in name: return 'memorial','Kerzen-Gedenkhof'
    if 'drill_yard' in name and any(r.startswith('roof_') for r in roles): return 'training','Übungsgebäude'
    if name in ('kezamba_gate_house_south','nhal_veyr_homes_gate_house') or re.search(r'forge_watch|market_watch|shore_watch|vigil_watch',name): return 'watchhouse','Wachhaus'
    if name == 'hearthpine_gatewatch': return 'tower','Wachtbau'
    if re.search(r'gate|tollhouse',name): return 'gate','Tor / Zollhaus'
    if re.search(r'watch|tower',name) and not re.search(r'barracks|captain|armoury|stables|drill|quartermaster|serjeant',name): return 'tower','Wachtbau'
    if 'colonnade' in name or 'cloister_walk' in name: return 'colonnade','Kolonnade / Kreuzgang'
    if 'bough' in name: return 'treehouse','Baumhaus'
    if re.search(r'grove|orchard|copse',name): return 'green','Grünanlage'
    if 'statue' in name: return 'statue','Denkmal'
    if 'well_court' in name: return 'well','Brunnenhof'
    if re.search(r'shrine|chapel|ancestor|star_hall|skull_hall|vigil_hall|spirit_hall|moot|ossuary|mausoleum|charnel',name): return 'sacred','Kult- und Versammlungsbau'
    if 'miners_guild' in name: return 'guild','Bergmannsgilde'
    if re.search(r'barracks|muster|quartermaster|serjeant|guard_house|captain|armoury',name): return 'military','Garnisonsgebäude'
    if 'drill_yard' in name: return 'drill','Übungsplatz'
    if re.search(r'stable|beast_pen',name): return 'stable','Stall / Tiergehege'
    if re.search(r'market|trade_shed',name): return 'market','Markt / Handelsunterstand'
    if re.search(r'yard|carvers|carver|tannery|drying_shed|court',name): return 'yard','Arbeits- oder Innenhof'
    raise ValueError('Unclassified deferred structure: '+name)


def proposal(name, race, roles, roof_nodes):
    kind, category = classify(name,roles)
    palette, materials = PALETTES[race]
    has_wall = bool(roles & {'wall','wall_accent','wall_infill','window_frame'})
    proposal = palette
    details = []
    priority = 'Abstimmen'
    if kind == 'royal':
        priority = 'Gezielt entwerfen'
        proposal = {'human':'Die große Halle als Steinbau erhalten: tragende Ecken und Torfassungen aus ruhigem Werkstein; dunkles Holz nur als klare Dachkonstruktion. Lehm höchstens in vorhandenen oberen Nebenfeldern.',
          'dwarf':'Monumentale Steinhalle erhalten: Werkstein an Ecken, Portalen und horizontalen Gesimsen; dunkleres Mauerwerk als zusammenhängende Fläche. Holz nur in tatsächlich vorhandenen Giebeln.',
          'elf':'Die Königshalle als hellen Monumentalbau ordnen: Marmorpfeiler über die volle Wandhöhe, Silberholz nur in sekundären Feldern; ein schmales grünes Gesims statt verstreuter Akzentblöcke.',
          'orc':'Die Herrscherhalle bleibt ein massiver roter Steinbau. Sockel, Eckstützen und Dachrand zusammenfassen; vorhandene geschlossene Nebenfelder mit dunklem ORS-Stein oder erdigem Lehm beruhigen.',
          'troll':'Die monumentale Königshalle behält ihre dunklen Basaltwände. Pfeiler und Wandfelder durch zusammenhängende Steinflächen ordnen; die vorhandene dunkle Dschungelholzdeckung erhalten. Lehm nur an tatsächlich leichten Nebenfeldern einsetzen.',
          'undead':'Das Mausoleum bleibt ein dunkler Steinmonumentalbau: Moos am Sockel, Basalt an Pfeilern und Portalen, Gewölbestein in den Feldern. Kryptendach erhalten; keine helle Einfassung.'}[race]
        details.append('Kampfraum, Türen, Treppen, Deckungen und begehbare Flächen exakt erhalten. Ausschließlich Materialwechsel; keine zusätzlichen Vorsprünge oder Dekorationen.')
    elif kind == 'ruin':
        priority = 'Behutsam erhalten'
        proposal = 'Den Verfall erhalten: vorhandene Bruchkanten, Löcher und schiefe Restflächen bleiben. Moosigen Sockelstein und die bestehenden Gravewood-Wandreste beibehalten; vorhandene Stützen und Wandfelder durch ruhige Holzrichtungen ordnen. Keine komplette Umwandlung der Holzruine in einen Steinbau.'
        details.append('Keine vollständigen Rahmen rekonstruieren und keine Lücken schließen. Die heutigen Ruinen bestehen überwiegend aus Holz: große Wandreste deshalb in modrigem Gravewood belassen, Stein nur an schon steinernen Füßen verwenden. Ablesbar machen, wie der Bau vor dem Verfall getragen wurde.')
    elif kind == 'treehouse':
        priority = 'Gezielt entwerfen'
        proposal = 'Die kleine erhöhte Hütte auf ihren bestehenden Stammpfeilern erhalten. Die Wohnfelder mit Silberholz beruhigen, die Ecken und den Dachabschluss aus hellem Marmor fassen. Ein grünes Akzentband bleibt auf die Hütte begrenzt; die Tragstämme behalten ihre Rinde.'
        details.append('Stammpfeiler, Plattform, Geländer und steinernen Treppenaufstieg erhalten. Diese Vorlage hat keine lebende Baumkrone; keine ergänzen und die Träger nicht zu steinernen Turmstützen umbauen.')
    elif kind == 'green':
        priority = 'Beibehalten'
        proposal = 'Bäume, Pflanzflächen und natürliche Unregelmäßigkeit erhalten. Auch vorhandene Ränder, Podeste und Sitzfassungen können so bleiben; sie bilden keinen störenden Stilbruch.'
        details.append({'elf':'Heilige Haine und die beiden Baumgruppen bleiben organische Gegenstücke zur geordneten Architektur.',
          'undead':'Kahle oder kranke Vegetation und der ungepflegte Eindruck gehören zur Kultur und bleiben bestehen.'}.get(race,'Die Pflanzen sind kein Stilbruch; die vorhandenen Übergänge zur Straße können bleiben.'))
    elif kind == 'statue':
        priority = 'Beibehalten'
        proposal = 'Die Figur als Wahrzeichen erhalten. Auch den bestehenden Sockel so lassen: Das Denkmal darf als eigenständiges historisches Stück erkennbar bleiben.'
        details.append('Keine neuen Verzierungen oder Änderungen an der Figur; Blickachsen und Standfläche erhalten.')
    elif kind == 'well':
        proposal = 'Brunnenring und vorhandene Hofkante aus dem Sockelstein des Volks zusammenfassen. Bestehende Pfosten als durchgehende Stützen aus dem Rahmenmaterial ausführen; Brunnenöffnung, Sitze und Zugang erhalten.'
        details.append('Ein kleiner öffentlicher Bau braucht nur Sockel und Tragwerk, keine zusätzlichen Lehmfelder oder umlaufenden Schmuckbänder.')
    elif kind == 'colonnade':
        proposal = {'human':'Die offene Säulenfolge bleibt steinern; dunkle Holzbalken nur dort, wo bereits ein Gebälk vorhanden ist. Einheitliche Füße und Kapitelle statt wechselnder Säulenmaterialien.',
          'dwarf':'Gleichmäßige Werksteinsäulen mit zusammenhängendem Steinarchitrav und dunkleren Sockelflächen. Die Anlage soll wie aus derselben Steinmetzwerkstatt wie die Häuser wirken.',
          'elf':'Schlanke Marmorsäulen mit einheitlichen hellen Füßen; Serpentine nur als schmaler durchgehender Abschluss des vorhandenen Gebälks.',
          'orc':'Massive ORS-Steinstützen auf roten Füßen, darüber ein durchgehender roter Steinabschluss. Keine Holzimitation der Steinsäulen.',
          'undead':'Dunkle Basaltsäulen auf moosigen Füßen; vorhandenes Gebälk aus dunklem Gewölbestein. Alle Öffnungen bleiben offen.'}.get(race,palette)
        details.append('Säulenabstände, offene Durchgänge und vorhandene Überdachung erhalten; Zwischenräume nicht mit Wandmaterial füllen.')
    elif kind == 'gate':
        priority = 'Gezielt entwerfen'
        if 'tollhouse' in name or 'homes_gate_house' in name:
            proposal = palette
            details.append('Das freistehende Zollhaus wie ein Nutzgebäude ordnen. Es besitzt einen normalen Eingang, keinen großen Torbogen; Dachform und Eingang bleiben erhalten.')
        else:
            proposal = {'human':'Den Torbogen als zusammenhängenden Werksteinbau behandeln. Pfeiler, Bogen und oberer Abschluss klar gliedern; dunkles Holz auf vorhandene Torflügel oder Wehrgänge begrenzen.',
              'dwarf':'Werkstein an Pfeilern und Bogen, dunkles Mauerwerk in massiven Flanken; keine Holzfelder im tragenden Torbogen.',
              'elf':'Helle Marmorpfeiler und ruhige helle Bogenflächen; Serpentine nur auf einer gemeinsamen Gesimshöhe.',
              'orc':'Rote Torflanken mit dunklen ORS-Steinpfeilern; einen einzigen roten Abschluss statt verstreuter Kontraststeine verwenden.',
              'troll':'Vorhandene Tragpfosten in dunklem Dschungelholz zusammenfassen; bodennahe Füße aus Basalt. Geschlossene obere Felder dürfen umbrabraunen Lehm erhalten.',
              'undead':'Torflanken und Bogen dunkel halten: Basalt als Tragwerk, moosiger Stein an den Füßen und Gewölbestein in geschlossenen Flächen.'}[race]
        details.append('Eingang, Fenster, Schwelle und Zugang zum Zollpersonal bleiben unverändert.' if 'tollhouse' in name else 'Durchfahrtsbreite, Bogenhöhe, Wehrgang und Kampfkollisionen bleiben exakt erhalten. Keine zusätzliche Dekoration.')
    elif kind == 'tower':
        priority = 'Gezielt entwerfen'
        details.append('Den kompakten Wachtbau mit durchgehenden Eckstützen und einem einzigen klaren Riegel unter dem Dach ordnen. Bei den zweigeschossigen Sunscar-Türmen die vorhandene Geschossgrenze als zusätzliche horizontale Gliederung nutzen.')
        if race in ('dwarf','orc','undead'):
            details.append('Massive Wehrwände bleiben Stein; Lehm oder Holz nur in bereits leichten oberen Aufbauten verwenden.')
        details.append('Vorhandene Fenster, Türen und gegebenenfalls obere Öffnungen bleiben erhalten. Keine neue Aussichtsplattform oder Schießscharten hinzufügen.')
    elif kind == 'sacred':
        priority = 'Gezielt entwerfen'
        details.append('Die sakrale Silhouette und vorhandene Säulen, Altäre, Totems oder Gewölbe behalten. Das Tragwerk folgt den Hallenachsen; Kultobjekte bleiben Einzelstücke.')
        if 'mere_shrine' in name:
            proposal = 'Den offenen Schrein offen lassen: bestehende Säulen aus '+('hellem Marmor' if race=='elf' else 'dunklem Dschungelholz')+', ruhige Sockelflächen und ein klarer oberer Abschluss. Keine neuen Wandfelder zwischen den Säulen.'
        if race=='undead':
            details.append('Patina und dunkle Kryptendeckung erhalten; geordnete Steinrahmen dürfen den verfallenen Gesamteindruck nicht verdrängen.')
        if name=='silverleaf_moon_shrine':
            priority='Umgesetzt'
            details=['266 Materialzellen geordnet: Marmorpfeiler, Silberholzfelder und ein grünes Band auf y=7; Marmorpfeiler auch am offenen Dachaufsatz.',
                     'Helles Dach samt Turmhaube, Fenster, Türen, Einrichtung und Geometrie unverändert. Im Worktree umgesetzt; der Elfen-Hintergrund wird daraus neu gerendert.']
    elif kind in ('watchhouse','utility','training'):
        priority = 'Als Nächstes'
        details.append({'watchhouse':'Ein bewohntes Wachhaus mit normalem Hausdach: Fensterachsen und Eingang geben die Rahmenordnung vor; keine Turmgliederung oder zusätzlichen Wehrgänge.',
            'utility':'Das kleine Kapellen-Nebenhaus wie ein Wohn- oder Diensthaus ordnen. Es ist keine monumentale Tempelhalle; Kamin und niedrige Hausform erhalten.',
            'training':'Trotz des Vorlagennamens „Drill Yard“ zeigt der Bestand einen geschlossenen quadratischen Bau mit Dach. Seine Fassaden wie ein Nutzgebäude ordnen, statt ihn als freien Hof zu behandeln.'}[kind])
        details.append('Innenraum, Türen, Fenster und Zugangspunkte bleiben unverändert.')
    elif kind == 'memorial':
        priority = 'Behutsam erhalten'
        proposal = 'Den offenen Kerzenhof als stillen Gedenkort erhalten: vorhandene Sockel und Randsteine in dunklem Basalt zusammenfassen, bodennahe Flächen moosig belassen. Kerzen und ihre hölzernen Träger bleiben die Akzente.'
        details.append('Keine Marktstände, Überdachung oder Wandfelder ergänzen. Die freie Mitte und der Zugang zu den Kerzen bleiben erhalten.')
    elif kind == 'guild':
        priority = 'Als Nächstes'
        details.append('Die Gilde ist ein gewöhnliches besuchbares Dienstleistungsgebäude und wurde allein wegen ihres Namens zurückgestellt. Die Fassadenordnung der neuen Berufsgebäude passt hier unmittelbar.')
        details.append('Portal und Schilder als Erkennungszeichen erhalten; Durchgänge zum Gildenpersonal und den vorhandenen Arbeitsplätzen bleiben frei.')
    elif kind == 'military':
        priority = 'Als Nächstes'
        if 'barracks' in name or 'muster' in name:
            details.append('Lange Fassaden in wiederkehrende Fensterachsen gliedern; durchgehende Eckstützen und ein waagerechter Abschluss verbinden die einzelnen Felder.')
        elif 'quartermaster' in name or 'armoury' in name:
            details.append('Das Lager- oder Ausgabegesicht mit einem klar gefassten Eingang und ruhigen Wandfeldern ordnen; vorhandene Waren, Regale und Schalter bleiben.')
        else:
            details.append('Den kleineren Dienstbau wie die überarbeiteten Nutzgebäude behandeln: Eingang und Fenster bestimmen die Stützenachsen, nicht die bisherigen Materialflecken.')
        details.append('Betten, Übungsobjekte, NPC-Zugänge und vorhandene Kampfflächen bleiben unverändert.')
    elif kind == 'drill':
        priority = 'Beibehalten'
        proposal = 'Die freie Übungsfläche erhalten. Bestehende Einfassungen an den örtlichen Sockelstein und vorhandene Pfosten an das Rahmenmaterial angleichen; Ziele und Übungsgeräte behalten ihre eigenen Materialien.'
        details.append('Keine neuen Stützen, Wände oder Hindernisse auf der Übungsfläche.')
    elif kind == 'stable':
        proposal = 'Offene Tierbereiche offen lassen. Vorhandene Pfosten und horizontale Balken zu einem einheitlichen dunklen Holztragwerk ordnen; nur wirklich geschlossene Rückwände erhalten das Füllmaterial des Volks. Stein- oder Plattformfüße an die benachbarten Häuser angleichen.'
        details.append('Boxen, Zäune, Tränken, Tierzugänge und freie Stallhöhe erhalten; Tiergehege nicht in geschlossene Häuser verwandeln.')
    elif kind == 'market':
        proposal = 'Vorhandene Marktstände und Überdachungen durch einheitliche Pfosten und verbundene Querbalken ordnen. Stoffdächer bleiben Stoff, offene Seiten bleiben offen; vorhandene massive Marktgebäude bekommen das örtliche Rahmen- und Füllmaterial.'
        details.append('Theken, Waren, Beschilderung und Laufwege erhalten. Auf den kleinen Ständen kein zusätzliches Fassadenband einführen.')
    elif kind == 'yard':
        proposal = 'Den Arbeitsablauf sichtbar lassen: vorhandene Überdachungen mit klaren Pfosten und Querbalken ordnen, gebaute Hofkanten an den Ortssockel anpassen. Arbeitsgeräte und Produkte behalten ihre eigenen Materialien.'
        details.append('Trockengestelle, Gerberflächen, Schnitzplätze oder Kessel nicht durch dekorative Wandfelder verdecken; offene Nutzflächen bleiben offen.')
    if name in ('kezamba_shrine','kezamba_vine_moot'):
        proposal = ('Das offene Ritualpodest mit seinen drei hohen Totempfosten erhalten. Sockel aus dunklem Basalt vereinheitlichen; die hellen Totembänder als bewusstes Ritualmotiv belassen.' if name=='kezamba_shrine' else
                    'Die offene Säulenhalle mit dunklen Holzstützen, einheitlichen Füßen und einem ruhigen Basaltgebälk ordnen. Die Zwischenräume bleiben vollständig offen.')
        details = ['Keine Lehmfelder in die offenen Zwischenräume setzen. Ritualobjekte, Durchgänge und vorhandene Plattformen erhalten.']
    if name=='nhal_veyr_watch_stables':
        proposal=palette
        details=['Dieser Stall ist ein geschlossenes Gebäude mit normalem Satteldach. Wandflächen und Ecken nach dem Untotenstil ordnen; die bestehende Form und die Türen erhalten.']
    if name in ('highcourt_service_yard','hearthpine_workyard','gor_drazhak_bazaar_tannery','kapok_drying_shed','kezamba_trade_shed'):
        priority='Als Nächstes'
        proposal=palette
        details=['Der Bestand ist ein niedriges überdachtes Nutzgebäude. Vorhandene Öffnungen zwischen Stützen erhalten; nur bereits geschlossene Wand- und Giebelflächen mit ruhigem Füllmaterial ordnen.',
                 'Dachform, Arbeitsplätze und freie Zugänge bleiben bestehen.']
    if name=='dur_brannoc_terrace_market':
        proposal='Die offene Marktkolonnade mit Werksteinstützen, einem durchgehenden dunkleren Steingebälk und ruhigen Sockelflächen ordnen. Keine Holzstände oder Wandfüllungen ergänzen.'
        details=['Die regelmäßige offene Säulenfolge und alle Durchgänge erhalten.']
    # The roof proposal is conditional on an actual roof in this placement.
    if roof_nodes and kind not in ('ruin','green','statue','well','drill','royal'):
        details.append(ROOFS[race])
    if kind in ('green','statue','drill'):
        materials=PALETTES[race][1][:2]
    details.append('Leitpalette: '+palette if kind not in ('royal','ruin','green','statue','drill') and proposal!=palette else 'Bestehende Grundform und belegte Blockpositionen erhalten.')
    return dict(category=category,kind=kind,priority=priority,proposal=proposal,details=details,material_names=materials)
