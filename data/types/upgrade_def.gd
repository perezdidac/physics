## One hub upgrade bought with silk (docs/nest_contracts.md section 2, economy in docs/story_mode.md). Combat and nest upgrades are applied
## by the sim to story COMBAT matches (SimUpgrades); platform upgrades by PlatformSim to the egg, pupa and moth levels (PlatformUpgrades).
class_name UpgradeDef
extends Resource

@export var id: String = ""
## Translation keys of the name and the description.
@export var name_key: String = ""
@export var desc_key: String = ""
## Price in silk.
@export var cost: int = 20
## MAX_HP_PCT (squad max HP +amount %), DAMAGE_PCT (weapon damage +amount %), NEST_HP (nest HP +amount), WARM_SILK (no cold),
## EXTRA_SILK_WEB (two webs per turn), START_AMMO (+amount ammo for limited weapons), EXTRA_HEART (+amount hearts in platform levels),
## FAST_DIG (pupa dig speed +amount %) or LONG_FLIGHT (moth glide sinks amount % slower).
@export var effect: String = ""
@export var amount: float = 0.0
## Where it works: COMBAT (every turn-based level), NEST (only the nest levels) or PLATFORM (egg, pupa and moth levels).
@export var scope: String = "COMBAT"
## Id of the upgrade that must be owned first (a tier II needs its tier I); "" = none.
@export var requires: String = ""


## Translation key of the hub line saying where the upgrade works.
func where_key() -> String:
	return "UPG_WHERE_" + scope
