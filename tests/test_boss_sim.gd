## Boss framework in the sim (docs/boss_contracts.md): the Mosca Taquina of larva_boss (intents, dodging, PARASITE and silk,
## armour and the RESTING window, phases and summons, the water rule, the defeat), a dummy boss made only of data, and
## CPU-vs-CPU runs of larva_boss (win rate of the caterpillar AI).
##   godot --headless --path . res://tests/TestBossSim.tscn
extends Node

const DT: float = 1.0 / 60.0
const RUN_SEEDS: int = 5
const RUN_LIMIT_S: float = 2400.0
## The weapons the larvae have unlocked before the boss (larva_2..4).
const UNLOCKED: Dictionary = {"FUET": -1, "CARQUINYOLI": -1, "BAT": -1}

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _level() -> LevelDef:
	return load("res://data/levels/larva_boss.tres")


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


func _kind(sim: CombatSim, kind: String) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in sim.fighters:
		if f.kind == kind:
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


## Steps (the larvae pass their turns) until the boss's own sub-turn has run and ended; false if it never came.
func _boss_turn(sim: CombatSim, max_s: float = 120.0) -> bool:
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


## Steps until team 0 plays again (TURN_PLAY).
func _until_player(sim: CombatSim, max_s: float = 60.0) -> void:
	var t: float = 0.0
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER and not (sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0):
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## Only this attack id can be announced (the others are put on a long cooldown).
func _force(sim: CombatSim, attack_id: String) -> void:
	for a in sim.boss_def.attacks:
		if a["id"] != attack_id:
			sim.boss_memory["cooldowns"][a["id"]] = 99


func _texts(sim: CombatSim) -> Array[String]:
	var texts: Array[String] = []
	sim.float_text.connect(func(_p: Vector2, tx: String, _c: Color, _l: float) -> void: texts.append(tx))
	return texts


## A ground point the fighter can walk to, at least `min_dx` px away sideways.
func _walk_spot(sim: CombatSim, f: SimFighter, min_dx: float) -> Vector2:
	for c in sim.nav.reachable(Vector2(f.x, f.y), false):
		if absf(c.x - f.x) >= min_dx and absf(c.x - f.x) <= min_dx + 120.0:
			return Vector2(c.x, c.y - f.r + 1.0)
	return Vector2.INF


## A walkable spot of the fighter more than 230 px from `mark` (the farthest one), or Vector2.INF.
func _far_spot(sim: CombatSim, f: SimFighter, mark: Vector2) -> Vector2:
	var best := Vector2.INF
	for c in sim.nav.reachable(Vector2(f.x, f.y), true):
		var p := Vector2(c.x, c.y - f.r + 1.0)
		if p.distance_to(mark) > 230.0 and (best == Vector2.INF or p.distance_to(mark) > best.distance_to(mark)):
			best = p
	return best


func _put(f: SimFighter, p: Vector2) -> void:
	f.x = p.x
	f.y = p.y
	f.grounded = true
	f.vx = 0.0
	f.vy = 0.0


