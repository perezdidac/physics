## La Processó in the sim (docs/procession_contracts.md): the CONVOY rule (the line trails the leader, march budget, lost and rejoined
## followers, goal and leader death, stars), the wild boar (telegraph, then the charge), the Calosoma, the spore clouds, the cuckoo boss
## (swoop and dodge, SATED, BOSS_OR_GOAL) and CPU runs of the six levels (the CPU drives the leader to the goal).
##   godot --headless --path . res://tests/TestProcSim.tscn
## CUCS_PROC_FAST=1 skips the CPU runs. Look for seeds of a level from a base:
##   CUCS_PROC_SCAN=proc_1:7000 godot --headless --path . res://tests/TestProcSim.tscn
extends Node

const DT: float = 1.0 / 60.0
const RUN_LIMIT_S: float = 3000.0
const PROC_LEVELS: Array[String] = ["proc_1", "proc_2", "proc_3", "proc_4", "proc_5", "proc_boss"]

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id)


func _make(level: LevelDef, seed_v: int = -1) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.level = level
	cfg.map_idx = level.map_idx
	cfg.seed = level.seed if seed_v < 0 else seed_v
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = level.player_names.size()
	cfg.extra_arsenal = {"FUET": -1, "CARQUINYOLI": -1, "BAT": -1, "BAZOOKA": -1, "GRENADE": -1}
	sim.setup(cfg)
	return sim


func _ready() -> void:
	var scan: String = OS.get_environment("CUCS_PROC_SCAN")
	if scan != "":
		var parts: PackedStringArray = scan.split(":")
		_scan(parts[0], int(parts[1]))
		get_tree().quit()
		return
	_data()
	_setup()
	_following()
	_march()
	_lost_and_rejoin()
	_goal_stars_and_defeat()
	_boar()
	_calosoma()
	_spores()
	_cuckoo()
	_classic_untouched()
	if OS.get_environment("CUCS_PROC_FAST") == "":
		_cpu_runs()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _squad(sim: CombatSim) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == 0:
			out.append(f)
	return out


func _kind(sim: CombatSim, kind: String) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.kind == kind:
			out.append(f)
	return out


func _sturdy(sim: CombatSim) -> void:
	for f in _squad(sim):
		f.hp = 9999
		f.max_hp = 9999


## The ants and the like are out of the way (the test is about something else).
func _no_ants(sim: CombatSim) -> void:
	for f in _kind(sim, "ANT") + _kind(sim, "BLUE_TIT"):
		f.alive = false


