## The battle simulation facade: owns all match state, steps it and exposes the input commands.
## Pure logic (no nodes, no drawing, no audio); everything the view/HUD/audio must know goes out as signals.
class_name CombatSim
extends RefCounted

enum Phase { TURN_PLAY, RETREAT, ACTION_WAIT, TURN_DELAY, GAME_OVER }

const WORLD_W: float = 3200.0
## A unit that ends its turn this close to a hiding spot becomes hidden.
const HIDING_SPOT_RADIUS: float = 34.0

# --- Events (replace every DOM / SND / camera write of the JS) ---
## Sound request: name is the JS SND method in snake_case.
signal sfx(name: String, params: Dictionary)
signal float_text(pos: Vector2, text: String, color: Color, life: float)
signal speech_bubble(fighter: SimFighter, text: String, life: float)
## Particle/visual request: kind is one of explosion_smoke, sparks, embers, debris, urticating_hairs, fireball,
## shockwave, water_plunge, flora_uproot, wine_splash, beam, bubbles, jet_flame, skid_smoke, steam_geyser...
signal effect(kind: String, params: Dictionary)
signal camera_focus(pos: Vector2, fighter: SimFighter)
signal screen_shake(amount: float)
signal flash(pos: Vector2, amount: float)
signal hit_stop(seconds: float, use_max: bool)
signal slow_mo(seconds: float, use_max: bool)
signal terrain_changed(rect: Rect2i)
signal hud_changed
## Wind or gust flash changed (JS updateWindHUD): only the wind widget listens, so no HUD rebuild per frame.
signal wind_changed
signal turn_started(team: int, fighter: SimFighter)
signal game_over(winner: int, stats: Dictionary)
## Story WAVES: an anthill wave just came out. `wave` counts from 1, `pos` is the top of the anthill.
signal wave_spawned(wave: int, count: int, pos: Vector2)
## El Bolsó (docs/nest_contracts.md): the nest changed (hp, repair, placed); a hit on it (`pos`, `damage`); it fell (the match is lost).
signal nest_changed
signal nest_hit(pos: Vector2, damage: int)
signal nest_destroyed
## Cold levels: a caterpillar outside the nest is about to lose `damage` HP at the start of its turn.
signal cold_tick(fighter: SimFighter, damage: int)
## The pole: a band (full height, x range) is marked for the next enemy turn / comes down now (also the boss LINE attack).
signal pole_warn(band: Rect2)
signal pole_sweep(band: Rect2)
## Boss levels (see docs/boss_contracts.md): hp, phase or state of the boss changed.
signal boss_changed
## boss_intent was announced or cleared.
signal boss_intent_changed
## The boss lands an attack (the moment of impact) at `pos`.
signal boss_attack(attack_id: String, pos: Vector2)
signal boss_phase_changed(phase: int)
signal boss_defeated

## La Processó (docs/procession_contracts.md): the file changed (a follower lost, rejoined or fallen).
signal convoy_changed
## The leader reached the goal (just before game_over).
signal convoy_goal_reached
## A wild boar announced its charge: the band (x range, full height) it will cross and the side it comes from (-1 = from the left, +1 = from the right).
signal boar_telegraph(boar: SimFighter, band: Rect2, side: int)
## The boar starts its charge now.
signal boar_charge(boar: SimFighter, band: Rect2, side: int)
## The boar hit a fighter, and it left (it is not killable: it just goes away).
signal boar_hit(boar: SimFighter, victim: SimFighter)
signal boar_gone(boar: SimFighter)
## A spore cloud is about to hurt a fighter (at its turn start).
signal spore_tick(fighter: SimFighter, damage: int)

static var _weapon_cache: Array[WeaponDef] = []
static var _classic_weapon_cache: Array[WeaponDef] = []
static var _map_cache: Array[MapDef] = []