func _ready() -> void:
	_data()
	_setup()
	_lay_eggs()
	_dodge()
	_parasite_and_silk()
	_armour()
	_buzz()
	_phase_and_summons()
	_water()
	_defeat()
	_dummy_boss()
	_sfx_names()
	_classic_untouched()
	if OS.get_environment("CUCS_BOSS_FAST") == "":
		_cpu_runs()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _data() -> void:
	var fly: BossDef = load("res://data/bosses/tachinid_fly.tres")
	_check(fly.id == "TACHINID_FLY" and fly.max_hp == 180 and fly.flies and fly.phases == [0.5] and fly.vulnerable_states == ["RESTING"] and is_equal_approx(fly.armored_mult, 0.25) and fly.water_damage == 20, "tachinid fly: 180 HP, flies, phase change at 50 %, vulnerable only RESTING, x0.25 armour, 20 HP water rule")
	var ids: Array[String] = []
	for a in fly.attacks:
		ids.append("%s/%d" % [a["id"], a["phase"]])
		_check(BossAttacks.handler(str(a["kind"])) != null, "attack %s has a handler for kind %s" % [a["id"], a["kind"]])
	_check(ids == ["LAY_EGGS/1", "BUZZ/-1", "SUMMON/2", "LAY_EGGS/2"], "fly attacks: LAY_EGGS (1 target), BUZZ, SUMMON once, LAY_EGGS (2 targets) (%s)" % str(ids))
	_check(fly.attacks_of_phase(1).size() == 2 and fly.attacks_of_phase(2).size() == 3, "attacks_of_phase: 2 in phase 1, 3 in phase 2")
	var p: Dictionary = fly.statuses["PARASITE"]
	_check(int(p["damage"]) == 6 and bool(p["silk_cleans"]) and int(fly.attacks[0]["turns"]) == 3, "PARASITE: 6 damage per turn for 3 turns, silk cleans it")
	var lv: LevelDef = _level()
	_check(_open_arena(_make(lv)), "larva_boss: its seed gives an open, gentle arena around the squad")
	_check(lv.win_rule == "BOSS" and lv.boss == fly and lv.map_idx == 1 and lv.seed != 0 and lv.player_names.size() == 3 and lv.player_unit.id == "LARVA_L2" and lv.has_ability("SILK_WEB") and lv.player_arsenal.has("URTICARIA") and lv.use_unlocked and lv.star_survivors == [2, 3], "larva_boss: map 1, fixed seed, 3 x L2, URTICARIA + unlocked + silk, rule BOSS, stars by survivors")
	var all: Array[LevelDef] = StoryProgress.levels()
	var order: Array[String] = []
	for l in all:
		order.append(l.id)
	_check(order.find("larva_boss") == order.find("larva_5") + 1, "level_list: larva_boss right after larva_5")


func _setup() -> void:
	var sim := _make(_level())
	var b: SimFighter = sim.boss
	_check(b != null and sim.boss_def == _level().boss and b.team == 1 and b.kind == "TACHINID_FLY" and b.unit.ai == "BOSS" and b.hp == 180 and b.max_hp == 180, "setup: the boss is a team-1 fighter of kind TACHINID_FLY with 180 HP")
	var ground: float = sim.terrain.find_surface_y(b.x, b.y)
	_check(b.flying and ground - b.y >= 120.0 and not sim.terrain.is_solid(b.x, b.y), "the fly hovers high, out of reach (%.0f px over the ground)" % (ground - b.y))
	_check(sim.boss_phase == 1 and sim.boss_state == "IDLE" and sim.boss_intent.is_empty() and _team(sim, 1).size() == 1 and sim.active_team == 0, "phase 1, IDLE, no intent yet, the larvae open")
	var order: Array = []
	sim.turn_started.connect(func(_t: int, f: SimFighter) -> void: order.append([f, sim.sub_turn_time]))
	_boss_turn(sim)
	_check(order.size() >= 1 and order[0][0] == b and is_equal_approx(float(order[0][1]), 14.0), "the boss plays its own 14 s sub-turn in the enemy turn")


