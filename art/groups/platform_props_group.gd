## Objects of the platformer world: puddle, pine needle platform, needle tufts, sap drop, checkpoint flag, goal.
## Registry file of the "platform_props" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	reg.add("platform:puddle", PuddleArt.new())
	reg.add("platform:needle", NeedleArt.new())
	reg.add("platform:tuft", PlatformTuftArt.new())
	reg.add("platform:nutrient", NutrientArt.new())
	reg.add("platform:checkpoint", CheckpointArt.new())
	reg.add("platform:goal", GoalArt.new())
