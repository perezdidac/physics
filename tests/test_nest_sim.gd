## El Bolsó in the sim (docs/nest_contracts.md): the nest (damage, repair, shelter), the DEFEND_NEST rule, the cold and WARM_SILK, the pole
## (telegraph, then the hit), birds pecking the nest, the upgrades (story only), silk and the save, the forestry brigade boss (LINE,
## WINDED, phase 2) and CPU-vs-CPU runs of the five levels.
##   godot --headless --path . res://tests/TestNestSim.tscn
## CUCS_NEST_FAST=1 skips the CPU runs. Print the first playable seeds from a base: CUCS_NEST_SCAN=6000 godot --headless --path . res://tests/TestNestSim.tscn
extends Node

const DT: float = 1.0 / 60.0
const RUN_SEEDS: int = 5
const RUN_LIMIT_S: float = 2400.0
const NEST_LEVELS: Array[String] = ["nest_1", "nest_2", "nest_3", "nest_4", "nest_boss"]
## Weapons of the earlier stages (the Cuca unlocks and the larva ones): what the player has when El Bolsó starts.
const EARLIER: Array[String] = ["FUET", "CARQUINYOLI", "BAT", "BAZOOKA", "GRENADE", "SHOTGUN", "GANXO", "CLUSTER", "DYNAMITE"]

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _level(id: String) -> LevelDef:
	return load("res://data/levels/%s.tres" % id)


func _arsenal(id: String) -> Dictionary:
	var out: Dictionary = {}
	for w in EARLIER:
		out[w] = -1
	if NEST_LEVELS.find(id) >= 1:
		out["PONT_PEDRA"] = 3
	if NEST_LEVELS.find(id) >= 3:
		out["AIRSTRIKE"] = 2
	return out


func _make(level: LevelDef, seed_v: int = -1, upgrades: Array[String] = []) -> CombatSim:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.level = level
	cfg.map_idx = level.map_idx
	cfg.seed = level.seed if seed_v < 0 else seed_v
	cfg.game_mode = "1P_CPU"
	cfg.worms_per_team = level.player_names.size()
	cfg.extra_arsenal = _arsenal(level.id)
	cfg.upgrades = upgrades
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
	var t: float = 0.0
	while t < seconds and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## Steps until team 0 plays again (TURN_PLAY); the squad passes any turn it is given on the way when `pass_turns` is set.
func _until_player(sim: CombatSim, max_s: float = 90.0) -> void:
	var t: float = 0.0
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER and not (sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0):
		sim.step(DT)
		sim.advance_real(DT)
		t += DT


## The squad ends its turn and the enemy plays a whole turn; returns when it is the squad's turn again.
func _next_round(sim: CombatSim) -> void:
	sim.end_turn()
	_run(sim, 0.2)
	_until_player(sim)


## Steps (the squad passes) until the boss's own sub-turn has run and ended; false if it never came.
## `hide`: the squad is out of the boss's sight all the time (it marks only the nest).
func _boss_turn(sim: CombatSim, max_s: float = 120.0, hide: bool = false) -> bool:
	var t: float = 0.0
	var seen: bool = false
	while t < max_s and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			sim.end_turn()
		if hide:
			for f in _team(sim, 0):
				f.hidden = true
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		if sim.active_fighter == sim.boss and sim.turn_phase == CombatSim.Phase.TURN_PLAY:
			seen = true
		elif seen:
			return true
	return seen


## Only this attack id can be announced (the others are put on a long cooldown).
func _force(sim: CombatSim, attack_id: String) -> void:
	for a in sim.boss_def.attacks:
		if a["id"] != attack_id:
			sim.boss_memory["cooldowns"][a["id"]] = 99


## Puts a fighter on the ground of column x: the tier closest to `ground` (default: to where the fighter was). When the column has
## no ground the next ones to either side are tried.
func _stand(sim: CombatSim, f: SimFighter, x: float, ground: float = NAN) -> void:
	var ref: float = f.y + f.r if is_nan(ground) else ground
	for k in 40:
		for d in ([0] if k == 0 else [-1, 1]):
			var cx: float = x + d * k * 10.0
			var best: float = NAN
			for tier in sim.terrain.find_all_walkable_surfaces_at_x(cx):
				if is_nan(best) or absf(float(tier) - ref) < absf(best - ref):
					best = float(tier)
			if not is_nan(best) and best < sim.terrain.water_y - 40.0:
				f.x = cx
				f.y = best - f.r - 2.0
				f.vx = 0.0
				f.vy = 0.0
				f.grounded = true
				f.sliding = false
				f.jump_start_y = f.y
				f.peak_air_y = f.y
				return


## Puts a fighter inside the nest (on its floor) at `dx` px from its centre.
func _in_nest(sim: CombatSim, f: SimFighter, dx: float = 0.0) -> void:
	f.x = sim.nest.pos.x + dx
	f.y = sim.nest.rect().end.y - f.r - 2.0
	f.vx = 0.0
	f.vy = 0.0
	f.grounded = true
	f.jump_start_y = f.y
	f.peak_air_y = f.y


func _hps(sim: CombatSim) -> Array[int]:
	var out: Array[int] = []
	for f in _team(sim, 0):
		out.append(f.hp)
	return out


func _ready() -> void:
	var scan: String = OS.get_environment("CUCS_NEST_SCAN")
	if scan.is_valid_int():
		_scan(scan.to_int())
		get_tree().quit()
		return
	_data()
	_levels_setup()
	_nest_damage()
	_shelter_and_repair()
	_rules()
	_cold()
	_pole()
	_birds()
	_upgrades()
	_silk_and_save()
	_economy()
	_boss_data()
	_boss_line()
	_boss_winded_and_phase_two()
	_boss_cartridge_and_end()
	_classic_untouched()
	if OS.get_environment("CUCS_NEST_FAST") == "":
		_cpu_runs()
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

