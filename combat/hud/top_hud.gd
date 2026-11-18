## Top HUD: two squad panels (names, health bars), turn timer + status + round, wind meter, and the command strip (music, exit).
## The six hidden buttons of the original (silk web, procession, mode, re-roll map, map, options) are never shown there and are not built here.
## Contract: `bind(sim)` with a CombatSim (signals hud_changed, turn_started, game_over); everything is guarded if `sim` is null.
class_name TopHud
extends Control

## Emitted when a living caterpillar pip is clicked (CombatScreen switches worm or peeks with the camera, JS pip.onclick).
signal fighter_pip_pressed(fighter: Variant)
## Emitted when the exit button or Esc leaves the match (already routed to ScreenRouter unless `go_callable` is set).
signal exit_requested

## Must match CombatSim.Phase (docs/port_contracts.md section 2).
const PHASE_TURN_PLAY := 0
const PHASE_RETREAT := 1
const PHASE_ACTION_WAIT := 2
const PHASE_TURN_DELAY := 3
const PHASE_GAME_OVER := 4
const NARROW_WIDTH := 820.0

var sim: Variant = null
## Replaceable in tests: called with the target screen name instead of ScreenRouter.go.
var go_callable: Callable = Callable()
var timer_label: Label
var status_label: Label
var round_label: Label
var wind_track: WindTrack
var wind_label: Label
var hp_labels: Array[Label] = []
var pip_grids: Array[GridContainer] = []
var music_button: Button
var exit_button: Button
var _narrow: bool = false
var _compact: bool = false
var _timer_color: Color = Color.TRANSPARENT


func _ready() -> void:
	theme = UiUtil.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("top_hud")
	_build()
	get_viewport().size_changed.connect(_on_resized)
	refresh()


## Connects the HUD to the simulation. Safe to call once; passing null keeps the placeholder values.
func bind(new_sim: Variant) -> void:
	sim = new_sim
	if sim == null:
		return
	if sim.has_signal("hud_changed"):
		sim.hud_changed.connect(refresh)
	if sim.has_signal("wind_changed"):
		sim.wind_changed.connect(_update_wind)
	if sim.has_signal("turn_started"):
		sim.turn_started.connect(_on_turn_started)
	if sim.has_signal("game_over"):
		sim.game_over.connect(_on_game_over)
	refresh()


func _on_resized() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if (vp.x < NARROW_WIDTH) != _narrow or UiUtil.is_compact(vp) != _compact:
		_build()
		refresh()


func _process(_delta: float) -> void:
	_update_timer()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_M:
		_toggle_music()
	elif key.keycode == KEY_ESCAPE:
		var bottom: Node = get_tree().get_first_node_in_group("bottom_hud")
		if bottom != null and bottom.has_method("is_drawer_open") and bottom.is_drawer_open():
			return
		exit_match()
		get_viewport().set_input_as_handled()


## Leaves the match and returns to the boot menu (original exitCurrentMatchToMenu).
func exit_match() -> void:
	exit_requested.emit()
	GameState.has_started_match = false
	if go_callable.is_valid():
		go_callable.call("boot")
	else:
		ScreenRouter.go("boot")


func _toggle_music() -> void:
	UiUtil.sfx("tick")
	UiUtil.toggle_music()
	_update_music_label()


func _update_music_label() -> void:
	if music_button != null:
		music_button.text = (tr("HUD_MUSIC_ON") if Options.music_on else tr("HUD_MUSIC_OFF")).to_upper()


# ---- updates -----------------------------------------------------------------------------------

## Rebuilds the pips and texts from the sim state (JS updateHUD + turn-status + round-sub).
func refresh() -> void:
	_update_music_label()
	var hp: Array[int] = [0, 0]
	var fighters: Variant = UiUtil.prop(sim, "fighters", [])
	var active: Variant = UiUtil.prop(sim, "active_fighter")
	var active_team: int = int(UiUtil.prop(sim, "active_team", 0))
	var seen: Array[int] = [0, 0]
	for f: Variant in fighters:
		var team: int = int(UiUtil.prop(f, "team", 0))
		if team < 0 or team > 1:
			continue
		var alive: bool = bool(UiUtil.prop(f, "alive", true)) and not bool(UiUtil.prop(f, "drowning", false))
		var cur_hp: float = float(UiUtil.prop(f, "hp", 0.0))
		var max_hp: float = maxf(1.0, float(UiUtil.prop(f, "max_hp", 100.0)))
		if alive:
			hp[team] += int(cur_hp)
		var pip: HpPip = _pip_at(team, seen[team])
		seen[team] += 1
		pip.setup(f, team, str(UiUtil.prop(f, "name", "")), cur_hp / max_hp if alive else 0.0, f == active and alive, not alive)
		pip.tooltip_text = (tr("HUD_PIP_OWN") if team == active_team else tr("HUD_PIP_OTHER")) if alive else ""
	for t in 2:
		# Surplus pips (a squad shrank in a new match) are removed; normally none.
		while pip_grids[t].get_child_count() > seen[t]:
			var extra: Node = pip_grids[t].get_child(pip_grids[t].get_child_count() - 1)
			pip_grids[t].remove_child(extra)
			extra.queue_free()
	for t in 2:
		hp_labels[t].text = UiUtil.fmt("HUD_HP_TOTAL", [hp[t]])
	_update_status()


