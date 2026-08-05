#!/usr/bin/env bash
# Copies the game into the games folder of the Luanti Flatpak installation.
# (The Flatpak sandbox has no access to ~/projects, hence copying instead
# of symlinking.) Simply re-run after code changes.
#
# Usage: tools/sync_to_luanti.sh [target_dir]
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/.var/app/org.luanti.luanti/.minetest/games/world_of_blockcraft}"

# Remove leftovers of an earlier symlink attempt
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

echo "Game synced to: $DEST"
