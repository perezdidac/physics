## Platformer creatures: pupa, moth, bat boss, nightjar, hoopoe (adapters over the Platform*Art classes).
## Registry file of the "creatures_platform" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	var at_feet: Dictionary = {"base": Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, -12.0))}
	# pupa / moth / nightjar state: {r: radius, o: options}; bat / hoopoe state: the options
	reg.add("platform:pupa", FuncArt.new(_draw_platform_pupa, {"r": 11.0, "o": at_feet}))
	reg.add("platform:moth", FuncArt.new(_draw_platform_moth, {"r": 13.0, "o": at_feet}))
	reg.add("platform:nightjar", FuncArt.new(_draw_platform_nightjar, {"r": 16.0, "o": at_feet}, Vector2(80.0, 50.0)))
	reg.add("platform:bat", FuncArt.new(_draw_platform_bat, at_feet, Vector2(80.0, 50.0)))
	reg.add("platform:hoopoe", FuncArt.new(_draw_platform_hoopoe, {"base": Transform2D.IDENTITY}, Vector2(80.0, 100.0)))


static func _draw_platform_pupa(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	PlatformPupaArt.draw(ci, s["r"], c.t, s["o"])


static func _draw_platform_moth(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	PlatformMothArt.draw(ci, s["r"], c.t, s["o"])


static func _draw_platform_nightjar(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	PlatformBirdArt.nightjar(ci, s["r"], c.t, s["o"])


static func _draw_platform_bat(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	PlatformBatArt.draw(ci, c.t, s)


static func _draw_platform_hoopoe(ci: CanvasItem, s: Variant, c: ArtContext) -> void:
	PlatformBirdArt.hoopoe(ci, c.t, s)