func _lay_eggs() -> void:
	var sim := _make(_level())
	_sturdy(sim)
	_force(sim, "LAY_EGGS")
	var b: SimFighter = sim.boss
	var intents: Array[int] = [0]
	sim.boss_intent_changed.connect(func() -> void: intents[0] += 1)
	var attacks: Array = []
	sim.boss_attack.connect(func(id: String, p: Vector2) -> void: attacks.append([id, p]))
	_check(_boss_turn(sim), "the boss gets its turn")
	var it: Dictionary = sim.boss_intent
	var target: SimFighter = BossAttack.fighter_by_id(sim, int(it.get("target_id", -1)))
	_check(it.get("attack_id", "") == "LAY_EGGS" and it.get("kind", "") == "MELEE_TARGET" and target != null and target.team == 0 and int(it["turns_left"]) == 1, "turn 1: intent LAY_EGGS on a larva")
	_check(target != null and str(it["label"]).contains(target.name) and it["label_key"] == "BOSS_INTENT_LAY_EGGS" and is_equal_approx(float(it["radius"]), 90.0) and (it["pos"] as Vector2).distance_to(Vector2(target.x, target.y)) < 1.0, "the intent names the target, marks its spot, dodge radius 90")
	_check(sim.boss_state == "INTENT" and intents[0] >= 1 and attacks.is_empty() and target.statuses.is_empty(), "announced only: nothing hit yet, state INTENT")
	_until_player(sim)
	_check(sim.boss_intent.get("attack_id", "") == "LAY_EGGS" and b.flying and b.y < target.y - 90.0, "the player gets a turn with the intent shown, the fly still out of reach")
	var hp0: int = target.hp
	_check(_boss_turn(sim), "turn 2 comes")
	_check(target.hp <= hp0 - 8 and target.hp >= hp0 - 20 and int(target.statuses.get("PARASITE", 0)) == 3, "turn 2: the dive lands: 8 contact damage and PARASITE x3 (%d -> %d, %s)" % [hp0, target.hp, str(target.statuses)])
	_check(attacks.size() >= 1 and attacks[0][0] == "LAY_EGGS", "boss_attack(LAY_EGGS) at the moment of impact")
	_check(sim.boss_state == "RESTING" and not b.flying and b.grounded and not sim.boss_intent.is_empty(), "then it lands to rest (RESTING) and already shows its next intent")
	_until_player(sim)
	_check(SimBoss.is_vulnerable(sim) and sim.boss_state == "RESTING", "the larvae's turn is the RESTING window")
	var bhp: int = b.hp
	SimCombat.damage_fighter(sim, b, 40)
	_check(b.hp == bhp - 40, "RESTING: full damage (%d -> %d)" % [bhp, b.hp])
	sim.end_turn()
	var took_off: bool = false
	var t: float = 0.0
	while t < 60.0 and not took_off:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		took_off = sim.active_fighter == b and b.flying and sim.boss_state != "RESTING"
	_check(took_off and not SimBoss.is_vulnerable(sim), "in its next turn it takes off and is armoured again")


func _dodge() -> void:
	for how in ["move", "hide"]:
		var sim := _make(_level())
		_sturdy(sim)
		_force(sim, "LAY_EGGS")
		var texts: Array[String] = _texts(sim)
		_boss_turn(sim)
		var target: SimFighter = BossAttack.fighter_by_id(sim, int(sim.boss_intent.get("target_id", -1)))
		_until_player(sim)
		if how == "move":
			var p: Vector2 = _walk_spot(sim, target, 140.0)
			_check(p != Vector2.INF, "scenario: a walkable spot 140 px away")
			_put(target, p)
		else:
			sim.hiding_spots.append(Vector2(target.x, target.y))
			target.hidden = true
		var hp0: int = target.hp
		_boss_turn(sim)
		_check(target.hp == hp0 and target.statuses.is_empty() and texts.has(sim.tx("FT_DODGED")), "dodge by %s: no damage, no eggs, \"dodged\" text" % ("moving > 90 px" if how == "move" else "hiding"))
		_check(sim.boss_state == "RESTING", "it still lands where it dived (%s)" % how)


