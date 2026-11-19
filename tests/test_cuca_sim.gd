## Cuca stage in the sim (docs/cuca_contracts.md): larva_l3..l5 and the great tit, the PICOTADA_FORTA peck, the six cuca levels and
## the great tit boss (perch, PERCHED is the only vulnerable state, phase 2), the unlock chain and CPU-vs-CPU runs of every level.
##   godot --headless --path . res://tests/TestCucaSim.tscn
## Print the first playable seed from a base: CUCS_CUCA_SCAN=5101 godot --headless --path . res://tests/TestCucaSim.tscn
extends Node

const DT: float = 1.0 / 60.0
const RUN_SEEDS: int = 5
const RUN_LIMIT_S: float = 2400.0
const CUCA_LEVELS: Array[String] = ["cuca_1", "cuca_2", "cuca_3", "cuca_4", "cuca_5", "cuca_6", "cuca_boss"]
const UNLOCKS: Array[String] = ["BAZOOKA", "GRENADE", "SHOTGUN", "GANXO", "CLUSTER", "DYNAMITE"]
const BEFORE: Array[String] = ["FUET", "CARQUINYOLI", "BAT"]

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id)


## The weapons the player already has when a Cuca level starts: the larva unlocks plus the rows of the earlier Cuca levels.
func _arsenal_before(id: String) -> Dictionary:
	var out: Dictionary = {}
	for w in BEFORE:
		out[w] = -1
	for i in CUCA_LEVELS.find(id):
		if i < UNLOCKS.size():
			out[UNLOCKS[i]] = -1
	return out


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


func _kind(sim: CombatSim, team: int, kind: String) -> Array[SimFighter]:
	var out: Array[SimFighter] = []
	for f in _team(sim, team):
		if f.kind == kind:
			out.append(f)
	return out


func _sturdy(sim: CombatSim) -> void:
	for f in _team(sim, 0):
		f.hp = 9999
		f.max_hp = 9999


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


func _until_player(sim: CombatSim, max_s: float = 60.0) -> void:
	var t: float = 0.0
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER and not (sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0):
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## Only this attack id can be announced (the others are put on a long cooldown).
func _force(sim: CombatSim, attack_id: String) -> void:
	for a in sim.boss_def.attacks:
		sim.boss_memory["cooldowns"][a["id"]] = 0 if a["id"] == attack_id else 99


func _ready() -> void:
	var scan: String = OS.get_environment("CUCS_CUCA_SCAN")
	if scan.is_valid_int():
		_scan(scan.to_int())
		get_tree().quit()
		return
	_units_and_weapon()
	_levels_data()
	_levels_setup()
	_boss_data()
	_boss_perch()
	_boss_peck_and_flap()
	_boss_phase_two()
	_unlock_chain()
	if OS.get_environment("CUCS_CUCA_FAST") == "":
		_cpu_runs()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

func _units_and_weapon() -> void:
	var want: Array = [["larva_l3", "LARVA_L3", 70, 11.0, 0.95], ["larva_l4", "LARVA_L4", 85, 11.5, 1.0], ["larva_l5", "LARVA_L5", 100, 12.0, 1.05]]
	for w in want:
		var u: UnitDef = load("res://data/units/%s.tres" % w[0])
		_check(u.id == w[1] and u.max_hp == w[2] and is_equal_approx(u.radius, w[3]) and is_equal_approx(u.art_scale, w[4]) and u.ai == "CATERPILLAR" and not u.flies and u.can_jump, "%s: %d HP, radius %.1f, art_scale %.2f, caterpillar AI" % [w[0], w[2], w[3], w[4]])
	var tit: UnitDef = load("res://data/units/great_tit.tres")
	_check(tit.id == "GREAT_TIT" and tit.max_hp == 60 and is_equal_approx(tit.radius, 15.0) and tit.flies and tit.ai == "FLYER" and tit.melee_weapon == "PICOTADA_FORTA", "great_tit: 60 HP, radius 15, flies, FLYER AI, peck PICOTADA_FORTA")
	var list: WeaponList = load("res://data/weapons/weapon_list.tres")
	var last: WeaponDef = list.weapons[list.weapons.size() - 2]
	_check(last.id == "PICOTADA_FORTA" and last.type == "MELEE" and is_equal_approx(last.max_dmg, 16.0) and is_equal_approx(last.reach, 44.0) and last.story_only and last.default_ammo == -1, "PICOTADA_FORTA follows PICOTADA: MELEE, 16 damage, reach 44, story-only (later story weapons come after it)")
	var peck: WeaponDef = list.weapons[list.weapons.size() - 3]
	_check(peck.id == "PICOTADA" and last.max_dmg > peck.max_dmg and last.reach > peck.reach, "it is stronger than PICOTADA")
	var classic := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 12
	classic.setup(cfg)
	_check(classic.weapons.size() == 16 and classic.weapon_index("PICOTADA_FORTA") == -1, "classic matches do not see PICOTADA_FORTA")