func _data() -> void:
	var worker: UnitDef = load("res://data/units/forestry_worker.tres")
	_check(worker.id == "FORESTRY_WORKER" and worker.max_hp == 45 and worker.ai == "MELEE_CRITTER" and not worker.flies and worker.melee_weapon == "PERXADA", "forestry_worker: 45 HP, walks, MELEE_CRITTER, peck weapon PERXADA")
	var list: WeaponList = load("res://data/weapons/weapon_list.tres")
	var pole: WeaponDef = list.weapons[list.weapons.size() - 1]
	_check(pole.id == "PERXADA" and pole.type == "MELEE" and pole.story_only and pole.max_dmg > 0.0 and pole.reach > 30.0, "PERXADA is the last weapon: MELEE, story-only")
	var ups: Array[UpgradeDef] = SimUpgrades.all()
	var effects: Array[String] = []
	var ids: Dictionary = {}
	var priced: bool = true
	for u in ups:
		effects.append(u.effect)
		ids[u.id] = true
		priced = priced and u.cost > 0 and u.name_key != "" and u.desc_key != ""
	effects.sort()
	effects.sort()
	var want: Array[String] = ["DAMAGE_PCT", "DAMAGE_PCT", "EXTRA_HEART", "EXTRA_HEART", "EXTRA_SILK_WEB", "FAST_DIG", "LONG_FLIGHT", "MAX_HP_PCT", "MAX_HP_PCT", "NEST_HP", "START_AMMO", "WARM_SILK"]
	_check(ups.size() == 12 and ids.size() == 12 and priced and effects == want, "twelve upgrades with an effect, a price and text keys (%s)" % str(effects))
	var scopes_ok: bool = true
	var tiers_ok: bool = true
	for u in ups:
		scopes_ok = scopes_ok and ["COMBAT", "NEST", "PLATFORM"].has(u.scope) and (u.effect in ["NEST_HP", "WARM_SILK"]) == (u.scope == "NEST") and (u.effect in ["EXTRA_HEART", "FAST_DIG", "LONG_FLIGHT"]) == (u.scope == "PLATFORM")
		if u.requires != "":
			var base: UpgradeDef = SimUpgrades.find(u.requires)
			tiers_ok = tiers_ok and base != null and base.effect == u.effect and base.requires == "" and base.cost < u.cost
	_check(scopes_ok and tiers_ok, "every upgrade has a valid scope; a tier II needs a cheaper tier I with the same effect")
	var rows: Dictionary = {
		"nest_1": [6, 4, {"GREAT_TIT": 2}, "DEFEND_NEST", 4, false, false, "PONT_PEDRA"],
		"nest_2": [6, 5, {"GREAT_TIT": 2, "BLUE_TIT": 1}, "DEFEND_NEST", 5, true, false, ""],
		"nest_3": [2, 5, {"GREAT_TIT": 3, "BLUE_TIT": 2}, "DEFEND_NEST", 5, true, false, "AIRSTRIKE"],
		"nest_4": [2, 5, {"GREAT_TIT": 2}, "DEFEND_NEST", 5, true, true, ""],
		"nest_boss": [7, 0, {}, "BOSS", 0, true, false, ""],
	}
	for id in NEST_LEVELS:
		var lv: LevelDef = _level(id)
		var r: Array = rows[id]
		var counts: Dictionary = {}
		for u in lv.enemy_roster():
			counts[u.id] = int(counts.get(u.id, 0)) + 1
		var ok: bool = lv.map_idx == r[0] and lv.survive_rounds == r[1] and counts == r[2] and lv.win_rule == r[3] and lv.cold == r[5] and lv.pole == r[6]
		ok = ok and lv.player_unit.id == "LARVA_L5" and lv.player_names.size() == 4 and lv.seed != 0 and lv.nest_hp == 300 and lv.stage == "NEST" and lv.mode == "COMBAT" and lv.playable
		ok = ok and lv.has_ability("SILK_WEB") and lv.use_unlocked and lv.player_arsenal == {"URTICARIA": -1} and (lv.unlocks == [r[7]] if r[7] != "" else lv.unlocks.is_empty())
		_check(ok, "%s: map %d, 4 x L5, enemies %s, rule %s %d rounds, cold %s, pole %s, unlocks '%s', nest 300 HP" % [id, r[0], str(counts), r[3], r[1], str(r[5]), str(r[6]), r[7]])
		_check(lv.title_key == "LVL_%s_TITLE" % id.to_upper() and lv.intro_key == "LVL_%s_INTRO" % id.to_upper() and lv.goal_key == "LVL_%s_GOAL" % id.to_upper() and lv.tip_key == "LVL_%s_TIP" % id.to_upper(), "%s: text keys LVL_%s_*" % [id, id.to_upper()])
	var all_ids: Array[String] = []
	for l in StoryProgress.levels():
		all_ids.append(l.id)
	_check(all_ids.slice(all_ids.find("cuca_boss"), all_ids.find("nest_boss") + 1) == ["cuca_boss"] + NEST_LEVELS, "level_list: the nest levels come right after cuca_boss, in order (%s)" % str(all_ids.slice(17)))
	var orders: Array[int] = []
	for id in NEST_LEVELS:
		orders.append(_level(id).order)
	_check(orders == [19, 20, 21, 22, 23], "orders 19..23")
	_check(_level("nest_boss").boss == load("res://data/bosses/brigade_boss.tres"), "nest_boss uses brigade_boss.tres")


# ---------------------------------------------------------------------------
# Levels
# ---------------------------------------------------------------------------

## True when the setup of this seed is playable: the nest stands on a clear flat spot (not the fallback), the squad can walk to it and
## to each other, open sky above every caterpillar (birds dive from there), every ground enemy / the boss can walk to the squad.
func _seed_ok(level: LevelDef, seed_v: int) -> bool:
	var sim := _make(level, seed_v)
	if sim.nest == null:
		return false
	var squad: Array[SimFighter] = _team(sim, 0)
	var home := Vector2(squad[0].x, squad[0].y)
	var area: Rect2 = sim.nest.rect()
	var ground: float = area.end.y
	var half: float = area.size.x * 0.5
	if absf(sim.terrain.find_surface_y(sim.nest.pos.x - half * 0.8, ground - 40.0) - ground) > SimBolso.FLAT_TOLERANCE or absf(sim.terrain.find_surface_y(sim.nest.pos.x + half * 0.8, ground - 40.0) - ground) > SimBolso.FLAT_TOLERANCE:
		return false
	if SimPlacement.hits_stamp(SimPlacement.stamp_rects(sim.terrain), area) or SimPlacement.buried_fraction(sim.terrain, area) >= SimBolso.MAX_BURIED:
		return false
	if sim.nav.find_path(home, Vector2(sim.nest.pos.x, ground - 14.0), true).is_empty():
		return false
	for f in squad:
		if not AiFlyer._clear_line(sim, Vector2(f.x, f.y - 150.0), Vector2(f.x, f.y)):
			return false
		if sim.nav.find_path(home, Vector2(f.x, f.y), true).is_empty() and f != squad[0]:
			return false
	for f in _team(sim, 1):
		if f.flying:
			continue
		if sim.nav.find_path(Vector2(f.x, f.y), home, true).is_empty():
			return false
	return true


func _scan(base: int) -> void:
	for id in NEST_LEVELS:
		var level: LevelDef = _level(id)
		var found: Array[int] = []
		var sd: int = base
		while found.size() < 3 and sd < base + 400:
			if _seed_ok(level, sd):
				found.append(sd)
			sd += 1
		print("SCAN  %s (current seed %d): %s" % [id, level.seed, str(found)])


func _levels_setup() -> void:
	for id in NEST_LEVELS:
		var lv: LevelDef = _level(id)
		var sim := _make(lv)
		var squad: Array[SimFighter] = _team(sim, 0)
		var want: int = lv.enemy_roster().size() + (1 if lv.boss != null else 0)
		var sized: bool = squad.size() == 4
		for f in squad:
			sized = sized and f.kind == "LARVA_L5" and f.hp >= 95
		_check(sized and _team(sim, 1).size() == want and sim.turn_phase != CombatSim.Phase.GAME_OVER, "%s sets up: 4 x L5 vs %d enemies" % [id, want])
		var n: SimBolso = sim.nest
		var near: int = 0
		for f in squad:
			near += 1 if n != null and n.distance_to(Vector2(f.x, f.y)) <= 140.0 else 0
		_check(n != null and n.hp == 300 and n.max_hp == 300 and n.size == SimBolso.SIZE and near >= 3 and sim.cold_active == lv.cold, "%s: the nest (300 HP, %s) stands beside the squad (%d of 4 within 140 px), cold %s" % [id, str(n.size) if n != null else "-", near, str(sim.cold_active)])
		_check(sim.rounds_left == (lv.survive_rounds if lv.win_rule == "DEFEND_NEST" else -1), "%s: rounds_left %d" % [id, sim.rounds_left])
		_check(_seed_ok(lv, lv.seed), "%s: its seed %d is playable (flat clear spot for the nest, open sky, walking paths)" % [id, lv.seed])
		var arsenal_ok: bool = sim.ammo_f(0, "URTICARIA") > 0.0
		for w in _arsenal(id):
			arsenal_ok = arsenal_ok and sim.ammo_f(0, w) > 0.0
		_check(arsenal_ok, "%s: the arsenal is URTICARIA + the weapons unlocked before it" % id)
	var tits: Array[SimFighter] = _kind(_make(_level("nest_1")), "GREAT_TIT")
	_check(tits.size() == 2 and tits[0].flying, "nest_1: two great tits hover in the air")


# ---------------------------------------------------------------------------
# The nest: damage, shelter, repair
# ---------------------------------------------------------------------------

