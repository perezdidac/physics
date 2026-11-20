## Display data of the 8 maps for the menus (id, background key, translation keys). Gameplay data lives in data/maps.
class_name UiMaps
extends RefCounted

## Same order as the JS MAPS array (world.js:70-205): the index is `GameState.map_idx`.
const IDS: Array[String] = ["MONTSERRAT", "CADAQUES", "TAULL", "CASTELLFOLLIT", "DELTA_EBRE", "TARRACO", "PEDRAFORCA", "MONTBLANC"]
const BACKGROUNDS: Array[String] = ["montserrat", "cadaques", "taull", "castellfollit", "delta", "tarraco", "pedraforca", "montblanc"]


## Translation key of the map name.
static func name_key(idx: int) -> String:
	return "MAP_%s_NAME" % IDS[idx]


## Translation key of the map subtitle (landmarks).
static func sub_key(idx: int) -> String:
	return "MAP_%s_SUB" % IDS[idx]


## Translation key of the map badge.
static func badge_key(idx: int) -> String:
	return "MAP_%s_BADGE" % IDS[idx]


## Background texture of the map.
static func background(idx: int) -> Texture2D:
	return ArtCatalog.background(BACKGROUNDS[idx])
