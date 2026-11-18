## Whole game flow with the real screens: boot -> quick match (CPU vs CPU, accelerated) -> game over -> victory modal ->
## rematch -> new match -> lobby -> boot. Any SCRIPT ERROR in the output makes tools/run_tests.sh fail the test.
##   godot --headless --path . res://tests/TestFlow.tscn
extends Node

const MAX_FRAMES: int = 6000
const STEPS_PER_FRAME: int = 40

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	# Screen changes free the current scene, so this node moves to the root and a dummy becomes the current scene.
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	_detach.call_deferred(dummy)


func _detach(dummy: Node) -> void:
	reparent(get_tree().root)
	get_tree().current_scene = dummy
	_drive()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _wait_scene(script_class: String) -> Node:
	for i in 120:
		await get_tree().process_frame
		var s: Node = _scene()
		if s != null and s.get_script() != null and s.get_script().get_global_name() == script_class:
			return s
	return null


func _drive() -> void:
	ScreenRouter.go("boot")
	await _frames(10)
	var boot: Node = _scene()
	_check(boot != null and boot.has_method("activate"), "boot screen is up")
	GameState.has_started_match = false
	boot.call("activate", 0)
	GameState.game_mode = "CPU_CPU"
	GameState.worms_per_team = 2
	GameState.ai_difficulty = "ROOKIE"
	var combat: CombatScreen = await _wait_scene("CombatScreen") as CombatScreen
	_check(combat != null and combat.sim != null, "quick match opens CombatScreen with a sim")
	if combat == null:
		_finish()
		return
	var modal: Node = _find_modal(combat)
	_check(modal != null and not modal.visible, "victory modal exists and is hidden at start")
	var over: bool = await _run_to_game_over(combat)
	_check(over, "match reaches game_over")
	await _frames(5)
	_check(modal != null and modal.visible, "victory modal is visible after game over")
	modal.call("rematch")
	var combat2: CombatScreen = await _wait_scene("CombatScreen") as CombatScreen
	_check(combat2 != null and combat2 != combat and combat2.sim != null, "rematch starts a new CombatScreen and sim")
	await _frames(30)
	_check(combat2.sim.get("t_now") > 0.0, "the new match is stepping")
	var sim2: CombatSim = combat2.sim as CombatSim
	sim2.nudge_aim_pitch(10.0)
	_check(is_equal_approx(sim2.aim_pitch, 1.30), "nudge_aim_pitch clamps at the keyboard limit")
	sim2.nudge_aim_pitch(-10.0)
	_check(is_equal_approx(sim2.aim_pitch, -1.48), "nudge_aim_pitch clamps at the upper limit")
	sim2.turn_phase = CombatSim.Phase.TURN_PLAY
	sim2.rotate_prompt_open = true
	var before: float = sim2.turn_timer
	sim2.step(0.1)
	_check(is_equal_approx(sim2.turn_timer, before), "turn timer is frozen while the rotate overlay is open")
	sim2.rotate_prompt_open = false
	sim2.step(0.1)
	_check(sim2.turn_timer < before, "turn timer runs again afterwards")
	_check(combat2.rotate_overlay != null, "CombatScreen instances the rotate overlay")
	ScreenRouter.go("lobby")
	await _frames(10)
	var lobby: Node = _scene()
	_check(lobby != null and lobby.has_method("back_to_menu"), "lobby screen is up")
	lobby.call("back_to_menu")
	await _frames(10)
	boot = _scene()
	_check(boot != null and boot.has_method("activate"), "back to boot")
	_finish()


func _find_modal(root: Node) -> Node:
	for h in (root as CombatScreen).huds:
		if h.has_method("rematch"):
			return h
	return null


func _run_to_game_over(combat: CombatScreen) -> bool:
	var sim: CombatSim = combat.sim as CombatSim
	var done: Array = [false]
	sim.game_over.connect(func(_w: int, _s: Dictionary) -> void: done[0] = true)
	for f in MAX_FRAMES:
		if done[0]:
			return true
		for i in STEPS_PER_FRAME:
			sim.step(0.033)
		await get_tree().process_frame
	return done[0]


func _finish() -> void:
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()