# --- Terrain and data ---
var terrain: TerrainSim = TerrainSim.new()
var weapons: Array[WeaponDef] = []
var maps: Array[MapDef] = []
var cfg: MatchConfig
## Story level of this match; null in the classic modes.
var level: LevelDef = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var game_mode: String = "1P_CPU"
var ai_difficulty: String = "VETERAN"
var worms_per_team: int = 4
## False for the splash/menu showcase (JS appStage != 'PLAYING').
var playing: bool = true

# --- Entities ---
var fighters: Array[SimFighter] = []
var projectiles: Array[SimProjectile] = []
var barrels: Array[SimBarrel] = []
var mines: Array[SimMine] = []
var crates: Array[SimCrate] = []
var airstrike_planes: Array[SimPlane] = []
var silk_webs: Array[SimWeb] = []
var silk_nests: Array[SimNest] = []
var pine_nuts: Array[SimNut] = []
var larvae_swarms: Array[SimLarvae] = []
var updrafts: Array[SimUpdraft] = []
var rovellons: Array[SimRovello] = []
var caganers: Array[SimCaganer] = []
var escudelles: Array[SimEscudella] = []
var tombstones: Array[SimTombstone] = []
var surface_flora: Array[SimFlora] = []
var next_fighter_id: int = 1

# --- Match / turn ---
var turn_phase: int = Phase.TURN_PLAY
var turn_timer: float = 30.0
## True while the rotate-device overlay is open (JS rotatePromptOpen): the turn timer does not count down.
var rotate_prompt_open: bool = false
var phase_timer: float = 0.0
var action_wait_timer: float = 0.0
var last_turn_tick_sec: int = 30
var active_team: int = 0
var active_fighter: SimFighter = null
## Worm the camera follows after an impact (JS impactCam.trackedWorm); reset every turn.
var impact_tracked_worm: SimFighter = null
var team_turn_idx: Array[int] = [0, 0]
var round_number: int = 1
var has_acted_or_moved_this_turn: bool = false
var shotgun_shots_left: int = 1
var silk_web_used_this_turn: bool = false
var procession_convoy_enabled: bool = true
var custom_grenade_fuse: int = 3
var selected_weapon_idx: int = 0
var team_selected_weapon_idx: Array[int] = [0, 0]
## team_ammo[team][weapon_id] -> float (INF = unlimited); use ammo() for an int (-1 = unlimited).
var team_ammo: Array[Dictionary] = [{}, {}]
var team_damage_dealt: Array[int] = [0, 0]
var winner: int = -1
## Seconds of a turn (30 in classic, LevelDef.turn_time in story).
var turn_time: float = 30.0
## Story: world points (an egg's centre) where a hiding unit can tuck in.
var hiding_spots: Array[Vector2] = []
## Story: walking map of the terrain (null in classic matches).
var nav: SimNav = null
## The strict walking map walkers that really move along paths use (AiCritter): links only where a body can pass. Built on first use.
var _walk_nav: SimNav = null
## The map the squad placement of a story level used: the strict one when its main ground is wide enough, else the permissive `nav`.
var placement_nav: SimNav = null
## Story SURVIVE_ROUNDS: rounds still to play including the current one; -1 otherwise. Changes at the start of each round.
var rounds_left: int = -1
## Story WAVES: waves that still have to come out of the anthill (counts down at the start of each enemy turn); -1 in other levels.
var waves_left: int = -1
## Story WAVES: top of the anthill mound (where the ants come out); Vector2.INF in other levels.
var anthill_pos: Vector2 = Vector2.INF
## Story levels of the second pass: REACH / RESCUE / COLLECT / ONE_SHOT state, the anthill HP (SimGoals); null in classic matches.
var goals: SimGoals = null
## Story: weapon id -> ammo of each team (the level arsenal, plus MatchConfig.extra_arsenal for the player).
var arsenals: Array[Dictionary] = [{}, {}]
## Multiplier of the random wind (LevelDef.wind_scale; 1 in classic). `wind` already includes it.
var wind_scale: float = 1.0
## Story: where the CPU critters last saw an enemy (Vector2.INF = nowhere).
var critter_last_seen: Vector2 = Vector2.INF
## Story: the end-of-turn hiding/sniffing was already done for the current turn.
var turn_end_handled: bool = false
## Story swarm turn: ids of the enemy units that still have to act in this enemy turn (each acts in its own sub-turn).
var swarm_queue: Array[int] = []
## Seconds of the current (sub-)turn: turn_time, or SimStory.SWARM_TURN_TIME for a swarm sub-turn.
var sub_turn_time: float = 30.0
## Fighters of the enemy team (team 1) still alive: the HUD "Enemies: N".
var enemies_alive: int:
	get:
		return team_alive_count(1, true)
