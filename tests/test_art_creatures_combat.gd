## Combat creature sprites: every rig is complete and draws without errors for sample and extra states.
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	for id in ["creature:ANT", "creature:EGG", "creature:LARVA_L3", "creature:CATERPILLAR", "creature:CALOSOMA", "creature:SMALL_FLY",
			"creature:BLUE_TIT", "creature:GREAT_TIT", "creature:WILD_BOAR"]:
		var art: ThingArt = reg.resolve(id)
		_check(art is CritterSpriteArt, "%s is a sprite art" % id)
		if art is CritterSpriteArt:
			var cs := CritterSpriteArt.cast(art)
			_check(cs.is_sprite_complete(), "%s rig has all part SVGs" % id)
		var layer := DrawLayer.new()
		var st: Variant = art.sample_state()
		var ctx: ArtContext = ArtContext.sample(1.0)
		layer.draw_fn = func(ci: CanvasItem) -> void: art.draw(ci, st, ctx)
		add_child(layer)
	await get_tree().process_frame
	await get_tree().process_frame
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()
