## Smooth sprites of the structures stamped into the terrain (trees, tower, terraces, viaduct, ...), drawn right after the terrain.
## Geometry and texture mapping come from TerrainStamps.overlay_pieces; terrain_overlay.gdshader cuts them against the live mask, so
## explosions still destroy the structures. The sim pixel mask is only the collision shape of these stamps.
class_name TerrainOverlay
extends Node2D

const SHADER: String = "res://combat/view/terrain/terrain_overlay.gdshader"

var _mat: ShaderMaterial = null
## Number of sprite pieces currently built (used by tests).
var piece_count: int = 0


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader


## Rebuilds the sprites for `stamps`; the mask textures come from the baker.
func setup(stamps: Array, baker: TerrainBaker) -> void:
	clear()
	_mat.set_shader_parameter("mask_tex", baker.mask_vp.get_texture())
	_mat.set_shader_parameter("struct_tex", baker.struct_vp.get_texture())
	for st in stamps:
		if st is Dictionary and TerrainStamps.has_overlay(st):
			for piece in TerrainStamps.overlay_pieces(st):
				_add_piece(piece)


func clear() -> void:
	for c in get_children():
		c.queue_free()
	piece_count = 0


## Adds the sprite of a girder built during the match (sim `last_build` data: x, y, angle, length, thickness).
func add_girder(beam: Dictionary) -> void:
	_add_piece(TerrainStamps.girder_piece(beam))


func _add_piece(piece: Dictionary) -> void:
	var path: String = str(piece["tex"])
	var tex: Texture2D = null
	if path != "":
		if not ResourceLoader.exists(path):
			return
		tex = load(path) as Texture2D
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = piece["pos"]
	arrays[Mesh.ARRAY_TEX_UV] = piece["uv"]
	var col: PackedColorArray = piece["col"]
	if col.size() == (piece["pos"] as PackedVector2Array).size():
		arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = piece["idx"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	mi.texture = tex
	mi.material = _mat
	mi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if bool(piece["repeat"]) else CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(mi)
	piece_count += 1
