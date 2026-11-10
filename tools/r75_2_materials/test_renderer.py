#!/usr/bin/env python3
"""Regression check for explicit alpha modes in the shared node renderer."""

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "tools/building_templates/viewer/renderer.js").read_text(encoding="utf-8")
match = re.search(r"const modeOf = t => ([^;]+);", SOURCE)
assert match, "renderer alpha-mode helper missing"
expression = match.group(1)
script = f"""
const modeOf = t => {expression};
const got = [
  modeOf({{alpha:'opaque', cube:false}}),
  modeOf({{alpha:'opaque', cube:true}}),
  modeOf({{alpha:'clip', cube:false}}),
  modeOf({{alpha:'blend', cube:false}}),
];
if (JSON.stringify(got) !== JSON.stringify(['opaque','opaque','clip','blend'])) {{
  throw new Error('bad alpha modes: ' + JSON.stringify(got));
}}
"""
subprocess.run(["node", "-e", script], check=True)
assert SOURCE.count("modeOf(t)") >= 3, "cube/nodebox/mesh paths must share the alpha mode"
mesh = re.search(r'if \(t\.dt === "mesh"\) \{(.*?)\n      \}', SOURCE, re.S)
assert mesh and "modeOf(t)" in mesh.group(1), "mesh path still forces alpha clipping"
print("R75.2 RENDERER ALPHA PASS modes=4 paths=cube,nodebox,mesh")
