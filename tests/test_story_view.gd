## Story-mode view and HUD: egg level on the real CombatScreen (objective widget, Pass button, filtered weapon bar, end of level
## routing, exit to the campaign map) and the classic screen untouched.
##   godot --headless --path . res://tests/TestStoryView.tscn
extends Node

var failures: int = 0
var routed: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	await _run()
	GameState.story_level = null
	GameState.story_result = {}
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hud(screen: CombatScreen, script_class: Variant) -> Node:
	for h in screen.huds:
		if is_instance_of(h, script_class):
			return h
	return null


func _run() -> void:
	GameState.story_level = load("res://data/levels/egg_1.tres") as LevelDef
	var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	add_child(screen)
	await _frames(30)
	var sim: CombatSim = screen.sim as CombatSim
	_check(sim != null and sim.level != null and screen.is_story(), "story CombatScreen binds a sim with a level")
	_check(screen.t_now > 0.0, "frame loop runs with eggs and ants (t_now=%.2f)" % screen.t_now)
	var top: TopHud = _hud(screen, TopHud) as TopHud
	var bottom: BottomHud = _hud(screen, BottomHud) as BottomHud
	_check(top != null and bottom != null and _hud(screen, VictoryModal) == null, "HUDs built, classic victory modal not instanced")

	# objective widget
	_check(top.objective_panel.visible and top.objective_label.text.contains(str(sim.rounds_left)) and sim.rounds_left == 4, "objective widget shows the rounds left (%s)" % top.objective_label.text)
	_check(top.squad_titles[0].text != top.squad_titles[1].text, "squad titles are set from the unit kinds")

	# weapon bar: eggs have no weapon
	_check(bottom.slots.size() == HudWeapons.total() and bottom.arsenal().is_empty(), "story drawer has all slots and the egg arsenal is empty")
	var shown: int = 0
	for sl in bottom.slots:
		shown += 1 if sl.visible else 0
	_check(shown == 0 and bottom.hint_panel.visible and not bottom.toggle_button.visible, "empty arsenal: no slot, the 'no weapons' hint instead of the pill")

	# Pass button
	_check(bottom.pass_button != null and bottom.pass_button.visible, "Pass button visible on the human turn")
	_check(sim.turn_phase == CombatSim.Phase.TURN_PLAY, "level starts in TURN_PLAY")
	_check(bottom.handle_key(KEY_N), "N key is the Pass shortcut")
	_check(sim.turn_phase != CombatSim.Phase.TURN_PLAY, "Pass ends the turn (phase %d)" % sim.turn_phase)
	await _frames(10)

	# ant team: only the Bite is shown
	sim.active_team = 1
	bottom.rebuild_weapon_bar()
	var ids: Array[String] = []
	for sl in bottom.slots:
		if sl.visible:
			ids.append(HudWeapons.name_key(sl.index))
	_check(ids == ["WPN_MOSSEGADA"] and not bottom.hint_panel.visible, "ant turn shows only the Bite in the bar (%s)" % str(ids))
	_check(HudWeapons.icon(16) != null and HudWeapons.icon(17) != null, "story weapons have procedural icons")
	sim.active_team = 0
	bottom.rebuild_weapon_bar()

	# hidden egg and ants draw without errors
	for f in sim.fighters:
		if f.kind == "EGG":
			f.hidden = true
			f.hurt_timer = 0.5
			break
	await _frames(8)
	_check(screen.view.ctx.hiding_spots.size() == sim.hiding_spots.size() and sim.hiding_spots.size() > 0, "view reads the hiding spots (%d)" % sim.hiding_spots.size())

	# exit goes to the campaign map
	top.go_callable = func(target: String) -> void: routed.append(target)
	top.exit_match()
	_check(routed == ["story_map"], "exit in story goes to story_map (%s)" % str(routed))

	# end of the level
	screen.go_callable = func(target: String) -> void: routed.append(target)
	routed.clear()
	GameState.story_result = {}
	sim.game_over.emit(0, {"level_id": "egg_1", "won": true, "survivors": 3, "stars": 3, "reason": "SURVIVED"})
	_check(GameState.story_result.get("level_id", "") == "egg_1" and GameState.story_result.get("stars", 0) == 3, "game_over stores the stats in GameState.story_result")
	_check(is_equal_approx(screen.story_end_timer, CombatScreen.STORY_END_DELAY) and routed.is_empty(), "results screen is delayed by about 2 s")
	screen.story_end_timer = 0.05
	await _frames(12)
	_check(routed == ["story_results"], "after the delay the screen goes to story_results (%s)" % str(routed))
	screen.queue_free()
	await _frames(2)

	# classic screen: no story widgets
	GameState.story_level = null
	var classic: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	add_child(classic)
	await _frames(20)
	var ctop: TopHud = _hud(classic, TopHud) as TopHud
	var cbottom: BottomHud = _hud(classic, BottomHud) as BottomHud
	_check(not classic.is_story() and _hud(classic, VictoryModal) != null, "classic screen keeps the victory modal")
	_check(not ctop.objective_panel.visible, "classic HUD has no objective widget")
	_check(cbottom.pass_button == null and cbottom.slots.size() == 16 and not cbottom.hint_panel.visible, "classic bottom HUD: no Pass button, 16 slots")
	var classic_shown: int = 0
	for sl in cbottom.slots:
		classic_shown += 1 if sl.visible else 0
	_check(classic_shown == 16 and not cbottom.handle_key(KEY_N), "classic weapon bar shows all 16 weapons, N does nothing")
	classic.go_callable = func(target: String) -> void: routed.append(target)
	classic.sim.game_over.emit(0, {})
	_check(classic.story_end_timer < 0.0, "classic game_over does not start the story end timer")
	classic.queue_free()