## Boss levels: the boss fighter (team 1, kind == boss_def.id) or null; its data, phase (from 1), state and announced intent.
var boss: SimFighter = null
var boss_def: BossDef = null
var boss_phase: int = 0
## "IDLE", "INTENT", "ACT", "RECOVER", "STUNNED", "DEFEATED" or a custom state of the boss data (e.g. "RESTING").
var boss_state: String = ""
## {} when none, else attack_id, kind, target_id (-1 = area), pos, radius, turns_left, label_key, label (translated text),
## targets ([{id, pos}] of every marked fighter). See SimBoss.
var boss_intent: Dictionary = {}
## Boss bookkeeping of SimBoss (cooldowns, used attacks, the current rest): not for the view.
var boss_memory: Dictionary = {}
## El Bolsó: the nest of the level (null in the other levels and in classic matches): pos (centre), size, rect(), hp, max_hp, destroyed.
var nest: SimBolso = null
## El Bolsó: the cold hurts the squad outside the nest (LevelDef.cold, and the WARM_SILK upgrade not owned).
var cold_active: bool = false
## El Bolsó pole: the marked band (Rect2(); empty size when none) and its state ("" or "WARN": it comes down at the start of the next enemy turn).
var pole_band: Rect2 = Rect2()
var pole_state: String = ""
## Story: ids of the upgrades applied to this match, the total `amount` per effect (SimUpgrades), the damage multiplier of each team,
## and how many silk webs a turn may spin (2 with EXTRA_SILK_WEB; `silk_web_used_this_turn` turns true once they are all spun).
var upgrades: Array[String] = []
var upgrade_effects: Dictionary = {}
var damage_mult: Array[float] = [1.0, 1.0]
var silk_webs_per_turn: int = 1
var silk_webs_spun: int = 0
## La Processó (CONVOY levels; defaults elsewhere): the leader, the file (leader first, then the followers that follow it, lost ones excluded),
## how many caterpillars the squad started with, the walking budget of the leader this turn and its size, the goal zone (the leader wins
## standing within goal_radius of goal_x, on the ground at goal_y), the wild boars' announced charges ({boar, band: Rect2, side, turns_left})
## and the spore clouds (their current rects; they drift every round).
var convoy_leader: SimFighter = null
var convoy_line: Array[SimFighter] = []
var convoy_start_count: int = 0
var march_budget: float = 0.0
var march_left: float = 0.0
var goal_x: float = -1.0
var goal_y: float = 0.0
var goal_radius: float = 80.0
var goal_reached: bool = false
var boar_intents: Array[Dictionary] = []
var spores: Array[Rect2] = []
## Convoy bookkeeping of SimConvoy (the leader's trail, the last x seen): not for the view.
var convoy_trail: SimTrail = SimTrail.new()
var convoy_s: Dictionary = {}
var convoy_air: bool = false
var convoy_last_x: float = 0.0
var spore_speeds: Array[float] = []
## Accumulated sim time in seconds (JS tNow).
var t_now: float = 0.0

# --- Wind ---
var wind: int = 0
var wind_float: float = 0.0
var wind_target: float = 0.0
var wind_gust_timer: float = 4.5
var wind_gust_flash: float = 0.0

