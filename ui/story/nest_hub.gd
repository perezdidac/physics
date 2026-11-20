## El Bolsó, the winter hub: spend the silk earned in the levels on upgrades (cards with name, description, cost and owned / buy) in a cosy
## nest. Opened from the story map once some silk is earned. The card list scrolls by dragging anywhere on it (cards and buy buttons too;
## see DragScroll), with the mouse wheel and with the keyboard focus. Keyboard: Tab / arrows move between the cards, Enter buys, Esc goes back.
extends Control

## Two card columns when the list is at least this wide (logical units).
const TWO_COLUMNS_WIDTH := 640.0
## Room kept below the last card so it never touches the frame's bottom edge (logical units).
const LIST_BOTTOM_GAP := 18.0
## Gap kept between a focused card and the edge of the list when it is scrolled into view.
const FOCUS_MARGIN := 8.0

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var back_button: Button
var silk_label: Label
## One buy button per upgrade id (the owned ones have none).
var buy_buttons: Dictionary = {}
## One card per upgrade, in shop order.
var cards: Array[Control] = []
## The scrolling card list and its drag handler (the handler lives across rebuilds).
var scroll: ScrollContainer
var drag: DragScroll
## Columns of the card grid (1 or 2, from the list width).
var columns: int = 1
var _settle_serial: int = 0


func _ready() -> void:
	theme = UiUtil.get_theme()
	drag = DragScroll.new()
	drag.name = "DragScroll"
	add_child(drag)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_build()
	get_viewport().size_changed.connect(_build)


func _go(screen_name: String) -> void:
	if go_callable.is_valid():
		go_callable.call(screen_name)
	else:
		ScreenRouter.go(screen_name)


## Back to the campaign map.
func back_to_map() -> void:
	UiUtil.sfx("tick")
	_go("story_map")


## Buys the upgrade with silk and redraws (keeping the list where it was); false when it cannot be bought.
func buy(id: String) -> bool:
	if not StoryProgress.buy(id):
		UiUtil.sfx("tick")
		return false
	UiUtil.sfx("stone_build")
	var ids: Array[String] = []
	for u in StoryProgress.upgrades():
		ids.append(u.id)
	_build(ids.find(id))
	return true


## A buy button was tapped: ignored when the touch was a drag that scrolled the list.
func _on_buy_pressed(id: String) -> void:
	if drag.moved:
		return
	buy(id)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_to_map()


