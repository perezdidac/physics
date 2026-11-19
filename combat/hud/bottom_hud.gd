## Bottom HUD: fuse picker, 16-weapon arsenal drawer, active weapon pill with previous/next buttons, and the touch controls
## (TouchPad: walk arrows, jump, backflip, aim, fire with charge ring, weapon picker, move, centre; TouchOverlay: aim-drag
## feedback and the phase hint). On touch the turn has two phases: MOVE (arrows, camera drag) and AIM (drag rotates the aim, FIRE).
## Owns the weapon keys of the original: B/R drawer, Z/X [ ] , . cycle, 1..0 - = u i o p select, Q/E fuse, and the drawer navigation.
## Contract: `bind(sim)` with a CombatSim; every call into the sim is guarded.
class_name BottomHud
extends Control

## Camera request: CombatScreen resets the pan (the touch centre button).
signal center_requested

const PHASE_TURN_PLAY := 0
const DRAWER_COLUMNS := 8
const KEY_TO_WEAPON: Dictionary = {
	KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9,
	KEY_MINUS: 10, KEY_EQUAL: 11, KEY_U: 12, KEY_I: 13, KEY_O: 14, KEY_P: 15,
}
const DOUBLE_JUMP_MSEC := 360

var sim: Variant = null
var drawer_cursor: int = 0
var selected_idx: int = 0
var fuse_picker: Control
var fuse_buttons: Array[Button] = []
var rack: PanelContainer
var slots: Array[WeaponSlot] = []
var toggle_button: ChamferButton
var prev_button: Button
var next_button: Button
var switch_button: HoldButton
var touch_pad: TouchPad
var touch_overlay: TouchOverlay
## Safe insets the column was built for (see TouchMetrics.safe_insets).
var _ins: Vector4 = Vector4.ZERO
var fire_button: TouchButton
var jump_button: TouchButton
var flip_button: TouchButton
## Touch phase: false = MOVE, true = AIM (see `set_touch_aim`).
var touch_aim: bool = false
## Story mode only: ends the turn early (eggs have no weapon to use) and the hint shown when the team has no weapon.
var pass_button: HoldButton
## El Bolsó: the REPAIR action (key T), shown only next to a damaged nest; the touch layout has its own button on the TouchPad.
var repair_button: HoldButton
var hint_panel: PanelContainer
## "NEW!" chip beside the active weapon name (story: unlocked by the last level won).
var _new_chip: PanelContainer
var _icon_rect: TextureRect
var _name_label: Label
var _ammo_label: Label
var _chevron: Label
var _compact: bool = false
var _narrow: bool = false
var _last_jump_msec: int = -10000
var _drawer_tween: Tween
var _built_story: bool = false
var _touch_built: bool = false


func _ready() -> void:
	theme = UiUtil.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("bottom_hud")
	_build()
	get_viewport().size_changed.connect(_on_resized)
	Options.button_size_changed.connect(_on_button_size_changed)
	rebuild_weapon_bar()


## Connects the HUD to the simulation (safe with null).
func bind(new_sim: Variant) -> void:
	sim = new_sim
	if sim == null:
		return
	if sim.has_signal("hud_changed"):
		sim.hud_changed.connect(rebuild_weapon_bar)
	if sim.has_signal("turn_started"):
		sim.turn_started.connect(func(_t: int, _f: Variant) -> void:
			set_touch_aim(false)
			rebuild_weapon_bar())
	if is_story():
		_build()
	elif touch_overlay != null:
		_bind_overlay()
	rebuild_weapon_bar()


func _on_resized() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if UiUtil.is_compact(vp) != _compact or (vp.x < 820.0) != _narrow or _touch_ui() != _touch_built \
			or not TouchMetrics.safe_insets(vp).is_equal_approx(_ins):
		var was_open: bool = is_drawer_open()
		_build()
		set_drawer_open(was_open, false)
		rebuild_weapon_bar()
	_update_touch_visibility()


func _on_button_size_changed() -> void:
	var was_open: bool = is_drawer_open()
	_build()
	set_drawer_open(was_open, false)
	rebuild_weapon_bar()


