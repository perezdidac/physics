## Builds ui/theme.tres (the one theme of the project). Run after changing styles:
##   godot --headless --path . -s res://ui/theme_builder.gd
extends SceneTree

const OUT := "res://ui/theme.tres"


func _init() -> void:
	var theme := Theme.new()
	var symbols: Font = load("res://assets/fonts/NotoSansMath-Regular.ttf")
	var f_title: FontVariation = _font("res://assets/fonts/Cinzel.ttf", 800, symbols)
	var f_title_black: FontVariation = _font("res://assets/fonts/Cinzel.ttf", 900, symbols)
	var f_body: FontVariation = _font("res://assets/fonts/PlusJakartaSans.ttf", 600, symbols)
	var f_body_bold: FontVariation = _font("res://assets/fonts/PlusJakartaSans.ttf", 800, symbols)
	var f_mono: FontVariation = _font("res://assets/fonts/JetBrainsMono.ttf", 700, symbols)
	var f_mono_heavy: FontVariation = _font("res://assets/fonts/JetBrainsMono.ttf", 800, symbols)
	theme.default_font = f_body
	theme.default_font_size = 13

	# Labels
	theme.set_color("font_color", "Label", Palette.IVORY)
	_label_variation(theme, "TitleLabel", f_title, 16, Palette.IVORY)
	_label_variation(theme, "TitleBlackLabel", f_title_black, 22, Palette.BRASS_BRIGHT)
	_label_variation(theme, "BodyBoldLabel", f_body_bold, 12, Palette.IVORY)
	_label_variation(theme, "MutedLabel", f_body, 11, Palette.IVORY_MUTED)
	_label_variation(theme, "MonoLabel", f_mono, 11, Palette.IVORY)
	_label_variation(theme, "MonoHeavyLabel", f_mono_heavy, 11, Palette.BRASS_BRIGHT)
	_label_variation(theme, "SectionLabel", f_mono, 11, Palette.BRASS)
	_label_variation(theme, "HintLabel", f_mono, 11, Palette.IVORY_HINT)

	# Secondary button family: same chamfered shape and Cinzel black lettering as the gold deploy button, dark fill, brass border.
	var f_cmd: FontVariation = f_title_black.duplicate()
	f_cmd.spacing_glyph = 1
	_cmd_variation(theme, "CmdButton", f_cmd, 12, Vector2(16, 8))
	_cmd_variation(theme, "CmdIconButton", f_cmd, 14, Vector2(8, 6))
	_cmd_variation(theme, "NavButton", f_cmd, 14, Vector2(6, 4))
	_cmd_variation(theme, "FuseButton", f_cmd, 12, Vector2(8, 3))

	# Mobile gamepad button (.mc-btn)
	theme.add_type("MobileButton")
	theme.set_type_variation("MobileButton", "Button")
	theme.set_font("font", "MobileButton", f_body_bold)
	theme.set_font_size("font_size", "MobileButton", 12)
	theme.set_color("font_color", "MobileButton", Palette.IVORY)
	theme.set_color("font_hover_color", "MobileButton", Palette.IVORY)
	theme.set_color("font_pressed_color", "MobileButton", Palette.BRASS_BRIGHT)
	var mc_normal: StyleBoxFlat = _flat(Color(18.0 / 255.0, 23.0 / 255.0, 32.0 / 255.0, 0.95), Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.52), 8, 1.5, Vector2(8, 4))
	var mc_pressed: StyleBoxFlat = _flat(Color(120.0 / 255.0, 86.0 / 255.0, 30.0 / 255.0, 0.96), Palette.BRASS_BRIGHT, 8, 1.5, Vector2(8, 4))
	theme.set_stylebox("normal", "MobileButton", mc_normal)
	theme.set_stylebox("hover", "MobileButton", mc_normal)
	theme.set_stylebox("pressed", "MobileButton", mc_pressed)
	theme.set_stylebox("focus", "MobileButton", StyleBoxEmpty.new())

	# Weapon pill navigation (.wp-nav-btn): round

	# Weapon pill toggle (#weapon-toggle-btn)
	theme.add_type("PillButton")
	theme.set_type_variation("PillButton", "Button")
	theme.set_stylebox("normal", "PillButton", _flat(Palette.GLASS_PILL, Palette.BRASS_BORDER_SOFT, 999, 1, Vector2(12, 4)))
	theme.set_stylebox("hover", "PillButton", _flat(Palette.CMD_BG_HOVER, Palette.BRASS_BRIGHT, 999, 1, Vector2(12, 4)))
	theme.set_stylebox("pressed", "PillButton", _flat(Palette.CMD_BG_HOVER, Palette.BRASS_BRIGHT, 999, 1, Vector2(12, 4)))
	theme.set_stylebox("focus", "PillButton", StyleBoxEmpty.new())

	# Fuse picker button (.fuse-btn)

	# Panels
	theme.add_type("GlassPanel")
	theme.set_type_variation("GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", _flat(Palette.GLASS, Palette.BRASS_BORDER_GLASS, 14, 1, Vector2(10, 7)))
	theme.add_type("PillPanel")
	theme.set_type_variation("PillPanel", "PanelContainer")
	theme.set_stylebox("panel", "PillPanel", _flat(Palette.GLASS_PILL, Color(240.0 / 255.0, 195.0 / 255.0, 110.0 / 255.0, 0.42), 999, 1, Vector2(14, 6)))
	theme.add_type("RackPanel")
	theme.set_type_variation("RackPanel", "PanelContainer")
	theme.set_stylebox("panel", "RackPanel", _flat(Color(14.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.94), Palette.BRASS_BORDER_RACK, 16, 1.5, Vector2(8, 8)))

	# Line edit (name inputs)
	theme.set_font("font", "LineEdit", f_body_bold)
	theme.set_font_size("font_size", "LineEdit", 12)
	theme.set_color("font_color", "LineEdit", Palette.IVORY)
	theme.set_color("caret_color", "LineEdit", Palette.BRASS_BRIGHT)
	theme.set_stylebox("normal", "LineEdit", _flat(Color(1, 1, 1, 0.05), Color(242.0 / 255.0, 236.0 / 255.0, 223.0 / 255.0, 0.18), 6, 1, Vector2(8, 4)))
	theme.set_stylebox("focus", "LineEdit", _flat(Color(1, 1, 1, 0.08), Palette.BRASS_BRIGHT, 6, 1, Vector2(8, 4)))

	# Option button (hat select) and its popup
	theme.set_font("font", "OptionButton", f_body_bold)
	theme.set_font_size("font_size", "OptionButton", 11)
	theme.set_color("font_color", "OptionButton", Palette.IVORY)
	theme.set_color("font_hover_color", "OptionButton", Palette.BRASS_BRIGHT)
	theme.set_color("font_focus_color", "OptionButton", Palette.BRASS_BRIGHT)
	theme.set_color("font_pressed_color", "OptionButton", Palette.BRASS_BRIGHT)
	var sel_normal: StyleBoxFlat = _flat(Color("#141821"), Palette.BRASS_DIM, 6, 1, Vector2(8, 4))
	theme.set_stylebox("normal", "OptionButton", sel_normal)
	theme.set_stylebox("hover", "OptionButton", _flat(Color("#1b202b"), Palette.BRASS, 6, 1, Vector2(8, 4)))
	theme.set_stylebox("pressed", "OptionButton", _flat(Color("#1b202b"), Palette.BRASS_BRIGHT, 6, 1, Vector2(8, 4)))
	theme.set_stylebox("focus", "OptionButton", _focus(6))
	theme.set_stylebox("panel", "PopupMenu", _flat(Color("#141821"), Palette.BRASS, 6, 1, Vector2(4, 4)))
	theme.set_stylebox("hover", "PopupMenu", _flat(Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.28), Color.TRANSPARENT, 4, 0, Vector2(4, 2)))
	theme.set_font("font", "PopupMenu", f_body_bold)
	theme.set_font_size("font_size", "PopupMenu", 11)
	theme.set_color("font_color", "PopupMenu", Palette.IVORY)
	theme.set_color("font_hover_color", "PopupMenu", Palette.BRASS_BRIGHT)

	# Scrollbars: thin brass
	var grab: StyleBoxFlat = _flat(Palette.BRASS_DIM, Color.TRANSPARENT, 4, 0, Vector2(2, 2))
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _flat(Palette.BRASS, Color.TRANSPARENT, 4, 0, Vector2(2, 2)))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _flat(Palette.BRASS_BRIGHT, Color.TRANSPARENT, 4, 0, Vector2(2, 2)))
	theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())

	var err: int = ResourceSaver.save(theme, OUT)
	print("theme saved: ", OUT, " err=", err)
	quit(0 if err == OK else 1)


