## "Rotate your device" overlay: shown on a portrait phone until dismissed (original updateRotateDeviceOverlay, main.js:20-31).
## Web only: the fullscreen button also asks the browser to lock the landscape orientation (guarded, errors swallowed).
class_name RotateOverlay
extends Control

signal dismissed

## True while the card is visible (the combat timer must not count down then).
var is_open: bool = false
var dismissed_flag: bool = false
## Force the phone check in tests.
var force_phone: bool = false


func _ready() -> void:
	theme = UiUtil.get_theme()
	add_to_group("rotate_overlay")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## True when `viewport_size` is portrait as the original defines it (height > 1.04 width and width <= 880).
static func is_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x * 1.04 and viewport_size.x <= 880.0


func _is_phone() -> bool:
	return force_phone or UiUtil.touch_seen or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _process(_delta: float) -> void:
	var portrait: bool = is_portrait(get_viewport_rect().size)
	if not portrait:
		dismissed_flag = false
	var want: bool = portrait and _is_phone() and not dismissed_flag
	if want != is_open:
		is_open = want
		visible = want


func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		dismiss()
		get_viewport().set_input_as_handled()


## Hides the card until the device is rotated back to landscape and to portrait again.
func dismiss() -> void:
	dismissed_flag = true
	is_open = false
	visible = false
	dismissed.emit()


func _on_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){try{var d=document.documentElement;var p=d.requestFullscreen?d.requestFullscreen():null;var lock=function(){try{screen.orientation.lock('landscape').catch(function(){});}catch(e){}};if(p&&p.then){p.then(lock,lock);}else{lock();}}catch(e){}})();", true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	dismiss()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(24.0 / 255.0, 29.0 / 255.0, 39.0 / 255.0, 0.97)
	sb.border_color = Palette.BRASS_BRIGHT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.x = 340
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var icon_wrap := CenterContainer.new()
	icon_wrap.add_child(RotatePhoneIcon.new())
	col.add_child(icon_wrap)
	var kicker: Label = UiUtil.spaced_label(tr("ROTATE_KICKER"), "TitleLabel", 12, Palette.KICKER_ORANGE, 3.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	var title: Label = UiUtil.spaced_label(tr("ROTATE_TITLE"), "TitleBlackLabel", 17, Palette.BRASS_BRIGHT, 1.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_color_override("default_color", Palette.IVORY_MUTED)
	body.add_theme_font_size_override("normal_font_size", 12)
	body.text = "[center]%s[/center]" % tr("ROTATE_BODY").replace("[b]", "[color=#f2ecdf]").replace("[/b]", "[/color]")
	col.add_child(body)
	var deploy: ChamferButton = ChamferButton.make_deploy()
	deploy.padding = Vector4(18, 10, 18, 10)
	var dl: Label = UiUtil.spaced_label(tr("ROTATE_BTN_FULLSCREEN").to_upper(), "TitleBlackLabel", 12, Color("#0b0d12"), 1.0)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deploy.add_child(dl)
	deploy.pressed.connect(_on_fullscreen)
	deploy.name = "FullscreenButton"
	col.add_child(deploy)
	var cont := Button.new()
	cont.theme_type_variation = "CmdButton"
	cont.text = tr("ROTATE_BTN_CONTINUE").to_upper()
	cont.name = "ContinueButton"
	cont.pressed.connect(dismiss)
	col.add_child(cont)