func _nest_damage() -> void:
	var sim := _make(_level("nest_1"))
	var n: SimBolso = sim.nest
	var hits: Array[int] = []
	var changed: Array[int] = [0]
	sim.nest_hit.connect(func(_p: Vector2, d: int) -> void: hits.append(d))
	sim.nest_changed.connect(func() -> void: changed[0] += 1)
	sim.active_team = 1
	SimCombat.trigger_explosion(sim, n.pos.x, n.pos.y, 45.0, 40.0, 100.0)
	_check(n.hp == 260 and hits == [40] and changed[0] == 1, "an enemy explosion on the nest does its full damage (hp %d, hits %s)" % [n.hp, str(hits)])
	sim.active_team = 0
	SimCombat.trigger_explosion(sim, n.pos.x, n.pos.y, 45.0, 40.0, 100.0)
	_check(n.hp == 240, "the squad's own explosion hurts it half as much (hp %d)" % n.hp)
	var rect: Rect2 = n.rect()
	SimCombat.trigger_explosion(sim, rect.end.x + 40.0, n.pos.y, 45.0, 40.0, 100.0)
	_check(n.hp < 240 and n.hp > 200, "a blast beside it hurts less, by the distance to its area (hp %d)" % n.hp)
	var before: int = n.hp
	SimCombat.trigger_explosion(sim, rect.end.x + 400.0, n.pos.y, 45.0, 40.0, 100.0)
	_check(n.hp == before, "a blast far away does nothing")
	n.hp = 20
	var res: Dictionary = {}
	var fell: Array[int] = [0]
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	sim.nest_destroyed.connect(func() -> void: fell[0] += 1)
	sim.active_team = 1
	SimCombat.trigger_explosion(sim, n.pos.x, n.pos.y, 45.0, 60.0, 100.0)
	_check(n.hp == 0 and n.destroyed and fell[0] == 1 and sim.turn_phase == CombatSim.Phase.GAME_OVER and res.get("winner", -1) == 1, "at 0 HP the nest falls: nest_destroyed, the match is lost")
	_check(res.get("reason", "") == "NEST_DESTROYED" and res.get("won", true) == false and int(res.get("nest_hp", -1)) == 0 and int(res.get("nest_max_hp", 0)) == 300 and int(res.get("stars", 1)) == 0, "the result says NEST_DESTROYED with the nest HP, no stars (%s)" % str(res.get("reason", "")))
	SimCombat.trigger_explosion(sim, n.pos.x, n.pos.y, 45.0, 60.0, 100.0)
	_check(fell[0] == 1, "a fallen nest cannot fall twice")


func _shelter_and_repair() -> void:
	var sim := _make(_level("nest_1"))
	var n: SimBolso = sim.nest
	var squad: Array[SimFighter] = _team(sim, 0)
	_in_nest(sim, squad[0])
	_stand(sim, squad[1], n.rect().end.x + 300.0)
	_check(SimBolso.in_nest(sim, squad[0]) and not SimBolso.in_nest(sim, squad[1]), "a caterpillar inside the nest area counts as sheltered, one outside does not")
	SimCombat.damage_fighter(sim, squad[0], 20)
	SimCombat.damage_fighter(sim, squad[1], 20)
	_check(squad[0].hp == 90 and squad[1].hp == 80, "sheltered: 20 damage becomes 10 (%d), outside it stays 20 (%d)" % [100 - squad[0].hp, 100 - squad[1].hp])
	SimCombat.damage_fighter(sim, squad[0], 1)
	_check(squad[0].hp == 89, "a sheltered hit is never less than 1")
	sim.active_team = 0
	sim.active_fighter = squad[0]
	_check(not sim.can_repair_nest() and not sim.repair_nest(), "no repair while the nest is whole")
	n.hp = 100
	_stand(sim, squad[0], n.rect().end.x + 200.0)
	_check(not sim.can_repair_nest() and not sim.repair_nest() and n.hp == 100, "no repair from far away")
	_in_nest(sim, squad[0], 30.0)
	_check(sim.can_repair_nest(), "next to the nest the caterpillar can repair")
	var hp_changes: Array[int] = [0]
	sim.nest_changed.connect(func() -> void: hp_changes[0] += 1)
	_check(sim.repair_nest() and n.hp == 140 and hp_changes[0] == 1, "REPAIR gives the nest +40 HP (%d)" % n.hp)
	_check(sim.turn_phase == CombatSim.Phase.RETREAT and not sim.can_repair_nest() and not sim.repair_nest() and n.hp == 140, "it uses the action: only a short walk is left, no second repair")
	n.hp = 280
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	sim.repair_nest()
	_check(n.hp == 300, "a repair never goes over the maximum (%d)" % n.hp)
	n.hp = 100
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	sim.active_team = 1
	_check(not SimBolso.can_repair(sim), "only the squad repairs, on its own turn")
	sim.active_team = 0
	sim.game_mode = "CPU_CPU"
	_check(not sim.can_repair_nest(), "the player's call is refused on a CPU turn")


# ---------------------------------------------------------------------------
# DEFEND_NEST
# ---------------------------------------------------------------------------

func _rules() -> void:
	var lv: LevelDef = _level("nest_1")
	var sim := _make(lv)
	_sturdy(sim)
	sim.nest.hp = 99999
	sim.nest.max_hp = 99999
	var res: Dictionary = {}
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	var rounds_seen: Array[int] = []
	var t: float = 0.0
	while sim.turn_phase != CombatSim.Phase.GAME_OVER and t < 900.0:
		if sim.turn_phase == CombatSim.Phase.TURN_PLAY and sim.active_team == 0:
			if rounds_seen.is_empty() or rounds_seen[rounds_seen.size() - 1] != sim.rounds_left:
				rounds_seen.append(sim.rounds_left)
			sim.end_turn()
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
	_check(sim.winner == 0 and res.get("won", false) == true and res.get("reason", "") == "SURVIVED", "nest_1: the nest standing after %d rounds wins (%s, reason %s)" % [lv.survive_rounds, str(res.get("won", false)), str(res.get("reason", ""))])
	_check(rounds_seen == [4, 3, 2, 1], "rounds_left counts 4, 3, 2, 1 (%s)" % str(rounds_seen))
	_check(int(res.get("survivors", 0)) == 4 and int(res.get("stars", 0)) == 3 and int(res.get("nest_hp", 0)) > 0 and int(res.get("rounds", 0)) == 4, "all four alive: 3 stars, nest HP in the stats")
	# the nest falls before the last round
	var sim2 := _make(lv)
	_sturdy(sim2)
	_run(sim2, 1.0)
	SimBolso.damage(sim2, 300, Vector2(sim2.nest.pos.x, sim2.nest.pos.y))
	_check(sim2.turn_phase == CombatSim.Phase.GAME_OVER and sim2.winner == 1, "the nest at 0 HP loses even with the whole squad alive")
	# the squad dies
	var sim3 := _make(lv)
	for f in _team(sim3, 0):
		SimCombat.damage_fighter(sim3, f, 9999)
	sim3.end_turn()
	_run(sim3, 6.0)
	_check(sim3.turn_phase == CombatSim.Phase.GAME_OVER and sim3.winner == 1, "losing the whole squad loses")
	# killing every enemy also ends it as a win
	var sim4 := _make(lv)
	for f in _team(sim4, 1):
		SimCombat.damage_fighter(sim4, f, 9999)
	sim4.end_turn()
	_run(sim4, 6.0)
	_check(sim4.turn_phase == CombatSim.Phase.GAME_OVER and sim4.winner == 0, "driving off every bird wins too")


# ---------------------------------------------------------------------------
# Cold
# ---------------------------------------------------------------------------

