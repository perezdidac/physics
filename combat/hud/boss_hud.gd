## Boss HUD (works for any BossDef): the big boss health bar with its name, title and phase pips at the top centre (compact on phones),
## the line with the announced intent, a "VULNERABLE!" tag, and the one-shot moments: intro banner, phase-change flash, defeat banner.
## Contract: `bind(sim)` with a CombatSim; it stays hidden when the level has no boss. Reads boss, boss_def, boss_phase, boss_state and
## boss_intent, and listens to boss_changed, boss_intent_changed, boss_phase_changed and boss_defeated.
class_name BossHud
extends Control

## Seconds the intro banner stays (before the fade).
const INTRO_HOLD: float = 2.6
const BANNER_HOLD: float = 1.8
const NARROW_WIDTH := 820.0

var sim: Variant = null
var bar: BossBar
var name_label: Label
var title_label: Label
var tag_label: Label
var intent_label: Label
var panel: PanelContainer
var banner: PanelContainer
var banner_kicker: Label
var banner_text: Label
var banner_sub: Label
var flash: ColorRect
## Last phase / state the HUD showed (the tests read them).
var shown_phase: int = 0
var _compact: bool = false
var _banner_tween: Tween
var _flash_tween: Tween
var _top: float = -1.0


func _ready() -> void:
	theme = UiUtil.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("boss_hud")
	_build()
	get_viewport().size_changed.connect(_on_resized)
	visible = false


## Connects the HUD to the simulation; with no boss in the level it stays hidden.
func bind(new_sim: Variant) -> void:
	sim = new_sim
	if sim == null or UiUtil.prop(sim, "boss_def") == null:
		visible = false
		return
	for sig in ["boss_changed", "boss_intent_changed"]:
		if sim.has_signal(sig):
			sim.connect(sig, refresh)
	if sim.has_signal("boss_phase_changed"):
		sim.boss_phase_changed.connect(_on_phase_changed)
	if sim.has_signal("boss_defeated"):
		sim.boss_defeated.connect(_on_defeated)
	visible = true
	refresh()
	shown_phase = int(UiUtil.prop(sim, "boss_phase", 1))
	var def: Variant = UiUtil.prop(sim, "boss_def")
	show_banner(tr("BOSS_BANNER_KICKER"), tr(str(UiUtil.prop(def, "name_key", ""))).to_upper(), tr(str(UiUtil.prop(def, "title_key", ""))), Palette.TEAM_CRIMSON, INTRO_HOLD)


func _on_resized() -> void:
	if UiUtil.is_compact(get_viewport_rect().size) != _compact:
		_build()
		refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	var y: float = _top_offset()
	if not is_equal_approx(y, _top):
		_top = y
		panel.offset_top = y


## Y of the bar: just under the timer and wind panels of the TopHud (under its squad rows on a narrow screen).
func _top_offset() -> float:
	var top: Node = get_tree().get_first_node_in_group("top_hud") if is_inside_tree() else null
	if top == null or top.get("wind_track") == null:
		return 96.0
	var node: Node = top.get("wind_track")
	var margin: Control = null
	while node != null and node != top:
		if node.get_parent() is MarginContainer:
			margin = node.get_parent() as MarginContainer
			break
		node = node.get_parent()
	if margin == null or not (node is Control):
		return 96.0
	var narrow: bool = top.is_narrow() if top.has_method("is_narrow") else get_viewport_rect().size.x < NARROW_WIDTH
	return _global_bottom(margin if narrow else node as Control) + 6.0


## Bottom edge of `ctrl` on screen, counting the scale of the TopHud's panels (get_global_rect ignores it).
func _global_bottom(ctrl: Control) -> float:
	return (ctrl.get_global_transform() * Rect2(Vector2.ZERO, ctrl.size)).end.y