func _levels_data() -> void:
	var rows: Dictionary = {
		"cuca_1": [3, "LARVA_L3", {"BLUE_TIT": 2}, "ELIMINATE", "BAZOOKA"],
		"cuca_2": [7, "LARVA_L3", {"BLUE_TIT": 1, "ANT": 2}, "COLLECT", "GRENADE"],
		"cuca_3": [2, "LARVA_L4", {"ANT": 3}, "ELIMINATE", "SHOTGUN"],
		"cuca_4": [6, "LARVA_L4", {"ANT": 1}, "ONE_SHOT", "GANXO"],
		"cuca_5": [5, "LARVA_L5", {"GREAT_TIT": 2, "BLUE_TIT": 1}, "ELIMINATE", "CLUSTER"],
		"cuca_6": [7, "LARVA_L5", {"GREAT_TIT": 1}, "WAVES", "DYNAMITE"],
		"cuca_boss": [3, "LARVA_L5", {}, "BOSS", ""],
	}
	for id in CUCA_LEVELS:
		var lv: LevelDef = _level(id)
		var r: Array = rows[id]
		var counts: Dictionary = {}
		for u in lv.enemy_roster():
			counts[u.id] = int(counts.get(u.id, 0)) + 1
		var ok: bool = lv.map_idx == r[0] and lv.player_unit.id == r[1] and counts == r[2] and lv.win_rule == r[3] and lv.player_names.size() == 4 and lv.seed != 0
		ok = ok and lv.mode == "COMBAT" and lv.playable and lv.stage == "LARVA" and lv.has_ability("SILK_WEB")
		# cuca_4 (ONE_SHOT) has its own fixed arsenal; the other levels: URTICARIA + what is unlocked
		ok = ok and (lv.use_unlocked and lv.player_arsenal == {"URTICARIA": -1} if id != "cuca_4" else not lv.use_unlocked and lv.player_arsenal == {"BAZOOKA": 3, "GRENADE": 1})
		ok = ok and (lv.unlocks == [r[4]] if r[4] != "" else lv.unlocks.is_empty())
		_check(ok, "%s: map %d, 4 x %s, enemies %s, rule %s, unlocks %s, URTICARIA + unlocked + silk web" % [id, r[0], r[1], str(counts), r[3], r[4]])
		_check(lv.title_key == "LVL_%s_TITLE" % id.to_upper() and lv.intro_key == "LVL_%s_INTRO" % id.to_upper() and lv.goal_key == "LVL_%s_GOAL" % id.to_upper() and lv.tip_key == "LVL_%s_TIP" % id.to_upper(), "%s: text keys LVL_%s_*" % [id, id.to_upper()])
	var six: LevelDef = _level("cuca_6")
	_check(six.survive_rounds == 3 and six.wave_size == 2 and six.enemy_unit.id == "ANT", "cuca_6: the anthill sends waves of 2 ants for 3 rounds")
	var ids: Array[String] = []
	for l in StoryProgress.levels():
		ids.append(l.id)
	_check(ids.slice(ids.find("larva_boss"), ids.find("cuca_boss") + 1) == ["larva_boss"] + CUCA_LEVELS, "level_list: the Cuca levels come right after larva_boss, in order (%s)" % str(ids.slice(11)))
	_check(_level("cuca_boss").boss == load("res://data/bosses/great_tit_boss.tres"), "cuca_boss uses great_tit_boss.tres")