func _step(sim: CombatSim, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## Steps until team 0 plays again (TURN_PLAY).
func _until_player(sim: CombatSim, max_s: float = 120.0) -> void:
	var t: float = 0.0
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER and not (sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0):
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## The leader ends its turn and the enemy plays a whole turn.
func _next_round(sim: CombatSim) -> void:
	sim.end_turn()
	_step(sim, 0.2)
	_until_player(sim)


## The player holds left (-1) or right (+1) for some seconds.
func _walk(sim: CombatSim, dir: int, seconds: float) -> void:
	sim.set_move(dir)
	_step(sim, seconds)
	sim.set_move(0)


## Puts a fighter on the ground of column x (the tier closest to `ground`; nearby columns when it has none).
func _stand(sim: CombatSim, f: SimFighter, x: float, ground: float) -> void:
	for k in 60:
		for d in ([0] if k == 0 else [-1, 1]):
			var cx: float = x + d * k * 8.0
			var best: float = NAN
			for tier in sim.terrain.find_all_walkable_surfaces_at_x(cx):
				if is_nan(best) or absf(float(tier) - ground) < absf(best - ground):
					best = float(tier)
			if not is_nan(best) and absf(best - ground) < 40.0 and best < sim.terrain.water_y - 40.0:
				f.x = cx
				f.y = best - f.r - 2.0
				f.vx = 0.0
				f.vy = 0.0
				f.grounded = true
				f.sliding = false
				f.hurt_timer = 0.0
				f.jump_start_y = f.y
				f.peak_air_y = f.y
				return


## A surface point (x, y, walking distance) from which `f` can be reached by walking (leaping allowed), `min_d` to `max_d` px of walking away.
func _walk_from(sim: CombatSim, f: SimFighter, min_d: float, max_d: float) -> Vector3:
	for c in sim.walk_nav().reachable(Vector2(f.x, f.y), true, true):
		if c.z >= min_d and c.z <= max_d:
			return c
	return Vector3.ZERO


## The match plays on until the end; the game_over stats are returned (empty when it never ended).
func _stats_of(sim: CombatSim) -> Dictionary:
	var res: Dictionary = {}
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	return res


func _texts(sim: CombatSim) -> Array[String]:
	var out: Array[String] = []
	sim.float_text.connect(func(_p: Vector2, text: String, _c: Color, _l: float) -> void: out.append(text))
	return out


# ---------------------------------------------------------------------------
# Seeds
# ---------------------------------------------------------------------------

## Is the setup of a level playable? The line fits (n spots in single file, close neighbours on connected ground), the walk to the goal
## exists without leaping and is 3.5 to 7 turns long (the arena is 2200 px wide), and every enemy found a place. Returns {ok, why, goal_x, path}.
func _seed_report(sim: CombatSim) -> Dictionary:
	var out: Dictionary = {"ok": false, "why": "", "goal_x": 0.0, "path": 0.0}
	var squad: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == 0:
			squad.append(f)
	var l: SimFighter = squad[0]
	var reach: Array[Vector3] = sim.nav.reachable(Vector2(l.x, l.y), false)
	var cols: Dictionary = {}
	for c in reach:
		var col: int = roundi(c.x / SimNav.STEP)
		if not cols.has(col):
			cols[col] = []
		cols[col].append(c.y)
	for k in squad.size():
		var f: SimFighter = squad[k]
		var on_ground: bool = false
		for y in cols.get(roundi(f.x / SimNav.STEP), []):
			on_ground = on_ground or absf(float(y) - (f.y + f.r + 2.0)) <= 12.0
		if not on_ground:
			out["why"] = "member %d is not on ground the leader can walk" % k
			return out
		if k > 0:
			var gap: float = squad[k - 1].x - f.x
			if gap < 26.0 or gap > 56.0 or absf(squad[k - 1].y - f.y) > 30.0:
				out["why"] = "gap %d: %.0f px" % [k, gap]
				return out
	var best: Vector3 = Vector3.ZERO
	for c in reach:
		if absf(c.x - sim.goal_x) <= 12.0 and absf(c.y - sim.goal_y) <= 12.0:
			best = c
	if best == Vector3.ZERO:
		out["why"] = "the goal (x %d) cannot be walked to" % int(sim.goal_x)
		return out
	if best.z < 1450.0 or best.z > 2900.0:
		out["why"] = "the walk to the goal is %d px" % int(best.z)
		return out
	var enemies: int = 0
	for f in sim.fighters:
		enemies += 1 if f.team == 1 else 0
	var want: int = sim.level.enemy_roster().size() + (1 if sim.level.boss != null else 0)
	if enemies != want:
		out["why"] = "%d of %d enemies" % [enemies, want]
		return out
	out["ok"] = true
	out["goal_x"] = sim.goal_x
	out["path"] = best.z
	return out


func _scan(id: String, base: int) -> void:
	var found: int = 0
	var sd: int = base
	while found < 14 and sd < base + 700:
		var lv: LevelDef = _level(id).duplicate()
		var sim: CombatSim = _make(lv, sd)
		var r: Dictionary = _seed_report(sim)
		if r["ok"]:
			found += 1
			var l: SimFighter = sim.convoy_leader
			var path: Array[Vector2] = sim.nav.find_path(Vector2(l.x, l.y), Vector2(r["goal_x"], 0.0), false, 40.0)
			var marks: String = ""
			for frac in [0.35, 0.65]:
				if not path.is_empty():
					var p: Vector2 = path[int(path.size() * frac)]
					marks += " cloud(%d,%d)" % [int(p.x), int(p.y)]
			print("SEED %s %d goal_x %d path %d leader x %d%s" % [id, sd, int(r["goal_x"]), int(r["path"]), int(l.x), marks])
		elif OS.get_environment("CUCS_PROC_WHY") != "":
			print("skip %d: %s" % [sd, r["why"]])
		sd += 1


# ---------------------------------------------------------------------------
# Data and setup
# ---------------------------------------------------------------------------

func _data() -> void:
	var list: LevelList = load("res://data/levels/level_list.tres")
	var ids: Array[String] = []
	for lv in list.levels:
		ids.append(lv.id)
	var at: int = ids.find("proc_1")
	_check(at == ids.find("nest_boss") + 1 and ids.slice(at, at + 6) == PROC_LEVELS and ids.find("pupa_1") == at + 6, "level_list: proc_1..5 and proc_boss follow nest_boss and come before pupa_1")
	_check(ids.has("egg_1") and ids.has("larva_boss") and ids.has("cuca_6") and ids.has("nest_1") and ids.has("moth_boss") and ids.has("pupa_boss"), "level_list keeps the other stages")
	var table: Dictionary = {
		"proc_1": [0, 5, "CONVOY", 2],
		"proc_2": [2, 5, "CONVOY", 4],
		"proc_3": [6, 5, "CONVOY", 3],
		"proc_4": [5, 6, "CONVOY", 3],
		"proc_5": [1, 6, "CONVOY", 7],
		"proc_boss": [7, 6, "BOSS_OR_GOAL", 0],
	}
	for id in PROC_LEVELS:
		var lv: LevelDef = _level(id)
		var row: Array = table[id]
		var ok: bool = lv.stage == "PROCESSION" and lv.map_idx == row[0] and lv.player_names.size() == row[1] and lv.win_rule == row[2] and lv.enemy_roster().size() == row[3] \
			and lv.player_unit.id == "LARVA_L5" and lv.seed != 0 and lv.goal_x > 2000.0 and lv.march_budget == 420.0 and lv.is_convoy() \
			and lv.star_survivors == [row[1] - 1, row[1]] and lv.title_key == "LVL_%s_TITLE" % id.to_upper()
		_check(ok, "%s: map %d, %d caterpillars, rule %s, %d enemies, fixed seed, goal_x %d, stars by the file" % [id, row[0], row[1], row[2], row[3], int(lv.goal_x)])
	var orders: Array[int] = []
	for id in PROC_LEVELS:
		orders.append(_level(id).order)
	_check(orders == [24, 25, 26, 27, 28, 29], "orders 24..29 (between nest_boss 23 and pupa_1 30)")
	_check(_level("proc_3").mini_boss == "CALOSOMA" and _level("proc_3").unlocks == ["HOLY"] and _level("proc_2").boar_rounds.size() == 2 and _level("proc_4").spores.size() == 2 and _level("proc_5").spores.size() == 2 and _level("proc_boss").boss.id == "CUCKOO_BOSS", "proc_3 mini-boss and HOLY, proc_2 boars, spore clouds in proc_4 and proc_5, the cuckoo in proc_boss")
	var boar: UnitDef = load("res://data/units/wild_boar.tres")
	var cal: UnitDef = load("res://data/units/calosoma.tres")
	_check(boar.id == "WILD_BOAR" and boar.ai == "CHARGER" and not boar.killable, "WILD_BOAR: ai CHARGER, not killable")
	_check(cal.id == "CALOSOMA" and cal.max_hp == 120 and cal.speed_mult > 1.5 and cal.melee_damage == 20 and cal.ai == "MELEE_CRITTER" and cal.killable, "CALOSOMA: 120 HP, fast, 20-damage bite, melee critter")
	var def: BossDef = load("res://data/bosses/cuckoo_boss.tres")
	var kinds: Dictionary = {}
	for a in def.attacks:
		kinds[a["kind"]] = true
	_check(def.max_hp == 240 and def.flies and def.armored_mult == 0.25 and def.vulnerable_states == ["SATED"] and def.phases == [0.5] and kinds.has("MELEE_TARGET") and kinds.has("GUST") and kinds.has("MOVE"), "cuckoo_boss: 240 HP, flies, armour x0.25 except SATED, phase at 50 %, SWOOP + GUST + MOVE")
	var swoop1: Dictionary = def.attacks_of_phase(1)[0]
	var swoop2: Dictionary = def.attacks_of_phase(2)[0]
	_check(swoop1["id"] == "SWOOP" and int(swoop1["damage"]) == 30 and int(swoop1["targets"]) == 1 and swoop2["id"] == "SWOOP" and int(swoop2["targets"]) == 2, "SWOOP: 30 damage, 1 follower in phase 1 and 2 in phase 2")
	_check(_level("proc_boss").unlocks.is_empty() and BossAttacks.handler("MELEE_TARGET") != null, "the boss framework is reused (no new handler)")


func _setup() -> void:
	for id in PROC_LEVELS:
		var lv: LevelDef = _level(id)
		var sim := _make(lv)
		var squad: Array[SimFighter] = _squad(sim)
		var leaders: int = 0
		for f in squad:
			leaders += 1 if f.is_leader else 0
		var spaced: bool = true
		var fits: bool = true
		for k in range(1, squad.size()):
			var gap: float = squad[k - 1].x - squad[k].x
			spaced = spaced and gap >= 30.0 and gap <= 42.0 and absf(squad[k - 1].y - squad[k].y) <= 17.0
			fits = fits and squad[k].line_index == k
		var rep: Dictionary = _seed_report(sim)
		_check(squad.size() == lv.player_names.size() and leaders == 1 and squad[0].is_leader and sim.convoy_leader == squad[0] and sim.convoy_line == squad and fits and spaced, "%s: the leader is member 0, the file has %d places 36 px apart on gentle ground" % [id, squad.size()])
		_check(rep["ok"] and sim.goal_x > 2000.0 and absf(sim.goal_x - lv.goal_x) <= 220.0, "%s: the seed is playable (%s), the walk to goal_x %d is %d px (no leaping)" % [id, str(rep["why"]), int(sim.goal_x), int(rep["path"])])
		_check(sim.active_team == 0 and sim.active_fighter == squad[0] and sim.march_left == 420.0 and sim.march_budget == 420.0 and sim.convoy_start_count == squad.size(), "%s: the leader plays first with a full march budget" % id)
	var sim := _make(_level("proc_1"))
	_check(sim.enemies_alive == 2 and sim.winner == -1 and not sim.goal_reached and sim.convoy_trail.points.size() == 4, "proc_1: 2 ants, nobody has won, the trail starts as the file stands")
	_check(not sim.switch_fighter(), "Tab does not switch fighters in a procession")


# ---------------------------------------------------------------------------
# Following, march budget
# ---------------------------------------------------------------------------

## Distance (px) from a point to the polyline of the leader's trail (and the leader).
func _off_trail(sim: CombatSim, p: Vector2) -> float:
	var pts: Array[Vector2] = sim.convoy_trail.points.duplicate()
	pts.append(Vector2(sim.convoy_leader.x, sim.convoy_leader.y))
	var best: float = INF
	for i in range(1, pts.size()):
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i]).distance_to(p))
	return best


