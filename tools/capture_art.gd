## Renders a contact sheet of every registered art kind (sprite and its vector fallback side by side, labelled) to
## /tmp/claude-1000/cucs_art_sheet.png. Kinds without a sample state (they need a live sim object) are listed as text cells.
## Needs a display (not --headless):   godot --path . res://tools/CaptureArt.tscn
extends Node

const OUT_PATH := "/tmp/claude-1000/cucs_art_sheet.png"
const COLUMNS: int = 6
const CELL := Vector2(300.0, 230.0)
const GROUND_Y: float = 165.0
const BG := Color("#2b3a3f")

var _viewport: SubViewport = null


func _ready() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	var ids: Array[String] = reg.kinds()
	var drawable: Array[String] = []
	var stateful: Array[String] = []
	for id in ids:
		var art: ThingArt = reg.art_of(id)
		if art != null and art.sample_state() != null:
			drawable.append(id)
		else:
			stateful.append(id)
	var rows: int = ceili(float(drawable.size()) / float(COLUMNS))
	var list_h: float = 40.0 + ceilf(float(stateful.size()) / 4.0) * 22.0
	var size := Vector2i(int(CELL.x) * COLUMNS, int(CELL.y * float(rows) + list_h))
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var bg := DrawLayer.new()
	bg.draw_fn = func(ci: CanvasItem) -> void: ci.draw_rect(Rect2(Vector2.ZERO, Vector2(size)), BG)
	_viewport.add_child(bg)
	var ctx: ArtContext = ArtContext.sample(1.3)
	for i in drawable.size():
		var cell: Vector2 = Vector2(float(i % COLUMNS) * CELL.x, floorf(float(i) / float(COLUMNS)) * CELL.y)
		_add_cell(reg, drawable[i], cell, ctx)
	var list := DrawLayer.new()
	var base_y: float = CELL.y * float(rows)
	list.draw_fn = func(ci: CanvasItem) -> void:
		ViewUtil.text(ci, "Kinds that need a live sim state (not drawn here): %d" % stateful.size(), Vector2(12.0, base_y + 22.0), 14, Color.WHITE, false)
		for k in stateful.size():
			ViewUtil.text(ci, stateful[k], Vector2(12.0 + float(k % 4) * 300.0, base_y + 46.0 + floorf(float(k) / 4.0) * 22.0), 12, Color("#c8d3d6"), false)
	_viewport.add_child(list)
	for i in 6:
		await get_tree().process_frame
	var img: Image = _viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var err: int = img.save_png(OUT_PATH)
	print("CAPTURE: %s (%dx%d) kinds=%d drawn=%d err=%d" % [OUT_PATH, img.get_width(), img.get_height(), ids.size(), drawable.size(), err])
	ArtRegistry.shutdown()
	get_tree().quit()


## One cell: the sprite (or the plain art) on the left, the vector fallback on the right when there is one, labels below.
func _add_cell(reg: ArtRegistry, id: String, cell: Vector2, ctx: ArtContext) -> void:
	var art: ThingArt = reg.art_of(id)
	var state: Variant = art.sample_state()
	var fb: ThingArt = art.vector_fallback()
	var ext: Vector2 = art.sample_extent()
	var k: float = clampf(100.0 / maxf(maxf(ext.x, ext.y), 1.0), 1.0, 4.0)
	var is_sprite: bool = art is SpriteArt and (art as SpriteArt).has_sprite()
	var halves: Array[ThingArt] = [art]
	var tags: Array[String] = ["sprite" if is_sprite else "vector"]
	if fb != null:
		halves.append(fb)
		tags.append("vector fallback")
	var slot_w: float = CELL.x / float(halves.size())
	for h in halves.size():
		var layer := DrawLayer.new()
		layer.position = cell + Vector2(slot_w * (float(h) + 0.5), GROUND_Y)
		layer.scale = Vector2(k, k)
		var which: ThingArt = halves[h]
		layer.draw_fn = func(ci: CanvasItem) -> void:
			ci.draw_line(Vector2(-70.0, 0.0) / k, Vector2(70.0, 0.0) / k, Color(1, 1, 1, 0.18), 1.0 / k)
			which.draw(ci, state, ctx)
		_viewport.add_child(layer)
	var label := DrawLayer.new()
	label.position = cell
	label.draw_fn = func(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(Vector2.ZERO, CELL), Color(1, 1, 1, 0.05), false, 1.0)
		ViewUtil.text(ci, id, Vector2(CELL.x * 0.5, 22.0), 15, Color.WHITE)
		ViewUtil.text(ci, reg.group_of(id), Vector2(CELL.x * 0.5, 40.0), 11, Color("#9fb4b9"))
		for h in tags.size():
			ViewUtil.text(ci, tags[h], Vector2(slot_w * (float(h) + 0.5), CELL.y - 14.0), 12, Color("#ffd966") if tags[h] == "sprite" else Color("#c8d3d6"))
	_viewport.add_child(label)
