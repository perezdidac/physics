## Smoke test: the autoloads exist and the boot screen loads.
##   godot --headless --path . res://tests/TestBoot.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_check(get_node_or_null("/root/GameState") != null, "GameState autoload exists")
	_check(get_node_or_null("/root/ScreenRouter") != null, "ScreenRouter autoload exists")
	_check(load("res://ui/menus/Boot.tscn") is PackedScene, "boot screen loads")
	_check(ArtCatalog.background("montserrat") != null, "background texture loads through ArtCatalog")
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()