func _following() -> void:
	var sim := _make(_level("proc_1"))
	_no_ants(sim)
	var squad: Array[SimFighter] = _squad(sim)
	var x0: Array[float] = []
	for f in squad:
		x0.append(f.x)
	var lead_texts: Array[int] = [0]
	sim.convoy_changed.connect(func() -> void: lead_texts[0] += 1)
	_walk(sim, 1, 2.5)
	_step(sim, 1.2)
	var moved: bool = true
	var ordered: bool = true
	var spaced: bool = true
	var on_trail: bool = true
	var gaps: Array[int] = []
	for k in squad.size():
		moved = moved and squad[k].x > x0[k] + 80.0
		if k > 0:
			ordered = ordered and squad[k].x < squad[k - 1].x
			var d: float = Vector2(squad[k - 1].x - squad[k].x, squad[k - 1].y - squad[k].y).length()
			gaps.append(int(d))
			spaced = spaced and d >= 20.0 and d <= 60.0
			on_trail = on_trail and _off_trail(sim, Vector2(squad[k].x, squad[k].y)) <= 3.0 and squad[k].facing == 1
	_check(moved, "the leader walks 2.5 s: every follower walked at least 80 px after it (%.0f px for the leader)" % (squad[0].x - x0[0]))
	_check(ordered and spaced, "the file keeps its order and its spacing (20-60 px between neighbours, 36 along the path): %s" % str(gaps))
	_check(on_trail, "the followers stand on the path the leader walked and face the way it went")
	_check(lead_texts[0] == 0 and sim.convoy_line.size() == 5, "nobody was lost on the way")
	# the leader walks back: the file turns round along the same path
	_walk(sim, -1, 1.5)
	_step(sim, 1.0)
	_check(Vector2(squad[0].x - squad[1].x, squad[0].y - squad[1].y).length() <= 46.0 and sim.convoy_line.size() == 5, "walking back: the file turns round with the leader and nobody is lost")
	# a follower that is hit stays in the file when it is not far
	var hp1: int = squad[2].hp
	SimCombat.damage_fighter(sim, squad[2], 10)
	_step(sim, 0.5)
	_check(squad[2].hp == hp1 - 10 and sim.convoy_line.has(squad[2]), "followers can be hit and stay in the line")


func _march() -> void:
	var sim := _make(_level("proc_1"))
	_no_ants(sim)
	var l: SimFighter = sim.convoy_leader
	var x0: float = l.x
	var huds: Array[int] = [0]
	sim.hud_changed.connect(func() -> void: huds[0] += 1)
	_walk(sim, 1, 1.0)
	var left1: float = sim.march_left
	_check(left1 < 420.0 and absf((420.0 - left1) - (l.x - x0)) <= 2.0 and huds[0] > 0, "the budget goes down with the distance walked (%.0f px walked, %.0f left) and the HUD hears of it" % [l.x - x0, left1])
	_walk(sim, 1, 8.0)
	_check(sim.march_left == 0.0 and absf((l.x - x0) - 420.0) <= 24.0, "the walk stops with the budget: %.0f px net for a budget of 420 (the leader may slip back a little)" % (l.x - x0))
	var xs: float = l.x
	_walk(sim, 1, 1.0)
	sim.jump_forward()
	_step(sim, 0.6)
	_check(l.x == xs and l.grounded, "with the budget spent the leader neither walks nor jumps")
	_check(sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_fighter == l, "the turn goes on (it may still fire) until the timer ends")
	_next_round(sim)
	_check(sim.march_left == 420.0 and sim.active_fighter == l and sim.round_number == 2, "next round: the budget is full again and the leader plays")
	_walk(sim, 1, 1.0)
	_check(sim.march_left < 420.0, "and the leader walks again")
	for k in 3:
		_next_round(sim)
		_check(sim.active_fighter == sim.convoy_leader, "round %d: it is always the leader's turn" % sim.round_number)