func _parasite_and_silk() -> void:
	var sim := _make(_level())
	_sturdy(sim)
	for f in _team(sim, 0):
		f.statuses["PARASITE"] = 3
	var hps: Dictionary = {}
	for f in _team(sim, 0):
		hps[f.id] = f.hp
	_boss_turn(sim)
	_until_player(sim)
	var af: SimFighter = sim.active_fighter
	_check(af.hp == int(hps[af.id]) - 6 and int(af.statuses["PARASITE"]) == 2, "PARASITE: 6 damage at the start of the larva's turn, 2 turns left (%d -> %d)" % [hps[af.id], af.hp])
	var others_ok: bool = true
	for f in _team(sim, 0):
		others_ok = others_ok and (f == af or (f.hp == int(hps[f.id]) and int(f.statuses["PARASITE"]) == 3))
	_check(others_ok, "only the larva whose turn starts is eaten")
	var texts: Array[String] = _texts(sim)
	sim.spin_silk_web()
	_check(af.statuses.is_empty() and sim.silk_webs.size() == 1 and sim.turn_phase == CombatSim.Phase.RETREAT and texts.has(sim.tx("FT_CLEANED", [af.name])), "spinning silk cleans the eggs, uses the action (RETREAT) and shows FT_CLEANED")
	# three ticks and it is gone
	var g := _make(_level())
	_sturdy(g)
	var v: SimFighter = _team(g, 0)[0]
	v.statuses["PARASITE"] = 3
	for k in 3:
		SimStatus.tick_turn_start(g, v)
	_check(v.statuses.is_empty() and v.hp == 9999 - 18, "PARASITE lasts 3 turns: 18 damage in all")
	# the caterpillar AI cleans itself
	var c := _make(_level())
	c.game_mode = "CPU_CPU"
	_sturdy(c)
	for f in _team(c, 0):
		f.statuses["PARASITE"] = 3
	_boss_turn(c)
	_until_player(c)
	_run(c, 0.3)
	_check(c.active_fighter.statuses.is_empty() and c.silk_webs.size() >= 1, "the CPU caterpillar spins silk to clean itself")


func _armour() -> void:
	var sim := _make(_level())
	_sturdy(sim)
	var b: SimFighter = sim.boss
	var texts: Array[String] = _texts(sim)
	var hp0: int = b.hp
	SimCombat.damage_fighter(sim, b, 40)
	_check(b.hp == hp0 - 10 and texts.has(sim.tx("FT_ARMORED")), "armoured (IDLE): 40 damage -> 10, \"ARMORED\" text")
	hp0 = b.hp
	SimCombat.trigger_explosion(sim, b.x, b.y + 4.0, 34.0, 28.0, 310.0, 0, true)
	_check(b.hp < hp0 and b.hp >= hp0 - 7, "an explosion on the hovering fly is armoured too (%d -> %d)" % [hp0, b.hp])
	_run(sim, 0.2)
	_check(sim.boss_state == "STUNNED" and not b.flying, "knocked out of the air: STUNNED (still armoured)")
	SimBoss.enter_rest(sim, {"rest_state": "RESTING"})
	hp0 = b.hp
	SimCombat.damage_fighter(sim, b, 20)
	_check(b.hp == hp0 - 20, "RESTING: full damage")
	# phase-2 rests are shorter: 12 s into the larvae's turn
	var s2 := _make(_level())
	_sturdy(s2)
	_until_player(s2)
	SimBoss.enter_rest(s2, s2.boss_def.attacks[3])
	_run(s2, 11.0)
	var still: bool = s2.boss_state == "RESTING"
	_run(s2, 1.5)
	_check(still and s2.boss_state == "RECOVER" and s2.boss.flying and not SimBoss.is_vulnerable(s2), "phase-2 rest: it takes off 12 s into the larvae's turn")
	# rest_hits: a rest that ends on the first hit (the great tit's perch)
	SimBoss.enter_rest(s2, {"rest_state": "RESTING", "rest_hits": 1})
	SimCombat.damage_fighter(s2, s2.boss, 5)
	_check(s2.boss_state == "RECOVER", "rest_hits 1: the first hit ends the rest")


