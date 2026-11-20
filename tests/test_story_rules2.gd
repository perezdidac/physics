## Story levels of the second pass (docs/story_contracts.md §7): the level data of larva_1..5 and cuca_1..6 (arena size, enemy counts, goal and
## twist of each), and the rules REACH, RESCUE, COLLECT, ONE_SHOT, the destructible anthill, the barrel chain, the mines, hide-and-seek and the
## tide, each with its win and lose paths, plus the HUD objective line of every new rule on the real CombatScreen.
##   godot --headless --path . res://tests/TestStoryRules2.tscn
## Print the playable seeds of a level from a base: CUCS_LVL2_SCAN=larva_2:4300 godot --headless --path . res://tests/TestStoryRules2.tscn
extends Node

const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["larva_1", "larva_2", "larva_3", "larva_4", "larva_5", "cuca_1", "cuca_2", "cuca_3", "cuca_4", "cuca_5", "cuca_6"]
## id -> [arena, rule, enemies at the start, twist]
const ROWS: Dictionary = {
	"larva_1": [900.0, "ELIMINATE", 2, "none"],
	"larva_2": [1000.0, "REACH", 2, "wind"],
	"larva_3": [1100.0, "WAVES", 0, "barrels"],
	"larva_4": [1100.0, "RESCUE", 3, "tide"],
	"larva_5": [1200.0, "SURVIVE_ROUNDS", 3, "mines"],
	"cuca_1": [1200.0, "ELIMINATE", 2, "wind"],
	"cuca_2": [1300.0, "COLLECT", 3, "supply"],
	"cuca_3": [1300.0, "ELIMINATE", 3, "barrels"],
	"cuca_4": [1400.0, "ONE_SHOT", 1, "wind"],
	"cuca_5": [1400.0, "ELIMINATE", 3, "mines"],
	"cuca_6": [1500.0, "WAVES", 1, "tide"],
}

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id)


func _make(level: LevelDef, seed_v: int = -1, extra: Dictionary = {}) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.level = level
	cfg.map_idx = level.map_idx
	cfg.seed = level.seed if seed_v < 0 else seed_v
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = level.player_names.size()
	cfg.extra_arsenal = extra
	sim.setup(cfg)
	return sim


func _team(sim: CombatSim, team: int) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.team == team:
			out.append(f)
	return out


func _sturdy(sim: CombatSim) -> void:
	for f in _team(sim, 0):
		f.hp = 9999
		f.max_hp = 9999


func _run(sim: CombatSim, seconds: float) -> void:
	for i in int(seconds / DT):
		sim.step(DT)
		sim.advance_real(DT)


## Steps until the match is over, passing every turn of the squad; returns the seconds spent.
func _pass_until_over(sim: CombatSim, max_s: float = 1200.0) -> float:
	var t: float = 0.0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and t < max_s:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
	return t


## Puts a squad caterpillar on the ground point `p` (the surface).
func _put(f: SimFighter, p: Vector2) -> void:
	f.x = p.x
	f.y = p.y - f.r - 2.0
	f.vx = 0.0
	f.vy = 0.0
	f.grounded = true
	f.jump_start_y = f.y
	f.peak_air_y = f.y


func _overs(sim: CombatSim) -> Array:
	var overs: Array = []
	sim.game_over.connect(func(w: int, s: Dictionary) -> void: overs.append([w, s]))
	return overs


func _ready() -> void:
	var place: String = OS.get_environment("CUCS_LVL2_PLACE")
	if place != "":
		for id in IDS:
			var lv: LevelDef = _level(id)
			var sim := _make(lv)
			var main: Dictionary = sim.walk_nav().main_ground(sim.terrain.arena_x0, sim.terrain.arena_x1)
			print("PLACE %s seed %d: arena %d-%d main span %d strict=%s" % [id, lv.seed, sim.terrain.arena_x0, sim.terrain.arena_x1, SimNav.node_span(main), str(sim.placement_nav == sim.walk_nav())])
		get_tree().quit()
		return
	var scan: String = OS.get_environment("CUCS_LVL2_SCAN")
	if scan != "":
		_scan(scan.split(":")[0], int(scan.split(":")[1]))
		get_tree().quit()
		return
	_data()
	_setup_all()
	_reach()
	_rescue()
	_anthill()
	_collect()
	_one_shot()
	_barrel_chain()
	_hide_and_seek()
	_tide()
	_ammo_free_levels()
	_integration_fixes()
	await _hud()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Seeds
# ---------------------------------------------------------------------------