# ---------------------------------------------------------------------------
# Lost and rejoined followers
# ---------------------------------------------------------------------------

func _lost_and_rejoin() -> void:
	var sim := _make(_level("proc_1"))
	_no_ants(sim)
	_sturdy(sim)
	var squad: Array[SimFighter] = _squad(sim)
	var changes: Array[int] = [0]
	sim.convoy_changed.connect(func() -> void: changes[0] += 1)
	var texts: Array[String] = _texts(sim)
	_walk(sim, 1, 1.5)
	_step(sim, 1.0)
	var l: SimFighter = squad[0]
	var tail: SimFighter = squad[4]
	# a follower flung 100 px (inside the limit) is not lost: it walks back to its place
	var near: float = tail.x - 100.0
	_stand(sim, tail, near, l.y + l.r)
	tail.hurt_timer = 0.0
	_step(sim, 0.3)
	_check(not tail.lost and sim.convoy_line.has(tail), "100 px away from its place a follower is still in the line")
	_step(sim, 1.5)
	# one flung 300 px behind is lost
	_stand(sim, tail, l.x - 330.0, l.y + l.r)
	_step(sim, 0.3)
	_check(tail.lost and not sim.convoy_line.has(tail) and tail.line_index == -1 and sim.convoy_line.size() == 4 and changes[0] >= 1, "300 px away it is lost: out of the line, line_index -1, the file closes up")
	_check(texts.has(sim.tx("FT_LINE_LOST", [tail.name])), "a floating text says it")
	var idx_ok: bool = true
	for k in 4:
		idx_ok = idx_ok and squad[k].line_index == k
	_check(idx_ok, "the others keep places 0..3")
	var lx: float = tail.x
	_step(sim, 1.0)
	_check(tail.lost and absf(tail.x - lx) < 1.0, "a lost follower stays where it is")
	# the leader walks back: it picks it up when it is within 60 px
	var rejoined: Array[int] = [-1]
	for step_i in 400:
		sim.set_move(-1)
		_step(sim, 0.05)
		if not tail.lost and rejoined[0] < 0:
			rejoined[0] = step_i
			break
	sim.set_move(0)
	_check(not tail.lost and sim.convoy_line.back() == tail and tail.line_index == 4 and absf(l.x - tail.x) <= 80.0, "the leader walked back to it (%.0f px apart): it is back in the line, at the tail" % absf(l.x - tail.x))
	_check(texts.has(sim.tx("FT_LINE_REJOINED", [tail.name])), "and the text says that too")
	# a dead follower leaves the line for good
	SimCombat.damage_fighter(sim, squad[2], 99999)
	_step(sim, 0.2)
	_check(not sim.convoy_line.has(squad[2]) and squad[3].line_index == 2 and squad[4].line_index == 3 and sim.convoy_line.size() == 4, "a fallen follower leaves the line and the places close up")


# ---------------------------------------------------------------------------
# Goal, defeat, stars
# ---------------------------------------------------------------------------

## The leader stands on the goal ground.
func _to_goal(sim: CombatSim) -> void:
	_stand(sim, sim.convoy_leader, sim.goal_x, sim.goal_y)


func _goal_stars_and_defeat() -> void:
	var cases: Array = [
		["all five in the line", 0, 0, 3, 5],
		["one follower lost", 1, 0, 2, 4],
		["two followers fallen", 0, 2, 1, 3],
	]
	for c in cases:
		var sim := _make(_level("proc_1"))
		_no_ants(sim)
		var res: Dictionary = _stats_of(sim)
		var goals: Array[int] = [0]
		sim.convoy_goal_reached.connect(func() -> void: goals[0] += 1)
		var squad: Array[SimFighter] = _squad(sim)
		for k in int(c[2]):
			SimCombat.damage_fighter(sim, squad[4 - k], 99999)
		for k in int(c[1]):
			_stand(sim, squad[4], squad[0].x - 500.0, squad[0].y + 12.0)
		_step(sim, 0.4)
		_to_goal(sim)
		_step(sim, 0.2)
		_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.winner == 0 and sim.goal_reached and goals[0] == 1 and res.get("winner", -1) == 0, "%s: the leader on the goal wins" % c[0])
		_check(res.get("reason", "") == "GOAL_REACHED" and res.get("survivors", -1) == c[4] and res.get("stars", -1) == c[3] and res.get("won", false), "%s: %d in the line, %d stars (%s)" % [c[0], c[4], c[3], str(res)])
		if int(c[1]) > 0:
			_check(res.get("followers_lost", -1) == 1 and res.get("followers", -1) == 3 and res.get("followers_start", -1) == 4, "the stats list the followers: 3 of 4 in the line, 1 lost")
	# the goal needs the leader standing on it
	var sim := _make(_level("proc_1"))
	_no_ants(sim)
	_stand(sim, sim.convoy_leader, sim.goal_x - 400.0, sim.goal_y)
	_step(sim, 0.5)
	_check(sim.turn_phase != CombatSim.Phase.GAME_OVER and not sim.goal_reached, "400 px from the goal nothing is won")
	# the leader dies: lost, even with the followers alive
	var d := _make(_level("proc_1"))
	var dres: Dictionary = _stats_of(d)
	SimCombat.damage_fighter(d, d.convoy_leader, 99999)
	_next_round(d)
	_step(d, 4.0)
	_check(d.turn_phase == CombatSim.Phase.GAME_OVER and d.winner == 1 and dres.get("reason", "") == "LEADER_DIED" and not dres.get("won", true) and dres.get("stars", -1) == 0 and d.team_alive_count(0) == 4, "the leader dies: the level is lost (LEADER_DIED) with the 4 followers alive")
	# wiping out the enemy wins nothing, and an empty enemy turn is skipped
	var e := _make(_level("proc_1"))
	for f in _kind(e, "ANT"):
		SimCombat.damage_fighter(e, f, 99999)
	var round0: int = e.round_number
	e.end_turn()
	_until_player(e)
	_step(e, 0.5)
	_check(e.turn_phase == CombatSim.Phase.TURN_PLAY and e.active_team == 0 and e.round_number == round0 + 1 and e.winner == -1, "no enemy left: nobody wins, the enemy turn is skipped and the leader plays again")
	_check(e.enemies_alive == 0, "enemies_alive counts 0")