func _buzz() -> void:
	var sim := _make(_level())
	_sturdy(sim)
	_force(sim, "BUZZ")
	_boss_turn(sim)
	var it: Dictionary = sim.boss_intent
	_check(it.get("attack_id", "") == "BUZZ" and it.get("kind", "") == "GUST" and is_equal_approx(float(it["radius"]), 200.0) and int(it["target_id"]) == -1 and str(it["label"]) != "", "BUZZ: an area intent of 200 px with its \"move away\" warning")
	_until_player(sim)
	# one larva right on the mark, the others well away
	var team: Array[SimFighter] = _team(sim, 0)
	var pos: Vector2 = it["pos"]
	var inside: SimFighter = null
	for f in team:
		if Vector2(f.x, f.y).distance_to(pos) <= 150.0:
			inside = f
	var outside: Array[SimFighter] = []
	for f in team:
		if f != inside and Vector2(f.x, f.y).distance_to(pos) > 200.0:
			outside.append(f)
		elif f != inside:
			var p: Vector2 = _far_spot(sim, f, pos)
			if p != Vector2.INF:
				_put(f, p)
				outside.append(f)
	var hp_in: int = inside.hp if inside != null else 0
	var hp_out: Array[int] = []
	for f in outside:
		hp_out.append(f.hp)
	_boss_turn(sim)
	var out_ok: bool = not outside.is_empty()
	for i in outside.size():
		out_ok = out_ok and outside[i].hp == hp_out[i]
	_check(inside != null and inside.hp <= hp_in - 4, "the buzz hurts and pushes the larva on the mark")
	_check(out_ok, "larvae more than 200 px away are untouched (%d)" % outside.size())


func _phase_and_summons() -> void:
	var sim := _make(_level())
	_sturdy(sim)
	var b: SimFighter = sim.boss
	var phases: Array[int] = []
	sim.boss_phase_changed.connect(func(p: int) -> void: phases.append(p))
	b.hp = 91
	SimCombat.damage_fighter(sim, b, 4)
	_check(b.hp == 90 and sim.boss_phase == 2 and phases == [2], "at 50 %% HP the fly enters phase 2 (boss_phase_changed(2))")
	_boss_turn(sim)
	_check(sim.boss_intent.get("attack_id", "") == "SUMMON", "phase 2: it first announces the summon (priority)")
	_force(sim, "LAY_EGGS")
	_boss_turn(sim)
	var minis: Array[SimFighter] = _kind(sim, "SMALL_FLY")
	var ok: bool = minis.size() == 2
	for m in minis:
		ok = ok and m.team == 1 and m.alive and m.flying and m.hp == 15 and m.unit.ai == "FLYER" and not sim.terrain.is_solid(m.x, m.y)
	_check(ok, "two small flies appear in the air (FLYER, 15 HP)")
	var it: Dictionary = sim.boss_intent
	_check(it.get("attack_id", "") == "LAY_EGGS" and (it["targets"] as Array).size() == 2 and int(it["targets"][0]["id"]) != int(it["targets"][1]["id"]), "phase-2 LAY_EGGS marks two larvae")
	var order: Array[SimFighter] = []
	sim.turn_started.connect(func(t: int, f: SimFighter) -> void:
		if t == 1:
			order.append(f))
	_boss_turn(sim)
	_check(order.size() == 3 and order[2] == b and order[0].kind == "SMALL_FLY" and order[1].kind == "SMALL_FLY", "the small flies act before the boss in the enemy turn")
	var marked: int = 0
	for f in _team(sim, 0):
		marked += 1 if f.statuses.has("PARASITE") else 0
	_check(marked == 2 and sim.boss_state == "RESTING", "both marked larvae got eggs, then it rests")
	_boss_turn(sim)
	_boss_turn(sim)
	_check(_kind(sim, "SMALL_FLY").size() == 2, "the summon happens only once")


