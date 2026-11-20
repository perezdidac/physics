## GPU side of the terrain: four persistent SubViewports (3200x820) that hold
##   mask   the solidity mask (R channel), updated by drawing only the changed rectangle,
##   front  the baked front colour layer (rock / soil / turf, fallback stamp colours, permanent crater scorch),
##   back   the baked back rock wall (alpha 0 where there is none or a crater cut it),
##   struct the structure mask: R = pixel solid at match start and owned by a stamp drawn as a sprite (TerrainOverlay), G = enclosed
##          void of such a stamp (tower chamber, door, log tube). The terrain shader hides its front layer there and the overlay
##          shader cuts the sprite where the live mask lost those pixels. Girders built later add to R.
## Everything is painted once at match start (`bake`) and afterwards only the dirty rectangles are redrawn, so the
## per-frame terrain shader is plain texture lookups. Temporary draw nodes live one frame, then are freed.
class_name TerrainBaker
extends Node

const W: int = 3200
const H: int = 820
const BAKE_SHADER: String = "res://combat/view/terrain/terrain_bake.gdshader"
const CUT_SHADER: String = "res://combat/view/terrain/terrain_cut.gdshader"
const COPY_SHADER: String = "res://combat/view/terrain/terrain_copy.gdshader"
const MODE_FRONT: int = 0
const MODE_BACK: int = 1
const MODE_STAMP: int = 2
const MODE_SCORCH: int = 3
const MODE_STRUCT: int = 4
## Pixels around a changed mask rectangle whose smoothed value changes too (the smoothing kernel reaches ~3 px).
const _SMOOTH_MARGIN: int = 3

var mask_vp: SubViewport = null
var front_vp: SubViewport = null
var back_vp: SubViewport = null
var struct_vp: SubViewport = null
var _common: Dictionary = {}
var _temps: Array = []
var _bake_shader: Shader = null
var _cut_shader: Shader = null
var _copy_mat: ShaderMaterial = null


func _init() -> void:
	_bake_shader = load(BAKE_SHADER) as Shader
	_cut_shader = load(CUT_SHADER) as Shader
	_copy_mat = ShaderMaterial.new()
	_copy_mat.shader = load(COPY_SHADER) as Shader
	mask_vp = _make_viewport("MaskVp")
	front_vp = _make_viewport("FrontVp")
	back_vp = _make_viewport("BackVp")
	struct_vp = _make_viewport("StructVp")


func _make_viewport(vp_name: String) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	return vp


## Paints the whole terrain once. `common` holds the bake shader inputs (perm_tex, surf_tex, colours, map_seed, tex_style),
## `stamps` the sim's stamp list (painted over the front layer when `paint_stamps`).
func bake(mask: PackedByteArray, common: Dictionary, stamps: Array, paint_stamps: bool) -> void:
	free_temps(true)
	var src: ImageTexture = ImageTexture.create_from_image(Image.create_from_data(W, H, false, Image.FORMAT_R8, mask))
	_common = common.duplicate()
	_common["mask_src"] = src
	var full := Rect2i(0, 0, W, H)
	var msp: Sprite2D = _add_sprite(mask_vp, src, Vector2i.ZERO, _copy_mat)
	msp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_add_rect(front_vp, full, _bake_material(MODE_FRONT))
	_add_rect(back_vp, full, _bake_material(MODE_BACK))
	if paint_stamps:
		for st in stamps:
			if st is Dictionary:
				_bake_stamp(st)
				if TerrainStamps.has_overlay(st):
					_bake_struct(st)
	_render(mask_vp)
	_render(front_vp)
	_render(back_vp)
	_render(struct_vp)


## Copies a rectangle of the sim mask into the mask texture (only those bytes are uploaded, plus a margin for the smoothing taps).
func upload_mask_rect(mask: PackedByteArray, rect: Rect2i) -> void:
	var full := Rect2i(0, 0, W, H)
	var r: Rect2i = rect.intersection(full)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var write: Rect2i = r.grow(_SMOOTH_MARGIN).intersection(full)
	var read: Rect2i = write.grow(_SMOOTH_MARGIN + 1).intersection(full)
	var buf := PackedByteArray()
	for y in range(read.position.y, read.end.y):
		var i0: int = y * W + read.position.x
		buf.append_array(mask.slice(i0, i0 + read.size.x))
	var img: Image = Image.create_from_data(read.size.x, read.size.y, false, Image.FORMAT_R8, buf)
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.centered = false
	sp.position = Vector2(write.position)
	sp.region_enabled = true
	sp.region_rect = Rect2(write.position - read.position, write.size)
	sp.material = _copy_mat
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mask_vp.add_child(sp)
	_temps.append([sp, Engine.get_process_frames()])
	_render(mask_vp)


