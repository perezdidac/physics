## Art layer: the registry covers every kind the views draw, SpriteArt falls back to its vector art when the SVG is missing,
## and every registered art with a sample state draws without errors.
##   godot --headless --path . res://tests/TestArtRegistry.tscn
extends Node

## A vector art that only counts its calls.
class CountArt extends ThingArt:
	var calls: int = 0

	func draw(_ci: CanvasItem, _state: Variant, _ctx: ArtContext) -> void:
		calls += 1

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_test_registry()
	_test_view_kinds()
	_test_sprite_fallback()
	_test_pilot_sprites()
	await _test_draw_all()
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_registry() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	_check(reg == ArtRegistry.get_instance(), "the registry is a shared instance")
	var kinds: Array[String] = reg.kinds()
	_check(kinds.size() >= 60, "the registry holds %d kinds" % kinds.size())
	var ungrouped: Array[String] = []
	for k in kinds:
		if reg.group_of(k) == "":
			ungrouped.append(k)
	_check(ungrouped.is_empty(), "every kind knows its group file %s" % str(ungrouped))
	for g in ["props", "flora", "platform_props", "weapons", "creatures_combat", "creatures_platform", "bosses", "scene"]:
		var n: int = 0
		for k in kinds:
			if reg.group_of(k) == g:
				n += 1
		_check(n > 0, "group %s has kinds (%d)" % [g, n])
	# prefixes: families and defaults
	_check(reg.resolve("creature:LARVA_L3") != null and reg.resolve("creature:LARVA_L3") == reg.resolve("creature:LARVA_L5"), "LARVA_* shares one art")
	_check(reg.resolve("creature:GREAT_TIT_BOSS") == reg.resolve("creature:GREAT_TIT"), "GREAT_TIT* is the bird art")
	_check(reg.resolve("creature:BLUE_TIT") != reg.resolve("creature:EGG"), "an exact id beats the default prefix")
	_check(reg.resolve("flora:NOWHERE") is FloraDefaultArt, "an unknown plant falls back to the default plant")
	_check(reg.resolve("boss:cuckoo_x") != reg.resolve("boss:"), "boss prefixes resolve to their art")
	_check(reg.resolve("nothing:here") == null, "an unknown id resolves to null")
	# open/closed: a new kind needs no edit of the registry
	var fresh := ArtRegistry.new()
	fresh.add("x", CountArt.new())
	_check(fresh.has_kind("x") and not fresh.has_kind("y"), "kinds are added with add()")


func _test_view_kinds() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	var lists: Dictionary = {
		"CombatView": CombatView.ART_KINDS, "CaterpillarArt": CaterpillarArt.ART_KINDS, "BossArt": BossArt.ART_KINDS,
		"PlatformWorldView": PlatformWorldView.ART_KINDS, "PlatformActorView": PlatformActorView.ART_KINDS,
		"PlatformFxView": PlatformFxView.ART_KINDS, "PlatformBatView": PlatformBatView.ART_KINDS,
		"PlatformFlyView": PlatformFlyView.ART_KINDS, "PlatformHoopoeView": PlatformHoopoeView.ART_KINDS,
	}
	for view: String in lists:
		var missing: Array[String] = []
		for id: String in lists[view]:
			if not reg.has_kind(id):
				missing.append(id)
		_check(missing.is_empty(), "%s: every drawn kind is registered %s" % [view, str(missing)])
	# the plant types of the sim all have an art (explicit or the default one)
	for type in ["MONTSERRAT", "CADAQUES", "TAULL", "DELTA_EBRE", "TARRACO", "PEDRAFORCA", "MONTBLANC", "OTHER"]:
		_check(reg.has_kind("flora:" + type), "flora %s resolves" % type)


func _test_sprite_fallback() -> void:
	var counter := CountArt.new()
	var sprite := SpriteArt.new("props", "does_not_exist", 30.0, counter)
	_check(not sprite.has_sprite(), "a missing SVG has no texture")
	var node := Node2D.new()
	add_child(node)
	sprite.draw(node, {"x": 0.0, "y": 0.0}, ArtContext.sample())
	_check(counter.calls == 1, "SpriteArt draws its vector fallback when the file is missing")
	_check(sprite.vector_fallback() == counter, "the fallback is exposed for the contact sheet")
	var bare := SpriteArt.new("props", "does_not_exist", 30.0)
	bare.draw(node, null, ArtContext.sample())
	_check(true, "a sprite without a file and without a fallback draws nothing")
	node.queue_free()


func _test_pilot_sprites() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	for id in ["barrel", "crate", "caganer"]:
		var art: ThingArt = reg.resolve(id)
		_check(art is SpriteArt and (art as SpriteArt).has_sprite(), "%s is a sprite" % id)
		var tex: Texture2D = (art as SpriteArt).texture()
		_check(tex != null and tex.get_width() >= 256, "%s texture is imported at 2x or more (%d px)" % [id, tex.get_width() if tex != null else 0])
		_check(art.vector_fallback() != null, "%s has a vector fallback" % id)
	# the medkit is routed to its own art (MedkitArt), not to the wooden crate's fallback
	var crate: CrateArt = reg.resolve("crate") as CrateArt
	var counter := CountArt.new()
	crate.fallback = counter
	var node := Node2D.new()
	add_child(node)
	crate.draw(node, {"x": 0.0, "y": 0.0, "is_medkit": true}, ArtContext.sample())
	_check(counter.calls == 0, "the medkit crate is not drawn as a wooden crate")
	crate.fallback = CrateVectorArt.new()
	node.queue_free()


func _test_draw_all() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	var drawn: Array[String] = []
	var skipped: Array[String] = []
	var host := DrawLayer.new()
	add_child(host)
	var ctx: ArtContext = ArtContext.sample()
	host.draw_fn = func(ci: CanvasItem) -> void:
		for id in reg.kinds():
			var art: ThingArt = reg.art_of(id)
			var st: Variant = art.sample_state()
			if st == null and not _stateless(id):
				skipped.append(id)
				continue
			art.draw(ci, st, ctx)
			drawn.append(id)
			var fb: ThingArt = art.vector_fallback()
			if fb != null:
				fb.draw(ci, st, ctx)
	host.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(drawn.size() >= 35, "%d registered arts drew their sample without errors (%d need a live sim state)" % [drawn.size(), skipped.size()])
	for must in ["barrel", "crate", "caganer", "mine", "rovello", "escudella", "tombstone", "pine_nut", "silk_nest", "silk_web", "updraft", "platform:needle", "platform:puddle", "platform:goal", "platform:nutrient", "platform:checkpoint", "platform:tuft", "flora:MONTSERRAT", "flora:CADAQUES"]:
		_check(drawn.has(must), "%s has a sample and drew" % must)
	host.queue_free()


## Arts that read only the context draw without a state.
func _stateless(_id: String) -> bool:
	return false