func _water() -> void:
	var sim := _make(_level())
	var b: SimFighter = sim.boss
	var hp0: int = b.hp
	# the sea rises over the ground under the fly (the map has no open water column)
	sim.terrain.water_y = sim.terrain.find_surface_y(b.x, b.y) - 60.0
	b.y = sim.terrain.water_y + 1.0
	b.flying = false
	b.grounded = false
	_run(sim, 0.1)
	_check(b.alive and not b.drowning and b.hp == hp0 - 20 and b.flying and b.y < sim.terrain.water_y, "knocked into the water: -20 HP (no armour), it flies out (%d -> %d)" % [hp0, b.hp])
	_run(sim, 3.0)
	_check(b.y < sim.terrain.water_y - 100.0 and b.flying, "and climbs back to its hover height")


func _defeat() -> void:
	var sim := _make(_level())
	_sturdy(sim)
	var b: SimFighter = sim.boss
	b.hp = 91
	SimCombat.damage_fighter(sim, b, 4)
	_boss_turn(sim)
	_boss_turn(sim)
	_until_player(sim)
	_check(_kind(sim, "SMALL_FLY").size() == 2, "scenario: the small flies are out")
	var overs: Array = []
	sim.game_over.connect(func(w: int, s: Dictionary) -> void: overs.append([w, s]))
	var defeated: Array[int] = [0]
	sim.boss_defeated.connect(func() -> void: defeated[0] += 1)
	SimBoss.enter_rest(sim, {"rest_state": "RESTING"})
	SimCombat.damage_fighter(sim, b, 999)
	_check(not b.alive and defeated[0] == 1 and sim.boss_state == "DEFEATED" and sim.boss_intent.is_empty(), "the boss falls: boss_defeated, state DEFEATED, no intent")
	_run(sim, 8.0)
	var st: Dictionary = overs[0][1] if overs.size() > 0 else {}
	_check(overs.size() == 1 and overs[0][0] == 0 and sim.winner == 0, "rule BOSS: the larvae win although the small flies are alive")
	_check(st.get("won", false) and st.get("reason", "") == "BOSS_DEFEATED" and st.get("survivors", 0) == 3 and st.get("stars", 0) == 3 and st.get("boss_id", "") == "TACHINID_FLY" and st.get("level_id", "") == "larva_boss", "stats: won, BOSS_DEFEATED, 3 survivors -> 3 stars (%s)" % str(st))
	var lost := _make(_level())
	var o2: Array = []
	lost.game_over.connect(func(w: int, s: Dictionary) -> void: o2.append([w, s]))
	for f in _team(lost, 0):
		f.alive = false
	_run(lost, 6.0)
	_check(o2.size() == 1 and o2[0][0] == 1 and o2[0][1].get("reason", "") == "LOST" and o2[0][1].get("boss_hp", 0) == 180, "all larvae down: LOST, the boss keeps its 180 HP")