## Playable setup: open sky over the squad (the birds dive from there), every ground enemy and the anthill can walk to the squad, the goal
## of the level exists and can be walked to, and what the level places (nuts, barrels, mines, hiding spots) was placed.
func _seed_report(level: LevelDef, seed_v: int) -> String:
	var sim := _make(level, seed_v)
	var squad: Array[SimFighter] = _team(sim, 0)
	var home := Vector2(squad[0].x, squad[0].y)
	if sim.placement_nav != sim.walk_nav() and level.mode == "COMBAT" and not level.is_convoy():
		return "permissive placement (the main ground is too narrow)"
	var birds: bool = false
	for e in level.enemy_roster():
		birds = birds or e.flies
	for f in squad:
		if birds and not AiFlyer._clear_line(sim, Vector2(f.x, f.y - 150.0), Vector2(f.x, f.y)):
			return "no open sky over %s" % f.name
		if f != squad[0] and sim.nav.find_path(home, Vector2(f.x, f.y), true).is_empty():
			return "%s cannot walk to the squad" % f.name
	for f in _team(sim, 1):
		if not f.flying and sim.nav.find_path(Vector2(f.x, f.y), home, true).is_empty():
			return "%s cannot reach the squad" % f.name
	if sim.anthill_pos != Vector2.INF and sim.nav.find_path(Vector2(sim.anthill_pos.x + SimStory.WAVE_GAP, sim.anthill_pos.y + TerrainSim.ANTHILL_H - 10.0), home, true).is_empty():
		return "the anthill cannot reach the squad"
	var span: Vector2 = SimStory.spawn_span(sim)
	var usable: float = span.y - span.x
	var g: SimGoals = sim.goals
	if g.pos != Vector2.INF:
		if absf(g.pos.x - home.x) < usable * 0.35:
			return "the goal is too close (%d px)" % int(absf(g.pos.x - home.x))
		var path: Array[Vector2] = sim.nav.find_path(home, Vector2(g.pos.x, g.pos.y - 12.0), false)
		if path.is_empty():
			return "the squad cannot walk to the goal"
		if SimNav.path_length(path) > usable * 2.2:
			return "the way to the goal is too long (%d px)" % int(SimNav.path_length(path))
	if level.win_rule == "COLLECT" and g.nut_total != level.collect_count:
		return "only %d of %d nuts placed" % [g.nut_total, level.collect_count]
	if level.win_rule == "ONE_SHOT":
		for f in _team(sim, 1):
			if SimGoals._cover(sim, Vector2(squad[0].x, squad[0].y - 16.0), Vector2(f.x, f.y - 14.0)) < 4:
				return "the enemy has no cover"
			if not SimGoals._arc_hits(sim, Vector2(squad[0].x, squad[0].y - 16.0), Vector2(f.x, f.y - 14.0)):
				return "the enemy cannot be hit (no arc)"
	if sim.barrels.size() < level.barrels:
		return "only %d of %d barrels placed" % [sim.barrels.size(), level.barrels]
	if sim.mines.size() < level.mines:
		return "only %d of %d mines placed" % [sim.mines.size(), level.mines]
	if sim.hiding_spots.size() < level.hiding_spots:
		return "only %d of %d hiding spots" % [sim.hiding_spots.size(), level.hiding_spots]
	return ""


func _scan(id: String, base: int) -> void:
	var level: LevelDef = _level(id)
	var found: Array[int] = []
	var why: Dictionary = {}
	var sd: int = base
	while found.size() < 6 and sd < base + 300:
		var r: String = _seed_report(level, sd)
		if r == "":
			found.append(sd)
		else:
			why[r.split(" ")[0] + " " + r.split(" ")[1]] = int(why.get(r.split(" ")[0] + " " + r.split(" ")[1], 0)) + 1
		sd += 1
	print("SCAN  %s (current seed %d): %s   rejected: %s" % [id, level.seed, str(found), str(why)])


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

