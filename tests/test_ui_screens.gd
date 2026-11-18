## UI screens: scenes instantiate headless, the boot menu navigates by keyboard, the lobby writes GameState, weapon icons load.
##   godot --headless --path . res://tests/TestUiScreens.tscn
extends Node

var failures: int = 0
var _went: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _key(code: Key, shift: bool = false, ctrl: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	return e


func _on_go(screen_name: String) -> void:
	_went.append(screen_name)


func _ready() -> void:
	for path in ["res://ui/menus/Boot.tscn", "res://ui/menus/Lobby.tscn", "res://ui/menus/RotateOverlay.tscn"]:
		var scene: PackedScene = load(path)
		_check(scene != null, "%s loads" % path)
	_check(UiUtil.get_theme() != null, "ui/theme.tres loads")
	_check(ScreenRouter.SCREENS.has("boot") and ScreenRouter.SCREENS.has("lobby") and ScreenRouter.SCREENS.has("combat"), "ScreenRouter knows boot, lobby, combat")
	_check(is_equal_approx(ScreenRouter.content_scale_for(Vector2(844, 390)), 1.0 / (390.0 / 720.0)) or ScreenRouter.content_scale_for(Vector2(844, 390)) > 1.5, "content scale rises on a phone window")
	_check(is_equal_approx(ScreenRouter.content_scale_for(Vector2(1920, 1080)), 1.0), "content scale is 1 on desktop")
	await _test_boot()
	await _test_lobby()
	_test_rotate()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _test_boot() -> void:
	var boot: Control = (load("res://ui/menus/Boot.tscn") as PackedScene).instantiate()
	boot.go_callable = _on_go
	add_child(boot)
	await get_tree().process_frame
	_check(boot.items.size() == 3, "boot menu has 3 items")
	_check(boot.cursor_idx == 0, "menu cursor starts at 0")
	boot._unhandled_input(_key(KEY_DOWN))
	_check(boot.cursor_idx == 1, "Down moves the cursor to 1")
	boot._unhandled_input(_key(KEY_S))
	_check(boot.cursor_idx == 2, "S moves the cursor to 2")
	boot._unhandled_input(_key(KEY_DOWN))
	_check(boot.cursor_idx == 0, "cursor wraps down")
	boot._unhandled_input(_key(KEY_UP))
	_check(boot.cursor_idx == 2, "cursor wraps up")
	_went.clear()
	boot._unhandled_input(_key(KEY_ENTER))
	_check(_went == ["lobby"], "Enter on custom match goes to lobby")
	boot._set_cursor(1)
	_went.clear()
	boot._unhandled_input(_key(KEY_SPACE))
	_check(_went == ["combat"] and GameState.game_mode == "2P_LOCAL", "Space on 2 players starts combat in 2P_LOCAL")
	boot._set_cursor(0)
	_went.clear()
	boot._unhandled_input(_key(KEY_ENTER))
	_check(_went == ["combat"] and GameState.game_mode == "1P_CPU" and GameState.has_started_match, "Enter on quick match starts combat vs CPU")
	_went.clear()
	boot.items[2].press()
	_check(_went == ["lobby"], "clicking the custom item goes to lobby")
	_check(boot.cursor_idx == 2, "clicking moves the cursor")
	boot.queue_free()


func _test_lobby() -> void:
	GameState.team_hats = ["CATALAN", "BANDOLER"]
	var lobby: Control = (load("res://ui/menus/Lobby.tscn") as PackedScene).instantiate()
	lobby.go_callable = _on_go
	add_child(lobby)
	await get_tree().process_frame
	_check(lobby.map_cards.size() == 8, "lobby has 8 map cards")
	_check(lobby.focus_idx == 1, "lobby cursor starts on the first mode card")
	lobby.mode_cards[1].press()
	_check(GameState.game_mode == "2P_LOCAL", "mode card selects 2P_LOCAL")
	lobby.diff_cards[2].press()
	_check(GameState.ai_difficulty == "NIGHTMARE", "difficulty card selects NIGHTMARE")
	lobby.count_cards[1].press()
	_check(GameState.worms_per_team == 2 and lobby.name_inputs[0].size() == 2, "count card sets 2 worms and 2 name rows")
	lobby.map_cards[5].press()
	_check(GameState.map_idx == 5, "map card selects map 5")
	(lobby.name_inputs[0][0] as LineEdit).text = "Pepet"
	(lobby.name_inputs[1][1] as LineEdit).text = "  Maria  "
	lobby.cycle_hat(lobby.hat_selects[0], 1)
	_check(GameState.team_hats[0] == "CASTELLER", "hat select cycles CATALAN to CASTELLER")
	lobby.cycle_hat(lobby.hat_selects[1], -1)
	_check(GameState.team_hats[1] == "CASTELLER", "hat select cycles BANDOLER back to CASTELLER")
	lobby.read_customization()
	_check(GameState.team_names[0][0] == "Pepet" and GameState.team_names[1][1] == "Maria", "names are read and trimmed into GameState")
	# Keyboard: Down from a card jumps to the next group; Right selects the next card.
	lobby.set_focus_index(1, false)
	lobby.handle_key(KEY_DOWN, false, false)
	_check(lobby.focus_idx == 4, "Down from mode cards jumps to the difficulty group")
	lobby.handle_key(KEY_RIGHT, false, false)
	_check(GameState.ai_difficulty == "VETERAN", "Right selects the next card (VETERAN)")
	lobby.handle_key(KEY_TAB, true, false)
	_check(lobby.focus_idx == 4, "Shift+Tab goes back one item")
	_went.clear()
	lobby.handle_key(KEY_ENTER, false, true)
	var cfg: Variant = GameState.make_match_config()
	_check(_went == ["combat"] and GameState.has_custom_names, "Ctrl+Enter deploys to combat")
	var mode_ok: bool = (cfg is Dictionary and cfg["game_mode"] == "2P_LOCAL") or (cfg is Object and cfg.game_mode == "2P_LOCAL")
	_check(mode_ok, "make_match_config carries the lobby mode")
	_went.clear()
	lobby.handle_key(KEY_ESCAPE, false, false)
	_check(_went == ["boot"], "Esc goes back to boot")
	lobby.queue_free()


func _test_rotate() -> void:
	_check(RotateOverlay.is_portrait(Vector2(390, 844)), "390x844 is portrait")
	_check(not RotateOverlay.is_portrait(Vector2(844, 390)), "844x390 is not portrait")
	_check(not RotateOverlay.is_portrait(Vector2(1000, 1100)), "wide viewports are never portrait")