# ---- build -------------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	_compact = UiUtil.is_compact(vp)
	_top = -1.0
	panel = PanelContainer.new()
	panel.theme_type_variation = "GlassPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = clampf(vp.x * (0.34 if _compact else 0.36), 250.0, 460.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 96.0
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2 if _compact else 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	name_label = UiUtil.spaced_label("", "TitleLabel", 12 if _compact else 15, Palette.BRASS_BRIGHT, 1.0)
	head.add_child(name_label)
	title_label = UiUtil.label("", "MutedLabel", 10 if _compact else 11)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	head.add_child(title_label)
	tag_label = UiUtil.spaced_label("", "SectionLabel", 10 if _compact else 12, Palette.BRASS_BRIGHT, 1.0)
	head.add_child(tag_label)
	bar = BossBar.new()
	bar.custom_minimum_size = Vector2(120.0, 12.0 if _compact else 18.0)
	box.add_child(bar)
	intent_label = UiUtil.label("", "HintLabel", 11 if _compact else 12, Palette.FT_ORANGE)
	intent_label.clip_text = true
	intent_label.visible = false
	box.add_child(intent_label)
	_build_overlays(vp)


func _build_overlays(vp: Vector2) -> void:
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.82, 0.5, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	banner = PanelContainer.new()
	banner.theme_type_variation = "GlassPanel"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.3
	banner.anchor_bottom = 0.3
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.custom_minimum_size.x = clampf(vp.x * 0.5, 240.0, 560.0)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(col)
	banner_kicker = UiUtil.spaced_label("", "SectionLabel", 10 if _compact else 12, Palette.TEAM_CRIMSON, 2.0)
	banner_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(banner_kicker)
	banner_text = UiUtil.spaced_label("", "TitleBlackLabel", 22 if _compact else 36, Palette.BRASS_BRIGHT, 2.0)
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(banner_text)
	banner_sub = UiUtil.label("", "MutedLabel", 11 if _compact else 14)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(banner_sub)
	banner.visible = false
	add_child(banner)


# ---- updates -----------------------------------------------------------------------------------

## Reads the boss from the sim: name, health, phase, vulnerable tag and the intent line.
func refresh() -> void:
	var def: Variant = UiUtil.prop(sim, "boss_def")
	var boss: Variant = UiUtil.prop(sim, "boss")
	if def == null or boss == null or bar == null:
		return
	name_label.text = tr(str(UiUtil.prop(def, "name_key", ""))).to_upper()
	title_label.text = tr(str(UiUtil.prop(def, "title_key", "")))
	var hp: float = maxf(0.0, float(UiUtil.prop(boss, "hp", 0.0)))
	var max_hp: float = maxf(1.0, float(UiUtil.prop(boss, "max_hp", 1.0)))
	bar.fraction = clampf(hp / max_hp, 0.0, 1.0)
	bar.hp_text = "%d / %d" % [ceili(hp), int(max_hp)]
	bar.phase_marks.assign(UiUtil.prop(def, "phases", []))
	bar.phase = int(UiUtil.prop(sim, "boss_phase", 1))
	var vul: bool = (UiUtil.prop(def, "vulnerable_states", []) as Array).has(str(UiUtil.prop(sim, "boss_state", ""))) and hp > 0.0
	bar.vulnerable = vul
	tag_label.text = tr("BOSS_VULNERABLE").to_upper() if vul else ""
	var intent: Dictionary = UiUtil.prop(sim, "boss_intent", {})
	var label: String = str(intent.get("label", ""))
	intent_label.visible = label != ""
	intent_label.text = label


func _on_phase_changed(phase: int) -> void:
	refresh()
	shown_phase = phase
	flash_screen(Color(1.0, 0.7, 0.3, 0.55))
	show_banner(tr("BOSS_BANNER_KICKER"), UiUtil.fmt("BOSS_PHASE_BANNER", [phase]).to_upper(), tr("FT_BOSS_PHASE"), Palette.FT_ORANGE, BANNER_HOLD)


func _on_defeated() -> void:
	refresh()
	flash_screen(Color(1.0, 0.9, 0.5, 0.7))
	var def: Variant = UiUtil.prop(sim, "boss_def")
	show_banner(tr("BOSS_BANNER_KICKER"), tr("BOSS_DEFEATED_BANNER").to_upper(), tr(str(UiUtil.prop(def, "name_key", ""))), Palette.BRASS_BRIGHT, 3.2)


## A quick full-screen colour flash that fades out.
func flash_screen(color: Color) -> void:
	if flash == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "color:a", 0.0, 0.6)


## The centred banner: fades in, holds, fades out.
func show_banner(kicker: String, text: String, sub: String, color: Color, hold: float) -> void:
	if banner == null:
		return
	banner_kicker.text = kicker.to_upper()
	banner_text.text = text
	banner_text.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	banner.visible = true
	banner.modulate.a = 0.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func() -> void: banner.visible = false)