## Rebuilds the screen. `bought_idx` >= 0 (shop index of the upgrade just bought) keeps the scroll and moves the focus to the next card.
func _build(bought_idx: int = -1) -> void:
	var keep_scroll: int = scroll.scroll_vertical if is_instance_valid(scroll) else 0
	for c in get_children():
		if c != drag:
			c.queue_free()
	buy_buttons.clear()
	cards.clear()
	var real_vp: Vector2 = get_viewport_rect().size
	var vp: Vector2 = StoryUi.logical(self)
	var small: bool = StoryUi.is_small(real_vp)
	var wide: bool = vp.x >= StoryUi.NARROW_WIDTH
	add_child(NestHubArt.new())
	var margin: float = 6.0 if (small or vp != real_vp) else maxf(6.0, real_vp.y * 0.03)
	var left_edge: float = real_vp.x * 0.42 if wide and vp == real_vp else margin
	var holder: Control = TouchMetrics.scaled_root(self, real_vp, Rect2(left_edge, margin, real_vp.x - left_edge - margin, real_vp.y - 2.0 * margin))
	var frame := ChamferPanel.new()
	frame.cuts = Vector4(0, 18, 0, 18)
	frame.fill_top = Color(0.07, 0.09, 0.17, 0.9)
	frame.fill_bottom = Color(0.05, 0.06, 0.12, 0.93)
	frame.padding = Vector4(14, 10, 14, 10) if small else Vector4(26, 20, 26, 20)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8 if small else 12)
	frame.add_child(outer)
	back_button = StoryUi.cmd_button(tr("STORY_BTN_BACK"))
	back_button.pressed.connect(back_to_map)
	# The silk counter sits in the header next to Back, so the card list gets the rest of the height.
	var head_right := HBoxContainer.new()
	head_right.add_theme_constant_override("separation", 12)
	var pill: Control = _silk_pill(small)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_right.add_child(pill)
	head_right.add_child(back_button)
	outer.add_child(StoryUi.make_header("", tr("NEST_HUB_TITLE"), tr("NEST_HUB_SUB"), head_right, small))
	scroll = ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE # a scrollbar that comes and goes would re-wrap the cards forever
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# DragScroll does the touch dragging (from any card or button); the built-in drag only starts on the gaps, so it is switched off.
	scroll.scroll_deadzone = 1 << 20
	outer.add_child(scroll)
	drag.scroll = scroll
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_bottom", int(LIST_BOTTOM_GAP))
	pad.add_theme_constant_override("margin_right", 4)
	scroll.add_child(pad)
	var grid := GridContainer.new()
	var list_width: float = holder.size.x - frame.padding.x - frame.padding.z
	columns = 2 if list_width >= TWO_COLUMNS_WIDTH else 1
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(grid)
	for u in StoryProgress.upgrades():
		var card: Control = _make_card(u, small)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		cards.append(card)
	if not small:
		outer.add_child(StoryUi.paragraph(tr("NEST_HUB_HINT"), 11, Palette.IVORY_HINT))
	TouchMetrics.fit_taps(frame, real_vp, vp.y)
	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	_settle(keep_scroll if bought_idx >= 0 else 0, bought_idx)


## After the layout settles: restores the scroll and puts the keyboard focus on the first card that can be bought (after a purchase,
## the next one after `bought_idx`). Touch players get no focus ring.
func _settle(keep_scroll: int, bought_idx: int) -> void:
	_settle_serial += 1
	var serial: int = _settle_serial
	for i in 2:
		await get_tree().process_frame
	if serial != _settle_serial or not is_instance_valid(scroll):
		return
	scroll.scroll_vertical = keep_scroll
	if UiUtil.touch_seen:
		return
	var ids: Array[String] = []
	for u in StoryProgress.upgrades():
		ids.append(u.id)
	var start: int = maxi(0, bought_idx)
	for k in ids.size():
		var id: String = ids[(start + k) % ids.size()]
		var b: Control = buy_buttons.get(id)
		if b != null and b.is_inside_tree() and not bool(b.get("disabled")):
			b.grab_focus()
			return
	if back_button != null and back_button.is_inside_tree():
		back_button.grab_focus()


func _on_focus_changed(control: Control) -> void:
	if control != null and is_instance_valid(scroll) and scroll.is_ancestor_of(control):
		reveal.call_deferred(control)


## Scrolls the list so the card holding `control` (or the control itself) is fully visible, with FOCUS_MARGIN around it.
func reveal(control: Control) -> void:
	if not is_instance_valid(control) or not is_instance_valid(scroll) or not scroll.is_ancestor_of(control):
		return
	var target: Control = control
	for card in cards:
		if card.is_ancestor_of(control):
			target = card
	# In the scroll's own units (the hub is drawn scaled, so global rects cannot be compared directly).
	var xf: Transform2D = scroll.get_global_transform().affine_inverse() * target.get_global_transform()
	var top: float = xf.origin.y
	var bottom: float = top + target.size.y * xf.get_scale().y
	var view_h: float = scroll.size.y
	if bottom - top > view_h - 2.0 * FOCUS_MARGIN or top < FOCUS_MARGIN:
		scroll.scroll_vertical += int(floor(top - FOCUS_MARGIN))
	elif bottom > view_h - FOCUS_MARGIN:
		scroll.scroll_vertical += int(ceil(bottom - view_h + FOCUS_MARGIN))


