## Weapons: the one held by a fighter, projectiles in flight and the airstrike plane (sprites in art/weapons, WeaponArt vector code as fallback).
## Registry file of the "weapons" art group: add or replace a kind by editing only this file (and the kind's own class).
extends RefCounted


static func register(reg: ArtRegistry) -> void:
	# state: {root: Transform2D of the fighter, f: the fighter}
	reg.add("weapon:held", WeaponHeldArt.new())
	reg.add("weapon:projectile", WeaponProjectileArt.new())
	reg.add("weapon:plane", WeaponPlaneArt.new())

