## Combat HUD scenes: weapon icons, top HUD, bottom HUD (weapons, drawer, fuse, touch buttons) and victory modal against a fake sim.
##   godot --headless --path . res://tests/TestUiHud.tscn
extends Node

var failures: int = 0
var _went: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _on_go(screen_name: String) -> void:
	_went.append(screen_name)


func _ready() -> void:
	_test_icons()
	_test_weapon_table()
	await _test_top()
	await _test_bottom()
	await _test_victory()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_icons() -> void:
	var loaded: int = 0
	for i in HudWeapons.count():
		var tex: Texture2D = HudWeapons.icon(i)
		if tex != null and tex.get_width() > 0:
			loaded += 1
		else:
			print("      missing icon for ", HudWeapons.LIST[i]["id"])
	_check(loaded == 16, "all 16 weapon icons load as textures (%d)" % loaded)
	var svg: String = FileAccess.get_file_as_string("res://assets/sprites/weapon_icons/bazooka.svg")
	_check(svg.begins_with("<svg viewBox=\"0 0 36 22\">") and svg.contains("#d9a14a"), "icon files hold the original SVG text")


func _test_weapon_table() -> void:
	_check(HudWeapons.count() == 16, "16 weapons in the HUD table")
	_check(HudWeapons.fire_label_key(0) == "FIRE_HOLD", "CHARGE weapons show the hold label")
	_check(HudWeapons.fire_label_key(5) == "FIRE_DEFAULT", "shotgun shows the default fire label")
	_check(HudWeapons.fire_label_key(6) == "FIRE_MELEE" and HudWeapons.fire_label_key(8) == "FIRE_DROP", "melee and drop labels")
	_check(HudWeapons.fire_label_key(10) == "FIRE_AIRSTRIKE" and HudWeapons.fire_label_key(11) == "FIRE_JET", "airstrike and jetpack labels")
	_check(HudWeapons.has_fuse(2) and HudWeapons.has_fuse(3) and not HudWeapons.has_fuse(0), "only grenade and cluster use the fuse picker")
	_check(HudWeapons.index_of_key("-") == 10 and HudWeapons.index_of_key("P") == 15, "hotkeys map to weapon indices")
	var ammo: Array = [{"BAZOOKA": INF, "CLUSTER": 2}, {}]
	_check(HudWeapons.ammo_for(ammo, 0, 0) == -1 and HudWeapons.ammo_for(ammo, 0, 3) == 2, "ammo_for reads INF as infinite and counts")
	_check(UiUtil.fmt("SOME_UNTRANSLATED_KEY", ["a", 3]) == "SOME_UNTRANSLATED_KEY a 3", "fmt falls back without a translation")


func _make_sim() -> HudFakeSim:
	return HudFakeSim.new()


func _test_top() -> void:
	var sim: HudFakeSim = _make_sim()
	var top: TopHud = (load("res://combat/hud/TopHud.tscn") as PackedScene).instantiate()
	top.go_callable = _on_go
	add_child(top)
	top.bind(sim)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(top.pip_grids[0].get_child_count() == 4 and top.pip_grids[1].get_child_count() == 4, "top HUD builds one pip per fighter")
	_check(top.hp_labels[0].text.contains("249"), "team HP total counts only living fighters (249)")
	_check(top.timer_label.text == "24", "timer shows the ceil of turn_timer")
	sim.turn_timer = 4.2
	await get_tree().process_frame
	_check(top.timer_label.text == "5" and top.timer_label.get_theme_color("font_color") == Palette.LOW_TIME_RED, "timer turns red at 5 s")
	sim.turn_phase = TopHud.PHASE_ACTION_WAIT
	await get_tree().process_frame
	_check(top.timer_label.text == "—", "timer shows a dash during ACTION_WAIT")
	sim.wind_changed.emit()
	_check(top.wind_label.text == "+42 »", "wind label shows sign and trend arrow (wind_changed only)")
	var pip0: Node = top.pip_grids[0].get_child(0)
	sim.hud_changed.emit()
	_check(top.pip_grids[0].get_child(0) == pip0, "hud_changed reuses the existing pips")
	sim.wind = -7
	sim.wind_target = -7.0
	sim.wind_float = -7.0
	sim.wind_changed.emit()
	_check(top.wind_label.text == "-7", "wind label negative without arrow")
	sim.winner = 1
	sim.turn_phase = TopHud.PHASE_GAME_OVER
	sim.hud_changed.emit()
	_check(top.status_label.text == tr("HUD_END_WIN_1"), "status shows the end text after game over")
	_check(top.music_button != null and top.exit_button != null, "music and exit buttons exist")
	_check(top.get_child_count() == 1, "hidden command buttons are not built")
	_went.clear()
	top.exit_button.pressed.emit()
	_check(_went == ["boot"], "exit button goes to boot")
	top.queue_free()


