## Two minutes of simulated play with random inputs (human-style commands) plus CPU vs CPU matches. Must not error.
##   godot --headless --path . res://tests/TestSimSmoke.tscn
extends Node

var failures: int = 0
var _events: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _count(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_events += 1


func _new_sim(mode: String, map_idx: int, seed_v: int) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = seed_v
	cfg.game_mode = mode
	cfg.worms_per_team = 4
	cfg.map_idx = map_idx
	sim.setup(cfg)
	sim.sfx.connect(_count)
	sim.float_text.connect(_count)
	sim.effect.connect(_count)
	return sim


func _sane(sim: CombatSim) -> bool:
	for f in sim.fighters:
		if is_nan(f.x) or is_nan(f.y) or is_inf(f.x) or is_inf(f.y) or f.hp < 0:
			return false
	for p in sim.projectiles:
		if is_nan(p.x) or is_nan(p.y):
			return false
	return true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var matches: int = 0
	var steps: int = 0
	var sim: CombatSim = _new_sim("2P_LOCAL", 0, 1)
	var t0: int = Time.get_ticks_msec()
	var total_steps: int = 120 * 60
	for i in total_steps:
		steps += 1
		if i % 20 == 0:
			sim.set_move(rng.randi_range(-1, 1))
			sim.set_aim_input(rng.randi_range(-1, 1))
			sim.set_glide(rng.randf() < 0.3)
		var r: float = rng.randf()
		if r < 0.01:
			sim.jump_forward()
		elif r < 0.015:
			sim.jump_backward()
		elif r < 0.03:
			sim.select_weapon(rng.randi_range(0, 15))
		elif r < 0.04:
			sim.begin_charge_or_fire()
		elif r < 0.05:
			sim.release_charge()
		elif r < 0.055:
			sim.spin_silk_web()
		elif r < 0.058:
			sim.toggle_convoy()
		elif r < 0.06:
			sim.switch_fighter()
		elif r < 0.062:
			sim.set_fuse(rng.randi_range(1, 5))
		elif r < 0.064:
			sim.set_target(Vector2(rng.randf_range(0.0, 3200.0), 300.0))
		elif r < 0.066:
			sim.cycle_weapon(1)
		sim.step(1.0 / 60.0)
		if not _sane(sim):
			_check(false, "NaN or negative hp at step %d" % i)
			break
		if sim.turn_phase == CombatSim.Phase.GAME_OVER:
			matches += 1
			sim = _new_sim("2P_LOCAL", matches % 8, matches + 1)
	_check(steps == total_steps, "random-input run: %d steps (2 minutes of sim time), %d matches restarted" % [steps, matches])
	print("random run took %d ms, %d events" % [Time.get_ticks_msec() - t0, _events])

	# CPU vs CPU on every map: must finish by game over (or at least keep turning) without errors.
	var finished: int = 0
	for map_idx in 8:
		var cpu: CombatSim = _new_sim("CPU_CPU", map_idx, 500 + map_idx)
		var turn_log: Array[int] = []
		cpu.turn_started.connect(func(t: int, _f: SimFighter) -> void: turn_log.append(t))
		for i in 60 * 60 * 6:
			cpu.step(1.0 / 30.0)
			if cpu.turn_phase == CombatSim.Phase.GAME_OVER:
				finished += 1
				break
		_check(turn_log.size() >= 3 and _sane(cpu), "CPU_CPU map %d: %d turns, round %d, phase %d" % [map_idx, turn_log.size(), cpu.round_number, cpu.turn_phase])
	_check(finished >= 4, "at least half of the CPU matches reach game over (%d/8)" % finished)
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()
