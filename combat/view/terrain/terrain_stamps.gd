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
const K_ANTHILL: int = 9
const TEX_DIR: String = "res://assets/sprites/structures/"
## Stamp kinds drawn as smooth sprites over the terrain (TerrainOverlay); the others keep their baked pixel colours.
const OVERLAY_KINDS: Array[String] = ["TREE", "WATCHTOWER", "BARRACA", "ROCK_ARCH", "MONOLITHS", "ANTHILL", "HOLLOW_LOG", "TERRACE", "VIADUCT", "TRUSS"]


## Pixel box of a stamp (mirrors the extents of the JS stamp functions), clipped to the terrain.
static func box(s: Dictionary) -> Rect2i:
	return _raw_box(s).intersection(Rect2i(0, 0, W, H))


## Upper-case "kind style" text the colour class is derived from.
static func label(s: Dictionary) -> String:
	return (str(s.get("kind", "")) + " " + str(s.get("style", ""))).to_upper()


## Colour class of the stamp (K_* constant), same priority order as the original per-pixel painter.
static func kind_id(s: Dictionary) -> int:
	var k: String = label(s)
	if str(s.get("kind", "")) == "ANTHILL":
		return K_ANTHILL
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


## True when the stamp is drawn as a smooth sprite overlay (TerrainOverlay) over the terrain; the sim pixel mask only collides.
static func has_overlay(s: Dictionary) -> bool:
	return str(s.get("kind", "")) in OVERLAY_KINDS


## Which pixels of the stamp are an enclosed void at match start (tower chamber, barraca door, log tube): 0 none, 1 tower, 2 barraca, 3 log.
static func hollow_id(s: Dictionary) -> int:
	match str(s.get("kind", "")):
		"WATCHTOWER":
			return 1
		"BARRACA":
			return 2
		"HOLLOW_LOG":
			return 3
	return 0


## Sprite file of a tree: the sim style picks the crown shape (umbrella pine, fir, palm, round crown for everything else).
static func tree_tex(s: Dictionary) -> String:
	match str(s.get("style", "")):
		"UMBRELLA_PINE":
			return "pine"
		"DOUGLAS_FIR":
			return "fir"
		"PALM_DELTA":
			return "palm"
	return "broadleaf"


## Draw pieces of a stamp's overlay sprite. Each piece is {tex (res path or "" for a plain colour strip), repeat (bool), pos, uv
## (PackedVector2Array, uv in 0..1 of the texture, may exceed 1 on repeating pieces), col (PackedColorArray, vertex tint), idx
## (triangle indices)}. Positions are world px; the sprite art is authored in world px (one SVG unit = one world px at scale 1).
static func overlay_pieces(s: Dictionary) -> Array:
	var out: Array = []
	var x: float = float(s.get("x", 0.0))
	var y: float = float(s.get("y", 0.0))
	match str(s.get("kind", "")):
		"TREE":
			var sc: float = float(s.get("scale", 1.0))
			out.append(_sprite(tree_tex(s), Vector2(x, y), Vector2(70, 140), Vector2(140, 170), sc))
		"WATCHTOWER":
			out.append(_sprite("watchtower", Vector2(x, y), Vector2(42, 96), Vector2(84, 112)))
		"BARRACA":
			out.append(_sprite("barraca", Vector2(x, y), Vector2(50, 76), Vector2(100, 92)))
		"ROCK_ARCH":
			out.append(_sprite("rock_arch", Vector2(x, y), Vector2(125, 82), Vector2(250, 92)))
		"MONOLITHS":
			out.append(_sprite("monoliths", Vector2(x, y), Vector2(62, 80), Vector2(124, 96)))
		"ANTHILL":
			out.append(_sprite("anthill", Vector2(x, y), Vector2(40, 34), Vector2(80, 44)))
		"HOLLOW_LOG":
			var p: Dictionary = _sprite("hollow_log", Vector2(x, y - 14.0), Vector2(88, 24), Vector2(176, 40))
			var tilt: float = float(s.get("tilt", 0.0))
			var pos: PackedVector2Array = p["pos"]
			for i in pos.size():
				pos[i].y += (pos[i].x - x) * tilt
			p["pos"] = pos
			out.append(p)
		"TERRACE":
			out.append_array(_terrace_pieces(s))
		"VIADUCT":
			out.append_array(_viaduct_pieces(s))
		"TRUSS":
			out.append_array(_truss_pieces(s))
	return out


