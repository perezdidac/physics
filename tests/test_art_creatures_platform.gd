## Platformer creature sprites: every rig is complete (all part SVGs imported), each creature draws in its animation states both as
## sprite rig and as the vector fallback, and a missing part makes it fall back to the vector art.
##   godot --headless --path . res://tests/TestArtCreaturesPlatform.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_test_rigs_complete()
	await _test_draws()
	_test_fallback()
	PlatformPupaArt.release()
	PlatformMothArt.release()
	PlatformBatArt.release()
	PlatformBirdArt.release()
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_rigs_complete() -> void:
	_check(PlatformPupaArt._get_rig().is_complete(), "pupa rig is complete")
	_check(PlatformMothArt._get_rig().is_complete(), "moth rig is complete")
	_check(PlatformBatArt._get_rig().is_complete(), "bat rig is complete")
	_check(PlatformBirdArt._get_nj_rig().is_complete(), "nightjar rig is complete")
	_check(PlatformBirdArt._get_hp_rig().is_complete(), "hoopoe body rig is complete")
	_check(PlatformBirdArt._get_hp_legs().is_complete(), "hoopoe legs rig is complete")
	var tex: Texture2D = PlatformBatArt._get_rig().part_texture("wing_near")
	_check(tex != null and tex.get_width() >= 384, "bat wing imported at 3x (%d px)" % (tex.get_width() if tex != null else 0))


func _cases() -> Array:
	var at: Dictionary = {"base": Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, -12.0))}
	var out: Array = []
	for o in [{}, {"dig": Vector2(1, 0), "wiggle": 1.0}, {"hurt": 1.0}, {"blink": 1.0, "dig": Vector2(0, 1), "wiggle": 1.0}]:
		out.append(["platform:pupa", {"r": 11.0, "o": _merge(at, o)}])
	for o in [{"flap": 0.9}, {"flap": -0.9, "glow": 1.0}, {"glide": true}, {"stun": 1.0}, {"hurt": 1.0, "facing": -1.0}]:
		out.append(["platform:moth", {"r": 13.0, "o": _merge(at, o)}])
	for o in [{"flap": 0.9}, {"flap": -0.9, "alert": 1.0, "chase": true, "vy": 200.0}, {}]:
		out.append(["platform:nightjar", {"r": 16.0, "o": _merge(at, o)}])
	for st in ["PATROL", "PULSE", "MARK", "SWOOP"]:
		out.append(["platform:bat", _merge(at, {"state": st, "open": 1.0})])
	for o in [{}, {"crest": 1.0, "wing": 1.0, "lean": 0.4, "alarm": 1.0, "walk": 2.0}, {"hide_beak": true, "step": 0.0}]:
		out.append(["platform:hoopoe", _merge({"base": Transform2D.IDENTITY}, o)])
	return out


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var m: Dictionary = a.duplicate()
	m.merge(b, true)
	return m


func _test_draws() -> void:
	var host := DrawLayer.new()
	add_child(host)
	var ctx: ArtContext = ArtContext.sample(0.9)
	var counter: Array[int] = [0]
	host.draw_fn = func(ci: CanvasItem) -> void:
		for vec in [false, true]:
			PlatformPupaArt.use_sprites(not vec)
			PlatformMothArt.use_sprites(not vec)
			PlatformBatArt.use_sprites(not vec)
			PlatformBirdArt.use_sprites(not vec)
			for cs: Array in _cases():
				ArtRegistry.draw(cs[0], ci, cs[1], ctx)
				counter[0] += 1
		PlatformPupaArt.use_sprites(true)
		PlatformMothArt.use_sprites(true)
		PlatformBatArt.use_sprites(true)
		PlatformBirdArt.use_sprites(true)
	host.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var count: int = counter[0]
	_check(count == _cases().size() * 2, "%d creature states drew as sprite and as vector without errors" % count)
	host.queue_free()


func _test_fallback() -> void:
	PlatformMothArt.use_sprites(false)
	_check(not PlatformMothArt._get_rig().is_complete(), "a missing part keeps the moth on its vector art")
	PlatformMothArt.use_sprites(true)
	_check(PlatformMothArt._get_rig().is_complete(), "sprites come back")
