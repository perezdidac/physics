## One weapon of the arsenal (see data/weapons/). The list order is the JS index.
class_name WeaponDef
extends Resource

## Weapon id used everywhere in the sim (BAZOOKA, GRENADE, ...).
@export var id: String = ""
## Keyboard shortcut character.
@export var key: String = ""
## Translation key of the display name.
@export var name_key: String = ""
## Starting ammo per team; -1 means unlimited.
@export var default_ammo: int = -1
## CHARGE, INSTANT, MELEE, DROP, TARGET_MAP, UTILITY_JET or TOOL_AIM.
@export var type: String = ""
@export var wind_factor: float = 0.0
@export var fuse: float = 0.0
@export var has_custom_fuse: bool = false
@export var blast_r: float = 0.0
@export var max_dmg: float = 0.0
@export var knockback: float = 0.0
## Melee reach in pixels (0 when not a melee weapon).
@export var reach: float = 0.0
## Icon filled in later by the data/i18n wave.
@export var icon: Texture2D