# --- Aim (the AI writes the same fields so the view can show it) ---
var aim_pitch: float = -0.42
var aim_angle: float = -0.42
var is_charging: bool = false
var charge_power: float = 0.0
var charge_dir: float = 1.0
var mouse_world: Vector2 = Vector2(1600.0, 360.0)
## AI turn plan (empty when none): target, wpn, angle, power, walk_dir, walk_time, aim_computed, aim_time, total_time, executed.
var ai_plan: Dictionary = {}
## Story critter phase (docs/story_contracts.md): the MELEE_CRITTER units (ants) of an enemy turn act together in one phase. `critter_group` holds them
## all (fighter index order), `critter_plans` their AI plans by fighter id, `critter_acting` the ones that are alive and have not finished yet.
## active_fighter is the leader (the first acting one: HUD, camera, turn timer); empty arrays outside such a phase.
var critter_group: Array[SimFighter] = []
var critter_plans: Dictionary = {}
var critter_acting: Array[SimFighter] = []

# --- Input state ---
var _move_dir: int = 0
var _aim_input: int = 0
var _glide_held: bool = false
## Real seconds since the match started (advance_real); the JS double-press check uses performance.now().
var real_time: float = 0.0
var _last_jump_press_time: float = -1000.0
var _last_charge_tick: float = 0.0
## Delayed events (JS setTimeout): [{t, kind, x, y}].
var _delayed: Array[Dictionary] = []


func _init() -> void:
	if _weapon_cache.is_empty():
		var wl: WeaponList = load("res://data/weapons/weapon_list.tres")
		_weapon_cache.assign(wl.weapons)
		for w in wl.weapons:
			if not w.story_only:
				_classic_weapon_cache.append(w)
		var ml: MapList = load("res://data/maps/map_list.tres")
		_map_cache.assign(ml.maps)
	weapons = _classic_weapon_cache
	maps = _map_cache
	terrain.terrain_changed.connect(_on_terrain_changed)


func _on_terrain_changed(rect: Rect2i) -> void:
	terrain_changed.emit(rect)


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Starts a new match (JS initMatch): generates the terrain, spawns everything and opens the first turn.
func setup(config: MatchConfig) -> void:
	SimSetup.init_match(self, config)


# ---------------------------------------------------------------------------
# Stepping
# ---------------------------------------------------------------------------

## Advances the simulation by `dt` (already scaled for slow-mo/hit-stop by the caller).
func step(dt: float) -> void:
	t_now += dt
	_process_delayed(dt)  # simulation time, so a headless run and a real one detonate the same frame
	SimTurns.update_dynamic_wind(self, dt)

	var phase_ok: bool = turn_phase == Phase.TURN_PLAY or turn_phase == Phase.RETREAT
	if playing and not is_current_turn_ai() and phase_ok and active_fighter != null and active_fighter.alive and not active_fighter.drowning:
		var pitch_input: int = (1 if _keys_down() else 0) - (1 if _keys_up() else 0)
		if pitch_input != 0:
			var cur: WeaponDef = weapons[selected_weapon_idx]
			if cur != null and cur.id == "AIRSTRIKE":
				mouse_world.x = SimMath.clamp_js(mouse_world.x - pitch_input * active_fighter.facing * 420.0 * dt, 120.0, WORLD_W - 120.0)
				mouse_world.y = SimMath.clamp_js(terrain.find_surface_y(mouse_world.x, 220.0) - 24.0, 90.0, terrain.water_y - 40.0)
			else:
				aim_pitch = SimMath.clamp_js(aim_pitch + pitch_input * 1.55 * dt, -1.48, 1.30)
				sync_aim_angle_from_pitch()

	if playing and is_charging and not is_current_turn_ai() and turn_phase == Phase.TURN_PLAY:
		charge_power += charge_dir * dt * 0.92
		if t_now - _last_charge_tick > 0.06:
			_last_charge_tick = t_now
			play("charge", {"power": charge_power})
		if charge_power >= 1.0:
			charge_power = 1.0
			is_charging = false
			SimCombat.fire_weapon(self, weapons[selected_weapon_idx], aim_angle, charge_power, mouse_world)

	if playing:
		AiBrain.update(self, dt)
		SimBoss.tick(self, dt)
	SimPhysics.step(self, dt)
	if playing:
		SimConvoy.update(self, dt)
		SimGoals.update(self, dt)

	if playing:
		SimTurns.update_turn_fsm(self, dt)