## A second boss made only of data: a walking beetle with an AREA stomp and a STATUS cloud, plus a custom kind registered at run time.
func _dummy_boss() -> void:
	var def := BossDef.new()
	def.id = "DUMMY_BEETLE"
	def.name_key = "BOSS_DUMMY"
	def.max_hp = 60
	def.radius = 14.0
	def.flies = false
	def.speed = 140.0
	def.turn_time = 10.0
	def.spawn_frac = 0.6
	def.attacks = [
		{"id": "STOMP", "kind": "AREA", "weight": 1.0, "cooldown": 1, "radius": 30.0, "damage": 15, "knockback": 200.0, "label": "BOSS_INTENT_STOMP"},
		{"id": "SPORES", "kind": "STATUS", "weight": 1.0, "cooldown": 1, "radius": 400.0, "status": "ITCHY", "turns": 2, "label": "BOSS_INTENT_SPORES"},
	]
	def.vulnerable_states = ["INTENT"]
	def.armored_mult = 0.5
	def.statuses = {"ITCHY": {"damage": 3, "label": "DMG_PARASITE"}}
	var lv := _level().duplicate() as LevelDef
	lv.boss = def
	var sim := _make(lv)
	_sturdy(sim)
	var b: SimFighter = sim.boss
	_check(b != null and b.kind == "DUMMY_BEETLE" and not b.flying and b.hp == 60 and not sim.terrain.is_solid(b.x, b.y) and sim.terrain.is_solid(b.x, b.y + b.r + 3.0), "dummy boss: a walking beetle standing on the ground")
	var announced: Array[String] = []
	sim.boss_intent_changed.connect(func() -> void:
		if not sim.boss_intent.is_empty():
			announced.append(sim.boss_intent["attack_id"]))
	var hits: Array[String] = []
	sim.boss_attack.connect(func(id: String, _p: Vector2) -> void: hits.append(id))
	var x0: float = b.x
	for k in 4:
		_boss_turn(sim)
	_check(announced.has("STOMP") and announced.has("SPORES") and hits.size() >= 2, "dummy: both attacks announced and executed (%s / %s)" % [str(announced), str(hits)])
	var itchy: bool = false
	for f in _team(sim, 0):
		itchy = itchy or f.statuses.has("ITCHY") or f.hp < 9999
	_check(itchy and absf(b.x - x0) > 5.0, "dummy: its attacks reach the larvae and it walks to them")
	_check(sim.boss_state == "INTENT" and SimBoss.is_vulnerable(sim), "dummy: vulnerable while it shows an intent (data)")
	# a new kind registered at run time works the same
	BossAttacks.register("HOWL", BossAttack.new())
	def.attacks.append({"id": "HOWL", "kind": "HOWL", "priority": 5, "label": "BOSS_INTENT_HOWL"})
	_boss_turn(sim)
	_check(sim.boss_intent.get("kind", "") == "HOWL", "a kind registered with BossAttacks.register() is used")
	_boss_turn(sim)
	_check(sim.turn_phase != CombatSim.Phase.GAME_OVER and b.alive, "its (empty) execution passes cleanly")
	var overs: Array = []
	sim.game_over.connect(func(w: int, _s: Dictionary) -> void: overs.append(w))
	_until_player(sim)
	SimCombat.damage_fighter(sim, b, 999)
	_run(sim, 8.0)
	_check(overs == [0], "dummy: defeating it wins the level")


