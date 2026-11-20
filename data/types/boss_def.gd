## A turn-based combat boss (see docs/boss_contracts.md). The boss is a fighter of team 1 whose behaviour is data:
## phases, an attack list (each attack is run by the handler of its `kind`, see BossAttacks) and vulnerable states.
class_name BossDef
extends Resource

## Also the fighter `kind` of the boss (the view picks the art by it).
@export var id: String = ""
## Translation keys of the name and the subtitle.
@export var name_key: String = ""
@export var title_key: String = ""
@export var max_hp: int = 100
@export var radius: float = 16.0
## Art key for the view (ArtCatalog); the view may also draw it procedurally by `id`.
@export var art: String = ""
## Size of the art relative to a caterpillar.
@export var art_scale: float = 1.0
## Flies kinematically (no gravity while it acts); a knockback makes it fall until its next turn.
@export var flies: bool = false
## Flying bosses: height (px) above the ground where it hovers between attacks.
@export var hover_height: float = 170.0
## Flying speed (px/s) of its moves; walking bosses use it as their charge speed.
@export var speed: float = 300.0
## Speed multiplier from phase 2 on: index 0 = phase 2, 1 = phase 3... (empty = no change).
@export var phase_speed_mult: Array[float] = []
## Where it appears: fraction of the world width (the nearest free ground or air there).
@export var spawn_frac: float = 0.7
## Seconds of its own sub-turn in the enemy turn (its attack choreography must fit in it).
@export var turn_time: float = 14.0
## HP fractions where the phase changes, high to low. Phases count from 1: [0.5] = phase 1 above 50 %, phase 2 at or below it.
@export var phases: Array[float] = []
## Attacks. Common keys: id, kind (a BossAttacks kind), phase (1, 2...; -1 = any), weight, priority (higher first), once, cooldown
## (own turns before it can be picked again), label (intent text key; %s = the target names), damage, radius, knockback,
## status, turns, targets (how many fighters it marks), dodge (px a target must move away), after (usable only once this many
## attacks were announced since the last attack with `after`: the "out of breath" rest), and the after-state:
## rest_state (e.g. "RESTING"), rest_time (seconds into the player's turn before it ends; 0 = until its next turn),
## rest_hits (hits that end it; 0 = none). Handler-specific keys are documented in each handler.
@export var attacks: Array[Dictionary] = []
## States in which it takes full damage; in any other state damage is multiplied by `armored_mult`.
@export var vulnerable_states: Array[String] = []
@export var armored_mult: float = 0.25
## HP it loses when knocked into the water (it flies out); -1 = it drowns like anyone else.
@export var water_damage: int = -1
## Status effects its attacks apply: status id -> {damage (per turn of the victim), label (damage label key), silk_cleans (bool)}.
@export var statuses: Dictionary = {}


## Speed (px/s) of its moves in a phase (phase 1 = `speed`).
func speed_of(phase: int) -> float:
	var i: int = phase - 2
	return speed * (phase_speed_mult[i] if i >= 0 and i < phase_speed_mult.size() else 1.0)


## The attacks usable in a phase (phase -1 attacks are usable in every phase).
func attacks_of_phase(phase: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in attacks:
		if int(a.get("phase", -1)) == -1 or int(a.get("phase", -1)) == phase:
			out.append(a)
	return out