## Real (unscaled) time of the frame, called by CombatScreen every frame, also during hit-stop:
## drives the double-press window (JS performance.now()). Delayed events (`schedule`) run in step() with the simulation time.
func advance_real(raw_dt: float) -> void:
	real_time += raw_dt


func _process_delayed(dt: float) -> void:
	var i: int = _delayed.size() - 1
	var due: Array[Dictionary] = []
	while i >= 0:
		_delayed[i]["t"] = float(_delayed[i]["t"]) - dt
		if float(_delayed[i]["t"]) <= 0.0:
			due.push_front(_delayed[i])
			_delayed.remove_at(i)
		i -= 1
	for ev in due:
		if ev["kind"] == "barrel_blast":
			SimCombat.trigger_explosion(self, ev["x"], ev["y"], 58.0, 55.0, 500.0, 0, false)


## Queues an event to run `seconds` of simulation time from now (replaces JS setTimeout; advanced by step).
func schedule(seconds: float, ev: Dictionary) -> void:
	ev["t"] = seconds
	_delayed.append(ev)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## True for the active fighter and for every unit of the current critter phase (the units whose AI moves them this frame).
func is_actor(f: SimFighter) -> bool:
	return f == active_fighter or (not critter_plans.is_empty() and critter_plans.has(f.id))


## The AI plan of an acting fighter ({} for the others).
func plan_of(f: SimFighter) -> Dictionary:
	if critter_plans.has(f.id):
		return critter_plans[f.id]
	return ai_plan if f == active_fighter else {}


## JS isCurrentTurnAI().
func is_current_turn_ai() -> bool:
	if not playing:
		return true
	if turn_phase == Phase.GAME_OVER:
		return false
	if game_mode == "CPU_CPU":
		return true
	if game_mode == "1P_CPU" and active_team == 1:
		return true
	return false


## True while the human may control the active fighter (JS canControl).
func can_control() -> bool:
	return playing and (turn_phase == Phase.TURN_PLAY or turn_phase == Phase.RETREAT) \
		and active_fighter != null and active_fighter.alive and not active_fighter.drowning and not is_current_turn_ai()


## Number of fighters of `team` that are alive and not drowning (`killable_only`: without the unkillable hazards, the wild boars).
func team_alive_count(team: int, killable_only: bool = false) -> int:
	var n: int = 0
	for f in fighters:
		if f.team == team and f.alive and not f.drowning and not (killable_only and f.is_hazard()):
			n += 1
	return n


## Index of the weapon with this id in the weapon list (-1 if unknown).
func weapon_index(id: String) -> int:
	for i in weapons.size():
		if weapons[i].id == id:
			return i
	return -1


## Ammo of a team for a weapon id: -1 means unlimited.
func ammo(team: int, id: String) -> int:
	var v: float = float(team_ammo[team].get(id, 0.0))
	return -1 if is_inf(v) else int(v)


## Float version used by the sim: INF when unlimited.
func ammo_f(team: int, id: String) -> float:
	return float(team_ammo[team].get(id, 0.0))


## Absolute aim angle from the pitch (JS syncAimAngleFromPitch); also updates the aim target point.
func sync_aim_angle_from_pitch() -> void:
	var facing: int = -1 if (active_fighter != null and active_fighter.facing < 0) else 1
	aim_pitch = SimMath.clamp_js(aim_pitch, -1.48, 1.30)
	aim_angle = aim_pitch if facing >= 0 else (PI - aim_pitch)
	if active_fighter != null:
		var cur: WeaponDef = weapons[selected_weapon_idx]
		if cur == null or cur.id != "AIRSTRIKE":
			mouse_world = Vector2(
				SimMath.clamp_js(active_fighter.x + cos(aim_angle) * 260.0, 120.0, WORLD_W - 120.0),
				SimMath.clamp_js((active_fighter.y - 4.0) + sin(aim_angle) * 260.0, 60.0, terrain.water_y - 20.0))


