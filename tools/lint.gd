## Loads every project script and reports failures. Run with: bash tools/lint.sh (it turns warnings into errors).
extends Node

const DIRS: Array[String] = ["res://core", "res://combat", "res://ui", "res://data", "res://tests", "res://tools"]


func _ready() -> void:
	var failures: int = 0
	var count: int = 0
	for dir in DIRS:
		for path in _scripts(dir):
			count += 1
			if ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) == null:
				print("FAIL loading ", path)
				failures += 1
	print("LINT: %d scripts, %d failures" % [count, failures])
	get_tree().quit()


func _scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return found
	for sub in d.get_directories():
		if not sub.begins_with(".") and not sub.begins_with("_"):
			found.append_array(_scripts(dir + "/" + sub))
	for f in d.get_files():
		if f.ends_with(".gd") and f != "lint.gd":
			found.append(dir + "/" + f)
	return found