func _data() -> void:
	var prev_arena: float = 0.0
	for id in IDS:
		var lv: LevelDef = _level(id)
		var r: Array = ROWS[id]
		var enemies: int = lv.enemy_roster().size()
		_check(is_equal_approx(lv.arena_width, r[0]) and lv.win_rule == r[1] and enemies == r[2], "%s: arena %d, rule %s, %d enemies at the start" % [id, int(lv.arena_width), r[1], enemies])
		_check(lv.arena_width >= prev_arena and lv.arena_width >= 900.0 and lv.arena_width <= 1500.0, "%s: the arena (%d) grows slowly between 900 and 1500" % [id, int(lv.arena_width)])
		prev_arena = lv.arena_width
		_check(enemies <= 3 and lv.wave_size <= 2, "%s: at most 3 enemies (%d) and waves of 2 at most" % [id, enemies])
		_check(lv.mode == "COMBAT" and lv.playable and lv.seed != 0 and not lv.hazards, "%s: playable COMBAT level with a fixed seed, no random hazards" % id)
		_check(lv.title_key == "LVL_%s_TITLE" % id.to_upper() and lv.goal_key == "LVL_%s_GOAL" % id.to_upper() and lv.tip_key == "LVL_%s_TIP" % id.to_upper(), "%s: text keys LVL_%s_*" % [id, id.to_upper()])
		for key in [lv.title_key, lv.intro_key, lv.goal_key, lv.tip_key]:
			_check(_has_text(key, "en") and _has_text(key, "ca"), "%s: %s has English and Catalan" % [id, key])
		var twist_ok: bool = false
		match r[3]:
			"wind":
				twist_ok = lv.wind_scale >= 1.5
			"barrels":
				twist_ok = lv.barrels >= 4
			"tide":
				twist_ok = lv.tide and lv.tide_round <= 3
			"mines":
				twist_ok = lv.mines >= 3
			"supply":
				twist_ok = lv.supply_drops
			"none":
				twist_ok = lv.wind_scale == 1.0 and not lv.tide and lv.barrels == 0 and lv.mines == 0 and not lv.supply_drops
		_check(twist_ok, "%s: twist %s" % [id, r[3]])
		_check(lv.star_survivors.size() == 2 and lv.star_survivors[0] <= lv.player_names.size() + (1 if lv.win_rule == "RESCUE" else 0) and lv.star_survivors[1] <= lv.player_names.size() + (1 if lv.win_rule == "RESCUE" else 0), "%s: the star thresholds %s fit the squad" % [id, str(lv.star_survivors)])
	var unlocks: Dictionary = {"larva_1": [], "larva_2": ["FUET"], "larva_3": ["CARQUINYOLI"], "larva_4": ["BAT"], "larva_5": [], "cuca_1": ["BAZOOKA"], "cuca_2": ["GRENADE"], "cuca_3": ["SHOTGUN"], "cuca_4": ["GANXO"], "cuca_5": ["CLUSTER"], "cuca_6": ["DYNAMITE"]}
	for id in IDS:
		_check(Array(_level(id).unlocks) == unlocks[id], "%s: unlocks unchanged %s" % [id, str(unlocks[id])])
	_check(_level("larva_3").survive_rounds == 3 and _level("larva_3").anthill_hp > 0 and _level("cuca_6").survive_rounds == 3 and _level("cuca_6").anthill_hp == 0, "larva_3 has a destructible anthill and 3 rounds; cuca_6 3 rounds")
	var lv4: LevelDef = _level("cuca_4")
	_check(lv4.enemy_still and lv4.player_arsenal == {"BAZOOKA": 3, "GRENADE": 1} and not lv4.use_unlocked, "cuca_4: still enemy, 3 bazooka + 1 grenade, nothing unlocked")


func _has_text(key: String, locale: String) -> bool:
	var old: String = TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	var ok: bool = TranslationServer.translate(key) != key
	TranslationServer.set_locale(old)
	return ok


func _setup_all() -> void:
	for id in IDS:
		var lv: LevelDef = _level(id)
		var reason: String = _seed_report(lv, lv.seed)
		_check(reason == "", "%s: its seed %d is playable %s" % [id, lv.seed, reason])
		var sim := _make(lv)
		_check(sim.goals != null and sim.goals.kind == lv.win_rule and sim.turn_phase != CombatSim.Phase.GAME_OVER, "%s: sets up with goals of kind %s" % [id, lv.win_rule])
	var classic := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 12
	classic.setup(cfg)
	_check(SimGoals.of(classic) == null and classic.level == null, "classic matches have no goals")


# ---------------------------------------------------------------------------
# REACH
# ---------------------------------------------------------------------------

func _reach() -> void:
	var lv: LevelDef = _level("larva_2")
	var sim := _make(lv)
	_sturdy(sim)
	var g: SimGoals = sim.goals
	_check(g.pos != Vector2.INF and g.limit == 8 and sim.rounds_left == 8 and lv.has_ability("SILK_WEB"), "REACH: a goal ground, 8 rounds, the silk web allowed (rounds_left %d)" % sim.rounds_left)
	_run(sim, 1.0)
	_check(sim.turn_phase != CombatSim.Phase.GAME_OVER, "REACH: nothing is won at the start")
	var squad: Array[SimFighter] = _team(sim, 0)
	_put(squad[1], g.pos + Vector2(g.radius + 40.0, 0.0))
	_run(sim, 0.5)
	_check(sim.turn_phase != CombatSim.Phase.GAME_OVER, "REACH: next to the goal, outside its radius, does not win")
	var overs: Array = _overs(sim)
	_put(squad[2], g.pos + Vector2(g.radius * 0.5, 0.0))
	_run(sim, 0.5)
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.winner == 0 and overs.size() == 1 and st.get("reason", "") == "REACHED" and st.get("won", false), "REACH: a caterpillar on the goal wins (reason %s)" % st.get("reason", "?"))
	_check(st.get("stars", 0) == 3 and st.get("survivors", 0) == 3, "REACH: all three alive: 3 stars")
	# timed out
	var sim2 := _make(lv)
	_sturdy(sim2)
	var overs2: Array = _overs(sim2)
	_pass_until_over(sim2)
	var st2: Dictionary = overs2[0][1] if overs2.size() > 0 else {}
	_check(sim2.winner == 1 and overs2.size() == 1 and st2.get("reason", "") == "TIME_UP" and not st2.get("won", true) and st2.get("stars", -1) == 0, "REACH: 8 rounds without reaching the goal: lost (TIME_UP), round %d" % sim2.round_number)
	# every enemy down is also a win (the harassing ants are gone)
	var sim3 := _make(lv)
	_sturdy(sim3)
	for a in _team(sim3, 1):
		a.alive = false
	sim3.end_turn()
	_run(sim3, 6.0)
	_check(sim3.turn_phase == CombatSim.Phase.GAME_OVER and sim3.winner == 0, "REACH: with every ant down the squad wins as in an ELIMINATE level")
	# the whole squad dies
	var sim4 := _make(lv)
	for f in _team(sim4, 0):
		f.alive = false
	_run(sim4, 3.0)
	_check(sim4.turn_phase == CombatSim.Phase.GAME_OVER and sim4.winner == 1, "REACH: a dead squad loses")