## Text with optional `%s` arguments; safe when the translation is missing (returns key + args).
func tx(key: String, args: Array = []) -> String:
	var s: String = tr(key)
	if args.is_empty():
		return s
	if s.contains("%"):
		return s % args
	var parts: PackedStringArray = PackedStringArray()
	for a in args:
		parts.append(str(a))
	return key + " " + " ".join(parts)


## The strict SimNav of the current terrain (see `_walk_nav`).
func walk_nav() -> SimNav:
	if _walk_nav == null:
		_walk_nav = SimNav.new(terrain)
	return _walk_nav


# ---------------------------------------------------------------------------
# Event helpers used by the sim modules
# ---------------------------------------------------------------------------

func play(sfx_name: String, params: Dictionary = {}) -> void:
	sfx.emit(sfx_name, params)


## Emits a floating text from a translation key (and optional %s arguments).
func ftext(x: float, y: float, key: String, color: Color, life: float, args: Array = []) -> void:
	float_text.emit(Vector2(x, y), tx(key, args), color, life)


func bubble(f: SimFighter, text_key: String, life: float) -> void:
	speech_bubble.emit(f, tx(text_key), life)


## Random taunt of a category as a speech bubble.
func taunt(f: SimFighter, category: String, life: float) -> void:
	if f.unit != null:
		return
	var list: Array = SimTables.TAUNTS[category]
	bubble(f, list[int(SimMath.rand01(rng) * list.size())], life)


func fx(kind: String, params: Dictionary) -> void:
	effect.emit(kind, params)


func focus(x: float, y: float, f: SimFighter) -> void:
	camera_focus.emit(Vector2(x, y), f)


func hud() -> void:
	hud_changed.emit()


func rand() -> float:
	return SimMath.rand01(rng)


## Indices into `weapons` the team may use, in list order (classic: every weapon).
func team_arsenal(team: int) -> Array[int]:
	var out: Array[int] = []
	var listed: Dictionary = arsenals[team] if level != null else {}
	for i in weapons.size():
		if level == null or listed.has(weapons[i].id):
			out.append(i)
	return out


## The human or the AI ends the turn early (TURN_PLAY -> ACTION_WAIT); needed by units with no weapon.
func end_turn() -> void:
	if not playing or turn_phase != Phase.TURN_PLAY or active_fighter == null:
		return
	is_charging = false
	charge_power = 0.0
	SimStory.on_turn_end(self)
	turn_phase = Phase.ACTION_WAIT


# ---------------------------------------------------------------------------
# Input commands
# ---------------------------------------------------------------------------

func _keys_up() -> bool:
	return _aim_input < 0 or _glide_held


func _keys_down() -> bool:
	return _aim_input > 0


## Walking / jetpack steering input: -1 left, 0 none, +1 right.
func set_move(dir: int) -> void:
	_move_dir = signi(dir)


## Aim input: -1 up, 0 none, +1 down (applied in step; also steers the spoon).
func set_aim_input(dir: int) -> void:
	_aim_input = signi(dir)


## Touch swipe aiming: adds `delta` radians to the pitch (clamped like the keyboard aim).
func nudge_aim_pitch(delta: float) -> void:
	aim_pitch = SimMath.clamp_js(aim_pitch + delta, -1.48, 1.30)
	sync_aim_angle_from_pitch()


## Touch aiming over the top of the circle: turns the active caterpillar to `dir` (-1 left, 1 right) and keeps the aim pitch.
func set_facing(dir: int) -> void:
	if active_fighter == null or turn_phase != Phase.TURN_PLAY or is_current_turn_ai():
		return
	active_fighter.facing = -1 if dir < 0 else 1
	sync_aim_angle_from_pitch()


## Up held for jetpack thrust and the metamorphosed glide (JS keys.up).
func set_glide(held: bool) -> void:
	_glide_held = held


## True while the left/right key state is read by the physics (left wins).
func key_left() -> bool:
	return _move_dir < 0


