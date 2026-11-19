## Draws the destructible terrain. The sim owns only the solidity mask (+ `stamps`, `surface_y`); TerrainBaker keeps the mask
## and the baked front / back colour layers on the GPU, and terrain.gdshader just composes them every frame.
## Terrain changes are queued by `on_terrain_changed` and applied once per frame (`flush`): only the touched mask bytes are
## uploaded, craters leave a permanent scorch and girders become structure-mask pixels with a TerrainOverlay sprite.
class_name TerrainView
extends Node2D

const W: int = 3200
const H: int = 820
const STYLES: Dictionary = {
	"STRATA_WAVES": 0, "BASALT_COLUMNS": 1, "ASHLAR_BLOCKS": 2,
	"CONGLOMERATE_PEBBLES": 3, "SLATE_FRACTURES": 4, "TERRACOTTA_DUNES": 5,
}
## Frames the terrain stays hidden after setup while the first bake renders.
const _BAKE_FRAMES: int = 2

var _mat: ShaderMaterial = null
var _baker: TerrainBaker = null
var _overlay: TerrainOverlay = null
var _terrain: Object = null
var _rects: Array[Rect2i] = []
var _events: Array[Dictionary] = []
var _hidden_frames: int = 0
## Number of flushed batches of terrain changes (used by tests).
var uploads: int = 0
## Number of craters whose scorch was painted (used by tests).
var scorch_count: int = 0


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://combat/view/terrain.gdshader") as Shader
	material = _mat
	_overlay = TerrainOverlay.new()
	add_child(_overlay)


func _process(_delta: float) -> void:
	if _baker == null:
		return
	_baker.free_temps()
	flush()
	if _hidden_frames > 0:
		_hidden_frames -= 1
		visible = _hidden_frames == 0


## Reads the freshly generated terrain from the sim and bakes the colour layers.
func setup(terrain: Object) -> void:
	_terrain = terrain
	_rects.clear()
	_events.clear()
	if _baker != null:
		_baker.free_temps(true)
		_baker.queue_free()
	var mask: PackedByteArray = ViewUtil.g(terrain, "mask", PackedByteArray())
	if mask.size() != W * H:
		mask = PackedByteArray()
		mask.resize(W * H)
	var surf: PackedFloat32Array = _read_surface(terrain, mask)
	var surf_img := Image.create_from_data(W, 1, false, Image.FORMAT_RF, surf.to_byte_array())
	var soil: Vector3 = _rgb255(ViewUtil.g(terrain, "match_soil"), _map_rgb(terrain, "soil_col", Vector3(134, 84, 58)))
	var style: String = ViewUtil.gs(terrain, "texture_style", "STRATA_WAVES")
	var common: Dictionary = {
		"perm_tex": ImageTexture.create_from_image(ViewNoise.perm_image()),
		"surf_tex": ImageTexture.create_from_image(surf_img),
		"turf_col": _rgb255(ViewUtil.g(terrain, "match_turf"), _map_rgb(terrain, "turf_col", Vector3(92, 118, 52))),
		"soil_col": soil,
		"rock_col": _rgb255(ViewUtil.g(terrain, "match_rock"), _map_rgb(terrain, "rock_col", Vector3(148, 128, 122))),
		"map_seed": ViewUtil.gf(terrain, "map_seed", 2.4),
		"tex_style": int(STYLES.get(style, 0)),
	}
	_baker = TerrainBaker.new()
	add_child(_baker)
	var stamps: Array = ViewUtil.g(terrain, "stamps", [])
	var real: bool = _has_real_surface(terrain)
	_baker.bake(mask, common, stamps, real)
	_overlay.setup(stamps if real else [], _baker)
	_mat.set_shader_parameter("mask_tex", _baker.mask_vp.get_texture())
	_mat.set_shader_parameter("front_tex", _baker.front_vp.get_texture())
	_mat.set_shader_parameter("back_tex", _baker.back_vp.get_texture())
	_mat.set_shader_parameter("struct_tex", _baker.struct_vp.get_texture())
	_hidden_frames = _BAKE_FRAMES
	visible = false
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-40, -40, W + 80, H + 80), Color.WHITE)


