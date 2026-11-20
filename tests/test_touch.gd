## Touch controls of the battle on the real CombatScreen: floating joystick, aim drag, FIRE button, two-finger gestures,
## desktop without touch widgets, layouts at phone sizes and the story Pass button.
##   godot --headless --path . res://tests/TestTouch.tscn
extends Node

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	await _run()
	TouchMetrics.force = -1
	GameState.story_level = null
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _make_screen(story: bool) -> CombatScreen:
	GameState.story_level = load("res://data/levels/egg_1.tres") as LevelDef if story else null
	var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	screen.auto_start = false
	add_child(screen)
	var sim := CombatSim.new()
	var cfg: MatchConfig = GameState.make_match_config()
	cfg.game_mode = "2P_LOCAL"
	sim.setup(cfg)
	screen.start(sim)
	return screen


func _bottom(screen: CombatScreen) -> BottomHud:
	for h in screen.huds:
		if h is BottomHud:
			return h as BottomHud
	return null


func _touch(input: CombatInput, index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	input._unhandled_input(e)


func _drag(input: CombatInput, index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	input._unhandled_input(e)


func _run() -> void:
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(1280, 720)
	await _frames(2)
	TouchMetrics.force = 0
	var screen: CombatScreen = _make_screen(false)
	await _frames(3)
	var bottom: BottomHud = _bottom(screen)
	_check(not bottom.touch_pad.visible and not bottom.fire_button.is_visible_in_tree(), "desktop (no touch): the touch pad is hidden")
	_check(not bottom.touch_overlay.aim_visible, "desktop: no aim overlay")
	_check(bottom.toggle_button.is_visible_in_tree(), "desktop keeps the weapon pill")
	var sim: CombatSim = screen.sim as CombatSim
	var input: CombatInput = screen.input

	TouchMetrics.force = 1
	await _frames(3)
	var pad: TouchPad = bottom.touch_pad
	_check(pad.visible and pad.left_button.is_visible_in_tree() and pad.right_button.is_visible_in_tree(), "touch UI starts in MOVE: the walk arrows are shown")
	_check(pad.jump_button.is_visible_in_tree() and pad.flip_button.is_visible_in_tree() and pad.aim_button.is_visible_in_tree(), "MOVE shows Salt, Mortal and Apunta")
	_check(not bottom.fire_button.is_visible_in_tree() and not pad.move_button.is_visible_in_tree() and not bottom.touch_aim, "MOVE hides FIRE and Moure")
	_check(bottom.fire_button.size.x >= 110.0 and not bottom.toggle_button.visible, "FIRE is at least 110 px; the weapon pill is replaced by the picker")
	_check(bottom.touch_overlay.phase_text == tr("TOUCH_PHASE_MOVE"), "MOVE shows its hint")
	var vs: Vector2 = get_viewport().get_visible_rect().size

	# walk arrows: hold to walk
	pad.right_button.pressed_down.emit()
	input.tick(0.016)
	_check(sim._move_dir == 1, "holding the right arrow walks right")
	pad.right_button.released.emit()
	pad.left_button.pressed_down.emit()
	input.tick(0.016)
	_check(sim._move_dir == -1, "holding the left arrow walks left")
	pad.left_button.released.emit()
	input.tick(0.016)
	_check(sim._move_dir == 0, "releasing the arrow stops")

	# a drag in MOVE pans the camera and does not aim
	var pitch_move: float = sim.aim_pitch
	var pan0 := Vector2(screen.cam.pan_x, screen.cam.pan_y)
	var start := Vector2(vs.x * 0.5, vs.y * 0.6)
	_touch(input, 0, start, true)
	_drag(input, 0, start + Vector2(60, 40), Vector2(60, 40))
	_drag(input, 0, start + Vector2(120, 80), Vector2(60, 40))
	_touch(input, 0, start + Vector2(120, 80), false)
	_check(Vector2(screen.cam.pan_x, screen.cam.pan_y) != pan0 and is_equal_approx(sim.aim_pitch, pitch_move), "a drag in MOVE pans the camera and does not aim")
	_check(not bottom.touch_overlay.aim_visible and sim._move_dir == 0, "no aim line and no walking from a map drag")

	# two fingers: pan and pinch only
	var zoom0: float = screen.cam.user_zoom
	_touch(input, 0, start, true)
	_touch(input, 1, start + Vector2(100, 0), true)
	_drag(input, 0, start + Vector2(-50, 0), Vector2(-50, 0))
	_drag(input, 1, start + Vector2(200, 0), Vector2(100, 0))
	input.tick(0.1)
	_check(sim._move_dir == 0 and is_equal_approx(sim.aim_pitch, pitch_move), "two fingers neither walk nor aim")
	_check(screen.cam.user_zoom > zoom0, "pinching out zooms in")
	_touch(input, 1, start + Vector2(200, 0), false)
	_drag(input, 0, start + Vector2(80, 0), Vector2(130, 0))
	_touch(input, 0, start, false)
	_check(sim._move_dir == 0 and is_equal_approx(sim.aim_pitch, pitch_move), "the remaining finger of a two-finger gesture does not aim")

	# weapon picker: choosing a weapon enters AIM
	pad.weapon_button.tapped.emit()
	await _frames(2)
	_check(bottom.is_drawer_open() and not pad.left_button.visible and not bottom.fire_button.visible, "the picker opens the drawer and hides the controls")
	bottom.slots[0].pressed.emit(0)
	await _frames(2)
	_check(not bottom.is_drawer_open() and bottom.touch_aim and sim.selected_weapon_idx == 0, "picking a weapon closes the drawer and enters AIM")
	_check(bottom.fire_button.is_visible_in_tree() and pad.move_button.is_visible_in_tree(), "AIM shows FIRE and Moure")
	_check(not pad.left_button.visible and not pad.right_button.visible and not pad.jump_button.visible and not pad.aim_button.visible, "AIM hides the arrows, Salt and Apunta")
	_check(bottom.touch_overlay.phase_text == tr("TOUCH_PHASE_AIM_HOLD"), "AIM shows its hint")

	# a drag anywhere in AIM rotates the aim (relative)
	sim.active_fighter.facing = 1
	sim.aim_pitch = -0.3
	var pitch_a: float = sim.aim_pitch
	var s2 := Vector2(vs.x * 0.6, vs.y * 0.5)
	var pan1 := Vector2(screen.cam.pan_x, screen.cam.pan_y)
	_touch(input, 0, s2, true)
	_drag(input, 0, s2 + Vector2(0, -40), Vector2(0, -40))
	_check(sim.aim_pitch < pitch_a and bottom.touch_overlay.aim_visible, "dragging up aims higher (facing right) and shows the line")
	var pitch_b: float = sim.aim_pitch
	_drag(input, 0, s2 + Vector2(0, 40), Vector2(0, 80))
	_check(sim.aim_pitch > pitch_b, "dragging down aims lower")
	_check(Vector2(screen.cam.pan_x, screen.cam.pan_y) == pan1, "an aim drag does not pan the camera")
	for i in 12:
		_drag(input, 0, s2, Vector2(0, -40))
	_check(sim.active_fighter.facing == 1 and sim.aim_pitch <= -1.4, "dragging up far enough points straight up")
	_touch(input, 0, s2, false)
	_check(not sim.is_charging and not bottom.touch_overlay.aim_visible, "releasing the aim drag does not fire")
	# facing left: dragging up aims higher too, and a sideways drag over the top flips the facing
	sim.active_fighter.facing = -1
	sim.aim_pitch = -0.3
	_touch(input, 0, s2, true)
	_drag(input, 0, s2, Vector2(0, -40))
	_check(sim.aim_pitch < -0.3, "dragging up aims higher when facing left")
	_touch(input, 0, s2, false)
	sim.active_fighter.facing = 1
	sim.aim_pitch = -1.2
	_touch(input, 0, s2, true)
	for i in 8:
		_drag(input, 0, s2, Vector2(-40, 0))
	_touch(input, 0, s2, false)
	_check(sim.active_fighter.facing == -1, "dragging over the top flips the facing")
	_check(is_equal_approx(sim.aim_angle, PI - sim.aim_pitch), "the aim angle follows the new facing")

	# FIRE button: hold to charge, release to fire
	var shots: int = sim.projectiles.size()
	bottom.fire_button.pressed_down.emit()
	_check(sim.is_charging, "holding FIRE charges")
	await _frames(20)
	_check(bottom.fire_button.fill > 0.0, "FIRE shows the charge ring")
	bottom.fire_button.released.emit()
	_check(not sim.is_charging and sim.projectiles.size() > shots, "releasing FIRE fires")
	await _frames(2)
	_check(not bottom.touch_aim and pad.left_button.is_visible_in_tree() and not bottom.fire_button.visible, "after firing the turn goes back to the MOVE controls")

	# Apunta enters AIM, Moure goes back
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	await _frames(2)
	pad.aim_button.tapped.emit()
	await _frames(2)
	_check(bottom.touch_aim and bottom.fire_button.is_visible_in_tree() and input.touch_aim, "tapping Apunta enters AIM")
	pad.move_button.tapped.emit()
	await _frames(2)
	_check(not bottom.touch_aim and pad.left_button.is_visible_in_tree() and not input.touch_aim, "tapping Moure returns to MOVE")
	pad.jump_button.pressed_down.emit()
	pad.jump_button.released.emit()
	pad.flip_button.pressed_down.emit()
	_check(not bottom.is_drawer_open(), "the drawer stays closed")
	screen.queue_free()
	await _frames(2)

	_test_layouts()
	_test_button_size_option()
	_test_safe_insets()
	await _test_story()


func _phase_groups(pad: TouchPad, aim: bool) -> Array[TouchButton]:
	if aim:
		return [pad.fire_button, pad.weapon_button, pad.move_button, pad.center_button]
	return [pad.left_button, pad.right_button, pad.jump_button, pad.flip_button, pad.weapon_button, pad.aim_button, pad.repair_button, pad.center_button]


## True when every button of the phase is inside the viewport, below the top HUD and disjoint from the others.
func _phase_fits(pad: TouchPad, aim: bool, vp: Vector2) -> bool:
	pad.set_aim(aim)
	pad.layout(vp)
	var rects: Array[Rect2] = []
	for b in _phase_groups(pad, aim):
		rects.append(Rect2(b.position, b.size))
	var ok: bool = true
	for i in rects.size():
		ok = ok and Rect2(Vector2.ZERO, vp).encloses(rects[i]) and rects[i].position.y >= vp.y * 0.3
		for j in range(i + 1, rects.size()):
			ok = ok and not rects[i].intersects(rects[j])
	return ok


func _test_layouts() -> void:
	var pad := TouchPad.new()
	add_child(pad)
	for vp: Vector2 in [Vector2(844, 390), Vector2(1280, 720), Vector2(1603, 720), Vector2(1024, 576), Vector2(2000, 900)]:
		for aim in [false, true]:
			var ok: bool = _phase_fits(pad, aim, vp)
			_check(ok and pad.fire_button.size.x >= 110.0, "layout %dx%d %s: inside, no overlap, top HUD free, FIRE >= 110" % [vp.x, vp.y, "AIM" if aim else "MOVE"])
		pad.set_aim(false)
		pad.layout(vp)
		_check(pad.left_button.size.x >= pad.jump_button.size.x, "layout %dx%d: the walk arrows are the big buttons" % [vp.x, vp.y])
		# the bar of Cuc/Passa (centred) keeps a free strip between the clusters
		var left_edge: float = pad.right_button.position.x + pad.right_button.size.x
		var right_edge: float = minf(pad.aim_button.position.x, pad.repair_button.position.x)
		_check(right_edge - left_edge >= 150.0, "layout %dx%d: %d px free for the bottom bar" % [vp.x, vp.y, int(right_edge - left_edge)])
	pad.queue_free()


## A camera hole on the left edge: the left controls of the battle and platformer pads start inside the safe inset.
func _test_safe_insets() -> void:
	var saved_force: int = TouchMetrics.force
	TouchMetrics.force = 1
	TouchMetrics.force_dpi = 440.0
	TouchMetrics.force_cutout = Vector4(120.0, 0.0, 0.0, 0.0)
	var vp := Vector2(1280, 720)
	var ins: Vector4 = TouchMetrics.safe_insets(vp)
	_check(ins.x >= 120.0 / TouchMetrics.pixel_ratio(vp) - 0.01 and ins.x > 0.0, "cutout: the left safe inset is %d" % int(ins.x))
	var pad := TouchPad.new()
	add_child(pad)
	for aim in [false, true]:
		pad.set_aim(aim)
		pad.layout(vp)
		var min_x: float = INF
		var max_right: float = 0.0
		for b: TouchButton in _phase_groups(pad, aim):
			min_x = minf(min_x, b.position.x)
			max_right = maxf(max_right, b.position.x + b.size.x)
		_check(min_x >= ins.x - 0.01, "cutout %s: the left touch buttons start at x >= inset (%d >= %d)" % ["AIM" if aim else "MOVE", int(min_x), int(ins.x)])
		_check(max_right <= vp.x - ins.z + 0.01, "cutout %s: the right touch buttons end inside the right inset" % ("AIM" if aim else "MOVE"))
	var plat := PlatformTouchPad.new()
	plat.size = vp
	add_child(plat)
	_check(plat.left_rect().position.x >= ins.x - 0.01, "cutout: the platformer left arrow starts at x >= inset")
	TouchMetrics.force_cutout = Vector4.ZERO
	TouchMetrics.force_dpi = 0.0
	TouchMetrics.force = 0
	_check(TouchMetrics.safe_insets(vp) == Vector4.ZERO, "touch UI off: no safe insets")
	_check(plat.left_rect().position.x == PlatformTouchPad.MARGIN, "touch UI off: the platformer pad keeps its margin")
	TouchMetrics.force = saved_force
	pad.queue_free()
	plat.queue_free()


## The "button size" option: scale values, bigger option = bigger buttons, no overlap in any size, platformer pad follows it.
func _test_button_size_option() -> void:
	var saved: int = Options.button_size
	Options.set_button_size(0)
	_check(is_equal_approx(Options.button_scale(), 0.85), "small = 0.85")
	Options.set_button_size(2)
	_check(is_equal_approx(Options.button_scale(), 1.25), "large = 1.25")
	Options.set_button_size(7)
	_check(Options.button_size == 2, "button size is clamped")
	Options.set_button_size(2)
	Options.set_button_size(Options.cycle_button_size())
	_check(Options.button_size == 0, "cycle wraps large to small")
	var vp := Vector2(1603, 720)
	var pad := TouchPad.new()
	add_child(pad)
	var plat := PlatformTouchPad.new()
	add_child(plat)
	var last_fire: float = 0.0
	var last_plat: float = 0.0
	for idx in 3:
		Options.set_button_size(idx)
		_check(_phase_fits(pad, false, vp) and _phase_fits(pad, true, vp), "button size %d: both phases inside, disjoint, below the top HUD" % idx)
		_check(pad.fire_button.size.x >= last_fire, "button size %d: FIRE does not shrink (%d px)" % [idx, int(pad.fire_button.size.x)])
		_check(pad.flip_button.size.x >= 0.85 * 57.0, "button size %d: the smallest button keeps a floor" % idx)
		last_fire = pad.fire_button.size.x
		var pb: float = TouchMetrics.platform_button(vp)
		_check(pb >= last_plat and pb >= 112.0 * minf(1.0, Options.button_scale()), "button size %d: platformer arrows %d px" % [idx, int(pb)])
		last_plat = pb
	var d: float = TouchMetrics.dpi(vp)
	_check(TouchMetrics.mm(12.0, vp) > 20.0 and d >= 96.0, "12 mm is a sane number of units at %d dpi" % int(d))
	Options.button_size = saved
	Options.save_options()
	pad.queue_free()
	plat.queue_free()


func _test_story() -> void:
	TouchMetrics.force = 1
	var screen: CombatScreen = _make_screen(true)
	await _frames(3)
	var bottom: BottomHud = _bottom(screen)
	var sim: CombatSim = screen.sim as CombatSim
	_check(bottom.pass_button != null and bottom.pass_button.is_visible_in_tree() and bottom.pass_button.size.y >= 40.0, "story + touch: a finger-sized Pass button is shown")
	_check(sim.turn_phase == CombatSim.Phase.TURN_PLAY, "story level starts in TURN_PLAY")
	bottom.pass_button.tapped.emit()
	_check(sim.turn_phase != CombatSim.Phase.TURN_PLAY, "tapping Pass ends the turn")
	screen.queue_free()
	await _frames(2)
