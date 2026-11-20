## Bosses by the art key of their BossDef ("boss:<art>"; "boss:" is the plain blob): cutout-rig arts in art/bosses/ with the old art classes as fallbacks.
## Registry file of the "bosses" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	# cutout-rig bosses (assets/sprites/bosses/<id>/), each with the old procedural art as the fallback while a part is missing
	reg.add("boss:tachinid_fly", TachinidFlyBossArt.new(FuncArt.new(_draw_boss_tachinid_fly)))
	reg.add_prefix("boss:great_tit", GreatTitBossArt.new(FuncArt.new(_draw_boss_great_tit)))
	reg.add_prefix("boss:cuckoo", CuckooBossArt.new(FuncArt.new(_draw_boss_cuckoo)))
	reg.add("boss:foreman", ForemanBossArt.new(FuncArt.new(_draw_boss_foreman)))
	reg.add_prefix("boss:", FuncArt.new(_draw_boss, {"x": 0.0, "y": -16.0, "r": 16.0, "facing": 1.0}))


static func _draw_boss_tachinid_fly(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	FlyArt.draw(ci, s, c.combat)


static func _draw_boss_great_tit(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	BirdArt.draw(ci, s, c.combat)


static func _draw_boss_cuckoo(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	CuckooArt.draw(ci, s, c.combat)


static func _draw_boss_foreman(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	ForestryArt.draw_foreman(ci, s, c.combat)


static func _draw_boss(ci: CanvasItem, s: Variant, _c: ArtContext) -> void:
	BossArt.draw_blob(ci, s)
