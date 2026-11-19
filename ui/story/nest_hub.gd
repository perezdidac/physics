## El Bolsó, the winter hub: spend the silk earned in the levels on upgrades (cards with name, description, cost and owned / buy) in a cosy
## nest. Opened from the story map once the NEST stage is open. Keyboard: Tab / arrows move between the cards, Enter buys, Esc goes back.
extends Control

## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var back_button: Button
var silk_label: Label
## One buy button per upgrade id (the owned ones have none).
var buy_buttons: Dictionary = {}
## One card per upgrade, in shop order.
var cards: Array[Control] = []


func _ready() -> void:
	theme = UiUtil.get_theme()
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


## Buys the upgrade with silk and redraws; false when it cannot be bought.
func buy(id: String) -> bool:
	if not StoryProgress.buy(id):
		UiUtil.sfx("tick")
		return false
	UiUtil.sfx("stone_build")
	_build()
	return true


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		UiUtil.touch_seen = true


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_to_map()


func _build() -> void:
	for c in get_children():
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
	outer.add_child(StoryUi.make_header("", tr("NEST_HUB_TITLE"), tr("NEST_HUB_SUB"), back_button, small))
	outer.add_child(_silk_pill(small))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2 if (wide and vp.x >= 1100.0) or (not wide and vp.x >= 700.0) else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for u in StoryProgress.upgrades():
		var card: Control = _make_card(u, small)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		cards.append(card)
	if not small:
		outer.add_child(StoryUi.paragraph(tr("NEST_HUB_HINT"), 11, Palette.IVORY_HINT))
	TouchMetrics.fit_taps(frame, real_vp, vp.y)
	add_child(load("res://ui/menus/RotateOverlay.tscn").instantiate())
	_focus_first.call_deferred()


func _focus_first() -> void:
	for id: String in buy_buttons:
		var b: ChamferButton = buy_buttons[id]
		if b.is_inside_tree() and not b.disabled:
			b.grab_focus()
			return
	if back_button != null and back_button.is_inside_tree():
		back_button.grab_focus()


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
	var buy_button: ChamferButton = StoryUi.deploy_button(tr("NEST_HUB_BUY") if affordable or not unlocked else tr("NEST_HUB_NEED"))
	buy_button.disabled = not affordable
	buy_button.modulate.a = 1.0 if affordable else 0.5
	buy_button.pressed.connect(buy.bind(u.id))
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