## Every sound the boss modules ask for exists.
func _sfx_names() -> void:
	var re := RegEx.new()
	re.compile("\\bplay\\(\"([a-z_0-9]+)\"")
	var bad: Array[String] = []
	var n: int = 0
	for dir in ["res://combat/sim/boss/", "res://combat/sim/boss/attacks/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				for m in re.search_all(FileAccess.get_file_as_string(dir + f)):
					n += 1
					if not Sound.has_sound(m.get_string(1)):
						bad.append(m.get_string(1))
	_check(n > 5 and bad.is_empty(), "boss sfx names are known to Sound (%d uses, unknown: %s)" % [n, str(bad)])


func _classic_untouched() -> void:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 77
	cfg.game_mode = "CPU_CPU"
	sim.setup(cfg)
	var events: Array[int] = [0]
	sim.boss_changed.connect(func() -> void: events[0] += 1)
	sim.boss_intent_changed.connect(func() -> void: events[0] += 1)
	_run(sim, 40.0)
	var no_status: bool = true
	for f in sim.fighters:
		no_status = no_status and f.statuses.is_empty()
	_check(sim.boss == null and sim.boss_def == null and sim.boss_intent.is_empty() and events[0] == 0 and no_status, "classic match: no boss, no boss signals, no statuses")


## Seeds (the level's own first) with an open, gentle arena around the squad, like the level's: open sky above every larva,
## at most 150 px of relief and 4 steep steps within 260 px of the squad.
func _good_seeds(level: LevelDef, count: int) -> Array[int]:
	var out: Array[int] = [level.seed]
	var sd: int = level.seed - 300
	while out.size() < count and sd < level.seed + 900:
		if sd != level.seed and _open_arena(_make(level, sd)):
			out.append(sd)
		sd += 1
	return out


func _open_arena(sim: CombatSim) -> bool:
	var xs: float = 0.0
	for f in _team(sim, 0):
		xs += f.x / 3.0
		if not AiFlyer._clear_line(sim, Vector2(f.x, f.y - 150.0), Vector2(f.x, f.y)):
			return false
	var lo: float = INF
	var hi: float = -INF
	var steps: int = 0
	var prev: float = NAN
	var x: float = xs - 260.0
	while x <= xs + 260.0:
		var sy: float = sim.terrain.find_surface_y(x, 40.0)
		lo = minf(lo, sy)
		hi = maxf(hi, sy)
		steps += 1 if not is_nan(prev) and absf(sy - prev) > 14.0 else 0
		prev = sy
		x += 10.0
	return hi - lo <= 150.0 and steps <= 4


func _cpu_match(level: LevelDef, seed_v: int) -> Dictionary:
	var sim := _make(level, seed_v, UNLOCKED)
	sim.game_mode = "CPU_CPU"
	var res: Dictionary = {}
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	var counts: Dictionary = {"eggs": 0, "cleaned": 0, "phase2": false}
	sim.boss_attack.connect(func(id: String, _p: Vector2) -> void: counts["eggs"] = int(counts["eggs"]) + (1 if id == "LAY_EGGS" else 0))
	sim.boss_phase_changed.connect(func(_p: int) -> void: counts["phase2"] = true)
	var cleaned_texts: Array[String] = []
	for f in _team(sim, 0):
		cleaned_texts.append(sim.tx("FT_CLEANED", [f.name]))
	sim.float_text.connect(func(_p: Vector2, tx: String, _c: Color, _l: float) -> void:
		if cleaned_texts.has(tx):
			counts["cleaned"] = int(counts["cleaned"]) + 1)
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
				var wrong: bool = is_nan(f.x) or is_nan(f.y) or (f.alive and not f.drowning and f.y > sim.terrain.water_y + 60.0)
				if wrong and not bad:
					print("INFO  bad state: %s (%s) at %s, drowning %s, hp %d" % [f.name, f.kind, Vector2(f.x, f.y), f.drowning, f.hp])
				bad = bad or wrong
	res["done"] = sim.turn_phase == CombatSim.Phase.GAME_OVER and res.has("winner")
	res["bad"] = bad
	res["seconds"] = t
	res["boss_hp_end"] = sim.boss.hp
	res.merge(counts, true)
	return res


func _cpu_runs() -> void:
	var level: LevelDef = _level()
	var seeds: Array[int] = _good_seeds(level, RUN_SEEDS)
	var wins: int = 0
	var finished: int = 0
	var clean: int = 0
	var started: int = Time.get_ticks_msec()
	for sd in seeds:
		var r: Dictionary = _cpu_match(level, sd)
		finished += 1 if r["done"] else 0
		clean += 0 if r["bad"] else 1
		wins += 1 if r.get("won", false) else 0
		print("INFO  larva_boss seed %d: %s, survivors %d, boss HP left %d, rounds %d, eggs laid %d, silk cleanings %d, phase 2 %s (%.0f s sim)" % [
			sd, "WON" if r.get("won", false) else "lost", int(r.get("survivors", 0)), int(r["boss_hp_end"]), int(r.get("rounds", 0)), int(r["eggs"]), int(r["cleaned"]), str(r["phase2"]), float(r["seconds"])])
	_check(seeds.size() == RUN_SEEDS and finished == RUN_SEEDS and clean == RUN_SEEDS, "larva_boss: %d CPU-vs-CPU runs end without errors (seeds %s)" % [finished, str(seeds)])
	print("INFO  larva_boss: caterpillar AI wins %d of %d (%.1f s)" % [wins, seeds.size(), (Time.get_ticks_msec() - started) / 1000.0])