func _boss_data() -> void:
	var def: BossDef = load("res://data/bosses/great_tit_boss.tres")
	_check(def.id == "GREAT_TIT_BOSS" and def.max_hp == 260 and def.flies and def.phases == [0.5] and def.vulnerable_states == ["PERCHED"] and is_equal_approx(def.armored_mult, 0.25), "great tit boss: 260 HP, flies, phase at 50 %, vulnerable only PERCHED, x0.25 armour")
	var ids: Array[String] = []
	for a in def.attacks:
		ids.append("%s/%d" % [a["id"], int(a["phase"])])
		_check(BossAttacks.handler(str(a["kind"])) != null, "attack %s has a handler for kind %s" % [a["id"], a["kind"]])
	_check(ids == ["PERCH/-1", "PECK_DIVE/1", "WING_FLAP/-1", "SUMMON/2", "PECK_DIVE/2"], "attacks: PERCH, PECK_DIVE (phase 1), WING_FLAP, SUMMON (phase 2), PECK_DIVE (phase 2) (%s)" % str(ids))
	var perch: Dictionary = def.attacks[0]
	_check(perch["kind"] == "MOVE" and perch["to"] == "PERCH" and perch["rest_state"] == "PERCHED" and int(perch["rest_hits"]) == 2, "PERCH: MOVE to a perch, rest state PERCHED, 2 hits end it")
	var peck: Dictionary = def.attacks[1]
	_check(peck["kind"] == "MELEE_TARGET" and int(peck["damage"]) == 18 and is_equal_approx(float(peck["knockback"]), 160.0) and is_equal_approx(float(peck["dodge"]), 90.0) and int(peck["targets"]) == 1 and int(def.attacks[4]["targets"]) == 2, "PECK_DIVE: 18 damage, knockback 160, dodge 90, 1 target (2 in phase 2)")
	var flap: Dictionary = def.attacks[2]
	_check(flap["kind"] == "GUST" and is_equal_approx(float(flap["radius"]), 220.0) and is_equal_approx(float(flap["knockback"]), 200.0), "WING_FLAP: GUST of radius 220, knockback 200")
	var summon: Dictionary = def.attacks[3]
	_check(summon["kind"] == "SUMMON" and int(summon["count"]) == 2 and (summon["unit"] as UnitDef).id == "BLUE_TIT" and bool(summon["once"]), "SUMMON: 2 blue tits, once")


# ---------------------------------------------------------------------------
# Levels
# ---------------------------------------------------------------------------

## True when the setup of this seed is playable: every caterpillar has open sky above it (the birds dive from there) and a walking
## path to the others, every ground enemy (and the anthill) a path to the squad.
func _seed_ok(level: LevelDef, seed_v: int) -> bool:
	var sim := _make(level, seed_v)
	var squad: Array[SimFighter] = _team(sim, 0)
	var home := Vector2(squad[0].x, squad[0].y)
	var birds: bool = false
	for e in level.enemy_roster():
		birds = birds or e.flies
	for f in squad:
		if birds and not AiFlyer._clear_line(sim, Vector2(f.x, f.y - 150.0), Vector2(f.x, f.y)):
			return false
		if sim.nav.find_path(home, Vector2(f.x, f.y), true).is_empty() and f != squad[0]:
			return false
	for f in _team(sim, 1):
		if f.flying or f == sim.boss:
			continue
		if sim.nav.find_path(Vector2(f.x, f.y), home, true).is_empty():
			return false
	if sim.anthill_pos != Vector2.INF:
		if sim.nav.find_path(Vector2(sim.anthill_pos.x + SimStory.WAVE_GAP, sim.anthill_pos.y + TerrainSim.ANTHILL_H - 10.0), home, true).is_empty():
			return false
	return true