func _process(_delta: float) -> void:
	if _touch_ui() != _touch_built:
		_on_resized()
	_update_touch_visibility()
	if sim == null:
		return
	var charging: bool = bool(UiUtil.prop(sim, "is_charging", false)) and not _is_ai_turn()
	fire_button.fill = float(UiUtil.prop(sim, "charge_power", 0.0)) if charging else 0.0
	var phase: int = int(UiUtil.prop(sim, "turn_phase", PHASE_TURN_PLAY))
	var can_switch: bool = phase == PHASE_TURN_PLAY and not bool(UiUtil.prop(sim, "has_acted_or_moved_this_turn", false)) and not _is_ai_turn() and _alive_in_active_team() > 1
	switch_button.visible = can_switch and _touch_ui()
	if pass_button != null:
		pass_button.visible = phase == PHASE_TURN_PLAY and not _is_ai_turn()
	var can_repair: bool = can_repair_nest()
	if repair_button != null:
		repair_button.visible = can_repair and not _touch_built
	touch_pad.repair_button.visible = can_repair and _touch_built
	_update_phase(phase)


## Keeps the touch phase valid (AIM only while this human can still shoot) and shows the buttons and the hint of the phase.
func _update_phase(phase: int) -> void:
	var none: bool = arsenal().is_empty()
	var open: bool = is_drawer_open()
	var fighter: Variant = UiUtil.prop(sim, "active_fighter")
	var jetting: bool = fighter != null and float(UiUtil.prop(fighter, "jet_fuel", 0.0)) > 0.0
	var can_aim: bool = phase == PHASE_TURN_PLAY and not none and not _is_ai_turn() and not jetting
	if touch_aim and not can_aim:
		set_touch_aim(false)
	var pad: TouchPad = touch_pad
	var jumper: bool = _active_can_jump()
	var move_ui: bool = not touch_aim and not open
	var aim_ui: bool = touch_aim and not open
	pad.left_button.visible = move_ui
	pad.right_button.visible = move_ui
	pad.jump_button.visible = jumper and move_ui
	pad.flip_button.visible = jumper and move_ui
	pad.aim_button.visible = move_ui and can_aim
	pad.fire_button.visible = aim_ui
	pad.move_button.visible = aim_ui
	pad.weapon_button.visible = not none
	pad.center_button.visible = not open
	touch_overlay.phase_text = "" if open or _is_ai_turn() else _phase_hint()


func _phase_hint() -> String:
	if not touch_aim:
		return tr("TOUCH_PHASE_MOVE")
	var id: String = HudWeapons.id_of(selected_idx)
	if id == "AIRSTRIKE":
		return tr("TOUCH_PHASE_TARGET")
	if HudWeapons.fire_label_key(selected_idx) == "FIRE_HOLD":
		return tr("TOUCH_PHASE_AIM_HOLD")
	return tr("TOUCH_PHASE_AIM_TAP")


## Switches between the MOVE (false) and AIM (true) touch phase.
func set_touch_aim(on: bool) -> void:
	if on == touch_aim:
		return
	touch_aim = on
	touch_pad.set_aim(on)
	var input: Node = _input_node()
	if input != null:
		input.set("touch_aim", on)


func _input_node() -> Node:
	return get_tree().get_first_node_in_group("combat_input") if is_inside_tree() else null


func _hold_key(cmd: String, held: bool) -> void:
	var input: Node = _input_node()
	if input != null:
		input.call("set_key", cmd, held)


# ---- sim helpers (guarded) ----------------------------------------------------------------------

## True in a story level (the sim has a LevelDef).
func is_story() -> bool:
	return UiUtil.prop(sim, "level") != null


## Weapon indices the active team may use: the level arsenal in story mode, the 16 classic weapons otherwise.
func arsenal() -> Array[int]:
	if sim != null and sim.has_method("team_arsenal"):
		return sim.call("team_arsenal", int(UiUtil.prop(sim, "active_team", 0)))
	var all: Array[int] = []
	for i in HudWeapons.count():
		all.append(i)
	return all