func _test_bottom() -> void:
	var sim: HudFakeSim = _make_sim()
	var bottom: BottomHud = (load("res://combat/hud/BottomHud.tscn") as PackedScene).instantiate()
	add_child(bottom)
	bottom.bind(sim)
	await get_tree().process_frame
	_check(bottom.slots.size() == 16, "drawer has 16 slots")
	_check(not bottom.is_drawer_open(), "drawer starts closed")
	bottom.handle_key(KEY_B)
	_check(bottom.is_drawer_open(), "B opens the drawer")
	bottom.handle_key(KEY_DOWN)
	_check(bottom.drawer_cursor == 8, "Down in the drawer moves the cursor by 8")
	_check(sim.calls.is_empty() or not sim.calls.has("select_weapon:8"), "ammo-less weapon (dynamite) is not selected by browsing")
	bottom.handle_key(KEY_RIGHT)
	_check(bottom.drawer_cursor == 9 and sim.selected_weapon_idx == 9, "Right moves to 9 and selects it (has ammo)")
	bottom.handle_key(KEY_ENTER)
	_check(not bottom.is_drawer_open() and "select_weapon:9" in sim.calls, "Enter selects and closes the drawer")
	bottom.handle_key(KEY_3)
	_check(sim.selected_weapon_idx == 2, "hotkey 3 selects the grenade")
	bottom.rebuild_weapon_bar()
	_check(bottom.fuse_picker.visible, "fuse picker shows for the grenade")
	bottom.handle_key(KEY_E)
	_check(sim.custom_grenade_fuse == 4, "E raises the fuse to 4")
	bottom.handle_key(KEY_Q)
	bottom.handle_key(KEY_Q)
	_check(sim.custom_grenade_fuse == 2, "Q lowers the fuse")
	bottom.handle_key(KEY_9)
	_check(sim.selected_weapon_idx == 2, "hotkey 9 (no ammo) keeps the weapon")
	sim.selected_weapon_idx = 7
	bottom.handle_key(KEY_X)
	_check(sim.selected_weapon_idx == 9, "X skips the weapon without ammo (8) and picks 9")
	sim.ai_turn = true
	bottom.handle_key(KEY_1)
	_check(sim.selected_weapon_idx == 9, "weapon keys are ignored on an AI turn")
	sim.ai_turn = false
	bottom.fire_button.pressed_down.emit()
	bottom.fire_button.released.emit()
	bottom.left_button.pressed_down.emit()
	bottom.left_button.released.emit()
	bottom.up_button.pressed_down.emit()
	bottom.jump_button.pressed_down.emit()
	bottom.flip_button.pressed_down.emit()
	_check("begin_charge_or_fire" in sim.calls and "release_charge" in sim.calls, "fire button presses and releases the charge")
	_check("set_move:-1" in sim.calls and "set_move:0" in sim.calls, "left arrow sets and clears movement")
	_check("set_aim_input:-1" in sim.calls and "jump_forward" in sim.calls and "jump_backward" in sim.calls, "aim, jump and flip buttons call the sim")
	var zooms: Array[float] = []
	bottom.zoom_requested.connect(func(d: float) -> void: zooms.append(d))
	bottom.right_cluster.get_child(2).tapped.emit()
	bottom.right_cluster.get_child(3).tapped.emit()
	_check(zooms.size() == 2 and is_equal_approx(zooms[0], -0.16) and is_equal_approx(zooms[1], 0.16), "zoom buttons request +-0.16")
	sim.is_charging = true
	sim.charge_power = 0.5
	await get_tree().process_frame
	_check(is_equal_approx(bottom.fire_button.fill, 0.5), "fire button shows the charge")
	bottom.queue_free()


func _test_victory() -> void:
	var sim: HudFakeSim = _make_sim()
	var victory: VictoryModal = (load("res://combat/hud/VictoryModal.tscn") as PackedScene).instantiate()
	victory.go_callable = _on_go
	add_child(victory)
	victory.bind(sim)
	await get_tree().process_frame
	_check(not victory.visible, "victory modal starts hidden")
	sim.game_over.emit(0, {})
	_check(victory.visible and victory.focus_idx == 1, "game_over shows the modal with focus on rematch")
	_check(victory.title_label.text == tr("VICTORY_TITLE_0"), "title for team 0")
	victory.handle_key(KEY_TAB)
	_check(victory.focus_idx == 0, "Tab swaps focus to the lobby button")
	_went.clear()
	victory.handle_key(KEY_ENTER)
	_check(_went == ["lobby"], "Enter on the lobby button goes to lobby")
	victory.show_result(-1, {"mvp_name": "Boira", "mvp_damage": 33})
	_check(victory.title_label.text == tr("VICTORY_TITLE_DRAW"), "draw title")
	_went.clear()
	victory.handle_key(KEY_ENTER)
	_check(_went == ["combat"], "Enter on rematch starts a new combat")
	victory.show_result(1)
	_went.clear()
	victory.handle_key(KEY_ESCAPE)
	_check(_went == ["boot"], "Esc exits to boot")
	var mvp: Array = victory._find_mvp(null)
	_check(mvp[0] == "Espina" and mvp[1] == 40, "MVP is the fighter with most damage dealt (first wins ties)")
	victory.queue_free()