func key_right() -> bool:
	return _move_dir > 0


func key_up() -> bool:
	return _keys_up()


func key_down() -> bool:
	return _keys_down()


func _jump_allowed() -> bool:
	return not SimConvoy.walk_blocked(self, active_fighter) and (turn_phase == Phase.TURN_PLAY or turn_phase == Phase.RETREAT) and active_fighter != null \
		and active_fighter.can_jump() and active_fighter.alive and not active_fighter.drowning and active_fighter.jet_fuel <= 0.0 \
		and not is_current_turn_ai()


## Enter/J: forward jump, or a backflip when pressed again in the air within 0.36 s.
func jump_forward() -> void:
	if not _jump_allowed():
		return
	var f: SimFighter = active_fighter
	if f.grounded and not f.sliding:
		_do_forward_jump(f)
	elif not f.grounded and real_time - _last_jump_press_time < 0.36:
		if f.has_jump_start_x:
			f.x = lerpf(f.x, f.jump_start_x, 0.72)
		_do_backward_jump(f)
		_last_jump_press_time = -1000.0


## Backspace: backflip from the ground.
func jump_backward() -> void:
	if not _jump_allowed():
		return
	var f: SimFighter = active_fighter
	if f.grounded and not f.sliding:
		_do_backward_jump(f)


func _do_forward_jump(f: SimFighter) -> void:
	has_acted_or_moved_this_turn = true
	f.grounded = false
	f.jump_start_x = f.x
	f.has_jump_start_x = true
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.is_voluntary_jump = true
	f.was_blasted = false
	f.flip_angle = 0.0
	f.flip_spin = 0.0
	f.vx = f.facing * 92.0
	f.vy = -178.0
	f.squash_x = 0.82
	f.squash_y = 1.22
	_last_jump_press_time = real_time
	play("jump")


func _do_backward_jump(f: SimFighter) -> void:
	has_acted_or_moved_this_turn = true
	f.grounded = false
	f.sliding = false
	f.jump_start_y = f.y
	f.peak_air_y = f.y
	f.is_voluntary_jump = true
	f.was_blasted = false
	f.vx = -f.facing * 34.0
	f.vy = -212.0
	f.flip_angle = 0.0
	f.flip_spin = -f.facing * PI * 2.35
	f.squash_x = 0.76
	f.squash_y = 1.30
	play("backflip")


## Space/fire pressed: starts charging a CHARGE weapon or fires any other weapon at once.
func begin_charge_or_fire() -> void:
	if is_current_turn_ai() or turn_phase != Phase.TURN_PLAY or active_fighter == null or not active_fighter.alive or active_fighter.drowning:
		return
	var wpn: WeaponDef = weapons[selected_weapon_idx]
	if wpn == null or ammo_f(active_team, wpn.id) <= 0.0:
		return
	sync_aim_angle_from_pitch()
	if wpn.type == "CHARGE":
		if not is_charging:
			is_charging = true
			charge_power = 0.08
			charge_dir = 1.0
	else:
		SimCombat.fire_weapon(self, wpn, aim_angle, 1.0, mouse_world)


## Space/fire released: fires the charged shot (minimum power 0.12).
func release_charge() -> void:
	if not is_charging:
		return
	if is_current_turn_ai() or turn_phase != Phase.TURN_PLAY or active_fighter == null or not active_fighter.alive or active_fighter.drowning:
		is_charging = false
		charge_power = 0.0
		return
	var wpn: WeaponDef = weapons[selected_weapon_idx]
	var pwr: float = maxf(0.12, charge_power)
	is_charging = false
	charge_power = 0.0
	if wpn != null and ammo_f(active_team, wpn.id) > 0.0:
		sync_aim_angle_from_pitch()
		SimCombat.fire_weapon(self, wpn, aim_angle, pwr, mouse_world)