## True in a story level when weapon `idx` was unlocked by the last level won (the human team only).
func _is_new(idx: int) -> bool:
	return _built_story and int(UiUtil.prop(sim, "active_team", 0)) == 0 and HudWeapons.new_ids(StoryProgress).has(HudWeapons.id_of(idx))


## Ends the turn early (the Pass button and its key).
func pass_turn() -> void:
	if sim != null and not _is_ai_turn():
		UiUtil.sfx("tick")
		_call_sim("end_turn")

## True when the active caterpillar can repair the nest now (next to a damaged nest on a human turn).
func can_repair_nest() -> bool:
	return sim != null and sim.has_method("can_repair_nest") and bool(sim.call("can_repair_nest"))


## REPAIR: the active caterpillar weaves the nest back together (the button and the T key).
func repair_nest() -> void:
	if can_repair_nest():
		UiUtil.sfx("tick")
		_call_sim("repair_nest")


func _call_sim(method: String, args: Array = []) -> Variant:
	if sim != null and sim.has_method(method):
		return sim.callv(method, args)
	return null


func _is_ai_turn() -> bool:
	if sim == null:
		return false
	var r: Variant = _call_sim("is_current_turn_ai")
	return bool(r) if r != null else false


## False when the active unit cannot jump (the egg): the jump buttons are hidden.
func _active_can_jump() -> bool:
	var f: Variant = UiUtil.prop(sim, "active_fighter")
	return f == null or not (f is Object) or not (f as Object).has_method("can_jump") or bool((f as Object).call("can_jump"))


func _alive_in_active_team() -> int:
	var n: int = 0
	var team: int = int(UiUtil.prop(sim, "active_team", 0))
	for f: Variant in UiUtil.prop(sim, "fighters", []):
		if int(UiUtil.prop(f, "team", -1)) == team and bool(UiUtil.prop(f, "alive", false)) and not bool(UiUtil.prop(f, "drowning", false)):
			n += 1
	return n


func _ammo(idx: int) -> int:
	return HudWeapons.ammo_for(UiUtil.prop(sim, "team_ammo"), int(UiUtil.prop(sim, "active_team", 0)), idx)


func _touch_ui() -> bool:
	return TouchMetrics.active(get_viewport_rect().size)


func _update_touch_visibility() -> void:
	if touch_pad != null:
		touch_pad.visible = _touch_built


# ---- weapons -----------------------------------------------------------------------------------

## Selects weapon `idx` if it has ammo and it is a human turn (JS selectWeaponByIndex). Returns true if accepted.
func select_weapon(idx: int, close_drawer: bool) -> bool:
	if _is_ai_turn() or _ammo(idx) == 0:
		return false
	var ok: Variant = _call_sim("select_weapon", [idx])
	if sim != null and ok == false:
		return false
	selected_idx = idx
	drawer_cursor = idx
	if close_drawer:
		set_drawer_open(false)
	rebuild_weapon_bar()
	return true


## Moves to the previous/next weapon that still has ammo (JS cycleAvailableWeapon).
func cycle_weapon(step: int) -> void:
	var list: Array[int] = arsenal()
	var n: int = list.size()
	var pos: int = maxi(0, list.find(_current_weapon()))
	for i in range(1, n + 1):
		var cand: int = list[posmod(pos + step * i, n)]
		if _ammo(cand) != 0:
			UiUtil.sfx("tick")
			select_weapon(cand, false)
			return


func _current_weapon() -> int:
	return clampi(int(UiUtil.prop(sim, "selected_weapon_idx", selected_idx)), 0, HudWeapons.total() - 1)


## Sets the fuse (1..5 s) of grenade-like weapons.
func set_fuse(seconds: int) -> void:
	_call_sim("set_fuse", [clampi(seconds, 1, 5)])
	_update_fuse_buttons(clampi(seconds, 1, 5))


func _update_fuse_buttons(active_sec: int) -> void:
	for i in fuse_buttons.size():
		fuse_buttons[i].button_pressed = (i + 1) == active_sec