## The silk counter: a pale-gold pill with a skein icon and the silk you can spend.
func _silk_pill(small: bool) -> Control:
	var pill := PanelContainer.new()
	pill.theme_type_variation = "PillPanel"
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	var icon := SilkIcon.new()
	icon.custom_minimum_size = Vector2(22, 22)
	row.add_child(icon)
	silk_label = UiUtil.label(UiUtil.fmt("NEST_HUB_SILK", [StoryProgress.silk()]), "TitleBlackLabel", 16 if small else 20, Palette.BRASS_BRIGHT)
	row.add_child(silk_label)
	return pill


func _make_card(u: UpgradeDef, small: bool) -> Control:
	var owned: bool = StoryProgress.owns(u.id)
	var unlocked: bool = StoryProgress.can_unlock(u)
	var affordable: bool = u.cost <= StoryProgress.silk() and unlocked
	var panel := PanelContainer.new()
	panel.name = "Card_%s" % u.id
	panel.mouse_filter = Control.MOUSE_FILTER_PASS # a PanelContainer stops the mouse by default: the wheel and drags must reach the list
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.2, 0.34, 0.88) if owned else Color(0.11, 0.14, 0.25, 0.9)
	sb.border_color = Palette.BRASS_BRIGHT if owned else Color(Palette.BRASS, 0.55 if affordable else 0.25)
	sb.set_border_width_all(2 if owned else 1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var badge := UpgradeIcon.new()
	badge.effect = u.effect
	badge.custom_minimum_size = Vector2(30, 30) if small else Vector2(38, 38)
	head.add_child(badge)
	var name_label: Label = UiUtil.label(tr(u.name_key), "BodyBoldLabel", 14 if small else 16, Palette.IVORY if not owned else Palette.BRASS_BRIGHT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name_label)
	col.add_child(StoryUi.paragraph(tr(u.desc_key), 12, Palette.IVORY_HINT))
	col.add_child(StoryUi.paragraph(tr(u.where_key()), 11, Palette.TEAM_GOLD))
	if not unlocked:
		col.add_child(StoryUi.paragraph(UiUtil.fmt("UPG_NEEDS", [tr(StoryProgress.upgrade(u.requires).name_key)]), 11, Palette.IVORY_MUTED))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	col.add_child(foot)
	if owned:
		foot.add_child(UiUtil.spaced_label(tr("NEST_HUB_OWNED").to_upper(), "SectionLabel", 12, Palette.TEAM_GOLD, 1.4))
		return panel
	var cost := UiUtil.label(UiUtil.fmt("NEST_HUB_COST", [u.cost]), "MonoHeavyLabel", 13, Palette.BRASS_BRIGHT if affordable else Palette.IVORY_MUTED)
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(cost)
	var buy_button: Control = StoryUi.deploy_button(tr("NEST_HUB_BUY") if affordable or not unlocked else tr("NEST_HUB_NEED"))
	buy_button.set("disabled", not affordable)
	buy_button.modulate.a = 1.0 if affordable else 0.5
	buy_button.connect("pressed", _on_buy_pressed.bind(u.id))
	foot.add_child(buy_button)
	buy_buttons[u.id] = buy_button
	return panel


## Little skein of silk (the silk counter icon).
class SilkIcon:
	extends Control

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.46
		draw_circle(c, r, Color("#eceae4"))
		draw_arc(c, r, 0.0, TAU, 24, Color("#8f96a3"), 1.4, true)
		for i in 4:
			var a: float = float(i) * 0.8 + 0.3
			draw_arc(c, r * (0.35 + 0.15 * float(i)), a, a + 2.4, 12, Color("#9aa2b0"), 1.0, true)


## Round badge of an upgrade, drawn from its effect: a heart (HP), a spike (damage), the nest (nest HP), a flame (warm silk), two threads
## (extra web), a pouch (ammo), a heart with a plus (extra heart), a drill (dig speed) or wings (long flight).
class UpgradeIcon:
	extends Control
	var effect: String = ""

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color("#26325a"))
		draw_arc(c, r - 1.0, 0.0, TAU, 24, Color(Palette.BRASS, 0.8), 1.6, true)
		var k: float = r / 19.0
		match effect:
			"MAX_HP_PCT":
				var pts := PackedVector2Array()
				for i in 20:
					var a: float = float(i) / 20.0 * TAU
					pts.append(c + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * k * 0.55 + Vector2(0.0, -1.0))
				draw_colored_polygon(pts, Color("#ff6b6b"))
			"DAMAGE_PCT":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12) * k, c + Vector2(4, -2) * k, c + Vector2(12, 0) * k, c + Vector2(4, 3) * k, c + Vector2(0, 12) * k, c + Vector2(-4, 3) * k, c + Vector2(-12, 0) * k, c + Vector2(-4, -2) * k]), Color("#d88aff"))
			"NEST_HP":
				draw_colored_polygon(NestArt.outline(c + Vector2(0, 1), Vector2(26, 22) * k), Color("#e8eef5"))
				draw_line(c + Vector2(-9, -12) * k, c + Vector2(9, -12) * k, Color("#8d5a2b"), 2.4)
			"WARM_SILK":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13) * k, c + Vector2(7, -2) * k, c + Vector2(5, 9) * k, c + Vector2(0, 12) * k, c + Vector2(-5, 9) * k, c + Vector2(-7, -2) * k]), Color("#ff9a2e"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3) * k, c + Vector2(3, 3) * k, c + Vector2(0, 9) * k, c + Vector2(-3, 3) * k]), Color("#ffe27a"))
			"EXTRA_SILK_WEB":
				for dx in [-5.0, 5.0]:
					draw_arc(c + Vector2(float(dx) * k, 0.0), 9.0 * k, 0.0, TAU, 16, Color("#eceae4"), 2.0, true)
			"EXTRA_HEART":
				draw_circle(c + Vector2(-4, -3) * k, 5.5 * k, Color("#ff6b6b"))
				draw_circle(c + Vector2(4, -3) * k, 5.5 * k, Color("#ff6b6b"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0) * k, c + Vector2(9, 0) * k, c + Vector2(0, 11) * k]), Color("#ff6b6b"))
				draw_line(c + Vector2(0, -2) * k, c + Vector2(0, 5) * k, Color("#ffffff"), 2.0)
				draw_line(c + Vector2(-3.5, 1.5) * k, c + Vector2(3.5, 1.5) * k, Color("#ffffff"), 2.0)
			"FAST_DIG":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 8) * k, c + Vector2(10, 8) * k, c + Vector2(4, -4) * k, c + Vector2(-4, -4) * k]), Color("#8d5a2b"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13) * k, c + Vector2(5, -4) * k, c + Vector2(-5, -4) * k]), Color("#d8d2c4"))
			"LONG_FLIGHT":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0) * k, c + Vector2(-13, -8) * k, c + Vector2(-9, 7) * k]), Color("#c9d4ee"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0) * k, c + Vector2(13, -8) * k, c + Vector2(9, 7) * k]), Color("#c9d4ee"))
			_:
				draw_circle(c + Vector2(0, 3) * k, 9.0 * k, Color("#c89b52"))
				draw_line(c + Vector2(-5, -6) * k, c + Vector2(5, -6) * k, Color("#7d5535"), 3.0)