## The `index`-th pip of a squad grid, created on first use and reused afterwards (no per-refresh node churn).
func _pip_at(team: int, index: int) -> HpPip:
	var grid: GridContainer = pip_grids[team]
	if index < grid.get_child_count():
		return grid.get_child(index) as HpPip
	var pip := HpPip.new()
	pip.pressed.connect(func(fighter: Variant) -> void:
		UiUtil.sfx("tick")
		fighter_pip_pressed.emit(fighter))
	grid.add_child(pip)
	return pip


func _update_status() -> void:
	var phase: int = int(UiUtil.prop(sim, "turn_phase", PHASE_TURN_PLAY))
	if sim != null and phase == PHASE_GAME_OVER:
		_show_end_text(int(UiUtil.prop(sim, "winner", -1)))
	else:
		var active: Variant = UiUtil.prop(sim, "active_fighter")
		var team: int = int(UiUtil.prop(sim, "active_team", 0))
		var who: String = str(UiUtil.prop(active, "name", "")) if active != null else ""
		if who.is_empty():
			who = str(GameState.team_names[team][0])
		status_label.text = UiUtil.fmt("HUD_TURN_OF", [who])
		status_label.add_theme_color_override("font_color", Palette.team_color(team))
	var round_no: int = int(UiUtil.prop(sim, "round_number", 1))
	round_label.text = UiUtil.fmt("HUD_ROUND_SUB", [round_no, tr(UiMaps.name_key(clampi(GameState.map_idx, 0, UiMaps.IDS.size() - 1)))]).to_upper()


func _show_end_text(winner: int) -> void:
	match winner:
		0:
			status_label.text = tr("HUD_END_WIN_0")
			status_label.add_theme_color_override("font_color", Palette.TEAM_GOLD)
		1:
			status_label.text = tr("HUD_END_WIN_1")
			status_label.add_theme_color_override("font_color", Palette.TEAM_CRIMSON)
		_:
			status_label.text = tr("HUD_END_DRAW")
			status_label.add_theme_color_override("font_color", Palette.IVORY)


func _on_turn_started(_team: int, _fighter: Variant) -> void:
	refresh()


func _on_game_over(winner: int, _stats: Variant) -> void:
	_show_end_text(winner)


func _update_timer() -> void:
	if sim == null:
		return
	var phase: int = int(UiUtil.prop(sim, "turn_phase", PHASE_TURN_PLAY))
	var txt: String = "—"
	var col: Color = Palette.BRASS_BRIGHT
	if phase == PHASE_TURN_PLAY:
		var sec: int = maxi(0, int(ceil(float(UiUtil.prop(sim, "turn_timer", 0.0)))))
		txt = str(sec)
		if sec <= 5:
			col = Palette.LOW_TIME_RED
	elif phase == PHASE_RETREAT:
		txt = str(maxi(0, int(ceil(float(UiUtil.prop(sim, "phase_timer", 0.0))))))
		col = Palette.RETREAT_YELLOW
	if timer_label.text != txt:
		timer_label.text = txt
	if _timer_color != col:
		_timer_color = col
		timer_label.add_theme_color_override("font_color", col)


func _update_wind() -> void:
	if sim == null:
		return
	var wind: int = int(UiUtil.prop(sim, "wind", 0))
	wind_track.wind = float(wind)
	wind_track.gust_flash = float(UiUtil.prop(sim, "wind_gust_flash", 0.0)) > 0.1
	var delta: float = float(UiUtil.prop(sim, "wind_target", 0.0)) - float(UiUtil.prop(sim, "wind_float", 0.0))
	var trend: String = ""
	if absf(delta) > 14.0:
		trend = " »" if delta > 0.0 else " «"
	wind_label.text = ("+" if wind > 0 else "") + str(wind) + trend