## Refreshes the pill, fire label, fuse picker and the 16 drawer slots (JS buildWeaponBar).
func rebuild_weapon_bar() -> void:
	if slots.is_empty():
		return
	selected_idx = _current_weapon()
	var list: Array[int] = arsenal()
	var none: bool = list.is_empty()
	if none and is_drawer_open():
		set_drawer_open(false)
		return
	var open: bool = is_drawer_open()
	var touch: bool = _touch_built
	hint_panel.visible = none
	toggle_button.visible = not none and not touch
	prev_button.visible = not none and list.size() > 1 and not touch
	next_button.visible = prev_button.visible
	fuse_picker.visible = not none and HudWeapons.has_fuse(selected_idx)
	_update_fuse_buttons(int(UiUtil.prop(sim, "custom_grenade_fuse", 3)))
	var ammo: int = _ammo(selected_idx)
	_icon_rect.texture = HudWeapons.icon(selected_idx)
	_name_label.text = tr(HudWeapons.name_key(selected_idx)).to_upper()
	_ammo_label.text = "∞" if ammo < 0 else str(ammo)
	fire_button.text = tr(HudWeapons.fire_label_key(selected_idx))
	touch_pad.weapon_button.icon = _icon_rect.texture
	touch_pad.weapon_button.sub_text = _ammo_label.text
	for i in slots.size():
		slots[i].visible = list.has(i)
		slots[i].setup(i, _ammo(i), i == selected_idx, open and i == drawer_cursor, _compact, _is_new(i))
	_new_chip.visible = not none and _is_new(selected_idx)


## True while the arsenal drawer is shown.
func is_drawer_open() -> bool:
	return rack != null and rack.visible


## Opens or closes the drawer with the 0.16 s pop animation (JS drawerPop).
func set_drawer_open(open: bool, animate: bool = true) -> void:
	if open:
		drawer_cursor = _current_weapon()
	_chevron.text = tr("HUD_ARSENAL_CLOSE") if open else tr("HUD_ARSENAL_OPEN")
	toggle_button.selected = open
	if _drawer_tween != null:
		_drawer_tween.kill()
	if open:
		rack.visible = true
		if animate:
			rack.modulate.a = 0.0
			rack.scale = Vector2(0.97, 0.97)
			_drawer_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_drawer_tween.tween_property(rack, "modulate:a", 1.0, 0.16)
			_drawer_tween.tween_property(rack, "scale", Vector2.ONE, 0.16)
		else:
			rack.modulate.a = 1.0
			rack.scale = Vector2.ONE
	else:
		rack.visible = false
	rebuild_weapon_bar()


func _toggle_drawer() -> void:
	UiUtil.sfx("tick")
	set_drawer_open(not is_drawer_open())


func _move_cursor(delta: int) -> void:
	var list: Array[int] = arsenal()
	if list.is_empty():
		return
	drawer_cursor = list[posmod(maxi(0, list.find(drawer_cursor)) + delta, list.size())]
	UiUtil.sfx("tick")
	if not _is_ai_turn() and _ammo(drawer_cursor) != 0:
		var ok: Variant = _call_sim("select_weapon", [drawer_cursor])
		if not (sim != null and ok == false):
			selected_idx = drawer_cursor
	rebuild_weapon_bar()


# ---- keyboard ----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	if handle_key(key.keycode, key.echo):
		get_viewport().set_input_as_handled()


