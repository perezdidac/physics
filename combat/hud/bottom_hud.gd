## Bottom HUD: fuse picker, 16-weapon arsenal drawer, active weapon pill with previous/next buttons, and the touch gamepad
## (move/aim arrows, jump, flip, zoom, centre, fire with charge bar, switch worm).
## Owns the weapon keys of the original: B/R drawer, Z/X [ ] , . cycle, 1..0 - = u i o p select, Q/E fuse, and the drawer navigation.
## Contract: `bind(sim)` with a CombatSim; every call into the sim is guarded.
class_name BottomHud
extends Control

## Camera requests: CombatScreen applies them (JS userZoomMult +-0.16 and pan reset).
signal zoom_requested(delta: float)
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
var left_cluster: Control
var right_cluster: Control
var fire_button: HoldButton
var left_button: HoldButton
var right_button: HoldButton
var up_button: HoldButton
var down_button: HoldButton
var jump_button: HoldButton
var flip_button: HoldButton
var _icon_rect: TextureRect
var _name_label: Label
var _ammo_label: Label
var _chevron: Label
var _compact: bool = false
var _narrow: bool = false
var _last_jump_msec: int = -10000
var _drawer_tween: Tween


func _ready() -> void:
	theme = UiUtil.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("bottom_hud")
	_build()
	get_viewport().size_changed.connect(_on_resized)
	rebuild_weapon_bar()


## Connects the HUD to the simulation (safe with null).
func bind(new_sim: Variant) -> void:
	sim = new_sim
	if sim == null:
		return
	if sim.has_signal("hud_changed"):
		sim.hud_changed.connect(rebuild_weapon_bar)
	if sim.has_signal("turn_started"):
		sim.turn_started.connect(func(_t: int, _f: Variant) -> void: rebuild_weapon_bar())
	rebuild_weapon_bar()


func _on_resized() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if UiUtil.is_compact(vp) != _compact or (vp.x < 820.0) != _narrow:
		var was_open: bool = is_drawer_open()
		_build()
		set_drawer_open(was_open, false)
		rebuild_weapon_bar()
	_update_touch_visibility()


func _process(_delta: float) -> void:
	_update_touch_visibility()
	if sim == null:
		return
	var charging: bool = bool(UiUtil.prop(sim, "is_charging", false)) and not _is_ai_turn()
	fire_button.fill = float(UiUtil.prop(sim, "charge_power", 0.0)) if charging else 0.0
	var phase: int = int(UiUtil.prop(sim, "turn_phase", PHASE_TURN_PLAY))
	var can_switch: bool = phase == PHASE_TURN_PLAY and not bool(UiUtil.prop(sim, "has_acted_or_moved_this_turn", false)) and not _is_ai_turn() and _alive_in_active_team() > 1
	switch_button.visible = can_switch and _touch_ui()


# ---- sim helpers (guarded) ----------------------------------------------------------------------

func _call_sim(method: String, args: Array = []) -> Variant:
	if sim != null and sim.has_method(method):
		return sim.callv(method, args)
	return null


func _is_ai_turn() -> bool:
	if sim == null:
		return false
	var r: Variant = _call_sim("is_current_turn_ai")
	return bool(r) if r != null else false


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
	return UiUtil.is_touch_ui(get_viewport_rect().size)


func _update_touch_visibility() -> void:
	var on: bool = _touch_ui()
	if left_cluster != null and left_cluster.visible != on:
		left_cluster.visible = on
		right_cluster.visible = on


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
	var n: int = HudWeapons.count()
	var cur: int = _current_weapon()
	for i in range(1, n + 1):
		var cand: int = posmod(cur + step * i, n)
		if _ammo(cand) != 0:
			UiUtil.sfx("tick")
			select_weapon(cand, false)
			return


func _current_weapon() -> int:
	return clampi(int(UiUtil.prop(sim, "selected_weapon_idx", selected_idx)), 0, HudWeapons.count() - 1)


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
	fuse_picker.visible = HudWeapons.has_fuse(selected_idx)
	_update_fuse_buttons(int(UiUtil.prop(sim, "custom_grenade_fuse", 3)))
	var ammo: int = _ammo(selected_idx)
	_icon_rect.texture = HudWeapons.icon(selected_idx)
	_name_label.text = tr(HudWeapons.name_key(selected_idx)).to_upper()
	_ammo_label.text = "∞" if ammo < 0 else str(ammo)
	fire_button.text = tr(HudWeapons.fire_label_key(selected_idx))
	var open: bool = is_drawer_open()
	for i in slots.size():
		slots[i].setup(i, _ammo(i), i == selected_idx, open and i == drawer_cursor, _compact)


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
	var n: int = HudWeapons.count()
	drawer_cursor = posmod(drawer_cursor + delta, n)
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


