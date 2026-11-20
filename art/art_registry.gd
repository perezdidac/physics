## Kind id -> ThingArt. Views draw with `ArtRegistry.draw("barrel", ci, state, ctx)`.
## Open/closed: a kind is added by writing a ThingArt class and one `reg.add(...)` line in the registry file of its group
## (art/groups/*_group.gd); nothing here matches on ids. Adding a whole new group = one line in GROUPS.
## Ids are plain strings ("barrel", "creature:ANT", "boss:cuckoo"); `resolve` also accepts the longest registered prefix
## (registered with `add_prefix`), which maps families such as LARVA_L1..L5 onto one art.
class_name ArtRegistry
extends RefCounted

## One registry script per group; each has `static func register(reg: ArtRegistry) -> void`.
const GROUPS: Array[String] = [
	"res://art/groups/props_group.gd",
	"res://art/groups/flora_group.gd",
	"res://art/groups/platform_props_group.gd",
	"res://art/groups/weapons_group.gd",
	"res://art/groups/creatures_combat_group.gd",
	"res://art/groups/creatures_platform_group.gd",
	"res://art/groups/bosses_group.gd",
	"res://art/groups/scene_group.gd",
]

static var _instance: ArtRegistry = null

var _arts: Dictionary = {}
var _prefixes: Dictionary = {}
var _group_of: Dictionary = {}
var _current_group: String = ""


## The shared registry, built on first use.
static func get_instance() -> ArtRegistry:
	if _instance == null:
		_instance = ArtRegistry.new()
		for path in GROUPS:
			var script: GDScript = load(path) as GDScript
			_instance._current_group = path.get_file().trim_suffix("_group.gd")
			script.call("register", _instance)
		_instance._current_group = ""
		# Lambdas held by the adapters must be freed before the script server shuts down, or the engine corrupts its heap at exit.
		var loop: SceneTree = Engine.get_main_loop() as SceneTree
		if loop != null:
			loop.root.tree_exiting.connect(shutdown, CONNECT_ONE_SHOT)
	return _instance


## Drops the shared registry (and the sprite and context caches); the next use rebuilds it. Used by tests and at shutdown.
static func shutdown() -> void:
	_instance = null
	SpriteArt.clear_cache()
	ArtContext.clear_shared()


## Draws one instance; an unknown id draws nothing (and is caught by the registry test).
static func draw(id: String, ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	var art: ThingArt = get_instance().resolve(id)
	if art != null:
		art.draw(ci, state, ctx)


## Registers `art` under the exact `id`.
func add(id: String, art: ThingArt) -> void:
	assert(not _arts.has(id), "art kind registered twice: " + id)
	_arts[id] = art
	_group_of[id] = _current_group


## Registers `art` for every id that starts with `prefix` and has no exact entry.
func add_prefix(prefix: String, art: ThingArt) -> void:
	_prefixes[prefix] = art
	_group_of["prefix:" + prefix] = _current_group


## Exact id first, then the longest registered prefix; null when nothing matches.
func resolve(id: String) -> ThingArt:
	if _arts.has(id):
		return _arts[id]
	var best: String = ""
	for p: String in _prefixes:
		if id.begins_with(p) and p.length() > best.length():
			best = p
	if best != "":
		return _prefixes[best]
	return null


func has_kind(id: String) -> bool:
	return resolve(id) != null


## Replaces the art of an exact id (tests and phase-2 swaps at runtime).
func replace(id: String, art: ThingArt) -> void:
	_arts[id] = art


## Sorted exact ids (prefix entries are listed as "prefix*").
func kinds() -> Array[String]:
	var out: Array[String] = []
	for k: String in _arts:
		out.append(k)
	for p: String in _prefixes:
		out.append(p + "*")
	out.sort()
	return out


## Group name ("props", "flora", ...) a kind was registered in.
func group_of(id: String) -> String:
	if _group_of.has(id):
		return _group_of[id]
	if id.ends_with("*") and _group_of.has("prefix:" + id.trim_suffix("*")):
		return _group_of["prefix:" + id.trim_suffix("*")]
	return ""


## Exact art of an id or of a prefix entry written as "NAME*" (for the contact sheet).
func art_of(id: String) -> ThingArt:
	if id.ends_with("*"):
		return _prefixes.get(id.trim_suffix("*"), null)
	return _arts.get(id, null)