func _cold() -> void:
	var calm := _make(_level("nest_1"))
	_check(not calm.cold_active, "nest_1 has no cold")
	var f1: SimFighter = _team(calm, 0)[1]
	_stand(calm, f1, calm.nest.rect().end.x + 300.0)
	SimBolso.on_turn_start(calm, f1)
	_check(f1.hp == 100, "no cold, no damage")
	var sim := _make(_level("nest_2"))
	_check(sim.cold_active, "nest_2 is cold")
	var squad: Array[SimFighter] = _team(sim, 0)
	var ticks: Array[int] = []
	sim.cold_tick.connect(func(_f: SimFighter, d: int) -> void: ticks.append(d))
	var texts: Array[String] = []
	sim.float_text.connect(func(_p: Vector2, tx: String, _c: Color, _l: float) -> void: texts.append(tx))
	_in_nest(sim, squad[0])
	_stand(sim, squad[1], sim.nest.rect().end.x + 300.0)
	SimBolso.on_turn_start(sim, squad[0])
	_check(squad[0].hp == 100 and ticks.is_empty(), "inside the nest there is no cold")
	SimBolso.on_turn_start(sim, squad[1])
	_check(squad[1].hp == 95 and ticks == [5], "outside it a caterpillar loses 5 HP and cold_tick fires (hp %d)" % squad[1].hp)
	_check(texts.any(func(tx: String) -> bool: return tx.contains(sim.tx("FT_COLD"))), "the damage label is FT_COLD")
	var enemy: SimFighter = _team(sim, 1)[0]
	SimBolso.on_turn_start(sim, enemy)
	_check(enemy.hp == enemy.max_hp, "the birds do not feel it")
	# a real turn: the whole squad outside, the cold ticks at the start of each turn
	for f in squad:
		_stand(sim, f, sim.nest.rect().end.x + 300.0 + 70.0 * f.member_idx)
		f.hp = 100
	ticks.clear()
	_next_round(sim)
	_check(ticks.size() >= 1 and squad.any(func(f: SimFighter) -> bool: return f.hp < 100), "in a real turn the cold hits the caterpillar that starts its turn outside")
	var warm := _make(_level("nest_2"), -1, ["WARM_SILK"])
	var w: SimFighter = _team(warm, 0)[1]
	_stand(warm, w, warm.nest.rect().end.x + 300.0)
	SimBolso.on_turn_start(warm, w)
	_check(not warm.cold_active and w.hp == 100, "WARM_SILK: no cold outside the nest")
	var one := _make(_level("nest_2"), -1, ["TOUGH_SKIN"])
	_check(one.cold_active, "another upgrade does not warm it")


# ---------------------------------------------------------------------------
# The pole
# ---------------------------------------------------------------------------

func _pole() -> void:
	var calm := _make(_level("nest_2"))
	_sturdy(calm)
	calm.nest.hp = 99999
	_next_round(calm)
	_next_round(calm)
	_check(calm.round_number >= 2 and calm.pole_state == "" and calm.pole_band.size == Vector2.ZERO, "a level without a pole never marks a band")
	var sim := _make(_level("nest_4"))
	_sturdy(sim)
	sim.nest.hp = 99999
	sim.nest.max_hp = 99999
	var warns: Array[Rect2] = []
	var sweeps: Array[Rect2] = []
	sim.pole_warn.connect(func(b: Rect2) -> void: warns.append(b))
	sim.pole_sweep.connect(func(b: Rect2) -> void: sweeps.append(b))
	_check(sim.round_number == 1 and sim.pole_state == "", "round 1: no pole")
	_next_round(sim)
	_check(sim.round_number == 2 and sim.pole_state == "WARN" and warns.size() == 1 and sweeps.is_empty(), "round 2: the band is marked at the start of the squad's turn (warn, no hit yet)")
	var band: Rect2 = sim.pole_band
	_check(is_equal_approx(band.size.x, SimBolso.POLE_WIDTH) and band == warns[0] and band.size.y > 400.0, "the band is %d px wide and full height" % int(band.size.x))
	var squad: Array[SimFighter] = _team(sim, 0)
	var out_x: float = band.end.x + 320.0 if band.end.x + 320.0 < 3000.0 else band.position.x - 320.0
	_stand(sim, squad[1], band.position.x + band.size.x * 0.5)
	_stand(sim, squad[2], out_x)
	var in_band_sheltered: bool = SimBolso.in_nest(sim, squad[1])
	var out_sheltered: bool = SimBolso.in_nest(sim, squad[2])
	for f in squad:
		f.hp = 1000
	sim.nest.hp = 5000
	var nest_before: int = sim.nest.hp
	var overlaps_nest: bool = sim.nest.rect().position.x <= band.end.x and sim.nest.rect().end.x >= band.position.x
	sim.end_turn()
	var snap: Array[int] = _hps(sim)
	var hit_frame: bool = false
	var t: float = 0.0
	while t < 12.0 and not hit_frame and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		snap = _hps(sim)
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
		hit_frame = sim.pole_state == ""
	var after: Array[int] = _hps(sim)
	_check(hit_frame and sweeps.size() == 1 and sweeps[0] == band, "the band comes down at the start of the next enemy turn (pole_sweep)")
	var want_in: int = 11 if in_band_sheltered else 22
	_check(snap[1] - after[1] == want_in, "a caterpillar in the band takes %d (%d)" % [want_in, snap[1] - after[1]])
	_check(snap[2] - after[2] == 0 or out_sheltered, "one outside the band takes nothing (%d)" % (snap[2] - after[2]))
	_check(not overlaps_nest or sim.nest.hp <= nest_before - SimBolso.POLE_NEST_DAMAGE, "a nest touching the band takes %d (%d)" % [SimBolso.POLE_NEST_DAMAGE, nest_before - sim.nest.hp])
	_check(sim.pole_band.size == Vector2.ZERO, "the band is cleared once swept")
	# the nest inside a band
	_until_player(sim)
	_next_round(sim)
	_check(sim.round_number == 4 and warns.size() == 2, "the pole comes every 2 rounds (round 4)")
	sim.pole_band = Rect2(sim.nest.pos.x - 60.0, 0.0, 120.0, sim.terrain.water_y)
	sim.nest.hp = 5000
	sim.end_turn()
	_run(sim, 12.0)
	_check(sim.nest.hp <= 5000 - SimBolso.POLE_NEST_DAMAGE and sweeps.size() == 2, "a band over the nest damages it (%d)" % (5000 - sim.nest.hp))


# ---------------------------------------------------------------------------
# Birds
# ---------------------------------------------------------------------------

func _birds() -> void:
	var sim := _make(_level("nest_1"))
	_sturdy(sim)
	var n: SimBolso = sim.nest
	var squad: Array[SimFighter] = _team(sim, 0)
	var tits: Array[SimFighter] = _kind(sim, "GREAT_TIT")
	# a bird beside the nest, the squad far away: it goes for the nest
	var far_x: float = n.rect().end.x + 700.0 if n.rect().end.x + 700.0 < 2900.0 else n.rect().position.x - 700.0
	for f in squad:
		_stand(sim, f, far_x + 40.0 * f.member_idx)
	var bird: SimFighter = tits[0]
	bird.x = n.pos.x + 190.0
	bird.y = n.rect().position.y - 100.0
	bird.perch = Vector2(bird.x, bird.y)
	bird.jump_start_y = bird.y
	bird.peak_air_y = bird.y
	var plan: Dictionary = {}
	var pick: SimFighter = SimBolso.flyer_target(sim, bird, plan, squad[0])
	_check(pick == n.target and pick.id == SimBolso.TARGET_ID, "a bird next to the nest, the caterpillars far: the nest is the target")
	var plan2: Dictionary = {}
	var near_bird: SimFighter = tits[1]
	_stand(sim, squad[0], near_bird.x - 60.0)
	near_bird.y = squad[0].y - 80.0
	_check(SimBolso.flyer_target(sim, near_bird, plan2, squad[0]) == squad[0], "a bird right over a caterpillar, the nest far: the caterpillar is the target")
	var pecks: Array[int] = []
	sim.nest_hit.connect(func(_p: Vector2, d: int) -> void: pecks.append(d))
	var before: int = n.hp
	var t: float = 0.0
	sim.end_turn()
	while t < 40.0 and pecks.is_empty() and sim.turn_phase != CombatSim.Phase.GAME_OVER:
		sim.step(DT)
		sim.advance_real(DT)
		t += DT
	_check(not pecks.is_empty() and n.hp < before and pecks[0] == 16, "the great tit pecks the nest (PICOTADA_FORTA, 16): nest_hit %s, hp %d -> %d" % [str(pecks), before, n.hp])
	_check(squad.all(func(f: SimFighter) -> bool: return f.hp == 9999), "no caterpillar was touched")
	# every caterpillar hidden: the nest is the only thing left to peck
	var lone := _make(_level("nest_1"))
	for f in _team(lone, 0):
		f.hidden = true
	var target: SimFighter = SimBolso.flyer_target(lone, _kind(lone, "GREAT_TIT")[0], {}, null)
	_check(target == lone.nest.target, "with nobody in sight the birds still go for the nest")
	# after the nest fell they would go back to the caterpillars (the match is over anyway)
	var gone := _make(_level("nest_1"))
	gone.nest.destroyed = true
	_check(SimBolso.flyer_target(gone, _kind(gone, "GREAT_TIT")[0], {}, _team(gone, 0)[0]) == _team(gone, 0)[0], "no nest, no nest target")
	var ant_free := _make(_level("cuca_3"), -1)
	_check(ant_free.nest == null and not ant_free.cold_active and ant_free.pole_state == "", "levels without a nest have no nest state")


