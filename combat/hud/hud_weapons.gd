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


## The story-only weapons (sim indices 16 to 19, present only when a level is loaded). Their icons are drawn in code.
const STORY_LIST: Array[Dictionary] = [
	{"id": "EMPENTA", "key": "1", "type": "MELEE", "fuse": false, "ammo": -1},
	{"id": "MOSSEGADA", "key": "2", "type": "MELEE", "fuse": false, "ammo": -1},
	{"id": "PICOTADA", "key": "3", "type": "MELEE", "fuse": false, "ammo": -1},
	{"id": "PICOTADA_FORTA", "key": "4", "type": "MELEE", "fuse": false, "ammo": -1},
	{"id": "PERXADA", "key": "5", "type": "MELEE", "fuse": false, "ammo": -1},
]
const STORY_ICONS: Dictionary = {
	"EMPENTA": "<svg xmlns='http://www.w3.org/2000/svg' width='36' height='22' viewBox='0 0 36 22'><g fill='none' stroke='#f6cf77' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><path d='M5 4 L13 11 L5 18'/><path d='M15 4 L23 11 L15 18'/></g><circle cx='30' cy='11' r='4' fill='#f3e5c1' stroke='#7d6740' stroke-width='1.5'/></svg>",
	"PICOTADA": PICOTADA_ICON,
	"PICOTADA_FORTA": PICOTADA_FORTA_ICON,
	"PERXADA": PICOTADA_ICON,
	"MOSSEGADA": "<svg xmlns='http://www.w3.org/2000/svg' width='36' height='22' viewBox='0 0 36 22'><g fill='#f3e5c1' stroke='#7d6740' stroke-width='1.4' stroke-linejoin='round'><path d='M4 3 L32 3 L28 10 L24 6 L20 11 L16 6 L12 11 L8 6 Z'/><path d='M4 19 L32 19 L28 12 L24 16 L20 11 L16 16 L12 11 L8 16 Z'/></g></svg>",
}
## The peck of the blue tit: a beak striking down.
const PICOTADA_ICON: String = "<svg xmlns='http://www.w3.org/2000/svg' width='36' height='22' viewBox='0 0 36 22'><path d='M4 4 L26 9 L6 14 Z' fill='#2b2d33' stroke='#f3e5c1' stroke-width='1.6' stroke-linejoin='round'/><path d='M6 14 L24 12 L9 19 Z' fill='#3a3f4a' stroke='#f3e5c1' stroke-width='1.6' stroke-linejoin='round'/><g stroke='#f6cf77' stroke-width='2.4' stroke-linecap='round'><path d='M29 4 L33 2'/><path d='M30 11 L35 11'/><path d='M29 18 L33 20'/></g></svg>"
const PICOTADA_FORTA_ICON: String = "<svg xmlns='http://www.w3.org/2000/svg' width='36' height='22' viewBox='0 0 36 22'><path d='M4 4 L26 9 L6 14 Z' fill='#2b2d33' stroke='#f3e5c1' stroke-width='1.6' stroke-linejoin='round'/><path d='M6 14 L24 12 L9 19 Z' fill='#3a3f4a' stroke='#f3e5c1' stroke-width='1.6' stroke-linejoin='round'/><g stroke='#ff6b5b' stroke-width='2.4' stroke-linecap='round'><path d='M29 4 L33 2'/><path d='M30 11 L35 11'/><path d='M29 18 L33 20'/></g></svg>"
static var _story_icons: Dictionary = {}


## Index of the weapon with this id, or -1.
static func index_of_id(weapon_id: String) -> int:
	for i in total():
		if id_of(i) == weapon_id:
			return i
	return -1


## Id of the weapon at `idx`.
static func id_of(idx: int) -> String:
	return String(_entry(idx)["id"])


## Ids of the weapons unlocked by the last story level won (the "NEW!" badge); empty before the first win.
static func new_ids(progress: Node) -> Array[String]:
	var out: Array[String] = []
	var last: LevelDef = null
	for level: LevelDef in progress.call("levels"):
		if int(progress.call("stars", level.id)) >= 1:
			last = level
	if last != null:
		out.assign(last.unlocks)
	return out


## Number of classic weapons (the story-only ones are reached through `total()`).
static func count() -> int:
	return LIST.size()


## Number of weapons including the story-only ones.
static func total() -> int:
	return LIST.size() + STORY_LIST.size()


static func _entry(idx: int) -> Dictionary:
	return LIST[idx] if idx < LIST.size() else STORY_LIST[idx - LIST.size()]


## Translation key of the weapon name.
static func name_key(idx: int) -> String:
	return ("WEAPON_%s" if idx < LIST.size() else "WPN_%s") % _entry(idx)["id"]


## Hotkey as shown in the slot (upper case).
static func hotkey_label(idx: int) -> String:
	return String(_entry(idx)["key"]).to_upper()


## True if the weapon uses the fuse picker.
static func has_fuse(idx: int) -> bool:
	return bool(_entry(idx)["fuse"])


## Index of the weapon whose hotkey is `key_text` (case-insensitive), or -1.
static func index_of_key(key_text: String) -> int:
	for i in LIST.size():
		if String(LIST[i]["key"]) == key_text.to_lower():
			return i
	return -1


## Icon texture of the weapon (cached by ArtCatalog).
static func icon(idx: int) -> Texture2D:
	if idx < LIST.size():
		return ArtCatalog.weapon_icon(String(LIST[idx]["id"]))
	var id: String = String(_entry(idx)["id"])
	if not _story_icons.has(id):
		var img := Image.new()
		img.load_svg_from_string(String(STORY_ICONS[id]))
		_story_icons[id] = ImageTexture.create_from_image(img)
	return _story_icons[id]


## Translation key of the fire label of weapon `idx` (JS buildWeaponBar, main.js:1719-1731).
static func fire_label_key(idx: int) -> String:
	var w: Dictionary = _entry(idx)
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
	var id: String = _entry(idx)["id"]
	if team_ammo is Array and team >= 0 and team < (team_ammo as Array).size():
		var d: Variant = team_ammo[team]
		if d is Dictionary:
			var dict: Dictionary = d
			var v: Variant = dict.get(id, dict.get(id.to_lower(), null))
			if v != null:
				var f: float = float(v)
				return INFINITE if (is_inf(f) or f < 0.0) else int(f)
	return int(_entry(idx)["ammo"])
