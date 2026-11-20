#!/usr/bin/env python3
"""Run: python3 -I assets/sprites/weapon_icons/extract_weapon_icons.py. Extracts the 16 inline weapon SVG strings from reference/js/state.js into assets/sprites/weapon_icons/<id>.svg (lowercase id), verbatim."""
import re, pathlib
root = pathlib.Path(__file__).resolve().parents[3]
src = (root / "reference/js/state.js").read_text(encoding="utf-8")
out = root / "assets/sprites/weapon_icons"
out.mkdir(parents=True, exist_ok=True)
ids = re.findall(r"^\s{4}id: '([A-Z_]+)',", src[:src.index("const WEAPONS") + 20000] if "const WEAPONS" in src else src, re.M)
svgs = re.findall(r"^\s{4}svg: `(<svg.*?</svg>)`", src, re.M)
n = 0
for wid, svg in zip(ids, svgs):
    (out / (wid.lower() + ".svg")).write_text(svg + "\n", encoding="utf-8")
    n += 1
print("weapon icons written:", n)