func _scan(base: int) -> void:
	for id in CUCA_LEVELS:
		var level: LevelDef = _level(id)
		var found: Array[int] = []
		var sd: int = base
		while found.size() < 3 and sd < base + 400:
			if _seed_ok(level, sd):
				found.append(sd)
			sd += 1
		print("SCAN  %s (current seed %d): %s" % [id, level.seed, str(found)])


func _levels_setup() -> void:
	for id in CUCA_LEVELS:
		var lv: LevelDef = _level(id)
		var sim := _make(lv, -1, _arsenal_before(id))
		var squad: Array[SimFighter] = _team(sim, 0)
		var foes: Array[SimFighter] = _team(sim, 1)
		var sized: bool = squad.size() == 4 and not squad.is_empty()
		for f in squad:
			sized = sized and f.kind == lv.player_unit.id and f.hp == lv.player_unit.max_hp
		var want: int = lv.enemy_roster().size() + (1 if lv.boss != null else 0)
		_check(sized and foes.size() == want and sim.turn_phase != CombatSim.Phase.GAME_OVER, "%s sets up: 4 x %s vs %d enemies" % [id, lv.player_unit.id, want])
		var birds_ok: bool = true
		for f in foes:
			birds_ok = birds_ok and (not f.flying or not sim.terrain.is_solid(f.x, f.y))
			birds_ok = birds_ok and (not f.unit.flies or f.flying)
		_check(birds_ok, "%s: the birds hover in free air" % id)
		_check(_seed_ok(lv, lv.seed), "%s: its seed %d is playable (open sky above the squad, every ground enemy can walk to it)" % [id, lv.seed])
		if id == "cuca_4":
			var plain := _make(lv) # the level's own arsenal: nothing is added from the unlocks (use_unlocked = false)
			_check(plain.ammo_f(0, "BAZOOKA") == 3.0 and plain.ammo_f(0, "GRENADE") == 1.0 and plain.ammo_f(0, "URTICARIA") <= 0.0, "cuca_4: the arsenal is 3 bazooka rounds + 1 grenade (ONE_SHOT)")
			continue
		var arsenal_ok: bool = sim.ammo_f(0, "URTICARIA") > 0.0
		for w in _arsenal_before(id):
			arsenal_ok = arsenal_ok and sim.ammo_f(0, w) > 0.0
		var later: Array[String] = UNLOCKS.slice(maxi(0, CUCA_LEVELS.find(id)))
		for w in later:
			arsenal_ok = arsenal_ok and sim.ammo_f(0, w) <= 0.0
		_check(arsenal_ok, "%s: the arsenal is URTICARIA + the weapons unlocked before it, nothing later" % id)
	var tit_level: LevelDef = _level("cuca_5")
	var sim3 := _make(tit_level)
	var tits: Array[SimFighter] = _kind(sim3, 1, "GREAT_TIT")
	_check(tits.size() == 2 and sim3.weapon_index("PICOTADA_FORTA") >= 0 and sim3.ammo_f(1, "PICOTADA_FORTA") > 0.0 and AiCritter.melee_weapon(sim3, tits[0]).id == "PICOTADA_FORTA", "great tits peck with PICOTADA_FORTA")
	var sim6 := _make(_level("cuca_6"))
	_check(sim6.waves_left == 3 and sim6.anthill_pos != Vector2.INF, "cuca_6: WAVES with an anthill and 3 rounds to survive")


# ---------------------------------------------------------------------------
# The great tit boss
# ---------------------------------------------------------------------------

func _boss_sim() -> CombatSim:
	var sim := _make(_level("cuca_boss"), -1, _arsenal_before("cuca_boss"))
	_sturdy(sim)
	return sim


