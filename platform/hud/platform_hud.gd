## HUD of the platformer: hearts and nutrients, pause button, pause menu, short hints, the end banner and the touch pad.
class_name PlatformHud
extends CanvasLayer

signal pause_requested
signal resume_requested
signal exit_requested

const INTRO_SECONDS: float = 2.2

var status: PlatformStatusBar
var pause_button: PlatformIconButton
var pad: PlatformTouchPad
var banner: Label
## Second line of the final banner ("and the cycle begins again").
var sub_banner: Label
## "La Vespa!" style announcement at the start of a boss level.
var intro_banner: Label
## Boss bar: label "Hatching in N s" over a bar that empties as the egg gets closer to hatching.
var boss_bar: PlatformBossBar
var hint: Label
var pause_panel: Control
var resume_button: ChamferButton
var exit_button: Button
var root: Control
var _hint_time: float = 0.0
var _banner_time: float = 0.0
## UI scale of the HUD texts and panels (TouchMetrics.ui_scale): 1 on desktop, more on a phone.
var _s: float = 1.0
## Top safe inset and the hint position last set (the hint keeps clear of the camera hole).
var _top_inset: float = 0.0
var _hint_low: bool = false
var _box: Control
var size_button: Button
var _intro_time: float = 0.0


func _init() -> void:
	layer = 10


func _ready() -> void:
	root = Control.new()
	root.theme = UiUtil.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	status = PlatformStatusBar.new()
	status.position = Vector2(14.0, 10.0)
	root.add_child(status)

	pause_button = PlatformIconButton.new()
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -70.0
	pause_button.offset_right = -14.0
	pause_button.offset_top = 12.0
	pause_button.offset_bottom = 68.0
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	root.add_child(pause_button)

	hint = UiUtil.label("", "", 17, Palette.IVORY)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.offset_top = 14.0
	hint.offset_bottom = 44.0
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.modulate.a = 0.0
	root.add_child(hint)

	banner = UiUtil.label("", "", 40, Palette.BRASS_BRIGHT)
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.02, 0.9))
	banner.add_theme_constant_override("outline_size", 8)
	banner.visible = false
	root.add_child(banner)

	sub_banner = UiUtil.label("", "", 22, Palette.IVORY)
	sub_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02, 0.9))
	sub_banner.add_theme_constant_override("outline_size", 6)
	sub_banner.visible = false
	root.add_child(sub_banner)

	boss_bar = PlatformBossBar.new()
	boss_bar.visible = false
	root.add_child(boss_bar)

	intro_banner = UiUtil.label("", "", 54, Palette.TEAM_GOLD)
	intro_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_banner.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.02, 0.95))
	intro_banner.add_theme_constant_override("outline_size", 10)
	intro_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_banner.visible = false
	root.add_child(intro_banner)

	pad = PlatformTouchPad.new()
	root.add_child(pad)
	_build_pause_panel()
	get_viewport().size_changed.connect(_layout)
	Options.button_size_changed.connect(_layout)
	_layout()


func _build_pause_panel() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	root.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Palette.OVERLAY_DARK
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	_box = box
	box.resized.connect(func() -> void: box.pivot_offset = box.size * 0.5)
	var title: Label = UiUtil.spaced_label(tr("PLAT_PAUSE_TITLE").to_upper(), "TitleBlackLabel", 30, Palette.BRASS_BRIGHT, 3.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	resume_button = StoryUi.deploy_button(tr("PLAT_RESUME"))
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume_button)
	size_button = StoryUi.cmd_button("")
	size_button.text = TouchMetrics.size_option_text()
	size_button.tooltip_text = tr("HUD_BTN_SIZE_TOOLTIP")
	size_button.pressed.connect(Options.cycle_button_size)
	Options.button_size_changed.connect(func() -> void: size_button.text = TouchMetrics.size_option_text())
	box.add_child(size_button)
	exit_button = StoryUi.cmd_button(tr("PLAT_EXIT"))
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	box.add_child(exit_button)


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_s = TouchMetrics.ui_scale(vp)
	var compact: bool = vp.y / _s < 400.0
	var pb: float = TouchMetrics.top_button(vp) if pad.is_shown() else 56.0
	var ins: Vector4 = TouchMetrics.safe_insets(vp) # rounded corners / camera hole
	_top_inset = ins.y
	status.position = Vector2(14.0 + ins.x, 10.0 + ins.y)
	pause_button.custom_minimum_size = Vector2(pb, pb)
	pause_button.offset_left = -(14.0 + pb + ins.z)
	pause_button.offset_right = -(14.0 + ins.z)
	pause_button.offset_top = 12.0 + ins.y
	pause_button.offset_bottom = 12.0 + ins.y + pb
	status.heart_size = 24.0 if compact else 30.0
	status.update_minimum_size()
	status.scale = Vector2(_s, _s)
	status.queue_redraw()
	banner.add_theme_font_size_override("font_size", int((28 if compact else 40) * _s))
	sub_banner.add_theme_font_size_override("font_size", int((16 if compact else 22) * _s))
	sub_banner.offset_top = vp.y * 0.14 + (46.0 if compact else 66.0) * _s
	intro_banner.add_theme_font_size_override("font_size", int((38 if compact else 56) * _s))
	boss_bar.compact = compact
	boss_bar.scale = Vector2(_s, _s)
	boss_bar.queue_redraw()
	hint.add_theme_font_size_override("font_size", int((14 if compact else 17) * _s))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The hint sits between the hearts and the pause button, so a long line wraps instead of running under them.
	hint.offset_left = status.get_combined_minimum_size().x * _s + 20.0 + ins.x
	hint.offset_right = -(pb + 28.0 + ins.z)
	hint.offset_top = (76.0 if _hint_low else 14.0) * _s + ins.y
	hint.offset_bottom = hint.offset_top + 30.0 * _s
	if _box != null:
		_box.scale = Vector2(_s, _s)
		if TouchMetrics.active(vp):
			var tap: float = minf(TouchMetrics.tap_min(vp), vp.y / _s * 0.14)
			for b: Control in [resume_button, size_button, exit_button]:
				b.custom_minimum_size.y = tap


