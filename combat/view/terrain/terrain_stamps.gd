## Geometry and colour class of the stamped structures (trees, towers, terraces, ...) the terrain bake paints.
class_name TerrainStamps
extends RefCounted

const W: int = 3200
const H: int = 820
const K_TREE: int = 0
const K_TERRACE: int = 1
const K_LOG: int = 2
const K_MONOLITH: int = 3
const K_ARCH: int = 4
const K_BARRACA: int = 5
const K_TRUSS: int = 6
const K_VIADUCT: int = 7
const K_STONE: int = 8


## Pixel box of a stamp (mirrors the extents of the JS stamp functions), clipped to the terrain.
static func box(s: Dictionary) -> Rect2i:
	return _raw_box(s).intersection(Rect2i(0, 0, W, H))


## Upper-case "kind style" text the colour class is derived from.
static func label(s: Dictionary) -> String:
	return (str(s.get("kind", "")) + " " + str(s.get("style", ""))).to_upper()


## Colour class of the stamp (K_* constant), same priority order as the original per-pixel painter.
static func kind_id(s: Dictionary) -> int:
	var k: String = label(s)
	if k.contains("TREE") or k.contains("PINE") or k.contains("FIR") or k.contains("CYPRESS") or k.contains("PALM"):
		return K_TREE
	if k.contains("TERRACE") or k.contains("DECK") or k.contains("PLATFORM"):
		return K_TERRACE
	if k.contains("LOG"):
		return K_LOG
	if k.contains("MONOLITH"):
		return K_MONOLITH
	if k.contains("ARCH"):
		return K_ARCH
	if k.contains("BARRACA"):
		return K_BARRACA
	if k.contains("TRUSS") or k.contains("STEEL"):
		return K_TRUSS
	if k.contains("VIADUCT") or k.contains("BRIDGE"):
		return K_VIADUCT
	return K_STONE


## Tree foliage palette: 0 default, 1 fir, 2 palm, 3 cypress.
static func tree_style(s: Dictionary) -> int:
	var k: String = label(s)
	if k.contains("FIR"):
		return 1
	if k.contains("PALM"):
		return 2
	if k.contains("CYPRESS"):
		return 3
	return 0


## Rows a stamp may colour below the natural surface (towers and barracas are built into the ground).
static func rows_below_surface(s: Dictionary) -> int:
	var k: String = label(s)
	return 14 if k.contains("TOWER") or k.contains("BARRACA") else 0


static func _raw_box(s: Dictionary) -> Rect2i:
	var v: Variant = s.get("rect")
	if v is Rect2i:
		return v
	var x: float = float(s.get("x", 0.0))
	var y: float = float(s.get("y", 0.0))
	var w: float = float(s.get("w", 80.0))
	var h: float = float(s.get("h", 80.0))
	match str(s.get("kind", "")):
		"TERRACE":
			var hw: float = float(s.get("half_w", w * 0.5))
			return Rect2i(int(x - hw) - 1, int(y) - 6, int(hw * 2.0) + 3, 40)
		"WATCHTOWER":
			return Rect2i(int(x) - 35, int(y) - 85, 71, 99)
		"HOLLOW_LOG":
			var hl: float = float(s.get("half_len", w * 0.5))
			return Rect2i(int(x - hl) - 1, int(y) - 40, int(hl * 2.0) + 3, 54)
		"ROCK_ARCH":
			var sp: float = float(s.get("span", w * 0.5))
			return Rect2i(int(x - sp) - 1, int(y) - 76, int(sp * 2.0) + 3, 80)
		"MONOLITHS":
			return Rect2i(int(x) - 57, int(y) - 69, 115, 82)
		"VIADUCT", "TRUSS":
			var x1: float = float(s.get("x1", x - w * 0.5))
			var x2: float = float(s.get("x2", x + w * 0.5))
			var dy: float = float(s.get("deck_y", y))
			return Rect2i(int(x1) - 1, int(dy) - 3, int(x2 - x1) + 3, 66)
		"BARRACA":
			return Rect2i(int(x) - 45, int(y) - 72, 91, 84)
		"TREE":
			var sc: float = float(s.get("scale", 1.0))
			var crown_y: float = float(s.get("crown_y", y - 60.0 * sc))
			var rx: float = 50.0 * sc
			return Rect2i(int(x - rx) - 2, int(crown_y - 32.0 * sc), int(rx * 2.0) + 4, int(y - crown_y + 32.0 * sc) + 12)
	return Rect2i(int(x - w * 0.5), int(y - h), int(w), int(h) + 12)
