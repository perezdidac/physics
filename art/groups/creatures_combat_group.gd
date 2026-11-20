## Combat creatures by fighter kind ("creature:<KIND>"; the egg is the default). Adapters over the old art classes.
## Registry file of the "creatures_combat" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	reg.add("creature:ANT", AntSpriteArt.new())
	reg.add("creature:CUCKOO", CuckooSpriteArt.new())
	reg.add("creature:CATERPILLAR", CaterpillarSpriteArt.new())
	reg.add("creature:WILD_BOAR", BoarSpriteArt.new())
	reg.add("creature:CALOSOMA", CalosomaSpriteArt.new())
	reg.add("creature:FORESTRY_WORKER", WorkerSpriteArt.new())
	reg.add("creature:SMALL_FLY", FlySpriteArt.new())
	reg.add("creature:BLUE_TIT", BirdSpriteArt.new(false))
	reg.add_prefix("creature:GREAT_TIT", BirdSpriteArt.new(true))
	reg.add_prefix("creature:LARVA", LarvaSpriteArt.new())
	reg.add_prefix("creature:", EggSpriteArt.new())


## The egg (Perleta and the story eggs); the state may carry "alpha" (otherwise 0.45 while hidden, 1 otherwise).
static func _egg(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	var a: float = ViewUtil.gf(s, "alpha", -1.0)
	if a < 0.0:
		a = 0.45 if ViewUtil.gb(s, "hidden") else 1.0
	EggArt.draw(ci, s, c.combat, a)