## Permanent crater scorch (front layer) and the cut of the back wall, at the exact crater centre and radius.
func carve(cx: float, cy: float, radius: float) -> void:
	var reach: int = int(ceilf(radius + 18.0)) + 1
	var box := Rect2i(int(floorf(cx)) - reach, int(floorf(cy)) - reach, reach * 2 + 1, reach * 2 + 1).intersection(Rect2i(0, 0, W, H))
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var m: ShaderMaterial = _bake_material(MODE_SCORCH)
	m.set_shader_parameter("crater", Vector3(cx, cy, radius))
	_add_rect(front_vp, box, m)
	var cut := ShaderMaterial.new()
	cut.shader = _cut_shader
	cut.set_shader_parameter("crater", Vector3(cx, cy, radius))
	var cr: int = int(ceilf(radius * 0.68)) + 1
	var cbox := Rect2i(int(floorf(cx)) - cr, int(floorf(cy)) - cr, cr * 2 + 1, cr * 2 + 1).intersection(Rect2i(0, 0, W, H))
	if cbox.size.x > 0 and cbox.size.y > 0:
		_add_rect(back_vp, cbox, cut)
	_render(front_vp)
	_render(back_vp)


## Marks the pixels a girder turned solid as structure (`added` is rect-sized, 1 = newly solid): its sprite is drawn by TerrainOverlay.
func paint_girder(rect: Rect2i, added: PackedByteArray) -> void:
	var r: Rect2i = rect.intersection(Rect2i(0, 0, W, H))
	if r != rect or added.size() != rect.size.x * rect.size.y:
		return
	var img: Image = Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for yy in r.size.y:
		for xx in r.size.x:
			if added[yy * r.size.x + xx] != 0:
				img.set_pixel(xx, yy, Color(1, 0, 0, 1))
	_add_sprite(struct_vp, ImageTexture.create_from_image(img), r.position, null)
	_render(struct_vp)


## Frees the temporary draw nodes of earlier frames (all of them with `everything`).
func free_temps(everything: bool = false) -> void:
	var now: int = Engine.get_process_frames()
	var keep: Array = []
	for t in _temps:
		if everything or int(t[1]) < now:
			(t[0] as Node).queue_free()
		else:
			keep.append(t)
	_temps = keep
	if _temps.is_empty():
		_common.erase("mask_src")


func _bake_stamp(s: Dictionary) -> void:
	var box: Rect2i = TerrainStamps.box(s)
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var sc: float = float(s.get("scale", 1.0))
	var sy: float = float(s.get("y", 0.0))
	var m: ShaderMaterial = _bake_material(MODE_STAMP)
	m.set_shader_parameter("stamp", Vector4(float(s.get("x", 0.0)), sy, sc, float(s.get("crown_y", sy - 60.0 * sc))))
	m.set_shader_parameter("stamp_box", Vector3(box.position.y, box.end.y, TerrainStamps.rows_below_surface(s)))
	m.set_shader_parameter("stamp_kind", Vector2i(TerrainStamps.kind_id(s), TerrainStamps.tree_style(s)))
	_add_rect(front_vp, box, m)


## Structure mask pass of a stamp drawn as a sprite: R on its solid pixels, G on its enclosed void.
func _bake_struct(s: Dictionary) -> void:
	var box: Rect2i = TerrainStamps.box(s)
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var sy: float = float(s.get("y", 0.0))
	var m: ShaderMaterial = _bake_material(MODE_STRUCT)
	m.set_shader_parameter("stamp", Vector4(float(s.get("x", 0.0)), sy, 1.0, 0.0))
	m.set_shader_parameter("stamp_box", Vector3(box.position.y, box.end.y, TerrainStamps.rows_below_surface(s)))
	m.set_shader_parameter("stamp_hollow", TerrainStamps.hollow_id(s))
	m.set_shader_parameter("stamp_extra", Vector2(float(s.get("tilt", 0.0)), float(s.get("half_len", 78.0))))
	_add_rect(struct_vp, box, m)


func _bake_material(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _bake_shader
	for k in _common:
		m.set_shader_parameter(k, _common[k])
	m.set_shader_parameter("mode", mode)
	return m


func _add_rect(vp: SubViewport, box: Rect2i, m: ShaderMaterial) -> void:
	var cr := ColorRect.new()
	cr.position = Vector2(box.position)
	cr.size = Vector2(box.size)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.set_shader_parameter("origin", Vector2(box.position))
	cr.material = m
	vp.add_child(cr)
	_temps.append([cr, Engine.get_process_frames()])


func _add_sprite(vp: SubViewport, tex: Texture2D, pos: Vector2i, m: Material) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2(pos)
	sp.material = m
	vp.add_child(sp)
	_temps.append([sp, Engine.get_process_frames()])
	return sp


func _render(vp: SubViewport) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