# ---------------------------------------------------------------------------
# RESCUE
# ---------------------------------------------------------------------------

func _rescue() -> void:
	var lv: LevelDef = _level("larva_4")
	var sim := _make(lv)
	_sturdy(sim)
	var g: SimGoals = sim.goals
	_check(g.pos != Vector2.INF and not g.freed and _team(sim, 0).size() == 3 and g.limit == 8, "RESCUE: the sister is trapped at a spot, 3 caterpillars, 8 rounds")
	var overs: Array = _overs(sim)
	var squad: Array[SimFighter] = _team(sim, 0)
	_put(squad[0], g.pos + Vector2(g.radius + 40.0, 0.0))
	_run(sim, 0.4)
	_check(sim.turn_phase != CombatSim.Phase.GAME_OVER, "RESCUE: close but outside the radius frees nobody")
	_put(squad[0], g.pos + Vector2(10.0, 0.0))
	_run(sim, 0.4)
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	var sister: SimFighter = null
	for f in _team(sim, 0):
		if f.name == SimGoals.SISTER_NAME:
			sister = f
	_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.winner == 0 and g.freed and sister != null and _team(sim, 0).size() == 4, "RESCUE: reaching her frees her: she joins the squad and the level is won")
	_check(st.get("reason", "") == "RESCUED" and st.get("survivors", 0) == 4 and st.get("stars", 0) == 3, "RESCUE: reason RESCUED, 4 survivors with her, 3 stars (%s)" % str(st.get("stars")))
	_check(sister != null and sister.kind == lv.player_unit.id and sister.hp == lv.player_unit.max_hp and sister.team == 0, "RESCUE: the sister is a full-health %s of the squad" % lv.player_unit.id)
	var sim2 := _make(lv)
	_sturdy(sim2)
	var overs2: Array = _overs(sim2)
	_pass_until_over(sim2)
	var st2: Dictionary = overs2[0][1] if overs2.size() > 0 else {}
	_check(sim2.winner == 1 and st2.get("reason", "") == "TIME_UP", "RESCUE: 8 rounds without freeing her: lost (TIME_UP)")


# ---------------------------------------------------------------------------
# Anthill with HP
# ---------------------------------------------------------------------------

func _anthill() -> void:
	var lv: LevelDef = _level("larva_3")
	var sim := _make(lv)
	_sturdy(sim)
	var g: SimGoals = sim.goals
	var top: Vector2 = sim.anthill_pos
	_check(g.anthill_hp == 90 and g.anthill_max == 90 and top != Vector2.INF and sim.waves_left == 3 and sim.enemies_alive == 0, "anthill: 90 HP, 3 waves still to come, no ants yet")
	_check(sim.barrels.size() == 4, "anthill: 4 explosive barrels round it (%d)" % sim.barrels.size())
	var near: bool = true
	for b in sim.barrels:
		near = near and absf(b.x - top.x) < 260.0 and not sim.terrain.is_solid(b.x, b.y)
	_check(near, "anthill: the barrels stand within 260 px of it, on free ground")
	SimCombat.trigger_explosion(sim, top.x + 300.0, top.y, 34.0, 28.0, 300.0, 0, true)
	_check(g.anthill_hp == 90, "anthill: an explosion far away does not hurt it")
	SimCombat.trigger_explosion(sim, top.x, top.y + 6.0, 34.0, 28.0, 300.0, 0, true)
	_check(g.anthill_hp < 90 and g.anthill_hp >= 60, "anthill: a direct urticating hit takes about 28 HP (%d left)" % g.anthill_hp)
	# a barrel next to it
	var sim2 := _make(lv)
	_sturdy(sim2)
	var hp0: int = sim2.goals.anthill_hp
	var b0: SimBarrel = sim2.barrels[0]
	var count0: int = sim2.barrels.size()
	SimCombat.trigger_explosion(sim2, b0.x, b0.y, 58.0, 55.0, 500.0, 0, false)
	_run(sim2, 2.5)
	_check(sim2.goals.anthill_hp < hp0 and sim2.barrels.size() < count0, "anthill: a barrel blast beside it hurts it (%d -> %d) and sets neighbours off" % [hp0, sim2.goals.anthill_hp])
	# destroy it: early win
	var sim3 := _make(lv)
	_sturdy(sim3)
	var overs: Array = _overs(sim3)
	var rounds_before: int = sim3.round_number
	var guard: int = 0
	while sim3.turn_phase != CombatSim.Phase.GAME_OVER and guard < 20:
		SimCombat.trigger_explosion(sim3, sim3.anthill_pos.x, sim3.anthill_pos.y + 6.0, 34.0, 28.0, 300.0, 0, true)
		guard += 1
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(sim3.turn_phase == CombatSim.Phase.GAME_OVER and sim3.winner == 0 and sim3.goals.anthill_hp == 0 and overs.size() == 1 and sim3.round_number <= rounds_before + 1, "anthill: 0 HP wins the level at once (round %d)" % sim3.round_number)
	_check(st.get("reason", "") == "ANTHILL_DESTROYED" and st.get("anthill_hp", -1) == 0 and st.get("stars", 0) == 3, "anthill: reason ANTHILL_DESTROYED, stats carry the HP")
	_check(not sim3.terrain.is_solid(sim3.anthill_pos.x, sim3.anthill_pos.y + 10.0), "anthill: the mound is blown away")
	# surviving the 3 rounds still wins
	var sim4 := _make(lv)
	_sturdy(sim4)
	var overs4: Array = _overs(sim4)
	_pass_until_over(sim4)
	var st4: Dictionary = overs4[0][1] if overs4.size() > 0 else {}
	_check(sim4.winner == 0 and st4.get("reason", "") == "SURVIVED" and sim4.round_number == 4 and sim4.waves_left == 0, "anthill: surviving 3 rounds also wins (SURVIVED, round %d)" % sim4.round_number)
	# the anthill of cuca_6 cannot be destroyed
	var six := _make(_level("cuca_6"))
	SimCombat.trigger_explosion(six, six.anthill_pos.x, six.anthill_pos.y + 6.0, 34.0, 28.0, 300.0, 0, true)
	_check(six.goals.anthill_max == 0 and six.turn_phase != CombatSim.Phase.GAME_OVER, "cuca_6: its anthill has no HP and is not destroyed")


