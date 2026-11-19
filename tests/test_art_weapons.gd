## Weapon sprites: every held / projectile / plane SVG loads, the registry kinds draw with and without a sprite.
extends Node

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)


func _ready() -> void:
	var held: Array[String] = ["bazooka", "carquinyoli", "grenade", "cluster", "urticaria", "shotgun", "fuet", "bat", "dynamite", "holy",
		"airstrike", "cullera", "barrina", "pont_pedra", "ganxo"]
	for h in held:
		_check(SpriteArt.new("weapons", "held_" + h, 40.0).has_sprite(), "held_%s.svg loads" % h)
	for p in ["carquinyoli", "fuet_slice", "bazooka", "bombler", "urticaria", "grenade", "cluster", "holy", "dynamite"]:
		_check(SpriteArt.new("weapons", "proj_" + p, 32.0).has_sprite(), "proj_%s.svg loads" % p)
	_check(WeaponPlaneArt.new().has_sprite(), "plane.svg loads")
	_check(WeaponProjectileArt.sprite_kind({"type": "CARQUINYOLI", "is_fuet_slice": true}) == "fuet_slice", "fuet slice kind")
	_check(WeaponProjectileArt.sprite_kind({"type": "BAZOOKA"}) == "bazooka", "projectile kind")
	var reg: ArtRegistry = ArtRegistry.get_instance()
	for id in ["weapon:held", "weapon:projectile", "weapon:plane"]:
		_check(reg.art_of(id) != null, id + " registered")
	ArtRegistry.shutdown()
	print("RESULT: ALL GOOD" if _fails == 0 else "RESULT: %d FAILED" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