# ---------------------------------------------------------------------------
# Wild boar
# ---------------------------------------------------------------------------

func _boar() -> void:
	var lv: LevelDef = _level("proc_2")
	var sim := _make(lv)
	_no_ants(sim)
	_sturdy(sim)
	var boars: Array[SimFighter] = _kind(sim, "WILD_BOAR")
	var squad: Array[SimFighter] = _squad(sim)
	var l: SimFighter = squad[0]
	_check(boars.size() == 2 and boars[0].x < 0.0 and boars[0].ai_state == "wait" and boars[0].team == 1 and boars[0].alive, "proc_2: two wild boars wait off the map")
	_check(sim.enemies_alive == 0 and sim.boar_intents.is_empty(), "boars are not counted as enemies; nothing is announced yet")
	var hp0: int = boars[0].hp
	SimCombat.damage_fighter(sim, boars[0], 9999)
	SimCombat.trigger_explosion(sim, boars[0].x, boars[0].y, 60.0, 80.0, 300.0)
	_check(boars[0].hp == hp0 and boars[0].alive, "a boar cannot be hurt")
	var tele: Array[Dictionary] = []
	sim.boar_telegraph.connect(func(b: SimFighter, band: Rect2, side: int) -> void: tele.append({"boar": b, "band": band, "side": side}))
	var charged: Array[Dictionary] = []
	sim.boar_charge.connect(func(b: SimFighter, band: Rect2, side: int) -> void: charged.append({"boar": b, "band": band, "side": side}))
	var hits: Array[int] = [0]
	sim.boar_hit.connect(func(_b: SimFighter, _v: SimFighter) -> void: hits[0] += 1)
	var gone: Array[int] = [0]
	sim.boar_gone.connect(func(_b: SimFighter) -> void: gone[0] += 1)
	var texts: Array[String] = _texts(sim)
	_next_round(sim)
	_check(sim.round_number == 2 and tele.is_empty() and sim.boar_intents.is_empty() and boars[0].ai_state == "wait", "round 1 enemy turn: the boar is not due yet")
	_next_round(sim)
	_check(tele.size() == 1 and sim.boar_intents.size() == 1 and boars[0].ai_state == "warn" and charged.is_empty() and boars[1].ai_state == "wait", "round 2 enemy turn: the first boar announces its charge and does not charge yet")
	var it: Dictionary = sim.boar_intents[0]
	var band: Rect2 = it["band"]
	_check(it["boar"] == boars[0] and band.size.x == AiCharger.BAND_WIDTH and band.position.x >= l.x + 150.0 and band.size.y >= sim.terrain.water_y - 1.0 and (it["side"] == -1 or it["side"] == 1) and tele[0]["band"] == band and tele[0]["side"] == it["side"] and int(it["turns_left"]) == 1, "the telegraph: a band %d-%d px, ahead of the leader (x %d), from side %d" % [int(band.position.x), int(band.end.x), int(l.x), it["side"]])
	_check(texts.has(sim.tx("FT_BOAR_WARN")), "a warning text is shown")
	var fhp: int = squad[2].hp
	_check(l.x < band.position.x and sim.convoy_line.size() == 5, "the line is clear of the band")
	# a follower stands in the band, the leader stays out: the charge hits the follower only
	var victim: SimFighter = squad[2]
	_stand(sim, victim, band.position.x + band.size.x * 0.5, float(it["ground_y"]))
	var vx0: float = victim.x
	var lhp: int = l.hp
	_next_round(sim)
	var side: int = int(it["side"])
	_check(charged.size() == 1 and charged[0]["side"] == side and hits[0] >= 1 and gone[0] == 1, "next enemy turn: the boar charges (%d hit)" % hits[0])
	_check(victim.hp == fhp - AiCharger.HIT_DAMAGE and l.hp == lhp, "it hits the fighter in the band for %d and not the one outside" % AiCharger.HIT_DAMAGE)
	_check(signf(victim.x - vx0) == -float(side) and absf(victim.x - vx0) > 20.0, "and knocks it away from the side it came from (%.0f px)" % (victim.x - vx0))
	_check(boars[0].ai_state == "gone" and boars[0].x < 0.0 and boars[0].alive and sim.boar_intents.is_empty(), "the boar leaves: gone, off the map, alive (not killable), nothing announced")
	_check(boars[1].ai_state == "wait", "the second boar is not due yet")
	_next_round(sim)
	_check(boars[1].ai_state == "warn" and sim.boar_intents.size() == 1 and sim.boar_intents[0]["boar"] == boars[1], "round 4 enemy turn: the second boar announces")
	_next_round(sim)
	_check(boars[1].ai_state == "gone" and hits[0] >= 1 and gone[0] == 2, "and charges the turn after: both boars are gone")
	for k in 3:
		_next_round(sim)
	_check(sim.boar_intents.is_empty() and sim.turn_phase == CombatSim.Phase.TURN_PLAY, "later rounds are quiet")


# ---------------------------------------------------------------------------
# Calosoma
# ---------------------------------------------------------------------------