## Plain textured quad: the texture `size` (SVG units = world px at scale 1) anchored at `anchor` on world point `at`.
static func _sprite(tex: String, at: Vector2, anchor: Vector2, size: Vector2, sc: float = 1.0) -> Dictionary:
	var o: Vector2 = at - anchor * sc
	var e: Vector2 = size * sc
	return {"tex": TEX_DIR + tex + ".svg", "repeat": false,
		"pos": PackedVector2Array([o, o + Vector2(e.x, 0), o + e, o + Vector2(0, e.y)]),
		"uv": PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]),
		"col": PackedColorArray(), "idx": PackedInt32Array([0, 1, 2, 0, 2, 3])}


## Textured rectangle with repeating uv: world rect (x0..x1, y0..y1), `tile` world px per texture, uv origin (u0, v0) at the rect's top left.
static func _tiled(tex: String, x0: float, x1: float, y0: float, y1: float, tile: Vector2, u0: float, v0: float) -> Dictionary:
	var ua: float = u0
	var ub: float = u0 + (x1 - x0) / tile.x
	var va: float = v0
	var vb: float = v0 + (y1 - y0) / tile.y
	return {"tex": TEX_DIR + tex + ".svg", "repeat": true,
		"pos": PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		"uv": PackedVector2Array([Vector2(ua, va), Vector2(ub, va), Vector2(ub, vb), Vector2(ua, vb)]),
		"col": PackedColorArray(), "idx": PackedInt32Array([0, 1, 2, 0, 2, 3])}


## Dark vertical strip (end cap outline of a long structure).
static func _edge_strip(xc: float, y0: float, y1: float) -> Dictionary:
	var c := Color(0.16, 0.11, 0.07, 1.0)
	return {"tex": "", "repeat": false,
		"pos": PackedVector2Array([Vector2(xc - 0.9, y0), Vector2(xc + 0.9, y0), Vector2(xc + 0.9, y1), Vector2(xc - 0.9, y1)]),
		"uv": PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]),
		"col": PackedColorArray([c, c, c, c]), "idx": PackedInt32Array([0, 1, 2, 0, 2, 3])}


## Terrace slab: top and bottom follow the sim's wavy profile exactly (unrounded); the 64 x 36 tile keeps its stone courses unstretched.
static func _terrace_pieces(s: Dictionary) -> Array:
	var cx: float = float(s.get("x", 0.0))
	var deck: float = float(s.get("y", 0.0))
	var hw: float = float(s.get("half_w", float(s.get("w", 80)) * 0.5))
	var thick: float = float(s.get("thickness", 24.0))
	var pos := PackedVector2Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var xa: float = cx - hw
	var xb: float = cx + hw + 1.0
	var n: int = maxi(2, int(ceilf((xb - xa) / 3.0)))
	var dark := Color(0.42, 0.34, 0.3, 1.0)
	var ty0: float = 0.0
	var yb0: float = 0.0
	for i in n + 1:
		var xx: float = lerpf(xa, xb, float(i) / n)
		var wx: float = clampf(xx, xa, xb - 1.0)
		var edge_frac: float = absf(wx - cx) / hw
		var y_top: float = deck + sin(wx * 0.06) * 2.5
		var y_bot: float = deck + thick - pow(edge_frac, 2.2) * 10.0 + cos(wx * 0.09) * 3.0 + 0.5
		var r0: float = y_top - 4.0
		var u: float = xx / 64.0
		var vbot: float = (y_bot - r0) / 36.0
		var vmid: float = (y_bot - 2.4 - r0) / 36.0
		pos.append_array(PackedVector2Array([Vector2(xx, r0), Vector2(xx, y_bot - 2.4), Vector2(xx, y_bot)]))
		uv.append_array(PackedVector2Array([Vector2(u, 0.0), Vector2(u, vmid), Vector2(u, vbot)]))
		col.append_array(PackedColorArray([Color.WHITE, Color.WHITE, dark]))
		if i == 0:
			ty0 = y_top
			yb0 = y_bot
		if i > 0:
			var b: int = (i - 1) * 3
			idx.append_array(PackedInt32Array([b, b + 3, b + 4, b, b + 4, b + 1, b + 1, b + 4, b + 5, b + 1, b + 5, b + 2]))
	var out: Array = [{"tex": TEX_DIR + "terrace.svg", "repeat": true, "pos": pos, "uv": uv, "col": col, "idx": idx}]
	out.append(_edge_strip(xa + 0.3, ty0 - 0.5, yb0))
	var ye: float = deck + sin((xb - 1.0) * 0.06) * 2.5
	out.append(_edge_strip(xb - 0.3, ye - 0.5, deck + thick - 10.0 * pow(1.0, 2.2) + cos((xb - 1.0) * 0.09) * 3.0 + 0.5))
	return out


