## Constant tables of the simulation (names, taunts, palettes, difficulty, text colours).
## Other data lives in data/ as Resources; these are the second-wave tables of the port contract.
class_name SimTables
extends RefCounted

const TERRAIN_W: int = 3200
const TERRAIN_H: int = 820
const WATER_Y_START: float = 700.0
const GRAVITY: float = 440.0

const NAMES_POOL_0: PackedStringArray = [
	"Peluda", "Serrallonga", "Pinassa", "Rovelló", "Botifarra", "Calçot",
	"Gaudí", "Garbí", "Fuet", "Escudella", "Barretina", "Porró",
	"Senyera", "Caganer", "Timbaler", "Casteller", "Enxaneta", "Gralla",
	"Sardana", "Ginesta", "Romaní", "Pinyó", "Llobregat", "Montseny",
	"Carquinyoli", "Crema", "Allioli", "Romesco", "Cargol", "Bolets",
]
const NAMES_POOL_1: PackedStringArray = [
	"Urticària", "Tramuntana", "Boira", "Espina", "Tió", "Fageda",
	"Ratafia", "Empordà", "Canigó", "Pedraforca", "Bruixa", "Drac",
	"Correfoc", "Diable", "Mestral", "Xaloc", "Llevant", "Pissarra",
	"Basalt", "Cingle", "Falç", "Trabuc", " Bandoler", "Gorg",
	"Albera", "Cadí", "Priorat", "Batea", "Lo Riu", "Garrotxa",
]

const HAT_STYLES: PackedStringArray = ["CATALAN", "CASTELLER", "BANDOLER", "PAGES", "BRISTLES"]

## Body palettes [fur, mid, dark].
const BODY_PALETTES: Array = [
	["#424859", "#252934", "#111318"],
	["#4f3d36", "#2e221d", "#16100d"],
	["#364a45", "#1e2b28", "#0e1514"],
	["#483b54", "#282030", "#130f18"],
	["#4d4738", "#2b281f", "#14120d"],
	["#384556", "#1f2733", "#0e131a"],
]
const DORSAL_PALETTES_0: PackedStringArray = ["#f58529", "#ffb338", "#e66030", "#ff9442", "#d99b26", "#f26d3d"]
const DORSAL_PALETTES_1: PackedStringArray = ["#e03a2b", "#ff5263", "#c92a42", "#eb4d36", "#d43559", "#ff6938"]

## AI aim jitter per difficulty (anything unknown behaves like VETERAN).
const AI_JITTER: Dictionary = {"ROOKIE": 0.095, "VETERAN": 0.042, "NIGHTMARE": 0.012}

const TEXTURE_STYLES: PackedStringArray = [
	"STRATA_WAVES", "BASALT_COLUMNS", "ASHLAR_BLOCKS", "CONGLOMERATE_PEBBLES", "SLATE_FRACTURES", "TERRACOTTA_DUNES",
]

## id and translation key of the 8 terrain archetypes.
const ARCHETYPES: Array = [
	["FEIXES_TERRACED", "ARCH_FEIXES_TERRACED"],
	["AGULLES_SPIRES", "ARCH_AGULLES_SPIRES"],
	["MULTI_DECK_GROTTO", "ARCH_MULTI_DECK_GROTTO"],
	["FLOATING_BALCONIES", "ARCH_FLOATING_BALCONIES"],
	["TWIN_MASSIFS", "ARCH_TWIN_MASSIFS"],
	["STEPPED_CANYONS", "ARCH_STEPPED_CANYONS"],
	["CITADEL_CALDERA", "ARCH_CITADEL_CALDERA"],
	["ARCHIPELAGO", "ARCH_ARCHIPELAGO"],
]

const LANDMARK_POOL: PackedStringArray = [
	"WATCHTOWER", "HOLLOW_LOG", "ROCK_ARCH", "MONOLITHS", "BRIDGE_SPAN", "SECOND_TOWER", "BARRACA_DELTA",
]

## Taunt translation keys per category (6/4/3/3/3 variants, see docs/i18n_keys_sim.md).
const TAUNTS: Dictionary = {
	"TURN": ["TAUNT_TURN_1", "TAUNT_TURN_2", "TAUNT_TURN_3", "TAUNT_TURN_4", "TAUNT_TURN_5", "TAUNT_TURN_6"],
	"HIT": ["TAUNT_HIT_1", "TAUNT_HIT_2", "TAUNT_HIT_3", "TAUNT_HIT_4"],
	"URTICARIA": ["TAUNT_URTICARIA_1", "TAUNT_URTICARIA_2", "TAUNT_URTICARIA_3"],
	"PROCESSION": ["TAUNT_PROCESSION_1", "TAUNT_PROCESSION_2", "TAUNT_PROCESSION_3"],
	"METAMORPH": ["TAUNT_METAMORPH_1", "TAUNT_METAMORPH_2", "TAUNT_METAMORPH_3"],
}

## Crate reward pool (uniform).
const CRATE_REWARDS: PackedStringArray = [
	"HOLY", "AIRSTRIKE", "DYNAMITE", "JETPACK", "CLUSTER", "URTICARIA", "CULLERA", "BARRINA", "PONT_PEDRA", "GANXO",
]

