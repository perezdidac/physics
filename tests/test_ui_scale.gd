## UI scale: TouchMetrics.ui_scale is 1 on desktop, grows on a phone-sized screen, never leaves less than the minimum logical
## layout, and the boot menu and the story map fit the viewport when scaled.
##   godot --headless --path . res://tests/TestUiScale.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	var old_option: int = Options.button_size
	Options.button_size = 1
	var vp := Vector2(1280, 720)
	TouchMetrics.force = 0
	TouchMetrics.force_dpi = 96.0
	_check(is_equal_approx(TouchMetrics.ui_scale(vp), 1.0), "desktop: scale is 1")
	Options.button_size = 0
	_check(is_equal_approx(TouchMetrics.ui_scale(vp), 1.0), "desktop, small buttons: never below 1")
	Options.button_size = 2
	_check(TouchMetrics.ui_scale(vp) > 1.2, "desktop, large buttons: bigger")
	Options.button_size = 1
	TouchMetrics.force = 1
	TouchMetrics.force_dpi = 486.0
	var s: float = TouchMetrics.ui_scale(vp)
	_check(s > 1.25 and s <= TouchMetrics.MAX_UI_SCALE + 0.001, "phone dpi: scale %.2f is the medium scale (1.25 to %.1f)" % [s, TouchMetrics.MAX_UI_SCALE])
	TouchMetrics.force_dpi = 440.0
	var s440: float = TouchMetrics.ui_scale(Vector2(1600, 720))
	_check(s440 >= 1.3 and s440 <= 1.4 + 0.001, "2000x900 window at 440 dpi: scale %.2f is 1.3-1.4" % s440)
	TouchMetrics.force_dpi = 486.0
	var logical: Vector2 = TouchMetrics.logical_size(vp)
	_check(logical.x >= TouchMetrics.MIN_LOGICAL.x - 0.5 and logical.y >= TouchMetrics.MIN_LOGICAL.y - 0.5, "phone: logical size %s keeps the minimum" % logical)
	_check(TouchMetrics.tap_min(vp) >= 40.0, "tap height at least 40 units")
	var small := Vector2(844, 390)
	_check(TouchMetrics.logical_size(small).y >= TouchMetrics.MIN_LOGICAL.y - 0.5, "844x390 keeps the minimum logical height")
	TouchMetrics.force_dpi = 486.0
	# Phone-like viewports (1600x720 is a 2000x900 window; 844x390 the small phone): everything stays inside.
	for case: Array in [[Vector2i(1600, 720), 486.0], [Vector2i(844, 390), 142.0], [Vector2i(1280, 720), 96.0]]:
		TouchMetrics.force_dpi = case[1]
		var holder := SubViewport.new()
		holder.size = case[0]
		add_child(holder)
		await _test_boot_fits(holder)
		await _test_map_fits(holder)
		await _test_hud_fits(holder)
		holder.queue_free()
	TouchMetrics.force = -1
	TouchMetrics.force_dpi = 0.0
	Options.button_size = old_option
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


## True when `ctrl`, as drawn (scale included), lies inside the viewport.
func _inside(ctrl: Control, vp: Vector2) -> bool:
	var r: Rect2 = ctrl.get_global_transform() * Rect2(Vector2.ZERO, ctrl.size)
	return r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0


func _test_boot_fits(host: SubViewport) -> void:
	var vp := Vector2(host.size)
	var boot: Control = (load("res://ui/menus/Boot.tscn") as PackedScene).instantiate()
	host.add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame
	var all_in: bool = true
	for item in boot.items:
		all_in = all_in and _inside(item, vp)
	_check(all_in, "boot %s: the four entries fit" % vp)
	boot.queue_free()


func _test_map_fits(host: SubViewport) -> void:
	var vp := Vector2(host.size)
	var map: Control = (load("res://ui/story/StoryMap.tscn") as PackedScene).instantiate()
	map.go_callable = func(_n: String) -> void: pass
	host.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_inside(map.back_button, vp), "story map %s: Back button inside the screen" % vp)
	var in_row: bool = map.stage_chips.size() == 7
	var all_in: bool = true
	for chip: ChamferButton in map.stage_chips:
		in_row = in_row and is_equal_approx(chip.global_position.y, map.stage_chips[0].global_position.y)
		all_in = all_in and _inside(chip, vp)
	_check(in_row and all_in, "story map %s: the 7 stage tabs are in one row inside the screen" % vp)
	var last: ChamferButton = map.level_nodes[map.level_nodes.size() - 1]
	_check(_inside(last, vp), "story map %s: the last level card is inside the screen" % vp)
	map.queue_free()


func _test_hud_fits(host: SubViewport) -> void:
	var vp := Vector2(host.size)
	var top: TopHud = (load("res://combat/hud/TopHud.tscn") as PackedScene).instantiate()
	host.add_child(top)
	await get_tree().process_frame
	await get_tree().process_frame
	var all_in: bool = _inside(top.exit_button, vp) and _inside(top.wind_track, vp) and _inside(top.timer_label, vp)
	_check(all_in, "top hud %s: exit button, wind bar and timer inside the screen" % vp)
	top.queue_free()
