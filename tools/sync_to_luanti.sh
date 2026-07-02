#!/usr/bin/env bash
# Kopiert das Game in den Games-Ordner der Luanti-Flatpak-Installation.
# (Die Flatpak-Sandbox hat keinen Zugriff auf ~/projects, daher kopieren
# statt symlinken.) Nach Code-Aenderungen einfach erneut ausfuehren.
#
# Aufruf: tools/sync_to_luanti.sh [zielordner]
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/.var/app/org.luanti.luanti/.minetest/games/voxel_of_warcraft}"

# Reste eines frueheren Symlink-Versuchs entfernen
if [ -L "$DEST" ]; then
	rm "$DEST"
fi
mkdir -p "$DEST"

rsync -a --delete "$SRC/mods/" "$DEST/mods/"
cp "$SRC/game.conf" "$DEST/game.conf"
for f in minetest.conf settingtypes.txt; do
	[ -f "$SRC/$f" ] && cp "$SRC/$f" "$DEST/$f"
done
if [ -d "$SRC/menu" ]; then
	rsync -a --delete "$SRC/menu/" "$DEST/menu/"
fi

echo "Game synchronisiert nach: $DEST"