## Updates hearts and nutrients from the sim and fades the hint and banner.
func refresh(hearts: int, max_hearts: int, nutrients: int, total: int, delta: float) -> void:
	status.set_state(hearts, max_hearts, nutrients, total)
	if _hint_time > 0.0:
		_hint_time -= delta
		hint.modulate.a = clampf(_hint_time, 0.0, 1.0)
	if intro_banner.visible:
		_intro_time -= delta
		var k: float = 1.0 - clampf(_intro_time / INTRO_SECONDS, 0.0, 1.0)
		intro_banner.modulate.a = clampf(minf(k * 6.0, (1.0 - k) * 3.0), 0.0, 1.0)
		intro_banner.scale = Vector2.ONE * (1.0 + 0.25 * (1.0 - clampf(k * 5.0, 0.0, 1.0)))
		intro_banner.pivot_offset = intro_banner.size * 0.5
		if _intro_time <= 0.0:
			intro_banner.visible = false
	if banner.visible:
		_banner_time += delta
		banner.modulate.a = clampf(_banner_time * 2.0, 0.0, 1.0)
		sub_banner.modulate.a = clampf((_banner_time - 1.2) * 1.5, 0.0, 1.0)


## Shows `text` at the top for a few seconds.
func show_hint(text: String, seconds: float = 6.0, low: bool = false) -> void:
	_hint_low = low
	hint.offset_top = (76.0 if low else 14.0) * _s + _top_inset
	hint.offset_bottom = hint.offset_top + 30.0 * _s
	hint.text = text
	_hint_time = seconds
	hint.modulate.a = 1.0


## Big message at the end of the level (centred, or higher up while something happens in the middle).
func show_banner(text: String, won: bool, high: bool = false) -> void:
	banner.vertical_alignment = VERTICAL_ALIGNMENT_TOP if high else VERTICAL_ALIGNMENT_CENTER
	banner.offset_top = get_viewport().get_visible_rect().size.y * 0.14 if high else 0.0
	banner.text = text
	_hint_time = 0.0
	hint.modulate.a = 0.0
	banner.add_theme_color_override("font_color", Palette.BRASS_BRIGHT if won else Palette.FT_WINE)
	banner.modulate.a = 0.0
	_banner_time = 0.0
	banner.visible = true
	sub_banner.visible = false


## Shows `text` in the lower part of the screen after a short delay (the "cycle begins again" line of the ending).
func show_sub_banner(text: String) -> void:
	sub_banner.text = text
	sub_banner.modulate.a = 0.0
	sub_banner.visible = true


## Announces the boss with a big banner for `seconds`.
func show_intro(text: String, seconds: float = INTRO_SECONDS) -> void:
	intro_banner.text = text
	_intro_time = seconds
	intro_banner.modulate.a = 0.0
	intro_banner.visible = true


## Shows or updates the boss bar: `time_left` of `total` seconds until the egg hatches (or the pupa turns into a moth, or the
## moth lays her eggs: `mode` "", "DIG" or "FLY" picks the text and the little rider).
func set_boss_time(time_left: float, total: float, mode: String = "") -> void:
	boss_bar.visible = true
	boss_bar.rider = "pupa" if mode == "DIG" else "moth" if mode == "FLY" else "egg"
	var key: String = "PLAT_BOSS_BAR_PUPA" if mode == "DIG" else "PLAT_BOSS_BAR_MOTH" if mode == "FLY" else "PLAT_BOSS_BAR"
	boss_bar.set_time(time_left, total, tr(key))
	boss_bar.pivot_offset = Vector2(boss_bar.custom_minimum_size.x * 0.5, 0.0)


## Adapts the touch pad to the level mode ("", "DIG" or "FLY").
func set_mode(mode: String) -> void:
	pad.mode = mode
	pad.queue_redraw()


## Opens or closes the pause menu.
func set_paused(paused: bool) -> void:
	pause_panel.visible = paused
	if paused:
		pad.release_all()
		resume_button.grab_focus.call_deferred()