func _calosoma() -> void:
	var sim := _make(_level("proc_3"))
	_no_ants(sim)
	_sturdy(sim)
	var squad: Array[SimFighter] = _squad(sim)
	var cal: SimFighter = _kind(sim, "CALOSOMA")[0]
	_check(cal.hp == 120 and cal.team == 1 and cal.unit.speed_mult == 1.8, "proc_3: the Calosoma has 120 HP and walks 1.8 times faster")
	var tail: SimFighter = squad[4]
	var from: Vector3 = _walk_from(sim, tail, 240.0, 320.0)
	_check(from != Vector3.ZERO, "scenario: a spot 240-320 px of walking behind the tail")
	_stand(sim, cal, from.x, from.y)
	var cx0: float = cal.x
	var nearest: SimFighter = AiCritter._nearest_visible(sim, cal)
	var hps: Dictionary = {}
	for f in squad:
		hps[f.id] = f.hp
	var texts: Array[String] = _texts(sim)
	sim.end_turn()
	_step(sim, 0.2)
	var chased: float = 0.0
	var t: float = 0.0
	while t < 30.0 and not (sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0):
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		chased = maxf(chased, absf(cal.x - cx0))
	var hurt: Array[SimFighter] = []
	for f in squad:
		if f.hp < int(hps[f.id]):
			hurt.append(f)
	_check(chased > 30.0 and chased < 700.0, "it chases the line: %.0f px of its turn (it walks 1.8 times as fast as an ant)" % chased)
	_check(hurt.size() == 1 and hurt[0] == nearest and nearest.hp == int(hps[nearest.id]) - 20, "it bites the caterpillar nearest to it (%s) for exactly 20 and nobody else" % nearest.name)
	_check(texts.any(func(s: String) -> bool: return s.contains("20")), "the bite shows its damage")
	# its defeat wins the level (ELIMINATE it or reach the goal)
	var res: Dictionary = _stats_of(sim)
	SimCombat.damage_fighter(sim, cal, 99999)
	_next_round(sim)
	_step(sim, 0.5)
	_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.winner == 0 and res.get("reason", "") == "MINI_BOSS_DEFEATED" and res.get("stars", 0) >= 1, "the Calosoma down: the level is won (MINI_BOSS_DEFEATED)")
	# the others do not win it
	var s2 := _make(_level("proc_3"))
	for f in _kind(s2, "ANT"):
		SimCombat.damage_fighter(s2, f, 99999)
	_next_round(s2)
	_check(s2.turn_phase == CombatSim.Phase.TURN_PLAY and s2.winner == -1, "killing the ants wins nothing while the Calosoma lives")


# ---------------------------------------------------------------------------
# Spore clouds
# ---------------------------------------------------------------------------

func _spores() -> void:
	var lv: LevelDef = _level("proc_4")
	var sim := _make(lv)
	_no_ants(sim)
	var squad: Array[SimFighter] = _squad(sim)
	_check(sim.spores.size() == 2 and sim.spores[0] == lv.spores[0] and sim.spores[1] == lv.spores[1], "proc_4: the level's two clouds are in the sim at their start rects")
	var cloud: Rect2 = sim.spores[0]
	var ticks: Array[SimFighter] = []
	sim.spore_tick.connect(func(f: SimFighter, d: int) -> void:
		if d == SimSpores.SPORE_DAMAGE:
			ticks.append(f))
	# the leader and one follower stand in the cloud, the rest outside
	var l: SimFighter = squad[0]
	_stand(sim, l, cloud.position.x + 40.0, cloud.position.y + 150.0)
	_stand(sim, squad[1], cloud.position.x + 80.0, cloud.position.y + 150.0)
	_check(SimSpores.inside(sim, l) and SimSpores.inside(sim, squad[1]) and not SimSpores.inside(sim, squad[3]), "scenario: two caterpillars inside the cloud, the others outside")
	var hps: Array[int] = []
	for f in squad:
		hps.append(f.hp)
	_next_round(sim)
	_check(l.hp == hps[0] - 6 and squad[1].hp == hps[1] - 6 and squad[3].hp == hps[3] and squad[4].hp == hps[4], "at the start of the turn each caterpillar inside loses 6 HP, the others nothing")
	_check(ticks.size() == 2 and ticks.has(l) and ticks.has(squad[1]), "spore_tick is announced for each")
	# a drifting cloud moves every round and turns round at the end of the map; a static one stays
	var c2: Rect2 = sim.spores[1]
	_check(sim.spores[0] == lv.spores[0], "the static cloud did not move")
	_check(c2.position.x == lv.spores[1].position.x + 40.0, "the drifting cloud moved 40 px at the start of round 2")
	_next_round(sim)
	_check(sim.spores[1].position.x == lv.spores[1].position.x + 80.0, "and 40 more at round 3")
	# it bounces at the edge
	var edge := CombatSim.new()
	var elv: LevelDef = lv.duplicate()
	elv.spores = [Rect2(SimTables.TERRAIN_W * 0.5 + elv.arena_width * 0.5 - 250.0, 200.0, 120.0, 100.0)]
	elv.spore_drift = [100.0]
	var cfg := MatchConfig.new()
	cfg.level = elv
	cfg.map_idx = elv.map_idx
	cfg.seed = elv.seed
	edge.setup(cfg)
	SimSpores.drift(edge)
	SimSpores.drift(edge)
	_check(edge.spores[0].end.x <= edge.terrain.arena_x1 - SimSpores.EDGE + 0.1 and edge.spore_speeds[0] < 0.0, "a cloud at the edge of the map turns round")
	# enemies cough too, at the start of their own turn
	var s2 := _make(lv)
	var ant: SimFighter = _kind(s2, "ANT")[0]
	var c0: Rect2 = s2.spores[0]
	_stand(s2, ant, c0.position.x + 60.0, c0.position.y + 150.0)
	s2.active_team = 1
	s2.active_fighter = ant
	var ahp: int = ant.hp
	SimSpores.on_turn_start(s2)
	_check(ant.hp == ahp - 6, "an ant inside a cloud at the start of its own turn loses 6 too")


# ---------------------------------------------------------------------------
# The cuckoo
# ---------------------------------------------------------------------------

## Only this attack id can be announced (the others are put on a long cooldown).
func _force(sim: CombatSim, attack_id: String) -> void:
	for a in sim.boss_def.attacks:
		if a["id"] != attack_id:
			sim.boss_memory["cooldowns"][a["id"]] = 99


## The squad ends its turn and steps until the boss's own sub-turn ran and ended; false if it never came.
func _boss_turn(sim: CombatSim, max_s: float = 150.0) -> bool:
	var t: float = 0.0
	var seen: bool = false
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		if sim.active_fighter == sim.boss and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
			seen = true
		elif seen:
			return true
	return seen


