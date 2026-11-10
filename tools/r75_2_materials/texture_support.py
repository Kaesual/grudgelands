"""Local exact support for texture modifiers used by the audited city set."""

from PIL import Image


def install(render_blueprint):
    original = render_blueprint.apply_modifier

    def apply_modifier(image, modifier, warnings):
        if modifier.startswith("[makealpha:"):
            try:
                color = tuple(int(value) for value in modifier.split(":", 1)[1].split(","))
            except ValueError:
                color = ()
            if len(color) != 3:
                warnings["makealpha-unparsed: " + modifier] += 1
                return image
            source = image.convert("RGBA")
            out = source.copy()
            source_pixels = source.load()
            out_pixels = out.load()
            for y in range(source.height):
                for x in range(source.width):
                    red, green, blue, alpha = source_pixels[x, y]
                    if (red, green, blue) == color:
                        out_pixels[x, y] = (red, green, blue, 0)
            return out
        return original(image, modifier, warnings)

    render_blueprint.apply_modifier = apply_modifier