func _boss_perch() -> void:
	var sim := _boss_sim()
	var b: SimFighter = sim.boss
	_check(b != null and b.kind == "GREAT_TIT_BOSS" and b.hp == 260 and b.flying and sim.boss_state == "IDLE" and sim.boss_phase == 1, "boss setup: team 1, 260 HP, flying, IDLE, phase 1")
	_check(not SimBoss.is_vulnerable(sim), "IDLE is not vulnerable")
	var hp0: int = b.hp
	SimCombat.damage_fighter(sim, b, 40)
	_check(hp0 - b.hp == 10, "in the air it takes x0.25 damage (40 -> %d)" % (hp0 - b.hp))
	b.hp = b.max_hp
	_force(sim, "PERCH")
	_check(_boss_turn(sim), "the boss gets its first turn")
	var it: Dictionary = sim.boss_intent
	_check(it.get("attack_id", "") == "PERCH" and it.get("kind", "") == "MOVE" and sim.boss_state == "INTENT", "turn 1: it announces PERCH")
	var dest: Vector2 = it["pos"]
	_check(dest.y < sim.terrain.water_y - 60.0 and not sim.terrain.is_solid(dest.x, dest.y), "the perch is a free point above the ground (%s)" % str(dest))
	var highest: float = INF
	var squad_x: float = _team(sim, 0)[0].x
	var x: float = maxf(80.0, squad_x - 350.0)
	while x <= minf(SimTables.TERRAIN_W - 80.0, squad_x + 350.0):
		highest = minf(highest, sim.terrain.find_surface_y(x, BossMotion.CEILING))
		x += 20.0
	_check(dest.y <= highest, "it picks one of the highest points near the squad")
	_boss_turn(sim)
	_check(sim.boss_state == "PERCHED" and not b.flying and b.grounded and Vector2(b.x, b.y).distance_to(dest) < 60.0, "turn 2: it flies to the perch and lands: PERCHED (%s)" % str(Vector2(b.x, b.y)))
	_until_player(sim)
	_check(sim.boss_state == "PERCHED" and SimBoss.is_vulnerable(sim), "the larvae's turn: PERCHED is vulnerable")
	var h1: int = b.hp
	SimCombat.damage_fighter(sim, b, 40)
	_check(h1 - b.hp == 40, "PERCHED: full damage (%d -> %d)" % [h1, b.hp])
	_check(sim.boss_state == "PERCHED", "one hit does not end the perch")
	SimCombat.damage_fighter(sim, b, 10)
	_check(sim.boss_state == "RECOVER" and b.flying and not SimBoss.is_vulnerable(sim), "the second hit scares it off: back in the air, armoured again")
	var h2: int = b.hp
	SimCombat.damage_fighter(sim, b, 40)
	_check(h2 - b.hp == 10, "after taking off it is armoured again (x0.25)")
	# only PERCHED is vulnerable: every other state is armoured
	for st in ["IDLE", "INTENT", "ACT", "RECOVER", "STUNNED", "RESTING"]:
		sim.boss_state = st
		_check(not SimBoss.is_vulnerable(sim), "%s is not vulnerable" % st)
	sim.boss_state = "PERCHED"
	_check(SimBoss.is_vulnerable(sim), "PERCHED is vulnerable")


