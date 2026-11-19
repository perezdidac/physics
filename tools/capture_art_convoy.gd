## Crown, worry mark and sign of the convoy at 6x: /tmp/claude-1000/sheet_creatures_combat_convoy.png (needs a display).
extends Node


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(600, 220)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var layer := DrawLayer.new()
	layer.scale = Vector2(5.0, 5.0)
	layer.draw_fn = func(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(0, 0, 200, 80), Color("#5d6f52"))
		ConvoyArt._crown(ci, Vector2(20, 30), 1.0, 1.0)
		ConvoyArt._crown(ci, Vector2(45, 30), 1.4, -1.0)
		ConvoyArt._worry(ci, Vector2(80, 25), 1.0, 0.3)
		ConvoyArt._sign(ci, Vector2(130, 60), 0.0)
	vp.add_child(layer)
	for i in 6:
		await get_tree().process_frame
	vp.get_texture().get_image().save_png("/tmp/claude-1000/sheet_creatures_combat_convoy.png")
	get_tree().quit()
