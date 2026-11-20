## Scene-level battle things: silk, updrafts, larvae swarms, ropes, shadows, tufts, anthill, convoy, nest, spores, boar warnings.
## Registry file of the "scene" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	reg.add("silk_nest", SilkNestArt.new())
	reg.add("silk_web", SilkWebArt.new())
	reg.add("updraft", UpdraftArt.new())
	reg.add("larvae", LarvaeSwarmArt.new())
	reg.add("grapple", GrappleArt.new())
	reg.add("tethers", TethersArt.new())
	reg.add("shadows", ContactShadowsArt.new())
	# adapters (states: see the old classes; those reading only the ViewCtx take null)
	reg.add("tuft", TuftSpriteArt.new(FuncArt.new(_draw_tuft, Vector2(0.0, 0.0), Vector2(60.0, 36.0))))
	reg.add("tuft_front", TuftFrontSpriteArt.new(FuncArt.new(_draw_tuft_front, {"ground": Vector2.ZERO, "seed": 3})))
	reg.add("anthill", AnthillSpriteArt.new(FuncArt.new(_draw_anthill)))
	reg.add("convoy_goal", FuncArt.new(_draw_convoy_goal))
	reg.add("story_goal", FuncArt.new(_draw_story_goal))
	reg.add("convoy_thread", FuncArt.new(_draw_convoy_thread))
	reg.add("convoy_reach", FuncArt.new(_draw_convoy_reach))
	reg.add("convoy_marks", FuncArt.new(_draw_convoy_marks))
	reg.add("nest_back", FuncArt.new(_draw_nest_back))
	reg.add("nest_front", FuncArt.new(_draw_nest_front))
	reg.add("nest_frozen", FuncArt.new(_draw_nest_frozen))
	reg.add("spores", FuncArt.new(_draw_spores))
	reg.add("boar_warning", FuncArt.new(_draw_boar_warning))


static func _draw_tuft(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	TuftArt.draw(ci, s, c.t)


static func _draw_tuft_front(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	TuftArt.draw_front(ci, s["ground"], c.t, s["seed"])


static func _draw_anthill(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	AnthillArt.draw(ci, c.combat.anthill_pos, c.t, c.t - c.combat.wave_time)


static func _draw_convoy_goal(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	ConvoyArt.draw_goal(ci, c.combat)


static func _draw_story_goal(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	StoryGoalArt.draw(ci, c.combat)


static func _draw_convoy_thread(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	ConvoyArt.draw_thread(ci, c.combat)


static func _draw_convoy_reach(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	ConvoyArt.draw_reach(ci, c.combat)


static func _draw_convoy_marks(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	ConvoyArt.draw_marks(ci, s, c.combat)


static func _draw_nest_back(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	NestArt.draw_back(ci, c.combat, s)


static func _draw_nest_front(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	NestArt.draw_front(ci, c.combat)


static func _draw_nest_frozen(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	NestArt.draw_frozen(ci, s, c.combat)


static func _draw_spores(ci: CanvasItem, _s: Variant, c: ArtContext) -> void:
	SporeArt.draw(ci, c.combat)


static func _draw_boar_warning(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	BoarArt.draw_warning(ci, s, c.combat)