# ---------------------------------------------------------------------------
# COLLECT
# ---------------------------------------------------------------------------

func _collect() -> void:
	var lv: LevelDef = _level("cuca_2")
	var sim := _make(lv)
	_sturdy(sim)
	var g: SimGoals = sim.goals
	_check(g.nut_total == 5 and g.nut_need == 4 and g.nut_got == 0 and g.limit == 8 and sim.pine_nuts.size() == 5, "COLLECT: 5 nuts on the map, 4 needed, 8 rounds")
	var on_ground: bool = true
	for pn in g.nuts:
		on_ground = on_ground and sim.terrain.is_solid(pn.x, pn.y + pn.r + 2.0) and pn.y < sim.terrain.water_y - 100.0
	_check(on_ground, "COLLECT: every nut lies on the ground well above the water")
	_run(sim, 6.0)
	_check(sim.pine_nuts.size() == 5, "COLLECT: the nuts do not decay")
	# an enemy walking over a nut takes nothing
	var foe: SimFighter = _team(sim, 1)[0]
	var nut0: SimNut = g.nuts[0]
	foe.x = nut0.x
	foe.y = nut0.y - 4.0
	_run(sim, 0.3)
	_check(g.nut_got == 0 and sim.pine_nuts.has(nut0), "COLLECT: an enemy does not pick nuts up")
	var overs: Array = _overs(sim)
	var squad: Array[SimFighter] = _team(sim, 0)
	var picks: Array = g.nuts.duplicate()
	for k in 3:
		squad[0].x = picks[k].x
		squad[0].y = picks[k].y - 4.0
		squad[0].vx = 0.0
		squad[0].vy = 0.0
		_run(sim, 0.2)
	_check(g.nut_got == 3 and sim.turn_phase != CombatSim.Phase.GAME_OVER and sim.pine_nuts.size() == 2, "COLLECT: 3 nuts gathered, nothing won yet (%d)" % g.nut_got)
	squad[1].x = picks[3].x
	squad[1].y = picks[3].y - 4.0
	_run(sim, 0.2)
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(sim.turn_phase == CombatSim.Phase.GAME_OVER and sim.winner == 0 and st.get("reason", "") == "COLLECTED" and st.get("nuts", 0) == 4, "COLLECT: the 4th nut wins (COLLECTED)")
	# timeout
	var sim2 := _make(lv)
	_sturdy(sim2)
	sim2.level = lv.duplicate() # the enemies stand still: nothing else can end this run
	sim2.level.enemy_still = true
	var overs2: Array = _overs(sim2)
	_pass_until_over(sim2)
	_check(sim2.winner == 1 and overs2.size() == 1 and overs2[0][1].get("reason", "") == "TIME_UP", "COLLECT: 8 rounds without 4 nuts: lost (TIME_UP) %s" % str(overs2[0][1].get("reason", "?") if overs2.size() > 0 else "no game over"))
	# too many nuts lost to ever reach 4
	var sim3 := _make(lv)
	_sturdy(sim3)
	var overs3: Array = _overs(sim3)
	sim3.pine_nuts.erase(sim3.goals.nuts[0])
	sim3.pine_nuts.erase(sim3.goals.nuts[1])
	_run(sim3, 0.3)
	_check(sim3.winner == 1 and overs3.size() == 1 and overs3[0][1].get("reason", "") == "NUTS_LOST", "COLLECT: with only 3 nuts left for a need of 4 the level is lost (NUTS_LOST)")


# ---------------------------------------------------------------------------
# ONE_SHOT
# ---------------------------------------------------------------------------