func _cuckoo() -> void:
	var lv: LevelDef = _level("proc_boss")
	var sim := _make(lv)
	_sturdy(sim)
	var b: SimFighter = sim.boss
	_check(b != null and b.kind == "CUCKOO_BOSS" and b.hp == 240 and sim.boss_def.flies and lv.win_rule == "BOSS_OR_GOAL" and sim.boss_phase == 1, "proc_boss: the cuckoo (240 HP, flying) and the BOSS_OR_GOAL rule")
	# the announcement: it marks one follower, never the leader
	_force(sim, "SWOOP")
	_boss_turn(sim)
	var intent: Dictionary = sim.boss_intent
	var marks: Array = intent.get("targets", [])
	var victim: SimFighter = BossAttack.fighter_by_id(sim, int(intent.get("target_id", -1)))
	_check(intent.get("attack_id", "") == "SWOOP" and intent.get("kind", "") == "MELEE_TARGET" and marks.size() == 1 and victim != null and not victim.is_leader and sim.boss_state == "INTENT", "SWOOP is announced on one follower (%s), not the leader" % (victim.name if victim != null else "?"))
	var leader_marked_once: bool = false
	for k in 6:
		var s2 := _make(lv, lv.seed + k)
		_force(s2, "SWOOP")
		_boss_turn(s2)
		leader_marked_once = leader_marked_once or int(s2.boss_intent.get("target_id", -1)) == s2.convoy_leader.id
	_check(not leader_marked_once, "over 6 different matches the leader is never marked")
	# not moving: it dives and hits for 30; moving the line away dodges it
	var hit_sim := _make(lv)
	_sturdy(hit_sim)
	_force(hit_sim, "SWOOP")
	_boss_turn(hit_sim)
	_until_player(hit_sim)
	var hv: SimFighter = BossAttack.fighter_by_id(hit_sim, int(hit_sim.boss_intent["target_id"]))
	var hhp: int = hv.hp
	var attacks: Array[String] = []
	hit_sim.boss_attack.connect(func(id: String, _p: Vector2) -> void: attacks.append(id))
	_boss_turn(hit_sim)
	_check(hv.hp == hhp - 30 and attacks.has("SWOOP"), "if the line stays put the marked follower takes 30 (%d -> %d)" % [hhp, hv.hp])
	var dodge_sim := _make(lv)
	_sturdy(dodge_sim)
	_force(dodge_sim, "SWOOP")
	var dtexts: Array[String] = _texts(dodge_sim)
	_boss_turn(dodge_sim)
	_until_player(dodge_sim)
	var dv: SimFighter = BossAttack.fighter_by_id(dodge_sim, int(dodge_sim.boss_intent["target_id"]))
	var dhp: int = dv.hp
	var mark_pos: Vector2 = dodge_sim.boss_intent["targets"][0]["pos"]
	_walk(dodge_sim, 1, 3.0)
	_step(dodge_sim, 1.2)
	_check(Vector2(dv.x, dv.y).distance_to(mark_pos) > 90.0, "scenario: walking the line moved the marked follower %.0f px" % Vector2(dv.x, dv.y).distance_to(mark_pos))
	_boss_turn(dodge_sim)
	_check(dv.hp == dhp and dtexts.has(dodge_sim.tx("FT_DODGED")), "walking the line dodges the swoop: no damage, \"dodged\" text")
	# phase 2: two followers are marked
	var p2 := _make(lv)
	_sturdy(p2)
	p2.boss.hp = 100
	SimCombat.damage_fighter(p2, p2.boss, 1)
	_check(p2.boss_phase == 2, "below 50 % HP the cuckoo is in phase 2")
	_force(p2, "SWOOP")
	_boss_turn(p2)
	var m2: Array = p2.boss_intent.get("targets", [])
	var leader_marked: bool = false
	for m in m2:
		leader_marked = leader_marked or int(m["id"]) == p2.convoy_leader.id
	_check(m2.size() == 2 and not leader_marked and int(m2[0]["id"]) != int(m2[1]["id"]), "phase 2: SWOOP marks two different followers")
	# SATED: after two attacks it perches to digest; only then it takes full damage
	var s3 := _make(lv)
	_sturdy(s3)
	var states: Array[String] = []
	s3.boss_changed.connect(func() -> void:
		if states.is_empty() or states.back() != s3.boss_state:
			states.append(s3.boss_state))
	var sated_at: int = -1
	for turn_i in 8:
		_boss_turn(s3)
		if s3.boss_state == "SATED":
			sated_at = turn_i
			break
	_check(sated_at >= 2, "after 2 attacks it goes to a perch and is SATED (turn %d)" % sated_at)
	if sated_at >= 0:
		_until_player(s3)
		var hp0: int = s3.boss.hp
		SimCombat.damage_fighter(s3, s3.boss, 40)
		_check(s3.boss.hp == hp0 - 40, "SATED: it takes full damage (%d -> %d)" % [hp0, s3.boss.hp])
		_boss_turn(s3)
		_check(s3.boss_state != "SATED", "its next turn ends the window")
		hp0 = s3.boss.hp
		SimCombat.damage_fighter(s3, s3.boss, 40)
		_check(s3.boss.hp == hp0 - 10, "outside SATED the armour x0.25 holds (40 -> 10)")
	# BOSS_OR_GOAL: either wins
	var w1 := _make(lv)
	var r1: Dictionary = _stats_of(w1)
	w1.boss.hp = 5
	_stand(w1, w1.boss, w1.boss.x, w1.boss.y + w1.boss.r)
	_force(w1, "SWOOP")
	_boss_turn(w1)
	_until_player(w1)
	SimBoss.set_state(w1, "SATED")
	SimCombat.damage_fighter(w1, w1.boss, 99999)
	_next_round(w1)
	_step(w1, 0.5)
	_check(w1.turn_phase == CombatSim.Phase.GAME_OVER and w1.winner == 0 and r1.get("reason", "") == "BOSS_DEFEATED" and not w1.goal_reached, "the cuckoo defeated: the level is won (BOSS_DEFEATED)")
	var w2 := _make(lv)
	var r2: Dictionary = _stats_of(w2)
	_to_goal(w2)
	_step(w2, 0.2)
	_check(w2.turn_phase == CombatSim.Phase.GAME_OVER and w2.winner == 0 and r2.get("reason", "") == "GOAL_REACHED" and w2.boss.alive and r2.get("stars", 0) == 3, "the leader on the goal with the cuckoo alive: the level is won (GOAL_REACHED, 3 stars)")
	var w3 := _make(lv)
	SimCombat.damage_fighter(w3, w3.convoy_leader, 99999)
	_boss_turn(w3)
	_step(w3, 3.0)
	_check(w3.turn_phase == CombatSim.Phase.GAME_OVER and w3.winner == 1, "the leader dead: lost")


