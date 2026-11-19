## Registry of the boss attack handlers, keyed by the attack `kind` of BossDef.attacks. A new kind of attack is one small
## BossAttack subclass registered here (or at run time with register()); everything else about a boss is data.
class_name BossAttacks
extends RefCounted

static var _handlers: Dictionary = {}


## The handler of an attack kind (null when unknown).
static func handler(kind: String) -> BossAttack:
	if _handlers.is_empty():
		_handlers = {
			"MELEE_TARGET": AttackMeleeTarget.new(),
			"AREA": AttackArea.new(),
			"GUST": AttackGust.new(),
			"STATUS": AttackStatus.new(),
			"SUMMON": AttackSummon.new(),
			"MOVE": AttackMove.new(),
			"LINE": AttackLine.new(),
			"REST": AttackRest.new(),
		}
	return _handlers.get(kind)


## Adds or replaces the handler of a kind.
static func register(kind: String, h: BossAttack) -> void:
	handler(kind)
	_handlers[kind] = h