## Called on the sim's `terrain_changed(rect)`: queues the update (applied at most once per frame).
func on_terrain_changed(rect: Rect2i) -> void:
	if _terrain == null or _baker == null:
		return
	_rects.append(rect)
	var kind: String = ViewUtil.gs(_terrain, "last_change_kind", "")
	if kind == "carve":
		var c: Dictionary = ViewUtil.g(_terrain, "last_carve", {})
		if c.has("r"):
			_events.append({"kind": "carve", "x": float(c["x"]), "y": float(c["y"]), "r": float(c["r"])})
	elif kind == "build":
		var b: Dictionary = ViewUtil.g(_terrain, "last_build", {})
		if b.has("added"):
			_events.append({"kind": "build", "rect": b["rect"], "added": b["added"], "beam": b})


## Applies the queued terrain changes now: mask rectangles first, then scorch / girder colours in order.
func flush() -> void:
	if _rects.is_empty() or _baker == null:
		return
	var mask: PackedByteArray = ViewUtil.g(_terrain, "mask", PackedByteArray())
	if mask.size() != W * H:
		_rects.clear()
		_events.clear()
		return
	if _rects.size() > 6:
		var all: Rect2i = _rects[0]
		for r in _rects:
			all = all.merge(r)
		_rects = [all]
	for r in _rects:
		_baker.upload_mask_rect(mask, r)
	for ev in _events:
		if ev["kind"] == "carve":
			_baker.carve(ev["x"], ev["y"], ev["r"])
			scorch_count += 1
		else:
			_baker.paint_girder(ev["rect"], ev["added"])
			_overlay.add_girder(ev.get("beam", {}))
	_rects.clear()
	_events.clear()
	uploads += 1


## Updates the perspective offset of the back wall for the camera centre (renderer.js:110-111).
func set_camera(cx: float, cy: float) -> void:
	var px: float = clampf((float(W) * 0.5 - cx) * 0.018, -14.0, 14.0)
	var py: float = -9.0 + clampf((400.0 - cy) * 0.02, -6.0, 6.0)
	_mat.set_shader_parameter("persp", Vector2(px, py))


# ------------------------------------------------------------------ helpers

func _has_real_surface(terrain: Object) -> bool:
	var s: Variant = ViewUtil.g(terrain, "surface_y")
	return s != null and (s is PackedFloat32Array or s is Array or s is PackedFloat64Array) and (s as Variant).size() >= W


func _read_surface(terrain: Object, mask: PackedByteArray) -> PackedFloat32Array:
	var s: Variant = ViewUtil.g(terrain, "surface_y")
	if s is PackedFloat32Array and (s as PackedFloat32Array).size() >= W:
		return s
	var out := PackedFloat32Array()
	out.resize(W)
	if s != null and (s is Array or s is PackedFloat64Array) and (s as Variant).size() >= W:
		for x in W:
			out[x] = float(s[x])
		return out
	for x in W:
		var y: int = 0
		while y < H and mask[y * W + x] == 0:
			y += 1
		out[x] = float(y if y < H else H + 100)
	return out


static func _rgb255(v: Variant, fallback: Vector3) -> Vector3:
	if v is Color:
		var c: Color = v
		return Vector3(c.r, c.g, c.b) * 255.0
	if v is Vector3:
		return v
	if v is Array or v is PackedFloat32Array or v is PackedInt32Array or v is PackedFloat64Array:
		if (v as Variant).size() >= 3:
			return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


func _map_rgb(terrain: Object, key: String, fallback: Vector3) -> Vector3:
	var map: Variant = ViewUtil.g(terrain, "map")
	return _rgb255(ViewUtil.g(map, key), fallback)
