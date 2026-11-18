## Every sound name the sim (or the input controller) can emit must be a valid Sound.play() name.
##   godot --headless --path . res://tests/TestSfxNames.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var re := RegEx.new()
	re.compile("(?:\\bplay|sound_requested\\.emit)\\(\"([a-z_0-9]+)\"")
	var names: Dictionary = {}
	for dir in ["res://combat/sim/", "res://combat/view/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text: String = FileAccess.get_file_as_string(dir + f)
			for m in re.search_all(text):
				names[m.get_string(1)] = f
	_check_param_names()
	_check(names.size() > 20, "found %d distinct sfx names in the sim and input" % names.size())
	for n in names:
		_check(Sound.has_sound(n), "Sound knows '%s' (used in %s)" % [n, names[n]])
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


## Every param key the sim passes to play() must be one Sound reads (guards the pct/power, fatal/dead, mood/kind class of bugs).
func _check_param_names() -> void:
	var read_re := RegEx.new()
	read_re.compile("params\\.get\\(\"([a-z_]+)\"")
	var known: Dictionary = {}
	for m in read_re.search_all(FileAccess.get_file_as_string("res://core/sound.gd")):
		known[m.get_string(1)] = true
	var emit_re := RegEx.new()
	emit_re.compile("\\bplay\\(\"([a-z_0-9]+)\", \\{([^}]*)\\}")
	var key_re := RegEx.new()
	key_re.compile("\"([a-z_]+)\":")
	var checked: int = 0
	for dir in ["res://combat/sim/", "res://combat/view/"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			for m in emit_re.search_all(FileAccess.get_file_as_string(dir + f)):
				for k in key_re.search_all(m.get_string(2)):
					checked += 1
					_check(known.has(k.get_string(1)), "Sound reads param '%s' of '%s' (%s)" % [k.get_string(1), m.get_string(1), f])
	_check(checked >= 5, "found %d sfx params in the sim" % checked)