# ---------------------------------------------------------------------------
# Upgrades
# ---------------------------------------------------------------------------

func _upgrades() -> void:
	var lv: LevelDef = _level("nest_2")
	var plain := _make(lv)
	var all_ids: Array[String] = []
	for u in SimUpgrades.all():
		all_ids.append(u.id)
	var full := _make(lv, -1, all_ids)
	_check(plain.upgrades.is_empty() and plain.damage_mult[0] == 1.0 and plain.silk_webs_per_turn == 1, "no upgrades: nothing changes")
	var ok: bool = full.upgrades.size() == 12
	for f in _team(full, 0):
		ok = ok and f.max_hp == 132 and f.hp == 132
	_check(ok, "MAX_HP_PCT: tiers I and II give the squad 132 HP")
	for f in _team(full, 1):
		ok = ok and f.max_hp == f.unit.max_hp
	_check(ok, "the enemy is not stronger")
	_check(is_equal_approx(full.damage_mult[0], 1.3225) and full.damage_mult[1] == 1.0, "DAMAGE_PCT: tiers I and II, team 0 deals 32 % more")
	_check(full.nest.max_hp == 400 and full.nest.hp == 400, "NEST_HP: the nest has 400 HP")
	_check(not full.cold_active and plain.cold_active, "WARM_SILK: no cold (the plain level has it)")
	_check(full.silk_webs_per_turn == 2 and plain.silk_webs_per_turn == 1, "EXTRA_SILK_WEB: two webs per turn")
	_check(full.ammo_f(0, "PONT_PEDRA") == plain.ammo_f(0, "PONT_PEDRA") + 1.0 and full.ammo_f(0, "URTICARIA") == INF and full.ammo_f(0, "BAT") == INF, "START_AMMO: +1 for limited weapons (PONT_PEDRA %d -> %d), unlimited ones stay unlimited" % [int(plain.ammo_f(0, "PONT_PEDRA")), int(full.ammo_f(0, "PONT_PEDRA"))])
	# two webs
	var webs: int = full.silk_webs.size()
	full.spin_silk_web()
	full.turn_phase = CombatSim.Phase.TURN_PLAY
	full.spin_silk_web()
	full.turn_phase = CombatSim.Phase.TURN_PLAY
	full.spin_silk_web()
	_check(full.silk_webs.size() == webs + 2, "two webs spin in a turn, not three (%d)" % (full.silk_webs.size() - webs))
	plain.spin_silk_web()
	plain.turn_phase = CombatSim.Phase.TURN_PLAY
	plain.spin_silk_web()
	_check(plain.silk_webs.size() == 1, "without the upgrade only one")
	_check(full.silk_webs_spun == 2 and full.silk_web_used_this_turn, "silk_web_used_this_turn is set once they are all spun")
	# damage numbers
	var shot_plain: float = _shot_damage(plain)
	var shot_full: float = _shot_damage(full)
	_check(shot_plain > 0.0 and is_equal_approx(shot_full, roundf(shot_plain * 1.3225)), "URTICARIA's blast does %.0f, with DAMAGE_PCT %.0f" % [shot_plain, shot_full])
	# unknown ids and duplicates
	var odd := _make(lv, -1, ["NOPE", "TOUGH_SKIN", "TOUGH_SKIN"])
	_check(odd.upgrades == ["TOUGH_SKIN"] and _team(odd, 0)[0].max_hp == 115, "unknown ids are ignored, an upgrade counts once")
	# story only
	var classic := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 12
	cfg.upgrades = ["TOUGH_SKIN", "SHARP_HAIRS"] as Array[String]
	classic.setup(cfg)
	var same: bool = classic.upgrades.is_empty() and classic.damage_mult == [1.0, 1.0] and classic.nest == null
	for f in classic.fighters:
		same = same and f.max_hp == 100
	_check(same, "classic matches ignore upgrades")
	var other_story := _make(_level("cuca_3"), -1, ["TOUGH_SKIN"])
	_check(_team(other_story, 0)[0].max_hp == roundi(85 * 1.15), "any story level (not only the nest) gets them: L4 85 -> %d" % _team(other_story, 0)[0].max_hp)


## Damage of the projectile of the active fighter's URTICARIA shot.
func _shot_damage(sim: CombatSim) -> float:
	var wpn: WeaponDef = sim.weapons[sim.weapon_index("URTICARIA")]
	sim.projectiles.clear()
	sim.turn_phase = CombatSim.Phase.TURN_PLAY
	SimCombat.fire_weapon(sim, wpn, -0.6, 0.5, null)
	return sim.projectiles[0].max_dmg if not sim.projectiles.is_empty() else -1.0


# ---------------------------------------------------------------------------
# Silk, buying, the save
# ---------------------------------------------------------------------------

## The shop must be affordable but not trivial: 3 stars everywhere buys everything, about 2 stars does not, and the first prices fit the
## silk of the first stage (docs/story_mode.md, economy).
## The silk economy against the real level list and shop (docs/story_mode.md section 9): a 3-star player affords the whole shop around
## level 26-28, a 2-star player around 34-35 (two or three levels before the last), and a 1-star player has the essentials by the middle.
func _economy() -> void:
	var levels: Array[LevelDef] = StoryProgress.levels()
	var bosses: Array[String] = []
	for level in levels:
		if StoryProgress.is_boss_level(level.id):
			bosses.append(level.id)
	_check(levels.size() == 37 and bosses.size() == 7, "37 levels, 7 of them bosses (%d, %d)" % [levels.size(), bosses.size()])
	_check(StoryProgress.level_silk("egg_1", 0) == 0 and StoryProgress.level_silk("egg_1", 1) == 10 and StoryProgress.level_silk("egg_1", 3) == 20 and StoryProgress.level_silk("egg_boss", 2) == 30, "a level is worth win 5 + 5 per star, + 15 on a boss (0 when not won)")
	var total: int = StoryProgress.shop_total()
	var curves: Dictionary = {}
	var full_at: Dictionary = {}
	for n in [1, 2, 3]:
		curves[n] = StoryProgress.silk_curve(n)
		full_at[n] = _first_level_reaching(curves[n], total)
	print("INFO  economy: shop %d; whole shop affordable at level %d (3 stars), %d (2 stars); 1 star ends with %d" % [total, full_at[3], full_at[2], curves[1][-1]])
	_check(StoryProgress.silk_max() == curves[3][-1] and total < StoryProgress.silk_max(), "the whole shop (%d) fits in the maximum silk (%d)" % [total, StoryProgress.silk_max()])
	_check(full_at[3] >= 26 and full_at[3] <= 28, "3 stars everywhere: the whole shop is affordable at level 26-28 (%d)" % full_at[3])
	_check(full_at[2] >= 34 and full_at[2] <= 35, "2 stars everywhere: the whole shop is affordable at level 34-35, before the final levels (%d)" % full_at[2])
	_check(curves[1][-1] < total, "1 star everywhere: not the whole shop (%d < %d), the player chooses" % [curves[1][-1], total])
	# the essentials for a 1-star player: a heart, the first combat upgrades and the nest ones before the nest stage
	var nest_first: int = _first_of_stage(levels, "NEST")
	var essentials: int = 0
	for id in ["EXTRA_HEART", "TOUGH_SKIN", "SHARP_HAIRS", "FULL_POUCH", "THICK_WALLS", "WARM_SILK"]:
		essentials += StoryProgress.upgrade(id).cost
	_check(nest_first >= 18 and curves[1][nest_first - 2] >= essentials, "1 star: the essentials (%d) are paid by mid-campaign, before the nest stage (%d silk after level %d)" % [essentials, curves[1][nest_first - 2], nest_first - 1])
	var tier_one: int = 0
	for u in StoryProgress.upgrades():
		if u.requires.is_empty():
			tier_one += u.cost
	var pupa_first: int = _first_of_stage(levels, "PUPA")
	_check(curves[1][pupa_first - 2] >= tier_one, "1 star: every tier I upgrade (%d) before the pupa stage (%d)" % [tier_one, curves[1][pupa_first - 2]])
	# early upgrades when they first matter: the heart inside the egg stage, the first combat upgrade before Pelussa
	var egg_boss: int = _first_of_stage(levels, "EGG") + 4
	_check(levels[egg_boss - 1].id == "egg_boss" and curves[1][egg_boss - 2] >= StoryProgress.upgrade("EXTRA_HEART").cost, "1 star: the first heart is affordable before the egg boss")
	var larva_first: int = _first_of_stage(levels, "LARVA_EARLY")
	_check(curves[1][larva_first - 2] >= StoryProgress.upgrade("EXTRA_HEART").cost + StoryProgress.upgrade("TOUGH_SKIN").cost, "1 star: heart and thick skin before the first Pelussa level")
	# 2 stars, buying in the order of docs/story_mode.md section 9: the nest upgrades before the nest stage, the tier II combat ones and the
	# pupa's jaws before the pupa stage (the second heart and the moth wings come during the last two stages)
	var order: Dictionary = {
		"NEST": ["EXTRA_HEART", "TOUGH_SKIN", "SHARP_HAIRS", "FULL_POUCH", "DOUBLE_WEB", "THICK_WALLS", "WARM_SILK"],
		"PUPA": ["TOUGH_SKIN_2", "SHARP_HAIRS_2", "FAST_DIG"],
	}
	var paid: int = 0
	for stage: String in order:
		for id: String in order[stage]:
			paid += StoryProgress.upgrade(id).cost
		var first: int = _first_of_stage(levels, stage)
		_check(curves[2][first - 2] >= paid, "2 stars: the shop in buying order up to %s (%d) is paid before it starts (%d)" % [stage, paid, curves[2][first - 2]])


