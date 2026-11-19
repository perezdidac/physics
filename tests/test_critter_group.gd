## The critter phase: the walking critters (ants) of an enemy turn move together in one phase (docs/story_contracts.md, "critter phase"), each with its
## own plan, every ant bites at most once, the order is the fighter index, the leader is the active fighter, birds keep their own turns, and the
## whole thing is deterministic.
##   godot --headless --path . res://tests/TestCritterGroup.tscn
extends Node

const DT: float = 1.0 / 60.0

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	_group_phase("larva_1")
	_group_phase("cuca_3")
	_birds_apart()
	_deterministic()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _make(id: String) -> CombatSim:
	var lv: LevelDef = load("res://data/levels/%s.tres" % id)
	var cfg := MatchConfig.new()
	cfg.level = lv
	cfg.map_idx = lv.map_idx
	cfg.seed = lv.seed
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = lv.player_names.size()
	var sim := CombatSim.new()
	sim.setup(cfg)
	return sim


func _step(sim: CombatSim) -> void:
	if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
		sim.end_turn()
	sim.step(DT)
	sim.advance_real(DT)


## Plays rounds until the enemy turn starts; returns false when it never does.
func _to_enemy_turn(sim: CombatSim) -> bool:
	for i in 60 * 120:
		_step(sim)
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 1:
			return true
		if sim.turn_phase == CombatSim.Phase.GAME_OVER:
			return false
	return false


func _group_phase(id: String) -> void:
	var sim := _make(id)
	var turns: Array = []
	sim.turn_started.connect(func(team: int, f: SimFighter) -> void: turns.append([team, f.id]))
	var ants: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == 1 and f.unit.ai == "MELEE_CRITTER" and not f.unit.flies:
			ants.append(f)
	_check(ants.size() >= 2, "%s: %d walking critters at the start" % [id, ants.size()])
	_check(_to_enemy_turn(sim), "%s: the enemy turn starts" % id)
	var group: Array[SimFighter] = sim.critter_group.duplicate()
	_check(group.size() == ants.size(), "%s: the critters form one group (%d of %d)" % [id, group.size(), ants.size()])
	_check(sim.active_fighter == group[0] and sim.critter_acting.size() == group.size(), "%s: the leader is the first of the group" % id)
	var idx_ok: bool = true
	for k in range(1, group.size()):
		idx_ok = idx_ok and sim.fighters.find(group[k - 1]) < sim.fighters.find(group[k])
	_check(idx_ok, "%s: the group is in fighter index order" % id)
	var start_x: Array[float] = []
	for m in group:
		start_x.append(m.x)
	var enemy_turn_events: int = 0
	for ev in turns:
		if ev[0] == 1:
			enemy_turn_events += 1
	var moved: int = 0
	var t: float = 0.0
	var bites: Dictionary = {}
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and sim.active_team == 1 and t < 60.0:
		_step(sim)
		t += DT
		for m in group:
			if m.bat_swing_timer > 0.47:
				bites[m.id] = int(bites.get(m.id, 0)) + 1
	for k in group.size():
		if absf(group[k].x - start_x[k]) > 20.0:
			moved += 1
	_check(moved >= 2 or sim.team_alive_count(0) == 0, "%s: several critters moved in the same enemy turn (%d)" % [id, moved])
	var once: bool = true
	for k in bites:
		once = once and int(bites[k]) <= 1
	_check(once, "%s: every critter bites at most once per enemy turn" % id)
	_check(t < sim.turn_time, "%s: the whole enemy turn took %.1f s (one sub-turn, not one per ant)" % [id, t])
	var enemy_events: int = 0
	for ev in turns:
		if ev[0] == 1:
			enemy_events += 1
	_check(enemy_events == enemy_turn_events + 0 and enemy_events == 1, "%s: one turn_started for the whole group (%d)" % [id, enemy_events])
	_check(sim.critter_group.is_empty() or sim.active_team == 1, "%s: the group is cleared after the phase" % id)


## Birds are not part of a critter phase.
func _birds_apart() -> void:
	var sim := _make("larva_5")
	var flyers: int = 0
	for f in sim.fighters:
		if f.team == 1 and f.unit.flies:
			flyers += 1
	_check(_to_enemy_turn(sim), "larva_5: the enemy turn starts")
	var any_flyer: bool = false
	for m in sim.critter_group:
		any_flyer = any_flyer or m.unit.flies
	_check(not any_flyer, "larva_5: no bird in the critter phase (%d birds, group %d)" % [flyers, sim.critter_group.size()])


func _run_signature(id: String) -> String:
	var sim := _make(id)
	for i in 60 * 70:
		_step(sim)
		if sim.turn_phase == CombatSim.Phase.GAME_OVER:
			break
	var sig: String = ""
	for f in sim.fighters:
		sig += "%s:%.2f,%.2f,%d;" % [f.name, f.x, f.y, f.hp]
	return sig


func _deterministic() -> void:
	_check(_run_signature("larva_1") == _run_signature("larva_1"), "larva_1: two runs end in the same state")
	_check(_run_signature("cuca_3") == _run_signature("cuca_3"), "cuca_3: two runs end in the same state")
