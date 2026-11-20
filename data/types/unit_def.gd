## A kind of combat unit used by story levels (egg, ant, caterpillar...). Classic matches use no UnitDef: their fighters are caterpillars with the original stats.
class_name UnitDef
extends Resource

## CATERPILLAR, EGG, ANT, ... Also selects the art in the view.
@export var id: String = "CATERPILLAR"
## Translation key of the unit name (shown in intro cards and results).
@export var name_key: String = ""
@export var max_hp: int = 100
## Body radius in world pixels (caterpillars: 12).
@export var radius: float = 12.0
## Multiplier of the walking speed (1 = caterpillar).
@export var speed_mult: float = 1.0
@export var can_jump: bool = true
## Can become hidden in a hiding spot (see docs/story_contracts.md).
@export var can_hide: bool = false
## Brain used when the CPU controls it: CATERPILLAR (the original AI), MELEE_CRITTER (walk to the nearest visible enemy and bite)
## FLYER (hover, warn, dive and peck; see AiFlyer) or CHARGER (the wild boar: a telegraphed horizontal charge; see AiCharger).
@export var ai: String = "CATERPILLAR"
## True for birds: they fly (no gravity while they act) until a hit or an explosion knocks them down.
@export var flies: bool = false
## Size of the art relative to a caterpillar (1 = caterpillar size).
@export var art_scale: float = 1.0
## Id of the melee weapon the CPU uses; empty = the first melee weapon of the team arsenal.
@export var melee_weapon: String = ""
## False: it cannot be hurt or knocked (an environmental hazard such as the wild boar); it does not count as an enemy.
@export var killable: bool = true
## > 0: damage of its melee bite whatever the weapon says (the Calosoma bites for 20 with the ant's MOSSEGADA).
@export var melee_damage: int = 0
## True for the ants: when the target cannot be reached (or only by a long detour) they chew a tunnel through the rock (see AiCritter).
@export var can_dig: bool = false