## Applies one key press; returns true when consumed. Exposed for tests.
func handle_key(keycode: Key, echo: bool = false) -> bool:
	if not is_visible_in_tree():
		return false
	if keycode in [KEY_B, KEY_R]:
		if not echo:
			_toggle_drawer()
		return true
	if is_drawer_open():
		match keycode:
			KEY_RIGHT, KEY_D:
				_move_cursor(1)
				return true
			KEY_LEFT, KEY_A:
				_move_cursor(-1)
				return true
			KEY_DOWN, KEY_S:
				_move_cursor(DRAWER_COLUMNS)
				return true
			KEY_UP, KEY_W:
				_move_cursor(-DRAWER_COLUMNS)
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not echo:
					select_weapon(drawer_cursor, true)
				return true
			KEY_ESCAPE:
				set_drawer_open(false)
				return true
	if echo:
		return false
	if keycode == KEY_N and is_story():
		pass_turn()
		return true
	if keycode == KEY_T and is_story() and UiUtil.prop(sim, "nest") != null:
		repair_nest()
		return true
	if is_story() and keycode >= KEY_1 and keycode <= KEY_9:
		var list: Array[int] = arsenal()
		var slot: int = keycode - KEY_1
		if slot < list.size() and select_weapon(list[slot], false):
			UiUtil.sfx("tick")
		return true
	match keycode:
		KEY_Z, KEY_BRACKETLEFT, KEY_COMMA:
			cycle_weapon(-1)
			return true
		KEY_X, KEY_BRACKETRIGHT, KEY_PERIOD:
			cycle_weapon(1)
			return true
		KEY_Q:
			UiUtil.sfx("tick")
			set_fuse(maxi(1, int(UiUtil.prop(sim, "custom_grenade_fuse", 3)) - 1))
			return true
		KEY_E:
			UiUtil.sfx("tick")
			set_fuse(mini(5, int(UiUtil.prop(sim, "custom_grenade_fuse", 3)) + 1))
			return true
	if KEY_TO_WEAPON.has(keycode):
		if select_weapon(int(KEY_TO_WEAPON[keycode]), false):
			UiUtil.sfx("tick")
		return true
	return false


# ---- touch buttons ------------------------------------------------------------------------------

func _on_jump() -> void:
	var grounded: bool = true
	var f: Variant = UiUtil.prop(sim, "active_fighter")
	if f != null:
		grounded = bool(UiUtil.prop(f, "grounded", true))
	var now: int = Time.get_ticks_msec()
	if not grounded and now - _last_jump_msec < DOUBLE_JUMP_MSEC:
		_call_sim("jump_backward")
		_last_jump_msec = -10000
	else:
		_call_sim("jump_forward")
		_last_jump_msec = now


# ---- building ----------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	slots.clear()
	fuse_buttons.clear()
	_built_story = is_story()
	var vp: Vector2 = get_viewport_rect().size
	_touch_built = TouchMetrics.active(vp)
	_compact = UiUtil.is_compact(vp)
	_narrow = vp.x < 820.0

	touch_aim = false
	_build_touch(vp)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var ins: Vector4 = TouchMetrics.safe_insets(vp)
	_ins = ins
	column.offset_left = (4.0 if _compact else 10.0) + ins.x
	column.offset_right = -(4.0 if _compact else 10.0) - ins.z
	column.offset_bottom = -(4.0 if _compact else 10.0) - ins.w
	column.add_theme_constant_override("separation", 4 if _compact else 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	add_child(column)

	fuse_picker = _make_fuse_picker()
	fuse_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(fuse_picker)

	rack = _make_rack(vp)
	rack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rack)

	var pill: Control = _make_weapon_pill()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(pill)
	_update_touch_visibility()


func _touch_button_size() -> Vector2:
	return TouchMetrics.bar_button_size(get_viewport_rect().size)


## The touch pad (buttons) and the gesture overlay; both exist on every layout, the pad is only shown on touch UIs.
func _build_touch(vp: Vector2) -> void:
	touch_overlay = TouchOverlay.new()
	add_child(touch_overlay)
	touch_pad = TouchPad.new()
	add_child(touch_pad)
	touch_pad.layout(vp)
	fire_button = touch_pad.fire_button
	jump_button = touch_pad.jump_button
	flip_button = touch_pad.flip_button
	fire_button.pressed_down.connect(func() -> void: _call_sim("begin_charge_or_fire"))
	fire_button.released.connect(func() -> void: _call_sim("release_charge"))
	jump_button.pressed_down.connect(func() -> void:
		_on_jump()
		_hold_key("up", true))
	jump_button.released.connect(func() -> void: _hold_key("up", false))
	touch_pad.left_button.pressed_down.connect(func() -> void: _hold_key("left", true))
	touch_pad.left_button.released.connect(func() -> void: _hold_key("left", false))
	touch_pad.right_button.pressed_down.connect(func() -> void: _hold_key("right", true))
	touch_pad.right_button.released.connect(func() -> void: _hold_key("right", false))
	touch_pad.aim_button.tapped.connect(func() -> void: set_touch_aim(true))
	touch_pad.move_button.tapped.connect(func() -> void: set_touch_aim(false))
	flip_button.pressed_down.connect(func() -> void: _call_sim("jump_backward"))
	touch_pad.weapon_button.tapped.connect(_toggle_drawer)
	touch_pad.center_button.tapped.connect(func() -> void: center_requested.emit())
	touch_pad.repair_button.tapped.connect(repair_nest)
	_bind_overlay()