static func _viaduct_pieces(s: Dictionary) -> Array:
	var x1: float = float(s.get("x1", 0.0))
	var x2: float = float(s.get("x2", 0.0))
	var fl: float = floorf(float(s.get("deck_y", s.get("y", 0.0))))
	var xa: float = floorf(x1)
	var xb: float = ceilf(x2) + 1.0
	var out: Array = [_tiled("viaduct", xa, xb, fl - 3.0, fl + 67.0, Vector2(130, 70), (xa - x1) / 130.0, 0.0)]
	out.append(_edge_strip(xa + 0.3, fl - 0.5, fl + 16.0))
	out.append(_edge_strip(xb - 0.3, fl - 0.5, fl + 16.0))
	return out


## Truss: chords + posts on the world's 28 px grid, and the two diagonals on their own 14 px phases (the sim derives them from absolute x + y).
static func _truss_pieces(s: Dictionary) -> Array:
	var x1: float = float(s.get("x1", 0.0))
	var x2: float = float(s.get("x2", 0.0))
	var fl: float = floorf(float(s.get("deck_y", s.get("y", 0.0))))
	var xa: float = floorf(x1)
	var xb: float = ceilf(x2) + 1.0
	var t: String = "truss_orange" if bool(s.get("is_orange", false)) else "truss"
	var out: Array = [
		_tiled(t + "_diag_b", xa, xb, fl, fl + 19.0, Vector2(14, 19), posmod_f(xa - fl + 1000.0, 14.0) / 14.0, 0.0),
		_tiled(t + "_diag_a", xa, xb, fl, fl + 19.0, Vector2(14, 19), posmod_f(xa + fl, 14.0) / 14.0, 0.0),
		_tiled(t, xa, xb, fl, fl + 19.0, Vector2(28, 19), posmod_f(xa, 28.0) / 28.0, 0.0)]
	return out


static func posmod_f(a: float, b: float) -> float:
	return fposmod(a, b)


## Sprite of a dry-stone girder (the sim's capsule: flat-tipped, 5 px round caps): beam = {x, y, angle, length, thickness}. A dark rim ring
## is tinted through the vertex colours.
static func girder_piece(beam: Dictionary) -> Dictionary:
	var cx: float = float(beam.get("x", 0.0))
	var cy: float = float(beam.get("y", 0.0))
	var ang: float = float(beam.get("angle", 0.0))
	var hl: float = float(beam.get("length", 78.0)) * 0.5
	var ht: float = float(beam.get("thickness", 16.0)) * 0.5
	var t0: float = acos(clampf(5.0 / ht, 0.0, 1.0))
	var half: Array[Vector2] = [Vector2(hl - 5.0, -ht)]
	var n: int = 6
	for i in range(0, n + 1):
		var t: float = lerpf(-PI * 0.5, -t0, float(i) / n)
		half.append(Vector2(hl - 5.0 + ht * cos(t), ht * sin(t)))
	for i in range(0, n + 1):
		var t: float = lerpf(t0, PI * 0.5, float(i) / n)
		half.append(Vector2(hl - 5.0 + ht * cos(t), ht * sin(t)))
	var outer: Array[Vector2] = half.duplicate()
	for q in half:
		outer.append(-q)
	var rot := Vector2(cos(ang), sin(ang))
	var nrm := Vector2(-sin(ang), cos(ang))
	var pos := PackedVector2Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var rim := Color(0.55, 0.47, 0.42, 1.0)
	var m: int = outer.size()
	for pass_i in 2:
		for q in outer:
			var k: float = 1.0 if pass_i == 0 else 0.0
			var a: float = q.x * (1.0 - (1.8 / hl) * (1.0 - k))
			var b: float = q.y * (1.0 - (1.8 / ht) * (1.0 - k))
			pos.append(Vector2(cx, cy) + rot * a + nrm * b)
			uv.append(Vector2((a + hl) / 41.0, b / (ht * 2.0) + 0.5))
			col.append(rim if pass_i == 0 else Color.WHITE)
	pos.append(Vector2(cx, cy))
	uv.append(Vector2(hl / 41.0, 0.5))
	col.append(Color.WHITE)
	var idx := PackedInt32Array()
	for i in m:
		var j: int = (i + 1) % m
		idx.append_array(PackedInt32Array([i, j, m + j, i, m + j, m + i]))
		idx.append_array(PackedInt32Array([m + i, m + j, 2 * m]))
	return {"tex": TEX_DIR + "girder.svg", "repeat": true, "pos": pos, "uv": uv, "col": col, "idx": idx}


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
