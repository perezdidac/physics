## UI-side table of the 16 weapons (order = JS WEAPONS index): hotkey, translation key, type, fuse picker flag, icon.
## Gameplay values live in the sim (WeaponDef); this table only feeds the HUD texts and icons.
class_name HudWeapons
extends RefCounted

## Infinite ammo marker used by the HUD (the sim may report -1 or INF).
const INFINITE := -1

## id, key, type, has_custom_fuse, default_ammo (-1 = infinite)
const LIST: Array[Dictionary] = [
	{"id": "BAZOOKA", "key": "1", "type": "CHARGE", "fuse": false, "ammo": -1},
	{"id": "CARQUINYOLI", "key": "2", "type": "CHARGE", "fuse": false, "ammo": -1},
	{"id": "GRENADE", "key": "3", "type": "CHARGE", "fuse": true, "ammo": -1},
	{"id": "CLUSTER", "key": "4", "type": "CHARGE", "fuse": true, "ammo": 3},
	{"id": "URTICARIA", "key": "5", "type": "CHARGE", "fuse": false, "ammo": 3},
	{"id": "SHOTGUN", "key": "6", "type": "INSTANT", "fuse": false, "ammo": -1},
	{"id": "FUET", "key": "7", "type": "MELEE", "fuse": false, "ammo": -1},
	{"id": "BAT", "key": "8", "type": "MELEE", "fuse": false, "ammo": -1},
	{"id": "DYNAMITE", "key": "9", "type": "DROP", "fuse": false, "ammo": 2},
	{"id": "HOLY", "key": "0", "type": "CHARGE", "fuse": false, "ammo": 1},
	{"id": "AIRSTRIKE", "key": "-", "type": "TARGET_MAP", "fuse": false, "ammo": 2},
	{"id": "JETPACK", "key": "=", "type": "UTILITY_JET", "fuse": false, "ammo": 2},
	{"id": "CULLERA", "key": "u", "type": "TOOL_AIM", "fuse": false, "ammo": 3},
	{"id": "BARRINA", "key": "i", "type": "TOOL_AIM", "fuse": false, "ammo": 3},
	{"id": "PONT_PEDRA", "key": "o", "type": "TOOL_AIM", "fuse": false, "ammo": 3},
	{"id": "GANXO", "key": "p", "type": "TOOL_AIM", "fuse": false, "ammo": 3},
]


## Number of weapons.
static func count() -> int:
	return LIST.size()


## Translation key of the weapon name.
static func name_key(idx: int) -> String:
	return "WEAPON_%s" % LIST[idx]["id"]


## Hotkey as shown in the slot (upper case).
static func hotkey_label(idx: int) -> String:
	return String(LIST[idx]["key"]).to_upper()


## True if the weapon uses the fuse picker.
static func has_fuse(idx: int) -> bool:
	return bool(LIST[idx]["fuse"])


## Index of the weapon whose hotkey is `key_text` (case-insensitive), or -1.
static func index_of_key(key_text: String) -> int:
	for i in LIST.size():
		if String(LIST[i]["key"]) == key_text.to_lower():
			return i
	return -1


## Icon texture of the weapon (cached by ArtCatalog).
static func icon(idx: int) -> Texture2D:
	return ArtCatalog.weapon_icon(String(LIST[idx]["id"]))


## Translation key of the fire label of weapon `idx` (JS buildWeaponBar, main.js:1719-1731).
static func fire_label_key(idx: int) -> String:
	var w: Dictionary = LIST[idx]
	var id: String = w["id"]
	var type: String = w["type"]
	if type == "CHARGE":
		return "FIRE_HOLD"
	match id:
		"AIRSTRIKE":
			return "FIRE_AIRSTRIKE"
		"CULLERA":
			return "FIRE_CULLERA"
		"BARRINA":
			return "FIRE_BARRINA"
		"PONT_PEDRA":
			return "FIRE_PONT_PEDRA"
		"GANXO":
			return "FIRE_GANXO"
	match type:
		"MELEE":
			return "FIRE_MELEE"
		"DROP":
			return "FIRE_DROP"
		"UTILITY_JET":
			return "FIRE_JET"
	return "FIRE_DEFAULT"


## Ammo of weapon `idx` for `team` from the sim's `team_ammo` (Array of Dictionaries keyed by weapon id). Returns -1 for infinite.
static func ammo_for(team_ammo: Variant, team: int, idx: int) -> int:
	var id: String = LIST[idx]["id"]
	if team_ammo is Array and team >= 0 and team < (team_ammo as Array).size():
		var d: Variant = team_ammo[team]
		if d is Dictionary:
			var dict: Dictionary = d
			var v: Variant = dict.get(id, dict.get(id.to_lower(), null))
			if v != null:
				var f: float = float(v)
				return INFINITE if (is_inf(f) or f < 0.0) else int(f)
	return int(LIST[idx]["ammo"])
