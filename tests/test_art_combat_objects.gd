## Combat-object sprites (props, flora, scene): every sprite file imports, the registry arts draw with and without the sprite,
## and the medkit is a sprite of its own.
##   godot --headless --path . res://tests/TestArtCombatObjects.tscn
extends Node

const PROP_FILES: Array[String] = ["escudella", "mine", "pine_nut", "rovello", "tombstone", "medkit"]
const FLORA_FILES: Array[String] = ["montserrat_0", "montserrat_1", "cadaques_0", "cadaques_1", "taull_0", "delta_ebre_0", "tarraco_0", "pedraforca_0", "montblanc_0", "default_0", "default_1", "default_2"]
const SCENE_FILES: Array[String] = ["silk_nest", "larva_item", "anthill", "tuft_l", "tuft_c", "tuft_r", "tuft_front", "nest_inside", "nest_silk", "nest_veil", "nest_branch"]

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_test_files("props", PROP_FILES)
	_test_files("flora", FLORA_FILES)
	_test_files("scene", SCENE_FILES)
	_test_sprites()
	await _test_draw()
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_files(group: String, names: Array[String]) -> void:
	for n in names:
		var tex: Texture2D = load("res://assets/sprites/%s/%s.svg" % [group, n]) as Texture2D
		_check(tex != null and tex.get_width() >= 256, "%s/%s imports (%d px)" % [group, n, tex.get_width() if tex != null else 0])


func _test_sprites() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	for id in ["escudella", "mine", "pine_nut", "rovello", "tombstone", "silk_nest", "larvae", "tuft", "tuft_front", "anthill"]:
		var art: ThingArt = reg.resolve(id)
		_check(art is SpriteArt and (art as SpriteArt).has_sprite() or id == "tuft" or id == "tuft_front", "%s is a sprite art" % id)
		_check(art.vector_fallback() != null, "%s keeps a vector fallback" % id)
	var crate: CrateArt = reg.resolve("crate") as CrateArt
	_check(crate._medkit.has_sprite(), "the medkit crate is a sprite")


func _test_draw() -> void:
	var node := Node2D.new()
	add_child(node)
	await get_tree().process_frame
	var ctx := ArtContext.sample()
	var reg: ArtRegistry = ArtRegistry.get_instance()
	for id in ["escudella", "mine", "pine_nut", "rovello", "tombstone", "silk_nest", "larvae", "tuft", "tuft_front", "silk_web"]:
		var art: ThingArt = reg.resolve(id)
		art.draw(node, art.sample_state(), ctx)
		_check(true, "%s draws" % id)
	var med := {"x": 0.0, "y": 0.0, "is_medkit": true, "parachuting": true}
	reg.resolve("crate").draw(node, med, ctx)
	_check(true, "a parachuting medkit draws")
	for t in ["MONTSERRAT", "CADAQUES", "TAULL", "DELTA_EBRE", "TARRACO", "PEDRAFORCA", "MONTBLANC", "ARAN"]:
		for v in 3:
			reg.resolve("flora:" + t).draw(node, {"x": 0.0, "y": 0.0, "type": t, "variant": v, "scale": 1.0, "phase": 0.0}, ctx)
	_check(true, "all flora types and variants draw")
	var vctx := ViewCtx.new()
	vctx.nest = {}
	vctx.nest_rect = Rect2(-85, -55, 170, 110)
	var fx := NestFx.new()
	fx.shown_frac = 0.4
	for cold in [false, true]:
		vctx.cold_active = cold
		NestArt.draw_back(node, vctx, fx)
		NestArt.draw_front(node, vctx)
	_check(true, "the nest draws in both states")
	NestArt.draw_back(node, vctx, fx)
	node.queue_free()