func _boss_peck_and_flap() -> void:
	var sim := _boss_sim()
	var b: SimFighter = sim.boss
	_force(sim, "PECK_DIVE")
	_boss_turn(sim)
	var it: Dictionary = sim.boss_intent
	var target: SimFighter = BossAttack.fighter_by_id(sim, int(it.get("target_id", -1)))
	_check(it.get("attack_id", "") == "PECK_DIVE" and target != null and target.team == 0 and (it["targets"] as Array).size() == 1 and is_equal_approx(float(it["radius"]), 90.0), "PECK_DIVE is announced on one larva (dodge 90)")
	var hp0: int = target.hp
	var hits: Array = []
	sim.boss_attack.connect(func(id: String, _p: Vector2) -> void: hits.append(id))
	_boss_turn(sim)
	_check(hp0 - target.hp >= 18 and hp0 - target.hp <= 30 and hits.has("PECK_DIVE"), "the dive lands: 18 damage and boss_attack (%d -> %d)" % [hp0, target.hp])
	_check(not SimBoss.is_vulnerable(sim) and b.flying, "after the peck it is still in the air and armoured")
	var sim2 := _boss_sim()
	_force(sim2, "WING_FLAP")
	_boss_turn(sim2)
	_check(sim2.boss_intent.get("attack_id", "") == "WING_FLAP" and sim2.boss_intent.get("kind", "") == "GUST" and is_equal_approx(float(sim2.boss_intent["radius"]), 220.0), "WING_FLAP is announced as a 220 px gust")
	var seen: Array = []
	sim2.boss_attack.connect(func(id: String, _p: Vector2) -> void: seen.append(id))
	_boss_turn(sim2)
	_check(seen.has("WING_FLAP"), "the wing flap happens the next turn")


func _boss_phase_two() -> void:
	var sim := _boss_sim()
	var b: SimFighter = sim.boss
	var phases: Array[int] = []
	sim.boss_phase_changed.connect(func(p: int) -> void: phases.append(p))
	b.hp = 131
	SimCombat.damage_fighter(sim, b, 12)
	_check(b.hp == 128 and sim.boss_phase == 2 and phases == [2], "at 50 %% HP the great tit enters phase 2 (hp %d)" % b.hp)
	_boss_turn(sim)
	_check(sim.boss_intent.get("attack_id", "") == "SUMMON", "phase 2: it announces the summon first")
	_force(sim, "PECK_DIVE")
	_boss_turn(sim)
	var tits: Array[SimFighter] = _kind(sim, 1, "BLUE_TIT")
	var ok: bool = tits.size() == 2
	for m in tits:
		ok = ok and m.team == 1 and m.alive and m.flying and m.unit.ai == "FLYER" and not sim.terrain.is_solid(m.x, m.y)
	_check(ok, "two blue tits appear in the air")
	var it: Dictionary = sim.boss_intent
	_check(it.get("attack_id", "") == "PECK_DIVE" and (it["targets"] as Array).size() == 2 and int(it["targets"][0]["id"]) != int(it["targets"][1]["id"]), "phase 2: PECK_DIVE marks two larvae")
	var marked: Array = []
	for m in it["targets"]:
		marked.append(BossAttack.fighter_by_id(sim, int(m["id"])))
	var before: Array = marked.map(func(f: SimFighter) -> int: return f.hp)
	_boss_turn(sim)
	var hurt: int = 0
	for i in marked.size():
		hurt += 1 if (marked[i] as SimFighter).hp < int(before[i]) else 0
	_check(hurt >= 1, "the double dive hurts the marked larvae")
	_boss_turn(sim)
	_boss_turn(sim)
	_check(_kind(sim, 1, "BLUE_TIT").size() == 2, "the summon happens only once")


# ---------------------------------------------------------------------------
# Progress
# ---------------------------------------------------------------------------

