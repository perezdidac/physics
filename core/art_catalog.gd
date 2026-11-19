## Art paths by name: gameplay code asks ArtCatalog for textures and never writes res://assets/... itself.
class_name ArtCatalog
extends RefCounted

const WEAPON_ICON_DIR := "res://assets/sprites/weapon_icons/"

static var _weapon_icons: Dictionary = {}

const BACKGROUNDS: Dictionary = {
	"cadaques": "res://assets/backgrounds/bg_cadaques.jpg",
	"castellfollit": "res://assets/backgrounds/bg_castellfollit.jpg",
	"delta": "res://assets/backgrounds/bg_delta.jpg",
	"montblanc": "res://assets/backgrounds/bg_montblanc.jpg",
	"montserrat": "res://assets/backgrounds/bg_montserrat.jpg",
	"pedraforca": "res://assets/backgrounds/bg_pedraforca.jpg",
	"tarraco": "res://assets/backgrounds/bg_tarraco.jpg",
	"taull": "res://assets/backgrounds/bg_taull.jpg",
	# Story-mode backgrounds (Gemini, prompts in docs/background_prompts.md).
	"cardona_glacada": "res://assets/backgrounds/bg_cardona_glacada.jpg",
	"cerdanya_neu": "res://assets/backgrounds/bg_cerdanya_neu.jpg",
	"collserola_barcelona": "res://assets/backgrounds/bg_collserola_barcelona.jpg",
	"costa_brava_pins": "res://assets/backgrounds/bg_costa_brava_pins.jpg",
	"emporda_sant_pere": "res://assets/backgrounds/bg_emporda_sant_pere.jpg",
	"garrotxa_volcans": "res://assets/backgrounds/bg_garrotxa_volcans.jpg",
	"montserrat_nit": "res://assets/backgrounds/bg_montserrat_nit.jpg",
	"pinar_montseny": "res://assets/backgrounds/bg_pinar_montseny.jpg",
	"pinar_montserrat_capvespre": "res://assets/backgrounds/bg_pinar_montserrat_capvespre.jpg",
	"pinar_montserrat_tempesta": "res://assets/backgrounds/bg_pinar_montserrat_tempesta.jpg",
	"poblet_tardor": "res://assets/backgrounds/bg_poblet_tardor.jpg",
	"siurana_tardor": "res://assets/backgrounds/bg_siurana_tardor.jpg",
	"sota_terra_pedraforca": "res://assets/backgrounds/bg_sota_terra_pedraforca.jpg",
	"tossa_nit": "res://assets/backgrounds/bg_tossa_nit.jpg",
}


## Returns the background texture registered as `key`, or null if unknown.
static func background(key: String) -> Texture2D:
	if not BACKGROUNDS.has(key):
		push_error("ArtCatalog: unknown background '%s'" % key)
		return null
	return load(BACKGROUNDS[key]) as Texture2D


## Weapon icon (assets/sprites/weapon_icons/<id>.svg) of a weapon id such as "BAZOOKA", or null if unknown.
static func weapon_icon(id: String) -> Texture2D:
	var key: String = id.to_lower()
	if not _weapon_icons.has(key):
		var path: String = WEAPON_ICON_DIR + key + ".svg"
		_weapon_icons[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _weapon_icons[key]
