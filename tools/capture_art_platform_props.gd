## Captures the platformer props: top = sprite art, bottom = vector fallback, at zoom 1 and 2.5 (two sheets):
## /tmp/claude-1000/sheet_platform_props_{1x,zoom}.png.   godot --path . res://tools/CaptureArtPlatformProps.tscn
extends Node2D

const OUT := "/tmp/claude-1000/sheet_platform_props"
const CELL := Vector2(256.0, 330.0)
var _zoom: float = 1.0
var _page: int = 0
var _ctx := ArtContext.new()


func _ready() -> void:
	_ctx.t = 0.7
	await get_tree().create_timer(0.3).timeout
	for page in 4:
		_page = page
		_zoom = 1.0 if page == 0 else 2.2
		_rebuild()
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [OUT, page])
	get_tree().quit()


func _cases() -> Array:
	var all: Array = [
		["platform:nutrient", {"i": 0, "p": Vector2(0, -14)}],
		["platform:checkpoint", {"i": 0, "p": Vector2(0, 0), "lit": false}],
		["platform:checkpoint", {"i": 1, "p": Vector2(0, 0), "lit": true}],
		["platform:tuft", {"rect": Rect2(-40, -20, 80, 20), "left": 0.0, "time": 8.0}],
		["platform:tuft", {"rect": Rect2(-40, -20, 80, 20), "left": 5.0, "time": 8.0}],
		["platform:needle", Rect2(-60, -6, 120, 10)],
		["platform:puddle", {"i": 0, "rect": Rect2(-30, -4, 60, 4), "storm": false}],
		["platform:puddle", {"i": 1, "rect": Rect2(-40, -6, 80, 6), "storm": true}],
		["platform:goal", {"goal": Rect2(-30, -60, 60, 60), "view": Rect2(-400, -700, 800, 800), "moonlit": false}],
		["platform:goal", {"goal": Rect2(-30, -60, 60, 60), "view": Rect2(-400, -700, 800, 800), "moonlit": true}],
	]
	if _page == 0:
		return all
	return all.slice((_page - 1) * 4, mini(_page * 4, all.size()))


class Cell extends Node2D:
	var art: ThingArt = null
	var state: Variant = null
	var ctx: ArtContext = null

	func _draw() -> void:
		art.draw(self, state, ctx)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 2000, 1000), Color(0.3, 0.38, 0.28))


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var cases: Array = _cases()
	for i in cases.size():
		for row in 2:
			var art: ThingArt = ArtRegistry.get_instance().art_of(cases[i][0])
			if row == 1:
				art = art.vector_fallback()
			var cell := Cell.new()
			cell.art = art
			cell.state = cases[i][1]
			cell.ctx = _ctx
			var n: float = float(cases.size())
			cell.position = Vector2((float(i) + 0.5) * 1280.0 / n, 190.0 + float(row) * (330.0 if _zoom > 1.0 else 200.0))
			cell.scale = Vector2(_zoom, _zoom)
			add_child(cell)