func _one_shot() -> void:
	var lv: LevelDef = _level("cuca_4")
	var sim := _make(lv)
	var g: SimGoals = sim.goals
	var foe: SimFighter = _team(sim, 1)[0]
	var squad: Array[SimFighter] = _team(sim, 0)
	_check(_team(sim, 1).size() == 1 and SimGoals.shots_left(sim) == 4 and g.shots == 4 and sim.ammo_f(0, "URTICARIA") <= 0.0, "ONE_SHOT: 1 enemy and 4 shots (3 bazooka + 1 grenade), nothing else")
	_check(SimGoals._cover(sim, Vector2(squad[0].x, squad[0].y - 16.0), Vector2(foe.x, foe.y - 14.0)) >= 4, "ONE_SHOT: rock stands between the squad and the enemy (no straight shot)")
	var x0: float = foe.x
	var turns: int = 0
	var guard: float = 0.0
	_sturdy(sim)
	while turns < 3 and guard < 400.0 and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
			turns += 1
		sim.step(DT)
		sim.advance_real(DT)
		guard += DT
	_check(absf(foe.x - x0) < 1.0 and foe.hp == foe.max_hp and sim.turn_phase != CombatSim.Phase.GAME_OVER, "ONE_SHOT: the enemy never moves nor attacks (3 rounds passed)")
	# out of ammo with the enemy alive: lost, but only after the last shot is over
	var sim2 := _make(lv)
	var overs2: Array = _overs(sim2)
	for id in ["BAZOOKA", "GRENADE"]:
		sim2.team_ammo[0][id] = 0.0
	_run(sim2, 0.7)
	_check(sim2.turn_phase != CombatSim.Phase.GAME_OVER, "ONE_SHOT: not lost the instant the ammo is gone (the verdict comes when the turn ends)")
	_pass_until_over(sim2, 60.0)
	var st2: Dictionary = overs2[0][1] if overs2.size() > 0 else {}
	_check(sim2.turn_phase == CombatSim.Phase.GAME_OVER and sim2.winner == 1 and st2.get("reason", "") == "OUT_OF_AMMO" and st2.get("stars", -1) == 0, "ONE_SHOT: no ammo and the enemy alive: lost (OUT_OF_AMMO)")
	# the verdict waits for the end of the squad's turn: a shell still in the air is settled first
	var sim3 := _make(lv)
	for id in ["BAZOOKA", "GRENADE"]:
		sim3.team_ammo[0][id] = 0.0
	_run(sim3, 3.0)
	_check(sim3.turn_phase != CombatSim.Phase.GAME_OVER, "ONE_SHOT: the turn in progress is never cut short by an empty arsenal")
	# killing the enemy with the last shot wins
	var sim4 := _make(lv)
	var overs4: Array = _overs(sim4)
	for id in ["BAZOOKA", "GRENADE"]:
		sim4.team_ammo[0][id] = 0.0
	var foe4: SimFighter = _team(sim4, 1)[0]
	SimCombat.damage_fighter(sim4, foe4, 999)
	_run(sim4, 4.0)
	var st4: Dictionary = overs4[0][1] if overs4.size() > 0 else {}
	_check(sim4.winner == 0 and st4.get("reason", "") == "ELIMINATED_ENEMY", "ONE_SHOT: the enemy down wins even with no ammo left (ELIMINATED_ENEMY)")
	# a real shot spends ammo
	var sim5 := _make(lv)
	var before: int = SimGoals.shots_left(sim5)
	sim5.select_weapon(sim5.weapon_index("BAZOOKA"))
	SimCombat.fire_weapon(sim5, sim5.weapons[sim5.weapon_index("BAZOOKA")], -0.6, 0.5, sim5.mouse_world)
	_run(sim5, 0.1)
	_check(SimGoals.shots_left(sim5) == before - 1 and sim5.goals.shots == before - 1, "ONE_SHOT: firing the bazooka leaves %d shots" % (before - 1))


# ---------------------------------------------------------------------------
# Barrel chain, mines, hide-and-seek, tide
# ---------------------------------------------------------------------------

func _barrel_chain() -> void:
	var lv: LevelDef = _level("cuca_3")
	var sim := _make(lv)
	_sturdy(sim)
	_check(sim.barrels.size() >= 5 and lv.win_rule == "ELIMINATE" and not lv.hazards, "barrel chain: %d barrels placed by the level, ELIMINATE rule" % sim.barrels.size())
	var foes: Array[SimFighter] = _team(sim, 1)
	var close: int = 0
	for f in foes:
		for b in sim.barrels:
			if absf(b.x - f.x) < 100.0:
				close += 1
				break
	_check(close >= 2, "barrel chain: at least two enemies have a barrel within 100 px (%d of %d)" % [close, foes.size()])
	var gaps_ok: bool = true
	for b in sim.barrels:
		gaps_ok = gaps_ok and not sim.terrain.is_solid(b.x, b.y)
	_check(gaps_ok, "barrel chain: the barrels stand on free ground")
	var first: SimBarrel = sim.barrels[0]
	var count0: int = sim.barrels.size()
	var hp_before: int = 0
	for f in foes:
		hp_before += f.hp
	SimCombat.trigger_explosion(sim, first.x, first.y, 58.0, 55.0, 500.0, 0, false)
	_run(sim, 4.0)
	var hp_after: int = 0
	for f in foes:
		hp_after += maxi(0, f.hp) if f.alive else 0
	_check(sim.barrels.size() <= count0 - 3, "barrel chain: one blast sets off at least 3 barrels in a chain (%d -> %d)" % [count0, sim.barrels.size()])
	_check(hp_after < hp_before, "barrel chain: the enemies are hurt by it (%d -> %d HP)" % [hp_before, hp_after])