## Level number (1-based) after which `curve` first reaches `amount` (0 = never).
func _first_level_reaching(curve: Array[int], amount: int) -> int:
	for i in curve.size():
		if curve[i] >= amount:
			return i + 1
	return 0


## Level number (1-based) of the first level of `stage`.
func _first_of_stage(levels: Array[LevelDef], stage: String) -> int:
	for i in levels.size():
		if levels[i].stage == stage:
			return i + 1
	return 0


func _silk_and_save() -> void:
	var saved_path: String = StoryProgress.save_path
	StoryProgress.save_path = "user://test_nest_story.cfg"
	StoryProgress.reset_progress()
	_check(StoryProgress.silk() == 0 and StoryProgress.owned_upgrades().is_empty() and not StoryProgress.buy("TOUGH_SKIN"), "a new save: 0 silk, nothing owned, nothing can be bought")
	var gained: int = StoryProgress.record_result({"level_id": "egg_1", "won": true, "stars": 1})
	_check(gained == 10 and StoryProgress.silk() == 10, "winning a level with 1 star earns 10 silk (win 5 + 1 star 5)")
	gained = StoryProgress.record_result({"level_id": "egg_1", "won": true, "stars": 1})
	_check(gained == 0 and StoryProgress.silk() == 10, "the same star again earns nothing")
	gained = StoryProgress.record_result({"level_id": "egg_1", "won": true, "stars": 3})
	_check(gained == 10 and StoryProgress.silk() == 20, "going from 1 to 3 stars earns the 2 new ones (+10), not the win again")
	gained = StoryProgress.record_result({"level_id": "egg_2", "won": false, "stars": 2})
	_check(gained == 0 and StoryProgress.silk() == 20, "a lost level earns nothing")
	StoryProgress.record_result({"level_id": "egg_2", "won": true, "stars": 2})
	StoryProgress.record_result({"level_id": "egg_3", "won": true, "stars": 3})
	_check(StoryProgress.silk() == 55 and StoryProgress.silk_earned() == 55, "silk = the worth of every best result (20 + 15 + 20 = 55)")
	var cost: int = StoryProgress.upgrade("TOUGH_SKIN").cost
	_check(not StoryProgress.buy("NOPE"), "an unknown upgrade cannot be bought")
	_check(StoryProgress.buy("TOUGH_SKIN") and StoryProgress.silk() == 55 - cost and StoryProgress.owned_upgrades() == ["TOUGH_SKIN"] and StoryProgress.owns("TOUGH_SKIN"), "buying takes its price (%d) and keeps the upgrade" % cost)
	_check(not StoryProgress.buy("TOUGH_SKIN") and StoryProgress.silk() == 55 - cost, "it cannot be bought twice")
	var dear: String = "SHARP_HAIRS_2"
	_check(StoryProgress.upgrade(dear).cost > StoryProgress.silk() and not StoryProgress.buy(dear) and not StoryProgress.owns(dear), "too expensive: refused, nothing taken")
	# tier II needs tier I, even with the silk
	StoryProgress.record_result({"level_id": "cuca_1", "won": true, "stars": 3})
	StoryProgress.record_result({"level_id": "cuca_2", "won": true, "stars": 3})
	for id in ["cuca_3", "cuca_4", "cuca_5", "cuca_6"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 3})
	_check(StoryProgress.silk() >= StoryProgress.upgrade("SHARP_HAIRS_2").cost and not StoryProgress.buy("SHARP_HAIRS_2"), "tier II is refused while tier I is not owned")
	_check(StoryProgress.buy("SHARP_HAIRS") and StoryProgress.buy("TOUGH_SKIN_2") and StoryProgress.owns("TOUGH_SKIN_2"), "with tier I owned, tier II can be bought")
	# round trip
	StoryProgress.load_progress()
	_check(StoryProgress.owned_upgrades() == ["TOUGH_SKIN", "SHARP_HAIRS", "TOUGH_SKIN_2"] and StoryProgress.stars("egg_1") == 3, "save round-trip: stars and upgrades come back")
	var left: int = StoryProgress.silk_earned() - StoryProgress.upgrade("TOUGH_SKIN").cost - StoryProgress.upgrade("SHARP_HAIRS").cost - StoryProgress.upgrade("TOUGH_SKIN_2").cost
	_check(StoryProgress.silk() == left, "silk is earned minus the prices (%d)" % left)
	var earned: int = StoryProgress.silk_earned()
	StoryProgress.refund_all()
	_check(StoryProgress.owned_upgrades().is_empty() and StoryProgress.silk() == earned, "refund_all gives every upgrade back (silk %d)" % earned)
	StoryProgress.load_progress()
	_check(StoryProgress.owned_upgrades().is_empty() and StoryProgress.silk() == earned, "and the refund is saved")
	# an old-format save: only [stars]
	var old := ConfigFile.new()
	old.set_value("stars", "egg_1", 2)
	old.set_value("stars", "larva_1", 3)
	old.save(StoryProgress.save_path)
	StoryProgress.load_progress()
	_check(StoryProgress.stars("egg_1") == 2 and StoryProgress.stars("larva_1") == 3 and StoryProgress.owned_upgrades().is_empty() and StoryProgress.silk() == 35, "an old save (no hub section) loads: its stars give silk (15 + 20 = 35), no upgrades")
	_check(StoryProgress.buy("TOUGH_SKIN") and StoryProgress.silk() == 35 - StoryProgress.upgrade("TOUGH_SKIN").cost, "and it can be spent")
	# a save naming an upgrade that no longer exists
	var odd := ConfigFile.new()
	odd.set_value("stars", "egg_1", 1)
	odd.set_value("hub", "upgrades", ["GONE", "WARM_SILK", "WARM_SILK", "SHARP_HAIRS_2"])
	odd.save(StoryProgress.save_path)
	StoryProgress.load_progress()
	_check(StoryProgress.owned_upgrades() == ["WARM_SILK"], "unknown, repeated and tier II-without-tier I ids in a save are dropped (refunded)")
	# into the match
	StoryProgress.reset_progress()
	for id in ["egg_1", "egg_2", "egg_3"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 3})
	StoryProgress.buy("SHARP_HAIRS")
	GameState.story_level = _level("nest_1")
	var cfg: MatchConfig = GameState.make_match_config()
	_check(cfg.upgrades == ["SHARP_HAIRS"] and cfg.level.id == "nest_1", "GameState puts the owned upgrades into MatchConfig.upgrades")
	var sim := CombatSim.new()
	sim.setup(cfg)
	_check(is_equal_approx(sim.damage_mult[0], 1.15), "and the sim applies them in the story match")
	GameState.story_level = null
	var classic: MatchConfig = GameState.make_match_config()
	_check(classic.upgrades.is_empty(), "a classic match config carries none")
	StoryProgress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StoryProgress.save_path))
	StoryProgress.save_path = saved_path
	StoryProgress.load_progress()


