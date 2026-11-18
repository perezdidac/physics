## View-side map facts (sky palette, water colours, weather, background key). Fallback table copied from world.js MAPS;
## the sim's MapDef wins when it provides the same field.
class_name ViewMaps
extends RefCounted

const TABLE: Array[Dictionary] = [
	{"id": "MONTSERRAT", "bg": "montserrat", "weather": "POLLEN", "sky": ["#2a1e2e", "#593b4f", "#9c6352", "#de9659", "#fae6b1"], "water_top": "rgba(42, 114, 122, 0.82)", "water_deep": "rgba(12, 36, 44, 0.98)"},
	{"id": "CADAQUES", "bg": "cadaques", "weather": "GULLS_BREEZE", "sky": ["#10355c", "#1f5a8f", "#4287bd", "#7eb8de", "#cbe6f7"], "water_top": "rgba(18, 152, 178, 0.82)", "water_deep": "rgba(6, 42, 68, 0.98)"},
	{"id": "TAULL", "bg": "taull", "weather": "SNOW", "sky": ["#172b47", "#2c4c73", "#527ca6", "#8eb3d4", "#d9eaf7"], "water_top": "rgba(48, 126, 162, 0.82)", "water_deep": "rgba(10, 32, 52, 0.98)"},
	{"id": "CASTELLFOLLIT", "bg": "castellfollit", "weather": "AUTUMN_LEAVES", "sky": ["#2b1d1c", "#633c2e", "#a8673e", "#dea05a", "#f7d89c"], "water_top": "rgba(44, 106, 112, 0.82)", "water_deep": "rgba(14, 34, 38, 0.98)"},
	{"id": "DELTA_EBRE", "bg": "delta", "weather": "POLLEN", "sky": ["#2d1b38", "#733857", "#c45d56", "#f29f60", "#ffebb3"], "water_top": "rgba(38, 166, 154, 0.82)", "water_deep": "rgba(10, 52, 56, 0.98)"},
	{"id": "TARRACO", "bg": "tarraco", "weather": "GULLS_BREEZE", "sky": ["#162a4a", "#2e557c", "#6e7889", "#d98a54", "#fce0a2"], "water_top": "rgba(22, 138, 188, 0.84)", "water_deep": "rgba(8, 36, 68, 0.98)"},
	{"id": "PEDRAFORCA", "bg": "pedraforca", "weather": "SNOW", "sky": ["#1a1636", "#382e63", "#5c5b94", "#8ea8cf", "#dbf0fa"], "water_top": "rgba(54, 142, 176, 0.82)", "water_deep": "rgba(14, 38, 58, 0.98)"},
	{"id": "MONTBLANC", "bg": "montblanc", "weather": "AUTUMN_LEAVES", "sky": ["#24111c", "#541e33", "#8f3438", "#cf6a44", "#f7be79"], "water_top": "rgba(64, 96, 118, 0.82)", "water_deep": "rgba(18, 26, 40, 0.98)"},
]


## Resolved facts of the map being played: {id, bg, weather, sky: Array[Color] (5), water_top: Color, water_deep: Color}.
static func resolve(sim: Object) -> Dictionary:
	var terrain: Variant = ViewUtil.g(sim, "terrain")
	var map: Variant = ViewUtil.g(terrain, "map")
	var idx: int = ViewUtil.gi(map, "idx", ViewUtil.gi(map, "index", -1))
	if idx < 0:
		idx = ViewUtil.gi(sim, "map_idx", ViewUtil.gi(terrain, "map_idx", 0))
	var base: Dictionary = TABLE[posmod(idx, TABLE.size())]
	var out: Dictionary = {}
	var map_id: String = ViewUtil.gs(map, "id", "")
	if map_id != "":
		for t in TABLE:
			if t["id"] == map_id:
				base = t
				break
	out["id"] = ViewUtil.gs(map, "id", str(base["id"]))
	out["bg"] = ViewUtil.gs(map, "background_key", str(base["bg"]))
	out["weather"] = ViewUtil.gs(map, "weather", str(base["weather"]))
	var sky_src: Variant = ViewUtil.g(map, "sky", base["sky"])
	var sky: Array[Color] = []
	for i in 5:
		sky.append(ViewColors.parse(sky_src[i] if (sky_src is Array or sky_src is PackedColorArray) and (sky_src as Variant).size() > i else base["sky"][i]))
	out["sky"] = sky
	out["water_top"] = ViewColors.parse(ViewUtil.g(map, "water_top", base["water_top"]))
	out["water_deep"] = ViewColors.parse(ViewUtil.g(map, "water_deep", base["water_deep"]))
	return out