## Drag-to-scroll for the card list that works wherever the drag starts. A ScrollContainer only drags on the events that reach it, and
## the cards' buy buttons stop them, so the list could only be dragged by the thin gaps between cards. This runs in `_input`, before the
## controls: past DRAG_THRESHOLD the list follows the finger (or the held mouse), the motion is eaten, a fling keeps gliding, and `moved`
## stays true until the end of the frame of the release so the button under the finger does not buy. The mouse wheel and the touchpad pan
## scroll it too (also over a button).
class DragScroll:
	extends Node

	## Travel (logical units of the list) before a press becomes a drag: below it the press stays a tap.
	const DRAG_THRESHOLD := 12.0
	const WHEEL_STEP := 64.0
	## How fast a fling slows down (1/s) and the speed under which it stops (units/s).
	const FRICTION := 5.0
	const MIN_FLING := 30.0

	var scroll: ScrollContainer
	## True while the current (or just released) press scrolled the list: the tap it ends is not a button press.
	var moved: bool = false
	var _down: bool = false
	var _touch: bool = false
	var _dragging: bool = false
	var _travel: float = 0.0
	var _pos: float = 0.0
	var _velocity: float = 0.0
	var _frame_dy: float = 0.0

	func _input(event: InputEvent) -> void:
		if not is_instance_valid(scroll) or not scroll.is_visible_in_tree():
			return
		var touch := event as InputEventScreenTouch
		var mb := event as InputEventMouseButton
		var screen_drag := event as InputEventScreenDrag
		var motion := event as InputEventMouseMotion
		var pan := event as InputEventPanGesture
		if touch != null and touch.index == 0:
			_press(touch.pressed, true, event)
		elif mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			_press(mb.pressed, false, event)
		elif mb != null and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and _inside(event):
			if mb.pressed:
				var step: float = WHEEL_STEP * (mb.factor if mb.factor > 0.0 else 1.0)
				scroll_by(step if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -step)
			get_viewport().set_input_as_handled()
		elif pan != null and _inside(event):
			scroll_by(pan.delta.y * scroll.size.y / 8.0)
			get_viewport().set_input_as_handled()
		elif _down and ((screen_drag != null and screen_drag.index == 0 and _touch) or (motion != null and not _touch and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)):
			var local: InputEvent = scroll.make_input_local(event)
			var dy: float = (local as InputEventScreenDrag).relative.y if screen_drag != null else (local as InputEventMouseMotion).relative.y
			_travel += absf(dy)
			if not _dragging and _travel >= DRAG_THRESHOLD:
				_dragging = true
				moved = true
				_pos = float(scroll.scroll_vertical)
			if _dragging:
				_set_pos(_pos - dy)
				_frame_dy += dy
				get_viewport().set_input_as_handled()

	## A press or release of the first finger (`touch`) or the left mouse button. Only one source drives a gesture: a touch also arrives
	## as an emulated mouse event, which is then ignored.
	func _press(pressed: bool, touch: bool, event: InputEvent) -> void:
		if pressed:
			if _down or not _inside(event):
				return
			_down = true
			_touch = touch
			_dragging = false
			moved = false
			_travel = 0.0
			_velocity = 0.0
			_frame_dy = 0.0
		elif _down and _touch == touch:
			_down = false
			if _dragging:
				_dragging = false
				_pos = float(scroll.scroll_vertical)
				_clear_moved.call_deferred()
			else:
				_velocity = 0.0

	func _clear_moved() -> void:
		if not _down:
			moved = false

	func _inside(event: InputEvent) -> bool:
		var p: Variant = scroll.make_input_local(event).get("position")
		return p is Vector2 and Rect2(Vector2.ZERO, scroll.size).has_point(p)

	## Scrolls the list by `amount` units (positive = down), clamped to its ends.
	func scroll_by(amount: float) -> void:
		_velocity = 0.0
		_pos = float(scroll.scroll_vertical)
		_set_pos(_pos + amount)

	func _set_pos(p: float) -> void:
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		var top: float = maxf(0.0, bar.max_value - bar.page)
		_pos = clampf(p, 0.0, top)
		if _pos <= 0.0 or _pos >= top:
			_velocity = 0.0
		scroll.scroll_vertical = roundi(_pos)

	func _process(delta: float) -> void:
		if not is_instance_valid(scroll):
			return
		if _down and _dragging:
			_velocity = lerpf(_velocity, _frame_dy / maxf(delta, 0.001), 0.5)
			_frame_dy = 0.0
		elif not _down and absf(_velocity) > MIN_FLING and scroll.scroll_vertical == roundi(_pos): # moved by something else: stop
			_set_pos(_pos - _velocity * delta)
			_velocity *= exp(-FRICTION * delta)
		else:
			_velocity = 0.0