func _hide_and_seek() -> void:
	var lv: LevelDef = _level("larva_5")
	var sim := _make(lv)
	_check(sim.hiding_spots.size() >= 4 and sim.mines.size() >= 3 and lv.win_rule == "SURVIVE_ROUNDS" and lv.survive_rounds == 4 and sim.rounds_left >= 0, "hide-and-seek: %d hiding spots, %d mines, survive 4 rounds" % [sim.hiding_spots.size(), sim.mines.size()])
	var squad: Array[SimFighter] = _team(sim, 0)
	_check(not squad[0].unit.can_hide, "hide-and-seek: the larva unit itself cannot hide (the level lets the squad hide)")
	var spot: Vector2 = sim.hiding_spots[0]
	_sturdy(sim)
	var f: SimFighter = sim.active_fighter
	f.x = spot.x
	f.y = spot.y
	f.vx = 0.0
	f.vy = 0.0
	f.grounded = true
	sim.end_turn()
	_run(sim, 1.0)
	_check(f.hidden, "hide-and-seek: ending the turn on a tuft hides the caterpillar")
	var overs: Array = _overs(sim)
	_pass_until_over(sim)
	_check(sim.winner == 0 and overs.size() == 1 and overs[0][1].get("reason", "") == "SURVIVED" and sim.round_number == 5, "hide-and-seek: surviving the 4 rounds wins")


func _tide() -> void:
	var rescue: LevelDef = _level("larva_4")
	var sim := _make(rescue)
	_sturdy(sim)
	var w0: float = sim.terrain.water_y
	var guard: float = 0.0
	while sim.round_number < 3 and guard < 300.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		guard += DT
	_check(is_equal_approx(sim.terrain.water_y, w0 - 14.0) and sim.round_number == 3, "tide: the water of larva_4 rises 14 px when round 3 starts (%.0f -> %.0f)" % [w0, sim.terrain.water_y])
	var classic := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 5
	classic.setup(cfg)
	_check(classic.level == null and classic.terrain.water_y > 0.0, "tide: classic matches keep round 10 (no level)")
	var six := _make(_level("cuca_6"))
	_sturdy(six)
	var w6: float = six.terrain.water_y
	guard = 0.0
	while six.round_number < 3 and guard < 300.0:
		if six.turn_phase == CombatSim.Phase.TURN_PLAY and six.active_team == 0:
			six.end_turn()
		six.step(DT)
		six.advance_real(DT)
		guard += DT
	_check(six.terrain.water_y < w6, "tide: the water of cuca_6 rises from round 2 (%.0f -> %.0f)" % [w6, six.terrain.water_y])


func _ammo_free_levels() -> void:
	# the levels that keep the old rules still play to the end with the usual stats
	var sim := _make(_level("larva_1"))
	var overs: Array = _overs(sim)
	for a in _team(sim, 1):
		a.alive = false
	sim.end_turn()
	_run(sim, 6.0)
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(sim.winner == 0 and st.get("reason", "") == "ELIMINATED_ENEMY", "larva_1: ELIMINATE still wins by clearing the ants")
	var sim2 := _make(_level("cuca_5"))
	_check(sim2.mines.size() >= 3 and sim2.goals.kind == "ELIMINATE", "cuca_5: 3 mines on the way, plain ELIMINATE")


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hud() -> void:
	StoryProgress.save_path = "user://story_rules2_test.cfg"
	StoryProgress.reset_progress()
	for id in ["larva_2", "larva_3", "larva_4", "cuca_2", "cuca_4", "cuca_6"]:
		GameState.story_level = _level(id)
		var screen: CombatScreen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
		add_child(screen)
		await _frames(20)
		var sim: CombatSim = screen.sim as CombatSim
		var top: TopHud = null
		for h in screen.huds:
			if is_instance_of(h, TopHud):
				top = h
		var text: String = top.objective_label.text if top != null else ""
		var lv: LevelDef = sim.level
		_check(top != null and top.objective_panel.visible and not text.begins_with("HUD_OBJECTIVE_ENEMIES"), "%s: objective line %s" % [id, text])
		match lv.win_rule:
			"REACH", "RESCUE":
				_check(text.contains(str(sim.rounds_left)) and screen.view.ctx.goal_pos != Vector2.ZERO, "%s: the objective shows the %d rounds left and the view reads the goal" % [id, sim.rounds_left])
			"COLLECT":
				_check(text.contains("0") and text.contains(str(sim.goals.nut_need)) and screen.view.ctx.goal_nuts.size() == 5, "%s: the objective shows nuts 0/%d, the view rings %d nuts" % [id, sim.goals.nut_need, screen.view.ctx.goal_nuts.size()])
			"ONE_SHOT":
				_check(text.contains("4"), "%s: the objective shows 4 shots" % id)
			"WAVES":
				if lv.anthill_hp > 0:
					_check(top.nest_bar.visible and top.nest_bar.fraction == 1.0 and text.contains("100") and screen.view.ctx.anthill_frac == 1.0, "%s: the anthill bar is full (100 %%) and the view reads its HP" % id)
					SimGoals.damage_anthill(sim, 30)
					await _frames(3)
					_check(top.nest_bar.hp_text == "60 / 90" and top.objective_label.text.contains("67"), "%s: after 30 damage the bar shows 60 / 90 and 67 %%" % id)
				else:
					_check(not top.nest_bar.visible and screen.view.ctx.anthill_frac < 0.0, "%s: an indestructible anthill shows no bar" % id)
		screen.queue_free()
		await _frames(2)
	GameState.story_level = null
	StoryProgress.reset_progress()