## Selects a weapon by list index; false if it is not selectable (AI turn, no ammo, bad index).
func select_weapon(idx: int) -> bool:
	if idx < 0 or idx >= weapons.size():
		return false
	var w: WeaponDef = weapons[idx]
	if is_current_turn_ai() or ammo_f(active_team, w.id) <= 0.0:
		return false
	selected_weapon_idx = idx
	team_selected_weapon_idx[active_team] = idx
	if w.id == "AIRSTRIKE" and active_fighter != null:
		var ax: float = active_fighter.x + active_fighter.facing * 220.0
		mouse_world = Vector2(
			SimMath.clamp_js(ax, 200.0, WORLD_W - 200.0),
			SimMath.clamp_js(terrain.find_surface_y(ax, 220.0) - 24.0, 90.0, terrain.water_y - 40.0))
	hud()
	return true


## Selects the next/previous weapon that still has ammo (JS cycleAvailableWeapon).
func cycle_weapon(step_dir: int) -> void:
	if is_current_turn_ai():
		return
	var n: int = weapons.size()
	for offset in range(1, n + 1):
		var candidate: int = (selected_weapon_idx + step_dir * offset + n * 10) % n
		if ammo_f(active_team, weapons[candidate].id) > 0.0:
			play("tick")
			select_weapon(candidate)
			return


## Grenade/cluster fuse in seconds (1..5).
func set_fuse(seconds: int) -> void:
	custom_grenade_fuse = clampi(seconds, 1, 5)


## Tab: switch to the next (or the given) squad member before moving or acting.
func switch_fighter(target: SimFighter = null) -> bool:
	if not playing or turn_phase != Phase.TURN_PLAY or is_current_turn_ai() or is_charging or has_acted_or_moved_this_turn or SimConvoy.active(self):
		return false
	var team_alive: Array[SimFighter] = []
	for f in fighters:
		if f.team == active_team and f.alive and not f.drowning:
			team_alive.append(f)
	if team_alive.size() <= 1:
		return false
	var next_worm: SimFighter = target
	if next_worm == null or next_worm.team != active_team or not next_worm.alive or next_worm.drowning:
		var cur_idx: int = maxi(0, team_alive.find(active_fighter))
		next_worm = team_alive[(cur_idx + 1) % team_alive.size()]
	if next_worm == null or next_worm == active_fighter:
		return false
	active_fighter = next_worm
	aim_pitch = active_fighter.last_aim_pitch
	sync_aim_angle_from_pitch()
	play("tick")
	ftext(active_fighter.x, active_fighter.y - 42.0, "FT_TURN_SWITCH", Palette.FT_TEAM_0 if active_team == 0 else Palette.FT_TEAM_1, 1.35, [active_fighter.name.to_upper()])
	hud()
	return true


## True when the silk web may be spun: always in classic matches, in a story level only when it lists "SILK_WEB".
func can_spin_web() -> bool:
	return level == null or level.has_ability("SILK_WEB")


## True when the active caterpillar may repair the nest now (next to a damaged nest, its turn, action not used).
func can_repair_nest() -> bool:
	return not is_current_turn_ai() and SimBolso.can_repair(self)


## REPAIR: the active caterpillar spends its action to give the nest 40 HP (it may still walk a little). True when done.
func repair_nest() -> bool:
	return not is_current_turn_ai() and SimBolso.repair(self)


## C: spin an elastic silk web in front of the active fighter (once per turn).
func spin_silk_web() -> void:
	if is_current_turn_ai() or not can_spin_web():
		return
	SimCombat.spin_silk_web(self)


## F: toggle the nose-to-tail convoy march.
func toggle_convoy() -> void:
	if level != null:
		return
	procession_convoy_enabled = not procession_convoy_enabled
	hud()


## Sets the Correfoc target point from a world position (mouse/touch).
func set_target(world_pos: Vector2) -> void:
	var tx_v: float = SimMath.clamp_js(world_pos.x, 120.0, WORLD_W - 120.0)
	mouse_world = Vector2(tx_v, SimMath.clamp_js(terrain.find_surface_y(tx_v, 220.0) - 24.0, 90.0, terrain.water_y - 40.0))