func _bind_overlay() -> void:
	var input: Node = _input_node()
	if input != null:
		touch_overlay.bind_input(input)
		input.set("touch_aim", touch_aim)


func _make_fuse_picker() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.RACK_BG
	sb.border_color = Palette.BRASS_BORDER_35
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", sb)
	panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	row.add_child(UiUtil.label(tr("HUD_FUSE"), "MonoHeavyLabel", 10, Palette.IVORY_MUTED))
	for s in range(1, 6):
		var b := Button.new()
		b.theme_type_variation = "FuseButton"
		b.text = "%ds" % s
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_fuse.bind(s))
		if _touch_built:
			b.custom_minimum_size = Vector2(0.0, _touch_button_size().y)
		row.add_child(b)
		fuse_buttons.append(b)
	return panel


func _make_rack(vp: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "RackPanel"
	panel.visible = false
	panel.pivot_offset = Vector2(0, 40)
	var grid := GridContainer.new()
	var columns: int = 5 if (_narrow and not _compact) else DRAWER_COLUMNS
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	panel.add_child(grid)
	for i in (HudWeapons.total() if _built_story else HudWeapons.count()):
		var slot := WeaponSlot.new()
		slot.pressed.connect(_on_slot_pressed)
		grid.add_child(slot)
		slots.append(slot)
	if _compact:
		panel.custom_minimum_size.x = minf(vp.x * 0.94, 520.0)
	return panel


func _on_slot_pressed(idx: int) -> void:
	if not _is_ai_turn() and _ammo(idx) != 0:
		UiUtil.sfx("tick")
		if select_weapon(idx, true) and _touch_built and int(UiUtil.prop(sim, "turn_phase", PHASE_TURN_PLAY)) == PHASE_TURN_PLAY:
			set_touch_aim(true)


func _make_weapon_pill() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev_button = Button.new()
	prev_button.theme_type_variation = "NavButton"
	prev_button.text = "◀"
	prev_button.custom_minimum_size = Vector2(32, 34) if _compact else Vector2(36, 40)
	prev_button.tooltip_text = tr("HUD_WEAPON_PREV_TOOLTIP")
	prev_button.focus_mode = Control.FOCUS_NONE
	prev_button.pressed.connect(func() -> void: cycle_weapon(-1))
	bar.add_child(prev_button)

	toggle_button = ChamferButton.new()
	toggle_button.radius = 999.0
	toggle_button.padding = Vector4(14, 0, 14, 0)
	toggle_button.custom_minimum_size.y = 36.0 if _compact else 44.0
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.draw_focus_ring = false
	toggle_button.border_width = 1.5
	toggle_button.look_normal = {"top": Palette.BTN_TOP, "bottom": Palette.BTN_BOTTOM, "border": Palette.BRASS_BORDER_58}
	toggle_button.look_hover = {"top": Palette.BTN_TOP_HOVER, "bottom": Palette.BTN_BOTTOM, "border": Palette.BRASS_BRIGHT}
	toggle_button.look_selected = {"top": Palette.BTN_TOP_SELECTED, "bottom": Palette.BTN_BOTTOM_SELECTED, "border": Palette.BRASS_BRIGHT}
	toggle_button.tooltip_text = tr("HUD_WEAPON_TOGGLE_TOOLTIP")
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(30, 20)
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_icon_rect)
	_name_label = UiUtil.label("", "BodyBoldLabel", 12, Color.WHITE)
	inner.add_child(_name_label)
	_new_chip = PanelContainer.new()
	var new_sb := StyleBoxFlat.new()
	new_sb.bg_color = Palette.TEAM_GOLD
	new_sb.set_corner_radius_all(999)
	new_sb.content_margin_left = 6
	new_sb.content_margin_right = 6
	new_sb.content_margin_top = 0
	new_sb.content_margin_bottom = 0
	_new_chip.add_theme_stylebox_override("panel", new_sb)
	_new_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_new_chip.visible = false
	_new_chip.add_child(UiUtil.label(tr("HUD_NEW"), "MonoHeavyLabel", 9, Palette.INK_ON_BRASS))
	inner.add_child(_new_chip)
	var chip := PanelContainer.new()
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = Palette.CHIP_BG
	chip_sb.set_corner_radius_all(999)
	chip_sb.content_margin_left = 7
	chip_sb.content_margin_right = 7
	chip_sb.content_margin_top = 1
	chip_sb.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", chip_sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ammo_label = UiUtil.label("∞", "MonoHeavyLabel", 11, Palette.BRASS_BRIGHT)
	chip.add_child(_ammo_label)
	inner.add_child(chip)
	if not _compact and not _narrow:
		_chevron = UiUtil.label(tr("HUD_ARSENAL_OPEN"), "MonoHeavyLabel", 9, Palette.IVORY_MUTED)
	else:
		_chevron = UiUtil.label("", "MonoHeavyLabel", 9, Palette.IVORY_MUTED)
		_chevron.visible = false
	inner.add_child(_chevron)
	toggle_button.add_child(inner)
	toggle_button.pressed.connect(_toggle_drawer)
	bar.add_child(toggle_button)

	next_button = Button.new()
	next_button.theme_type_variation = "NavButton"
	next_button.text = "▶"
	next_button.custom_minimum_size = Vector2(32, 34) if _compact else Vector2(36, 40)
	next_button.tooltip_text = tr("HUD_WEAPON_NEXT_TOOLTIP")
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(func() -> void: cycle_weapon(1))
	bar.add_child(next_button)

	switch_button = HoldButton.new(HoldButton.Kind.UTIL, tr("HUD_SWITCH_WORM"))
	switch_button.set_compact(_compact)
	switch_button.custom_minimum_size.x = 54
	switch_button.tooltip_text = tr("HUD_SWITCH_WORM_TOOLTIP")
	switch_button.visible = false
	switch_button.tapped.connect(func() -> void: _call_sim("switch_fighter"))
	bar.add_child(switch_button)
	if _touch_built:
		switch_button.custom_minimum_size = _touch_button_size()
	hint_panel = PanelContainer.new()
	hint_panel.theme_type_variation = "PillPanel"
	hint_panel.add_child(UiUtil.label(tr("HUD_NO_WEAPONS"), "BodyBoldLabel", 10 if _compact else 12, Palette.IVORY))
	hint_panel.visible = false
	bar.add_child(hint_panel)
	pass_button = null
	repair_button = null
	if _built_story and UiUtil.prop(sim, "nest") != null:
		repair_button = HoldButton.new(HoldButton.Kind.NORMAL, tr("HUD_REPAIR"))
		repair_button.set_compact(_compact)
		repair_button.custom_minimum_size.x = 64 if _compact else 86
		repair_button.tooltip_text = tr("HUD_REPAIR_TOOLTIP")
		repair_button.visible = false
		repair_button.tapped.connect(repair_nest)
		bar.add_child(repair_button)
	if _built_story:
		pass_button = HoldButton.new(HoldButton.Kind.NORMAL, tr("HUD_PASS"))
		pass_button.set_compact(_compact)
		pass_button.custom_minimum_size.x = 50 if _compact else 64
		pass_button.tooltip_text = tr("HUD_PASS_TOOLTIP")
		pass_button.tapped.connect(pass_turn)
		if _touch_built:
			pass_button.custom_minimum_size = _touch_button_size()
		bar.add_child(pass_button)
	return bar
