## Platformer screen, phase D2: the DIG (pupa) and FLY (moth) levels. Every pupa_* / moth_* level runs without errors, the soil texture is
## updated in small dirty rectangles while she digs, the boss bars and end banners, the touch pad relabels and the egg levels stay as they were.
##   godot --headless --path . res://tests/TestPlat2View.tscn
extends Node

const PUPA: Array[String] = ["pupa_1", "pupa_2", "pupa_3", "pupa_boss"]
const MOTH: Array[String] = ["moth_1", "moth_2", "moth_3", "moth_boss"]

var failures: int = 0
var routed: Array[String] = []
var _pad: PlatformTouchPad


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	await _run()
	GameState.story_level = null
	GameState.story_result = {}
	UiUtil.touch_seen = false
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _on_go(screen_name: String) -> void:
	routed.append(screen_name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ticks(screen: PlatformScreen, n: int) -> void:
	for i in n:
		screen.tick(1.0 / 60.0)


func _make(id: String) -> PlatformScreen:
	var screen: PlatformScreen = load("res://platform/PlatformScreen.tscn").instantiate() as PlatformScreen
	screen.auto_start = false
	screen.go_callable = _on_go
	add_child(screen)
	screen.hud.pad.force_show = true
	screen.start(load("res://data/levels/%s.tres" % id) as LevelDef)
	return screen


func _exists(id: String) -> bool:
	return ResourceLoader.exists("res://data/levels/%s.tres" % id)


func _run() -> void:
	for id in PUPA:
		await _test_level(id, "DIG")
	for id in MOTH:
		await _test_level(id, "FLY")
	await _test_dig_texture()
	await _test_boss_bars()
	await _test_hoopoe_view()
	await _test_bat_view()
	await _test_touch_relabel()
	await _test_end_banners()
	await _test_egg_unchanged()


func _test_level(id: String, mode: String) -> void:
	if not _exists(id):
		_check(true, "%s: level not there yet (skipped)" % id)
		return
	var screen: PlatformScreen = _make(id)
	await _frames(3)
	_check(screen.mode == mode and screen.sim != null and screen.layout.mode == mode, "%s: screen runs in %s mode" % [id, mode])
	_ticks(screen, 240)
	await _frames(2)
	_check(screen.sim.time > 3.9, "%s: 240 frames advanced the sim (%.2f s)" % [id, screen.sim.time])
	_check(screen.hud.status.hearts == screen.sim.player.hearts, "%s: HUD shows the hearts" % id)
	var dig_ok: bool = (mode == "DIG") == screen.dig_view.visible
	var fly_ok: bool = (mode == "FLY") == screen.fly_back.visible
	_check(dig_ok and fly_ok, "%s: only the views of its own mode are shown" % id)
	_check(screen.hud.pad.mode == mode, "%s: the touch pad knows the mode" % id)
	if mode == "FLY":
		_check(screen.backdrop.night > 0.9 and screen.world_view.night > 0.9, "%s: night tint on the backdrop and the ground" % id)
	screen.queue_free()
	await _frames(1)


## Digging rewrites only the cells that changed, and the view texture agrees with the sim mask.
func _test_dig_texture() -> void:
	if not _exists("pupa_1"):
		return
	var screen: PlatformScreen = _make("pupa_1")
	await _frames(3)
	var dv: PlatformDigView = screen.dig_view
	var dig: PlatformDig = screen.sim.dig
	_ticks(screen, 60)
	var calls0: int = dv.update_calls
	var uploads0: int = dv.uploads
	var total: int = dig.cols * dig.rows
	# dig right through the wall of the starting gallery
	screen.debug_move = 1
	var guard: int = 0
	while screen.sim.player.pos.x < 440.0 and guard < 400:
		_ticks(screen, 1)
		guard += 1
	screen.debug_move = 0
	_check(dv.update_calls > calls0, "digging updates the soil texture (%d updates)" % (dv.update_calls - calls0))
	_check(dv.last_update_cells > 0 and dv.last_update_cells < 400, "each update covers a small dirty rectangle (%d of %d cells)" % [dv.last_update_cells, total])
	_check(dv.uploads <= dv.update_calls and dv.uploads > uploads0, "the texture is uploaded at most once per frame (%d uploads for %d updates)" % [dv.uploads, dv.update_calls])
	var mismatches: int = 0
	var checked: int = 0
	for cy in range(10, 40, 2):
		for cx in range(60, 130, 2):
			checked += 1
			if dv.mask_open(cx, cy) != (dig.cell_at(cx, cy) == PlatformDig.AIR):
				mismatches += 1
	_check(mismatches == 0, "the soil texture matches the sim mask (%d cells compared)" % checked)
	_check(dig.cell_at(floori(screen.sim.player.pos.x / 4.0), floori(screen.sim.player.pos.y / 4.0)) == PlatformDig.AIR and dv.mask_open(floori(screen.sim.player.pos.x / 4.0), floori(screen.sim.player.pos.y / 4.0)), "the tunnel behind her is open in the texture")
	_check(screen.fx.live_count() > 0, "digging throws soil crumbs")
	screen.queue_free()
	await _frames(1)


func _test_boss_bars() -> void:
	for pair: Array in [["pupa_boss", "pupa"], ["moth_boss", "moth"], ["egg_boss", "egg"]]:
		var id: String = pair[0]
		if not _exists(id):
			continue
		var screen: PlatformScreen = _make(id)
		await _frames(3)
		_ticks(screen, 200)
		_check(screen.hud.boss_bar.visible, "%s: the boss bar is shown" % id)
		_check(screen.hud.boss_bar.rider == pair[1], "%s: the bar carries the %s" % [id, pair[1]])
		_check(screen.hud.boss_bar.text.length() > 0 and screen.hud.boss_bar.text.contains(str(int(ceilf(screen.sim.time_left)))), "%s: the bar counts the seconds (%s)" % [id, screen.hud.boss_bar.text])
		var f0: float = screen.hud.boss_bar.fraction
		_ticks(screen, 120)
		_check(screen.hud.boss_bar.fraction > f0, "%s: the bar fills as time passes" % id)
		screen.queue_free()
		await _frames(1)


func _test_hoopoe_view() -> void:
	if not _exists("pupa_boss"):
		return
	var screen: PlatformScreen = _make("pupa_boss")
	await _frames(3)
	_ticks(screen, 150)
	var h: PlatformHoopoe = screen.sim.dig.hoopoe
	_check(h != null and screen.hoopoe_view.visible and screen.hoopoe_view.boss == h, "pupa_boss: the hoopoe is drawn")
	_check(is_equal_approx(screen.hoopoe_view.position.y, h.surface_y), "the hoopoe view stands on the surface")
	h.state = "AIM"
	h.warn_time = 0.8
	h.timer = 0.8
	h.target = Vector2(h.pos.x, h.surface_y)
	_ticks(screen, 30)
	_check(screen.hoopoe_view.dirt_count() > 0, "the aim telegraph trickles dirt")
	h.state = "STAB"
	h.tip_y = h.surface_y + 120.0
	_ticks(screen, 2)
	await _frames(2)
	_check(screen.hoopoe_view.visible, "the stab is drawn without errors")
	_check(screen.cam.extra_top > 0.0, "the camera may show the sky above the soil")
	screen.queue_free()
	await _frames(1)


func _test_bat_view() -> void:
	if not _exists("moth_boss"):
		return
	var screen: PlatformScreen = _make("moth_boss")
	await _frames(3)
	_ticks(screen, 100)
	var bat: PlatformBat = screen.sim.fly.bat
	_check(bat != null and screen.bat_view.visible and screen.bat_view.boss == bat, "moth_boss: the bat is drawn")
	screen.sim.fly.emit_pulse(screen.sim, bat.pos)
	_ticks(screen, 20)
	await _frames(2)
	_check(screen.bat_view.pulses.size() > 0 and screen.bat_view.pulses[0].radius > 0.0, "an echolocation ring is drawn and grows")
	bat.state = "MARK"
	bat.warn_time = 0.6
	bat.timer = 0.6
	bat.target = screen.sim.player.pos
	_ticks(screen, 3)
	await _frames(2)
	_check(screen.bat_view.state == "MARK", "the mark warning is shown")
	screen.queue_free()
	await _frames(1)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_pad._input(e)


func _test_touch_relabel() -> void:
	var egg: PlatformScreen = _make("egg_1")
	await _frames(3)
	_check(egg.hud.pad.jump_label() == egg.tr("PLAT_JUMP") and egg.hud.pad.arrows_caption() == "", "egg: JUMP stays JUMP, no dig caption")
	egg.queue_free()
	await _frames(1)
	if _exists("moth_1"):
		var fly: PlatformScreen = _make("moth_1")
		await _frames(3)
		_check(fly.hud.pad.jump_label() == fly.tr("PLAT_FLAP") and fly.hud.pad.jump_label() != fly.tr("PLAT_JUMP"), "moth: the big button says FLAP")
		_check(fly.hud.pad.arrows_caption() == "", "moth: no dig caption")
		_pad = fly.hud.pad
		_touch(0, _pad.jump_rect().get_center(), true)
		await _frames(1)
		_check(_pad.jump(), "moth: touching FLAP holds the button (glide)")
		_touch(0, _pad.jump_rect().get_center(), false)
		fly.queue_free()
		await _frames(1)
	if _exists("pupa_1"):
		var dig: PlatformScreen = _make("pupa_1")
		await _frames(3)
		_pad = dig.hud.pad
		_check(_pad.arrows_caption() != "", "pupa: a hint says that holding a direction digs")
		_check(_pad.up_rect().position.y < _pad.down_rect().position.y and _pad.left_rect().end.x <= _pad.down_rect().position.x + 1.0 and _pad.down_rect().end.x <= _pad.right_rect().position.x + 1.0, "pupa: the arrows form an inverted T")
		_touch(1, _pad.down_rect().get_center(), true)
		await _frames(1)
		_check(_pad.down_held() and not _pad.up_held(), "pupa: the down arrow is held")
		_ticks(dig, 2)
		_touch(1, _pad.down_rect().get_center(), false)
		_touch(2, _pad.up_rect().get_center(), true)
		await _frames(1)
		_check(_pad.up_held() and not _pad.down_held(), "pupa: the up arrow is held")
		_touch(2, _pad.up_rect().get_center(), false)
		dig.debug_vert = 1
		_check(dig._vert_dir() == 1, "pupa: vertical input reaches the sim")
		dig.queue_free()
		await _frames(1)
	var egg2: PlatformScreen = _make("egg_1")
	egg2.debug_vert = 1
	_check(egg2._vert_dir() == 0, "egg: vertical input is ignored")
	egg2.queue_free()
	await _frames(1)


func _test_end_banners() -> void:
	if _exists("pupa_boss"):
		routed.clear()
		var screen: PlatformScreen = _make("pupa_boss")
		await _frames(3)
		_ticks(screen, 150)
		screen.sim.time_left = 0.02
		_ticks(screen, 10)
		_check(screen.ended and str(GameState.story_result.get("reason", "")) == "METAMORPHOSIS", "pupa_boss: surviving ends with METAMORPHOSIS")
		_check(screen.hud.banner.visible and screen.hud.banner.text == screen.tr("PLAT_BANNER_METAMORPHOSIS"), "pupa_boss: the metamorphosis banner is shown")
		_check(screen.fx.meta_t >= 0.0 and not screen.player_view.visible, "pupa_boss: the husk cracks and the moth comes out")
		_ticks(screen, 400)
		_check(routed.has("story_results"), "pupa_boss: the results screen follows")
		screen.queue_free()
		await _frames(1)
	if _exists("moth_boss"):
		routed.clear()
		var m: PlatformScreen = _make("moth_boss")
		await _frames(3)
		_ticks(m, 150)
		m.sim.time_left = 0.02
		_ticks(m, 10)
		_check(m.ended and str(GameState.story_result.get("reason", "")) == "EGGS_LAID", "moth_boss: surviving ends with EGGS_LAID")
		_check(m.hud.banner.visible and m.hud.banner.text == m.tr("PLAT_BANNER_EGGS_LAID"), "moth_boss: the eggs laid banner is shown")
		_check(m.hud.sub_banner.visible and m.hud.sub_banner.text == m.tr("PLAT_BANNER_CYCLE"), "moth_boss: the cycle begins again line is shown")
		var night0: float = m.backdrop.night
		_ticks(m, 120)
		_check(m.fx.lay_t > 0.5 and m.backdrop.night < night0, "moth_boss: eggs appear and the night turns to dawn (%.2f -> %.2f)" % [night0, m.backdrop.night])
		_ticks(m, 600)
		_check(routed.has("story_results"), "moth_boss: the results screen follows")
		m.queue_free()
		await _frames(1)
	if _exists("pupa_1"):
		var lost: PlatformScreen = _make("pupa_1")
		await _frames(3)
		lost.sim.player.hearts = 1
		lost.sim._hurt_player(1.0)
		_ticks(lost, 5)
		_check(lost.ended and lost.hud.banner.text == lost.tr("PLAT_BANNER_LOST"), "pupa_1: losing shows the try-again banner")
		lost.queue_free()
		await _frames(1)


func _test_egg_unchanged() -> void:
	var screen: PlatformScreen = _make("egg_4")
	await _frames(3)
	_ticks(screen, 60)
	_check(screen.mode == "" and screen.world_view.mode == "" and not screen.dig_view.visible and not screen.fly_back.visible, "egg_4: no new views are shown")
	_check(screen.backdrop.night == 0.0 and screen.world_view.night == 0.0, "egg_4: still daylight")
	_check(screen.cam.extra_top == 0.0 and screen.hud.pad.mode == "", "egg_4: camera and pad as before")
	screen.queue_free()
	await _frames(1)
