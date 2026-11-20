## Boss arts: every cutout rig has all its part SVGs, and each boss draws in its poses without errors.
##   godot --headless --path . res://tests/TestArtBosses.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var reg: ArtRegistry = ArtRegistry.get_instance()
	var host := DrawLayer.new()
	add_child(host)
	var ctx: ArtContext = ArtContext.sample(1.0)
	for id in ["boss:great_tit", "boss:cuckoo", "boss:tachinid_fly", "boss:foreman"]:
		var art: ThingArt = reg.resolve(id)
		_check(art is BossRigArt and (art as BossRigArt).rig.is_complete(), "%s rig is complete" % id)
	var wasp := WaspBossArt.new()
	_check(wasp.available(), "wasp rig is complete")
	host.draw_fn = func(ci: CanvasItem) -> void:
		for id in ["boss:great_tit", "boss:cuckoo", "boss:tachinid_fly", "boss:foreman"]:
			var art: ThingArt = reg.resolve(id)
			for st in ["", "INTENT", "ACT", "SATED", "WINDED"]:
				ctx.combat.boss_state = st
				var f: Dictionary = (art.sample_state() as Dictionary).duplicate()
				for ai in ["idle", "approach", "warn", "dive", "fall", "perch"]:
					f["ai_state"] = ai
					art.draw(ci, f, ctx)
		for st in ["PATROL", "WARN", "DIVE", "RECOVER"]:
			wasp.draw(ci, Vector2(50.0, 50.0), 0.2, -1.0, 1.3, st, 1.0)
	host.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()