# ---------------------------------------------------------------------------
# Integration fixes (review of the second pass)
# ---------------------------------------------------------------------------

func _integration_fixes() -> void:
	# the tide: once per round (not per enemy sub-turn), and the walking map drops the flooded ground
	var lv: LevelDef = _level("larva_4")
	var sim := _make(lv)
	var nav: SimNav = sim.walk_nav()
	var low: int = 0
	for t in nav.tiers:
		for y in t:
			low = maxi(low, y)
	var w0: float = sim.terrain.water_y
	sim.terrain.water_y = float(low) + 10.0
	nav.sync()
	var low2: int = 0
	for t in nav.tiers:
		for y in t:
			low2 = maxi(low2, y)
	_check(low2 < low, "tide: the walking map drops the surfaces the water covers (%d -> %d)" % [low, low2])
	sim.terrain.water_y = w0
	var sim2 := _make(lv)
	sim2.round_number = lv.tide_round  # the next rounds raise the water
	var before: float = sim2.terrain.water_y
	var seen: Array[int] = [0]
	sim2.turn_started.connect(func(team: int, _f: SimFighter) -> void: seen[0] += 1 if team == 0 else 0)
	for f in _team(sim2, 0):
		f.hp = 9999
		f.max_hp = 9999
	for i in 60 * 60:
		if sim2.turn_phase == CombatSim.Phase.TURN_PLAY and sim2.active_team == 0:
			sim2.end_turn()
		sim2.step(DT)
		if seen[0] >= 3 or sim2.turn_phase == CombatSim.Phase.GAME_OVER:
			break
	var rounds_seen: int = seen[0]
	var rise: float = before - sim2.terrain.water_y
	_check(absf(rise - SimTurns.TIDE_STEP * float(rounds_seen - 1)) < 0.5 or absf(rise - SimTurns.TIDE_STEP * float(rounds_seen)) < 0.5, "tide: %d px after %d squad turns (14 px per round)" % [int(rise), rounds_seen])
	# mines keep their distance from every fighter (the trigger is 38 px)
	for id in ["larva_5", "cuca_5"]:
		var sm := _make(_level(id))
		var near: float = INF
		for m in sm.mines:
			for f in sm.fighters:
				near = minf(near, Vector2(f.x - m.x, f.y - m.y).length())
		_check(near >= 50.0, "%s: no mine within 50 px of a fighter at the start (%d)" % [id, int(near)])
	# the nuts are always placed
	for id in ["cuca_2"]:
		var sn := _make(_level(id))
		_check(sn.goals.nut_total == _level(id).collect_count and sn.goals.nut_need > 0, "%s: all nuts placed (%d)" % [id, sn.goals.nut_total])
	# a goal blast that also kills the last caterpillar is not a victory
	var sw := _make(_level("larva_3"))
	var overs: Array = _overs(sw)
	for f in _team(sw, 0):
		f.alive = false
	SimGoals.damage_anthill(sw, 9999)
	_check(sw.turn_phase == CombatSim.Phase.GAME_OVER and sw.winner == 1 and overs.size() == 1, "anthill: no victory with the squad dead (winner %d)" % sw.winner)
	# a caterpillar flying through the goal zone does not win it
	var sr := _make(_level("larva_2"))
	var g: SimGoals = sr.goals
	var cat: SimFighter = _team(sr, 0)[0]
	cat.x = g.pos.x
	cat.y = g.pos.y - cat.r
	cat.grounded = false
	SimGoals.update(sr, DT)
	_check(sr.turn_phase != CombatSim.Phase.GAME_OVER, "REACH: not won while flying through the goal zone")
	cat.grounded = true
	SimGoals.update(sr, DT)
	_check(sr.turn_phase == CombatSim.Phase.GAME_OVER and sr.winner == 0, "REACH: won when standing on the goal ground")
	# a scheduled blast goes off with the simulation time (no advance_real needed)
	var sd := _make(_level("larva_3"))
	sd.schedule(0.1, {"kind": "barrel_blast", "x": -999.0, "y": -999.0})
	for i in 12:
		sd.step(DT)
	_check(sd._delayed.is_empty(), "delayed events run from step()")