# ---------------------------------------------------------------------------
# Classic matches
# ---------------------------------------------------------------------------

func _classic_untouched() -> void:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.map_idx = 3
	cfg.seed = 12
	cfg.worms_per_team = 4
	sim.setup(cfg)
	var any_leader: bool = false
	for f in sim.fighters:
		any_leader = any_leader or f.is_leader or f.lost or f.line_index != -1
	_check(not any_leader and sim.convoy_leader == null and sim.convoy_line.is_empty() and sim.march_budget == 0.0 and sim.goal_x < 0.0 and sim.spores.is_empty() and sim.boar_intents.is_empty() and not SimConvoy.active(sim), "classic: no leader, no line, no goal, no clouds, no boars")
	_check(sim.weapons.size() == 16 and sim.enemies_alive == sim.team_alive_count(1) and sim.team_alive_count(1, true) == 4, "classic: the 16 weapons and the usual counts")
	# the classic linked allies and the F convoy march still work
	var a: SimFighter = sim.active_fighter
	var ally: SimFighter = null
	for f in sim.fighters:
		if f != a and f.team == a.team:
			ally = f
			break
	ally.x = a.x - 40.0
	ally.y = a.y
	_step(sim, 0.1)
	_check(a.linked_allies.has(ally) and sim.procession_convoy_enabled, "classic: allies within 52 px are linked and the convoy march is on")
	sim.toggle_convoy()
	_check(not sim.procession_convoy_enabled, "classic: F toggles the convoy march")
	var rounds: int = sim.round_number
	var picked: Array[SimFighter] = []
	for k in 4:
		_next_round(sim)
		picked.append(sim.active_fighter)
	var distinct: Dictionary = {}
	for f in picked:
		distinct[f.id] = true
	_check(sim.round_number == rounds + 4 and sim.turn_phase != CombatSim.Phase.GAME_OVER and distinct.size() >= 2, "classic: the squad members still take turns")
	var jump_ok := CombatSim.new()
	jump_ok.setup(cfg)
	_check(jump_ok.switch_fighter() or jump_ok.team_alive_count(jump_ok.active_team) <= 1, "classic: Tab still switches fighters")


# ---------------------------------------------------------------------------
# CPU runs
# ---------------------------------------------------------------------------

## Seeds with a playable setup (found with CUCS_PROC_SCAN; each one is checked again with _seed_report before it is used). The first is the level seed.
const RUN_SEED_LIST: Dictionary = {
	"proc_1": [7368, 7121, 7548, 7184, 7274],
	"proc_2": [7103, 7133, 7155, 7266, 7379],
	"proc_3": [7176, 7482, 7274, 7368, 7843],
	"proc_4": [7372, 7103, 7106, 7192, 7315],
	"proc_5": [7287, 7133, 7411, 7729],
	"proc_boss": [7363, 7146, 7352, 7395],
}


func _cpu_match(level: LevelDef, seed_v: int) -> Dictionary:
	var sim := _make(level, seed_v)
	sim.game_mode = "CPU_CPU"
	var res: Dictionary = _stats_of(sim)
	var counters: Dictionary = {"lost": 0, "rejoined": 0, "charges": 0, "boar_hits": 0, "spores": 0}
	var was_lost: Dictionary = {}
	sim.convoy_changed.connect(func() -> void:
		for f in _squad(sim):
			if f.lost and not was_lost.get(f.id, false):
				counters["lost"] = int(counters["lost"]) + 1
			was_lost[f.id] = f.lost)
	sim.boar_charge.connect(func(_b: SimFighter, _band: Rect2, _s: int) -> void: counters["charges"] = int(counters["charges"]) + 1)
	sim.boar_hit.connect(func(_b: SimFighter, _v: SimFighter) -> void: counters["boar_hits"] = int(counters["boar_hits"]) + 1)
	sim.spore_tick.connect(func(_f: SimFighter, _d: int) -> void: counters["spores"] = int(counters["spores"]) + 1)
	var t: float = 0.0
	var bad: bool = false
	var frame: int = 0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and t < RUN_LIMIT_S:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		frame += 1
		if frame % 300 == 0:
			for f in sim.fighters:
				bad = bad or is_nan(f.x) or is_nan(f.y) or (f.alive and not f.drowning and f.unit != null and f.unit.killable and f.y > sim.terrain.water_y + 60.0)
	res["done"] = sim.turn_phase == CombatSim.Phase.GAME_OVER and res.has("winner")
	res["bad"] = bad
	res["seconds"] = t
	res["rounds_played"] = sim.round_number
	res.merge(counters, true)
	return res


func _cpu_runs() -> void:
	for id in PROC_LEVELS:
		var level: LevelDef = _level(id)
		var seeds: Array[int] = []
		for sd in RUN_SEED_LIST[id]:
			if _seed_report(_make(level, sd))["ok"]:
				seeds.append(sd)
		var wins: int = 0
		var finished: int = 0
		var clean: int = 0
		var in_line: int = 0
		var started: int = Time.get_ticks_msec()
		for sd in seeds:
			var r: Dictionary = _cpu_match(level, sd)
			finished += 1 if r["done"] else 0
			clean += 0 if r["bad"] else 1
			wins += 1 if r.get("won", false) else 0
			in_line += int(r.get("survivors", 0))
			print("INFO  %s seed %d: %s (%s), in the line %d of %d, rounds %d, lost %d, boar charges %d (%d hits), spore ticks %d (%.0f s sim)" % [
				id, sd, "WON" if r.get("won", false) else "lost", str(r.get("reason", "")), int(r.get("survivors", 0)), level.player_names.size(), int(r["rounds_played"]), int(r["lost"]), int(r["charges"]), int(r["boar_hits"]), int(r["spores"]), float(r["seconds"])])
		_check(seeds.size() == RUN_SEED_LIST[id].size() and finished == seeds.size() and clean == seeds.size(), "%s: %d CPU runs end without errors (seeds %s)" % [id, finished, str(seeds)])
		print("INFO  %s: the CPU leader reaches the goal in %d of %d runs, %.1f of %d in the line on average (%.1f s)" % [id, wins, seeds.size(), in_line / float(maxi(1, seeds.size())), level.player_names.size(), (Time.get_ticks_msec() - started) / 1000.0])
