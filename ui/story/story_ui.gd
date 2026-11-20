## Layout helpers shared by the three story screens (map, level card, results).
class_name StoryUi
extends RefCounted

## Life stages of the whole campaign, in order (ids of LevelDef.stage).
const STAGES: Array[String] = ["EGG", "LARVA_EARLY", "LARVA", "NEST", "PROCESSION", "PUPA", "MOTH"]
const NARROW_WIDTH := 820.0


## Dark backdrop plus a big framed panel with a scroll area; returns [panel, scroll body VBox, footer HBox].
static func make_frame(host: Control, map_idx: int) -> Array:
	var vp: Vector2 = host.get_viewport_rect().size
	var small: bool = is_small(vp)
	var backdrop := MenuBackdrop.new()
	host.add_child(backdrop)
	backdrop.use_lobby_shade()
	backdrop.set_map(map_idx)
	# Phones (scaled UI) use the whole screen; desktop keeps the centred frame.
	var whole: bool = small or TouchMetrics.ui_scale(vp) > 1.0
	var side: float = 6.0 if whole else maxf(6.0, (vp.x - minf(1120.0, vp.x * 0.96)) * 0.5)
	var vert: float = 6.0 if whole else vp.y * 0.03
	var holder: Control = TouchMetrics.scaled_root(host, vp, Rect2(side, vert, vp.x - 2.0 * side, vp.y - 2.0 * vert))
	var frame := ChamferPanel.new()
	frame.cuts = Vector4(0, 18, 0, 18) if not whole else Vector4(0, 10, 0, 10)
	frame.padding = Vector4(14, 8, 14, 8) if small else Vector4(28, 22, 28, 22)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(frame)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8 if small else 14)
	frame.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.clip_contents = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8 if small else 14)
	scroll.add_child(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(footer)
	return [frame, body, footer]


## Screen header: kicker line, big title and an optional subtitle on the left; `right` (usually Back) on the right.
static func make_header(kicker: String, title: String, subtitle: String, right: Control, small: bool) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	if not kicker.is_empty():
		var k: Label = UiUtil.spaced_label(kicker.to_upper(), "SectionLabel", 11, Palette.KICKER_ORANGE, 1.4)
		k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(k)
	var h1: Label = UiUtil.spaced_label(title.to_upper(), "TitleBlackLabel", 17 if small else 24, Palette.BRASS_BRIGHT, 2.0)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(h1)
	if not subtitle.is_empty():
		var s: Label = UiUtil.label(subtitle, "MutedLabel", 11 if small else 12)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(s)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(right)
	return head


## Secondary button (theme CmdButton): chamfered like the gold deploy button, dark fill, brass border, upper-case label.
static func cmd_button(text: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "CmdButton"
	b.text = text.to_upper()
	return b


## Small icon-only / one-glyph button ("?", close, pause): the same chamfered look as `cmd_button` in a square.
static func icon_button(text: String, side: float = 0.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = "CmdIconButton"
	b.text = text
	if side > 0.0:
		b.custom_minimum_size = Vector2(side, side)
	return b


## Gold call-to-action button with a dark label.
static func deploy_button(text: String) -> ChamferButton:
	var b: ChamferButton = ChamferButton.make_deploy()
	var l: Label = UiUtil.spaced_label(text, "TitleBlackLabel", 13, Color("#0b0d12"), 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	return b


## Small brass section heading.
static func section(text: String, size: int = 11) -> Label:
	return UiUtil.spaced_label(text.to_upper(), "SectionLabel", size, Palette.BRASS, 1.4)


## Wrapping body text.
static func paragraph(text: String, size: int = 13, color: Color = Palette.IVORY) -> Label:
	var l: Label = UiUtil.label(text, "", size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Display name of a weapon id: the story key when it exists, else the classic WEAPON_<ID> key.
static func weapon_name(weapon_id: String) -> String:
	var key: String = "STORY_WEAPON_" + weapon_id
	var text: String = TranslationServer.translate(key)
	if text != key:
		return text
	return TranslationServer.translate("WEAPON_" + weapon_id)


## Translated text of a level key, filling the rounds count when the text has a placeholder.
static func level_text(key: String, level: LevelDef) -> String:
	var text: String = TranslationServer.translate(key)
	var shots: int = 0
	for id: String in level.player_arsenal:
		shots += maxi(0, int(level.player_arsenal[id]))
	text = text.replace("{need}", str(level.collect_need)).replace("{total}", str(level.collect_count)).replace("{hp}", str(level.anthill_hp)).replace("{shots}", str(shots))
	if text.contains("%d"):
		return text % level.survive_rounds
	return text


## Finds the level with `level_id` in the campaign (null when unknown).
static func find_level(level_id: String) -> LevelDef:
	for level in StoryProgress.levels():
		if level.id == level_id:
			return level
	return null


## True on narrow or phone-sized windows.
static func is_small(vp: Vector2) -> bool:
	var lvp: Vector2 = TouchMetrics.logical_size(vp)
	return UiUtil.is_compact(lvp) or lvp.x < NARROW_WIDTH


## Size of the viewport of `host` in the units its scaled layout uses (see TouchMetrics.ui_scale).
static func logical(host: Control) -> Vector2:
	return TouchMetrics.logical_size(host.get_viewport_rect().size)


## Height a tappable item needs (12 mm) in the units of the scaled layout.
static func tap_height(host: Control) -> float:
	return TouchMetrics.tap_min(host.get_viewport_rect().size)