func _font(path: String, weight: int, fallback: Font) -> FontVariation:
	var base: Font = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	fv.fallbacks = [fallback]
	return fv


func _label_variation(theme: Theme, type_name: String, font: Font, size: int, color: Color) -> void:
	theme.add_type(type_name)
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)


func _flat(bg: Color, border: Color, radius: int, border_w: float, margin: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(int(ceilf(border_w)))
	sb.content_margin_left = margin.x
	sb.content_margin_right = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_bottom = margin.y
	sb.anti_aliasing = true
	return sb


func _focus(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.draw_center = false
	sb.border_color = Palette.FOCUS_OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.expand_margin_left = 2.0
	sb.expand_margin_right = 2.0
	sb.expand_margin_top = 2.0
	sb.expand_margin_bottom = 2.0
	return sb


## Chamfered secondary button: dark gradient, brass border, ivory text; hover/pressed brighten, focus adds a ring.
func _cmd_variation(theme: Theme, type_name: String, font: Font, size: int, margin: Vector2) -> void:
	theme.add_type(type_name)
	theme.set_type_variation(type_name, "Button")
	theme.set_font("font", type_name, font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, Palette.IVORY)
	theme.set_color("font_hover_color", type_name, Palette.BRASS_BRIGHT)
	theme.set_color("font_pressed_color", type_name, Palette.BRASS_BRIGHT)
	theme.set_color("font_focus_color", type_name, Palette.BRASS_BRIGHT)
	theme.set_color("font_hover_pressed_color", type_name, Palette.BRASS_BRIGHT)
	theme.set_color("font_disabled_color", type_name, Color(Palette.IVORY, 0.45))
	var base_top := Color(0.105, 0.125, 0.17, 0.96)
	var base_bottom := Color(0.05, 0.062, 0.088, 0.98)
	theme.set_stylebox("normal", type_name, _chamfer(base_top, base_bottom, Palette.BRASS, false, margin))
	theme.set_stylebox("hover", type_name, _chamfer(base_top.lightened(0.16), base_bottom.lightened(0.12), Palette.BRASS_BRIGHT, false, margin))
	theme.set_stylebox("pressed", type_name, _chamfer(Color(0.35, 0.25, 0.1, 0.98), Color(0.2, 0.14, 0.05, 0.98), Palette.BRASS_BRIGHT, false, margin))
	theme.set_stylebox("hover_pressed", type_name, _chamfer(Color(0.35, 0.25, 0.1, 0.98), Color(0.2, 0.14, 0.05, 0.98), Palette.BRASS_BRIGHT, false, margin))
	theme.set_stylebox("disabled", type_name, _chamfer(Color(base_top, 0.5), Color(base_bottom, 0.5), Color(Palette.BRASS, 0.4), false, margin))
	theme.set_stylebox("focus", type_name, _chamfer(Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, true, Vector2.ZERO))


func _chamfer(top: Color, bottom: Color, border: Color, ring: bool, margin: Vector2) -> StyleBox:
	var sb: StyleBox = preload("res://ui/widgets/chamfer_style_box.gd").new()
	sb.top = top
	sb.bottom = bottom
	sb.border = border
	sb.ring = ring
	sb.border_width = 1.5
	sb.cuts = Vector4(0, 8, 0, 8)
	sb.content_margin_left = margin.x
	sb.content_margin_right = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_bottom = margin.y
	return sb
