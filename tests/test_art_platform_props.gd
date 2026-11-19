## Platformer prop sprites: every SVG loads, each art draws with its sprites and with its vector fallback without errors.
##   godot --headless --path . res://tests/TestArtPlatformProps.tscn
extends Node

const KINDS: Array[String] = ["platform:puddle", "platform:needle", "platform:tuft", "platform:nutrient", "platform:checkpoint", "platform:goal"]
const SPRITES: Array[String] = ["nutrient", "checkpoint_pole", "checkpoint_flag_lit", "checkpoint_flag_dim", "tuft", "needle", "needle_sheath", "puddle_rim", "puddle_stones", "goal_base"]

class Canvas extends Node2D:
	pass

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	for id in SPRITES:
		_check(PlatformSprites.tex(id) != null, "sprite loads: " + id)
	var ctx := ArtContext.new()
	var canvas := Canvas.new()
	add_child(canvas)
	for k in KINDS:
		var art: ThingArt = ArtRegistry.get_instance().art_of(k)
		_check(art != null and art.vector_fallback() != null, k + " registered with a fallback")
		if art == null:
			continue
		for night in [0.0, 0.8]:
			ctx.night = night
			art.draw(canvas, art.sample_state(), ctx)
			art.vector_fallback().draw(canvas, art.sample_state(), ctx)
	var flat: Dictionary = {"rect": Rect2(-40.0, -20.0, 80.0, 20.0), "left": 4.0, "time": 8.0}
	ArtRegistry.draw("platform:tuft", canvas, flat, ctx)
	ArtRegistry.draw("platform:checkpoint", canvas, {"i": 2, "p": Vector2.ZERO, "lit": false}, ctx)
	_check(true, "draws without errors")
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()