# ---------------------------------------------------------------------------
# The forestry brigade boss
# ---------------------------------------------------------------------------

func _boss_sim(cold: bool = false) -> CombatSim:
	var sim := _make(_level("nest_boss"))
	sim.cold_active = cold
	_sturdy(sim)
	sim.nest.hp = 5000
	sim.nest.max_hp = 5000
	return sim


func _boss_data() -> void:
	var def: BossDef = load("res://data/bosses/brigade_boss.tres")
	_check(def.id == "BRIGADE_BOSS" and def.max_hp == 300 and not def.flies and def.phases == [0.5] and def.vulnerable_states == ["WINDED"] and is_equal_approx(def.armored_mult, 0.5), "brigade boss: 300 HP, walks, phase at 50 %, vulnerable only WINDED, x0.5 armour")
	var ids: Array[String] = []
	for a in def.attacks:
		ids.append("%s/%d" % [a["id"], int(a["phase"])])
		_check(BossAttacks.handler(str(a["kind"])) != null, "attack %s has a handler for kind %s" % [a["id"], a["kind"]])
	_check(ids == ["SUMMON_WORKERS/1", "CATCH_BREATH/-1", "POLE_SWEEP/-1", "CARTRIDGE/-1", "SUMMON_WORKERS_2/2"], "attacks: summon, catch breath, pole sweep, cartridge, second summon (%s)" % str(ids))
	_check(BossAttacks.handler("LINE") is AttackLine and BossAttacks.handler("REST") is AttackRest, "LINE and REST are registered in the boss registry")
	_check(def.attacks[3]["kind"] == "AREA" and def.attacks[3]["at"] == "NEST" and def.attacks[2]["kind"] == "LINE" and int(def.attacks[1]["after"]) == 2, "CARTRIDGE is an AREA on the nest, POLE_SWEEP a LINE, CATCH_BREATH comes after 2 attacks")
	_check(is_equal_approx(def.speed_of(1), 150.0) and def.speed_of(2) > def.speed_of(1), "phase 2 is faster (%.0f -> %.0f px/s)" % [def.speed_of(1), def.speed_of(2)])
	var sim := _boss_sim(true)
	var b: SimFighter = sim.boss
	_check(b != null and b.kind == "BRIGADE_BOSS" and b.hp == 300 and not b.flying and sim.boss_phase == 1 and sim.nest != null and sim.cold_active, "nest_boss: the Capatàs on the ground, the nest and the cold")
	_check(sim.level.win_rule == "BOSS" and sim.rounds_left == -1, "nest_boss is a BOSS level (no round count)")


func _boss_line() -> void:
	var sim := _boss_sim()
	var b: SimFighter = sim.boss
	var n: SimBolso = sim.nest
	var squad: Array[SimFighter] = _team(sim, 0)
	# the boss stands beside the nest and aims at it
	_stand(sim, b, n.pos.x + 360.0)
	for f in squad:
		f.hidden = true
	_stand(sim, squad[0], n.rect().position.x - 120.0)
	_force(sim, "POLE_SWEEP")
	sim.boss_memory["cooldowns"]["CATCH_BREATH"] = 99
	var warns: Array[Rect2] = []
	sim.pole_sweep.connect(func(r: Rect2) -> void: warns.append(r))
	_check(_boss_turn(sim, 120.0, true), "the boss plays its turn")
	var it: Dictionary = sim.boss_intent
	_check(it.get("attack_id", "") == "POLE_SWEEP" and it.get("kind", "") == "LINE" and it.has("rect") and sim.boss_state == "INTENT", "it announces POLE_SWEEP as a LINE with a band")
	var band: Rect2 = it["rect"]
	_check(is_equal_approx(band.size.x, 150.0) and is_equal_approx(float(it["radius"]), 75.0) and band.position.y <= 0.0 and band.size.y > 400.0, "the band is 150 px wide and full height")
	var in_band: float = band.position.x + band.size.x * 0.5
	_check(absf(in_band - n.pos.x) <= 80.0, "it chose the nest (the only visible target): band centre %.0f, nest %.0f, boss %.0f" % [in_band, n.pos.x, b.x])
	_check(warns.is_empty(), "nothing has hit yet: the band is only a telegraph")
	var hp_before: int = n.hp
	var inside: SimFighter = squad[1]
	_stand(sim, inside, in_band + 20.0)
	var outside: SimFighter = squad[2]
	_stand(sim, outside, band.end.x + 260.0)
	inside.hp = 500
	outside.hp = 500
	var in_nest: bool = SimBolso.in_nest(sim, inside)
	var out_nest: bool = SimBolso.in_nest(sim, outside)
	var start_x: float = b.x
	_check(_boss_turn(sim, 120.0, true), "the next boss turn executes it")
	_check(warns.size() == 1 and warns[0] == band, "pole_sweep fired with the telegraphed band")
	_check(absf(b.x - start_x) < 400.0 and b.alive, "the boss walked up to its standoff")
	_check(hp_before - n.hp == 45, "the nest in the band took 45 (%d)" % (hp_before - n.hp))
	_check(500 - inside.hp == (12 if in_nest else 24), "a caterpillar in the band took %d (%d)" % [12 if in_nest else 24, 500 - inside.hp])
	_check(500 - outside.hp == 0 or out_nest, "one outside it took nothing")
	# dodging: the band announced on a caterpillar, which walks out of it
	var sim2 := _boss_sim()
	_force(sim2, "POLE_SWEEP")
	sim2.boss_memory["cooldowns"]["CATCH_BREATH"] = 99
	var t2: Array[SimFighter] = _team(sim2, 0)
	for f in t2:
		f.hidden = true
	_stand(sim2, sim2.boss, sim2.nest.pos.x + 500.0)
	_stand(sim2, t2[0], sim2.nest.rect().end.x + 330.0)
	t2[0].hp = 500
	_boss_turn(sim2, 120.0, true)
	var hp0: int = t2[0].hp
	var band2: Rect2 = sim2.boss_intent["rect"]
	_stand(sim2, t2[0], band2.end.x + 300.0)
	_boss_turn(sim2, 120.0, true)
	_check(t2[0].hp == hp0, "walking out of the band dodges the sweep")


