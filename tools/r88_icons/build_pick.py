"""Build the standalone pick page from the proposal PNGs and in-game status art."""

from base64 import b64encode
from functools import cache
from html import escape
from string import Template

from draw_proposals import DRAWINGS, HERE, OUTPUT, TIERS, filename, ranked
from draw_sheet import STATUS

# Catalogue order keeps the two red families together, then the two blues.
FAMILIES = {
    "healing": ("Healing", "Potion · Instant HP", None),
    "vigor": ("Vigor", "Elixir · Maximum HP", "elixir_vigor"),
    "mana": ("Mana", "Potion · Instant Mana", None),
    "focus": ("Focus", "Elixir · Maximum Mana", "elixir_focus"),
    "precision": ("Precision", "Elixir · Critical chance", "elixir_precision"),
    "stoneskin": ("Stoneskin", "Elixir · Armor", "elixir_stoneskin"),
    "antivenom": ("Antivenom", "Draught · Cures poison", None),
    "swiftness": ("Swiftness", "Draught · Burst of speed", "alchemy_swiftness"),
    "cave": ("Cave", "Draught · Night vision", "alchemy_cave"),
    "deepwater": ("Deepwater", "Elixir · Water breathing", "elixir_deepwater"),
    "merchant": ("Merchant’s Healing Potion", "Weak potion · Instant HP", None),
}


@cache
def uri(path):
    return "data:image/png;base64," + b64encode(path.read_bytes()).decode("ascii")


def image(path, size, alt=""):
    return f'<img src="{uri(path)}" width="{size}" height="{size}" alt="{escape(alt)}">'


def key():
    entries = []
    for tier, (material, closure) in enumerate(TIERS, 1):
        path = OUTPUT / filename("healing", "A", tier)
        entries.append(f"""
          <li><span class="tier">Tier {tier}</span>
            <div class="key-art">{image(path, 32, f"Healing tier {tier}")}{image(path, 16)}</div>
            <strong>{material}</strong><span class="closure">{closure}</span></li>""")
    return "".join(entries)


def comparison(pair):
    links = []
    for family in pair:
        title = FAMILIES[family][0]
        studies = "".join(image(OUTPUT / filename(family, letter, 3), 32,
                               f"{family}-{letter} tier 3") for letter in "AB")
        links.append(f'<a href="#{family}">{studies}<span>{title}</span></a>')
    return '<div class="comparison">' + "".join(links) + "</div>"


def option(family, index, drawing):
    letter = chr(65 + index)
    pick = f"{family}-{letter}"
    tiers = range(1, 7) if ranked(family) else [None]
    samples = []
    for tier in tiers:
        path = OUTPUT / filename(family, letter, tier)
        tag = f'<span class="rank">T{tier}</span>' if tier else ""
        description = f"{pick} tier {tier}" if tier else pick
        sizes = image(path, 32, description) + image(path, 16)
        samples.append(f"""
            <span class="sample">{tag}<span class="dark well">{sizes}</span>
              <span class="light well">{sizes}</span></span>""")
    image_tier = 3 if ranked(family) else None
    study = image(OUTPUT / filename(family, letter, image_tier), 64)
    layout = "ranked" if ranked(family) else "single"
    return f"""
        <label class="option">
          <span class="pick-id"><input type="radio" name="{family}" value="{pick}" aria-label="{pick}, {escape(drawing.title)}"><code>{pick}</code></span>
          <span class="study">{study}</span><span class="name">{escape(drawing.title)}</span>
          <span class="samples {layout}">{''.join(samples)}</span>
        </label>"""


def family_section(family):
    title, subtitle, effect = FAMILIES[family]
    badge = ""
    if effect:
        art = image(STATUS / f"grug_status_{effect}.png", 40, f"{title} buff icon")
        badge = f'<figure class="buff">{art}<figcaption>Buff icon</figcaption></figure>'
    cards = "".join(option(family, index, drawing) for index, drawing in enumerate(DRAWINGS[family]))
    return f"""
      <section id="{family}" class="family" aria-labelledby="{family}-title">
        <header class="family-head">
          <div><h3 id="{family}-title">{escape(title)}</h3><p>{escape(subtitle)}</p></div>{badge}
        </header>
        <fieldset aria-labelledby="{family}-title">{cards}</fieldset>
      </section>"""


def main():
    # The enlarged title illustration uses the same pixels as the samples below.
    still_life = "".join(image(OUTPUT / filename(family, letter, tier), size)
                         for family, letter, tier, size in (
                             ("cave", "A", None, 64), ("vigor", "A", 4, 112),
                             ("mana", "A", 6, 96), ("merchant", "A", None, 64)))
    template = Template((HERE / "pick.template.html").read_text(encoding="utf-8"))
    page = template.substitute(still_life=still_life, key=key(),
                               red=comparison(("healing", "vigor")),
                               blue=comparison(("mana", "focus")),
                               families="".join(family_section(family) for family in FAMILIES))
    out = HERE / "pick/index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")


if __name__ == "__main__":
    main()