# ---- building ----------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	hp_labels.clear()
	pip_grids.clear()
	var vp: Vector2 = get_viewport_rect().size
	_narrow = vp.x < NARROW_WIDTH
	_compact = UiUtil.is_compact(vp)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", 6 if _compact else 10)
	margin.add_theme_constant_override("margin_left", 8 if _compact else 16)
	margin.add_theme_constant_override("margin_right", 8 if _compact else 16)
	add_child(margin)

	var squads: Array[Control] = [_make_squad(0), _make_squad(1)]
	var chrono: Control = _make_chrono()
	var strip: Control = _make_command_strip()

	if _narrow:
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 5)
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(rows)
		chrono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rows.add_child(chrono)
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for s in squads:
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(s)
		rows.add_child(pair)
		strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rows.add_child(strip)
	else:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 12)
		cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(cols)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.0
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		squads[0].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		left.add_child(squads[0])
		cols.add_child(left)
		chrono.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		cols.add_child(chrono)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_stretch_ratio = 1.0
		right.add_theme_constant_override("separation", 5)
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		squads[1].size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(squads[1])
		strip.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(strip)
		cols.add_child(right)


func _make_squad(team: int) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "GlassPanel"
	panel.custom_minimum_size.x = 225.0 if team == 1 else 200.0
	if _compact:
		panel.custom_minimum_size.x = 170.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title: Label = UiUtil.spaced_label(tr("HUD_SQUAD_1" if team == 0 else "HUD_SQUAD_2").to_upper(), "TitleLabel", 11, Palette.team_color(team), 0.5)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	var hp: Label = UiUtil.label(UiUtil.fmt("HUD_HP_TOTAL", [400]), "MonoHeavyLabel", 11, Palette.IVORY)
	head.add_child(hp)
	hp_labels.append(hp)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	pip_grids.append(grid)
	return panel


func _make_chrono() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var housing := PanelContainer.new()
	housing.theme_type_variation = "PillPanel"
	housing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(housing)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	housing.add_child(row)
	timer_label = UiUtil.label("30", "TitleBlackLabel", 22 if not _compact else 18, Palette.BRASS_BRIGHT)
	timer_label.custom_minimum_size.x = 28
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(timer_label)
	var divider := ColorRect.new()
	divider.color = Color(Palette.BRASS_BORDER_SOFT, 0.5)
	divider.custom_minimum_size = Vector2(1, 20)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(divider)
	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 0)
	row.add_child(meta)
	status_label = UiUtil.label(UiUtil.fmt("HUD_TURN_OF", [GameState.team_names[0][0]]), "BodyBoldLabel", 12, Palette.TEAM_GOLD)
	meta.add_child(status_label)
	round_label = UiUtil.label("", "MutedLabel", 9)
	meta.add_child(round_label)
	var anem := PanelContainer.new()
	anem.theme_type_variation = "PillPanel"
	anem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(anem)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	anem.add_child(arow)
	arow.add_child(UiUtil.label(tr("HUD_WIND"), "MonoHeavyLabel", 9, Palette.IVORY_MUTED))
	wind_track = WindTrack.new()
	wind_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arow.add_child(wind_track)
	wind_label = UiUtil.label("0", "MonoHeavyLabel", 10, Palette.IVORY)
	wind_label.custom_minimum_size.x = 34
	arow.add_child(wind_label)
	return col


func _make_command_strip() -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 5)
	music_button = Button.new()
	music_button.theme_type_variation = "CmdButton"
	music_button.icon = load("res://ui/icons/music.svg")
	music_button.expand_icon = true
	music_button.add_theme_constant_override("icon_max_width", 12)
	music_button.tooltip_text = tr("HUD_MUSIC_TOOLTIP")
	music_button.focus_mode = Control.FOCUS_NONE
	music_button.pressed.connect(_toggle_music)
	strip.add_child(music_button)
	exit_button = Button.new()
	exit_button.theme_type_variation = "CmdButton"
	exit_button.icon = load("res://ui/icons/exit.svg")
	exit_button.expand_icon = true
	exit_button.add_theme_constant_override("icon_max_width", 12)
	exit_button.text = tr("HUD_EXIT").to_upper()
	exit_button.tooltip_text = tr("HUD_EXIT_TOOLTIP")
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(exit_match)
	strip.add_child(exit_button)
	return strip