# ---- touch gamepad ------------------------------------------------------------------------------

func _hold_move(dir: int) -> void:
	_call_sim("set_move", [dir])


func _hold_aim(dir: int) -> void:
	_call_sim("set_aim_input", [dir])


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
	var vp: Vector2 = get_viewport_rect().size
	_compact = UiUtil.is_compact(vp)
	_narrow = vp.x < 820.0

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = 4.0 if _compact else 10.0
	column.offset_right = -(4.0 if _compact else 10.0)
	column.offset_bottom = -(4.0 if _compact else 10.0)
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

	left_cluster = _make_left_cluster()
	right_cluster = _make_right_cluster()
	var pill: Control = _make_weapon_pill()
	if _narrow and not _compact:
		# Portrait: the pill on its own row, the gamepad clusters wrap below it.
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(pill)
		var flow := FlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 4)
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(left_cluster)
		flow.add_child(right_cluster)
		column.add_child(flow)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6 if _compact else 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		row.add_child(left_cluster)
		var spacer_l := Control.new()
		spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer_l)
		row.add_child(pill)
		var spacer_r := Control.new()
		spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer_r)
		row.add_child(right_cluster)
	_update_touch_visibility()
	left_cluster.visible = _touch_ui()
	right_cluster.visible = _touch_ui()


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
	for i in HudWeapons.count():
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
		select_weapon(idx, true)


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
	return bar


func _hold(kind: HoldButton.Kind, label: String, on_down: Callable, on_up: Callable) -> HoldButton:
	var b := HoldButton.new(kind, label)
	b.set_compact(_compact)
	b.pressed_down.connect(on_down)
	b.released.connect(on_up)
	return b


func _make_left_cluster() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if _compact else 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_button = _hold(HoldButton.Kind.ARROW, "◀", _hold_move.bind(-1), _hold_move.bind(0))
	right_button = _hold(HoldButton.Kind.ARROW, "▶", _hold_move.bind(1), _hold_move.bind(0))
	up_button = _hold(HoldButton.Kind.ARROW, "▲", _hold_aim.bind(-1), _hold_aim.bind(0))
	down_button = _hold(HoldButton.Kind.ARROW, "▼", _hold_aim.bind(1), _hold_aim.bind(0))
	for b in [left_button, right_button, up_button, down_button]:
		box.add_child(b)
	left_button.tooltip_text = tr("HUD_MOVE_LEFT")
	right_button.tooltip_text = tr("HUD_MOVE_RIGHT")
	up_button.tooltip_text = tr("HUD_AIM_UP")
	down_button.tooltip_text = tr("HUD_AIM_DOWN")
	return box


func _make_right_cluster() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if _compact else 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jump_button = HoldButton.new(HoldButton.Kind.NORMAL, tr("HUD_JUMP"))
	jump_button.set_compact(_compact)
	jump_button.pressed_down.connect(_on_jump)
	jump_button.tooltip_text = tr("HUD_JUMP_TOOLTIP")
	box.add_child(jump_button)
	flip_button = HoldButton.new(HoldButton.Kind.UTIL, tr("HUD_FLIP"))
	flip_button.set_compact(_compact)
	flip_button.tooltip_text = tr("HUD_FLIP_TOOLTIP")
	flip_button.pressed_down.connect(func() -> void: _call_sim("jump_backward"))
	box.add_child(flip_button)
	box.add_child(_click_button("−", tr("HUD_ZOOM_OUT_TOOLTIP"), func() -> void: zoom_requested.emit(-0.16)))
	box.add_child(_click_button("+", tr("HUD_ZOOM_IN_TOOLTIP"), func() -> void: zoom_requested.emit(0.16)))
	box.add_child(_click_button(tr("HUD_CENTER"), tr("HUD_CENTER_TOOLTIP"), func() -> void: center_requested.emit()))
	fire_button = HoldButton.new(HoldButton.Kind.FIRE, tr("FIRE_DEFAULT"))
	fire_button.set_compact(_compact)
	fire_button.pressed_down.connect(func() -> void: _call_sim("begin_charge_or_fire"))
	fire_button.released.connect(func() -> void: _call_sim("release_charge"))
	box.add_child(fire_button)
	return box


func _click_button(label: String, tip: String, on_tap: Callable) -> HoldButton:
	var b := HoldButton.new(HoldButton.Kind.UTIL, label)
	b.set_compact(_compact)
	b.tooltip_text = tip
	b.tapped.connect(on_tap)
	return b