func _unlock_chain() -> void:
	var saved_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://test_cuca_chain.cfg"
	StoryProgress.reset_progress()
	var by_id: Dictionary = {}
	for l in StoryProgress.levels():
		by_id[l.id] = l
	_check(not StoryProgress.is_unlocked(by_id["cuca_1"]), "cuca_1 is locked until larva_boss is won")
	for id in ["egg_boss", "larva_1", "larva_2", "larva_3", "larva_4", "larva_5", "larva_boss"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 1})
	_check(StoryProgress.is_unlocked(by_id["cuca_1"]) and not StoryProgress.is_unlocked(by_id["cuca_2"]), "winning larva_boss opens cuca_1 only")
	var sizes: Array[int] = [GameState.unlocked_arsenal().size()]
	for i in CUCA_LEVELS.size() - 1:
		var id: String = CUCA_LEVELS[i]
		var next: String = CUCA_LEVELS[i + 1]
		_check(not StoryProgress.is_unlocked(by_id[next]), "%s is locked before %s is won" % [next, id])
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 1})
		_check(StoryProgress.is_unlocked(by_id[next]), "winning %s opens %s" % [id, next])
		var arsenal: Dictionary = GameState.unlocked_arsenal()
		sizes.append(arsenal.size())
		_check(arsenal.has(UNLOCKS[i]) and arsenal.size() == sizes[i] + 1, "after %s the merged arsenal gains %s (%d weapons)" % [id, UNLOCKS[i], arsenal.size()])
		var sim := _make(by_id[next], -1, arsenal)
		if next == "cuca_4":
			continue # the ONE_SHOT level has its own fixed arsenal (checked in _levels_setup)
		_check(sim.ammo_f(0, UNLOCKS[i]) > 0.0 and sim.ammo_f(0, "URTICARIA") > 0.0 and sim.ammo_f(0, "FUET") > 0.0, "%s starts with URTICARIA, the larva weapons and %s" % [next, UNLOCKS[i]])
	StoryProgress.record_result({"level_id": "cuca_6", "won": true, "stars": 1})
	_check(StoryProgress.unlocked_weapons() == BEFORE + UNLOCKS.slice(0, 6) and StoryProgress.is_unlocked(by_id["cuca_boss"]), "after cuca_6: nine weapons unlocked in order, the boss is open (%s)" % str(StoryProgress.unlocked_weapons()))
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = saved_path
	StoryProgress.load_progress()


# ---------------------------------------------------------------------------
# CPU runs
# ---------------------------------------------------------------------------

func _good_seeds(level: LevelDef, count: int) -> Array[int]:
	var out: Array[int] = [level.seed]
	var sd: int = level.seed + 1
	while out.size() < count and sd < level.seed + 600:
		if _seed_ok(level, sd):
			out.append(sd)
		sd += 1
	return out


func _cpu_match(level: LevelDef, seed_v: int) -> Dictionary:
	var sim := _make(level, seed_v, _arsenal_before(level.id))
	sim.game_mode = "CPU_CPU"
	var res: Dictionary = {}
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
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
				bad = bad or is_nan(f.x) or is_nan(f.y) or (f.alive and not f.drowning and f.y > sim.terrain.water_y + 60.0)
	res["done"] = sim.turn_phase == CombatSim.Phase.GAME_OVER and res.has("winner")
	res["bad"] = bad
	res["seconds"] = t
	res["boss_hp_end"] = sim.boss.hp if sim.boss != null else 0
	return res


func _cpu_runs() -> void:
	for id in CUCA_LEVELS:
		var level: LevelDef = _level(id)
		var seeds: Array[int] = _good_seeds(level, RUN_SEEDS)
		var wins: int = 0
		var finished: int = 0
		var clean: int = 0
		var surv: int = 0
		var started: int = Time.get_ticks_msec()
		for sd in seeds:
			var r: Dictionary = _cpu_match(level, sd)
			finished += 1 if r["done"] else 0
			clean += 0 if r["bad"] else 1
			wins += 1 if r.get("won", false) else 0
			surv += int(r.get("survivors", 0))
			print("INFO  %s seed %d: %s, survivors %d of 4, boss HP left %d, rounds %d (%.0f s sim)" % [id, sd, "WON" if r.get("won", false) else "lost", int(r.get("survivors", 0)), int(r["boss_hp_end"]), int(r.get("rounds", 0)), float(r["seconds"])])
		_check(seeds.size() == RUN_SEEDS and finished == RUN_SEEDS and clean == RUN_SEEDS, "%s: %d CPU-vs-CPU runs end without errors (seeds %s)" % [id, finished, str(seeds)])
		print("INFO  %s: caterpillar AI wins %d of %d, survivors avg %.1f of 4 (%.1f s)" % [id, wins, seeds.size(), surv / float(seeds.size()), (Time.get_ticks_msec() - started) / 1000.0])