func _boss_winded_and_phase_two() -> void:
	var sim := _boss_sim()
	var seen: Array[String] = []
	sim.boss_intent_changed.connect(func() -> void:
		if not sim.boss_intent.is_empty():
			seen.append(str(sim.boss_intent["attack_id"])))
	for i in 5:
		_boss_turn(sim)
	_check(seen.size() >= 4 and seen[0] == "SUMMON_WORKERS" and seen[2] == "CATCH_BREATH" and (seen[1] == "POLE_SWEEP" or seen[1] == "CARTRIDGE"), "after two attacks it announces CATCH_BREATH (%s)" % str(seen.slice(0, 5)))
	_check(not seen.slice(3).has("CATCH_BREATH") or seen.slice(3).find("CATCH_BREATH") >= 2, "and then two more attacks before the next rest (%s)" % str(seen))
	var workers: Array[SimFighter] = _kind(sim, "FORESTRY_WORKER")
	_check(workers.size() == 2 and workers[0].team == 1 and not workers[0].flying, "the summon brought 2 forestry workers")
	# the WINDED window
	var sim2 := _boss_sim()
	var b2: SimFighter = sim2.boss
	sim2.boss_memory["streak"] = 2
	_force(sim2, "CATCH_BREATH")
	_boss_turn(sim2)
	_check(sim2.boss_intent.get("attack_id", "") == "CATCH_BREATH" and sim2.boss_memory["streak"] == 0, "CATCH_BREATH announced, the streak starts over")
	var texts: Array[String] = []
	sim2.float_text.connect(func(_p: Vector2, tx: String, _c: Color, _l: float) -> void: texts.append(tx))
	_force(sim2, "CATCH_BREATH")
	sim2.boss_memory["cooldowns"]["CATCH_BREATH"] = 0
	var hp0: int = b2.hp
	b2.hp = 300
	SimCombat.damage_fighter(sim2, b2, 20)
	_check(300 - b2.hp == 10, "armoured: 20 damage becomes 10")
	b2.hp = 300
	_boss_turn(sim2)
	_check(sim2.boss_state == "WINDED" and SimBoss.is_vulnerable(sim2) and hp0 > 0, "it runs out of breath: state WINDED, vulnerable")
	_check(texts.any(func(tx: String) -> bool: return tx.contains(sim2.tx("FT_BOSS_WINDED"))), "with its own float text")
	SimCombat.damage_fighter(sim2, b2, 20)
	_check(b2.hp == 280, "WINDED: full damage (20)")
	for f in _team(sim2, 0):
		f.hidden = false
	_boss_turn(sim2)
	_check(sim2.boss_state != "WINDED", "the rest lasts one turn")
	# phase 2
	var sim3 := _boss_sim()
	var b3: SimFighter = sim3.boss
	var phases: Array[int] = []
	sim3.boss_phase_changed.connect(func(p: int) -> void: phases.append(p))
	_boss_turn(sim3)
	_boss_turn(sim3)
	_check(_kind(sim3, "FORESTRY_WORKER").size() == 2, "phase 1: the first summon, 2 workers")
	b3.hp = 151
	SimCombat.damage_fighter(sim3, b3, 3)
	_check(sim3.boss_phase == 2 and phases == [2] and b3.hp <= 150, "at 50 %% HP: phase 2 (hp %d)" % b3.hp)
	_check(sim3.boss_def.speed_of(sim3.boss_phase) > 150.0, "faster now (%.0f px/s)" % sim3.boss_def.speed_of(sim3.boss_phase))
	for i in 3:
		_boss_turn(sim3)
	_check(sim3.boss_memory["used"].has("SUMMON_WORKERS_2"), "phase 2: the second summon was announced")
	_check(_kind(sim3, "FORESTRY_WORKER").size() >= 4, "and now there are %d workers" % _kind(sim3, "FORESTRY_WORKER").size())


func _boss_cartridge_and_end() -> void:
	var sim := _boss_sim()
	var n: SimBolso = sim.nest
	var b: SimFighter = sim.boss
	for f in _team(sim, 0):
		f.hidden = true
	_force(sim, "CARTRIDGE")
	_stand(sim, b, n.pos.x + 520.0)
	_boss_turn(sim)
	var it: Dictionary = sim.boss_intent
	_check(it.get("attack_id", "") == "CARTRIDGE" and it.get("kind", "") == "AREA" and Vector2(it["pos"]).distance_to(n.pos) < 1.0, "CARTRIDGE is announced on the nest")
	var before: int = n.hp
	_boss_turn(sim)
	_check(before - n.hp >= 30 and before - n.hp <= 40, "the cartridge hurts the nest (%d)" % (before - n.hp))
	# the nest falls: the boss level is lost
	var lost := _boss_sim()
	lost.nest.hp = 10
	var res: Dictionary = {}
	lost.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	SimBolso.damage(lost, 10, lost.nest.pos)
	_check(res.get("winner", -1) == 1 and res.get("reason", "") == "NEST_DESTROYED", "the nest must survive the boss level too")
	# the boss is beaten: won
	var won := _boss_sim()
	var wres: Dictionary = {}
	won.game_over.connect(func(w: int, s: Dictionary) -> void:
		wres.merge(s, true)
		wres["winner"] = w)
	won.boss.hp = 5
	SimBoss._raw_hit = true
	SimCombat.damage_fighter(won, won.boss, 50)
	SimBoss._raw_hit = false
	_run(won, 3.0)
	won.end_turn()
	_run(won, 6.0)
	_check(wres.get("winner", -1) == 0 and wres.get("reason", "") == "BOSS_DEFEATED" and int(wres.get("nest_hp", 0)) > 0, "beating the boss with the nest standing wins")


func _classic_untouched() -> void:
	var sim := CombatSim.new()
	var cfg := MatchConfig.new()
	cfg.seed = 12
	sim.setup(cfg)
	_check(sim.nest == null and not sim.cold_active and sim.pole_state == "" and sim.weapons.size() == 16 and sim.weapon_index("PERXADA") == -1 and not sim.can_repair_nest(), "classic matches have no nest, cold or pole, and do not see PERXADA")
	_check(BossAttacks.handler("MELEE_TARGET") != null and BossAttacks.handler("NOPE") == null, "the old attack kinds are still registered")


# ---------------------------------------------------------------------------
# CPU runs
# ---------------------------------------------------------------------------

## Seeds with a playable setup (found with CUCS_NEST_SCAN; each one is checked again with _seed_ok before it is used). The first is the level seed.
const RUN_SEED_LIST: Dictionary = {
	"nest_1": [6003, 6805, 6822, 6833, 6408],
	"nest_2": [6003, 6004, 6005, 6013, 6009],
	"nest_3": [6003, 6013, 6017, 6019, 6033],
	"nest_4": [6003, 6013, 6017, 6019, 6033],
	"nest_boss": [6004, 6808, 6812, 6814, 6400],
}


func _good_seeds(level: LevelDef) -> Array[int]:
	var out: Array[int] = []
	for sd in RUN_SEED_LIST[level.id]:
		if _seed_ok(level, sd):
			out.append(sd)
	return out


func _cpu_match(level: LevelDef, seed_v: int) -> Dictionary:
	var sim := _make(level, seed_v)
	sim.game_mode = "CPU_CPU"
	var res: Dictionary = {}
	sim.game_over.connect(func(w: int, s: Dictionary) -> void:
		res.merge(s, true)
		res["winner"] = w)
	var stats: Dictionary = {"repairs": 0, "pecks": 0, "cold": 0, "poles": 0}
	sim.nest_changed.connect(func() -> void: stats["repairs"] = int(stats["repairs"]) + (1 if sim.active_team == 0 and sim.turn_phase == CombatSim.Phase.RETREAT else 0))
	sim.nest_hit.connect(func(_p: Vector2, _d: int) -> void: stats["pecks"] = int(stats["pecks"]) + 1)
	sim.cold_tick.connect(func(_f: SimFighter, _d: int) -> void: stats["cold"] = int(stats["cold"]) + 1)
	sim.pole_sweep.connect(func(_r: Rect2) -> void: stats["poles"] = int(stats["poles"]) + 1)
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
	res.merge(stats, true)
	return res


func _cpu_runs() -> void:
	for id in NEST_LEVELS:
		var level: LevelDef = _level(id)
		var seeds: Array[int] = _good_seeds(level)
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
			print("INFO  %s seed %d: %s (%s), survivors %d of 4, nest %d/%d, boss HP left %d, rounds %d, nest hits %d, cold ticks %d, poles %d (%.0f s sim)" % [
				id, sd, "WON" if r.get("won", false) else "lost", str(r.get("reason", "")), int(r.get("survivors", 0)), int(r.get("nest_hp", 0)), int(r.get("nest_max_hp", 0)), int(r["boss_hp_end"]), int(r.get("rounds", 0)), int(r["pecks"]), int(r["cold"]), int(r["poles"]), float(r["seconds"])])
		_check(seeds.size() == RUN_SEEDS and finished == RUN_SEEDS and clean == RUN_SEEDS, "%s: %d CPU-vs-CPU runs end without errors (seeds %s)" % [id, finished, str(seeds)])
		print("INFO  %s: caterpillar AI wins %d of %d, survivors avg %.1f of 4 (%.1f s)" % [id, wins, seeds.size(), surv / float(seeds.size()), (Time.get_ticks_msec() - started) / 1000.0])
