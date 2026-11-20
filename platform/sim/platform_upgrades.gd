## Hub upgrades in the platform levels (egg, pupa and moth; docs/story_mode.md economy). The ids come from the story flow (the sim never reads
## the save). Only the effects of scope PLATFORM count; unknown ids and combat upgrades are ignored.
class_name PlatformUpgrades
extends RefCounted


## Resets the sim's upgrade state (every level).
static func reset(sim: PlatformSim) -> void:
	sim.upgrades = []
	sim.dig_speed_mult = 1.0
	sim.glide_fall_mult = 1.0


## Applies the owned upgrades to a platform level once the player exists. EXTRA_HEART adds hearts, FAST_DIG speeds the pupa's digging up
## and LONG_FLIGHT slows the moth's sinking while gliding.
static func apply(sim: PlatformSim, ids: Array[String]) -> void:
	for id in ids:
		var u: UpgradeDef = SimUpgrades.find(id)
		if u == null or u.scope != "PLATFORM" or sim.upgrades.has(id):
			continue
		sim.upgrades.append(id)
		match u.effect:
			"EXTRA_HEART":
				sim.player.max_hearts += roundi(u.amount)
				sim.player.hearts += roundi(u.amount)
			"FAST_DIG":
				sim.dig_speed_mult += u.amount / 100.0
			"LONG_FLIGHT":
				sim.glide_fall_mult = maxf(0.1, sim.glide_fall_mult - u.amount / 100.0)
