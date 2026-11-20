## Texture lookup for the platformer prop sprites that are drawn stretched or in several pieces (needle, puddle rim, flag cloth).
## The single-sprite kinds use SpriteArt directly.
class_name PlatformSprites
extends RefCounted

const GROUP := "platform_props"

static var _cache: Dictionary = {}


## The imported texture of assets/sprites/platform_props/<id>.svg, or null while the file does not exist (cached either way).
static func tex(id: String) -> Texture2D:
	if not _cache.has(id):
		var p: String = "%s%s/%s.svg" % [SpriteArt.ROOT, GROUP, id]
		_cache[id] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _cache[id]


## True when every sprite id exists.
static func has_all(ids: Array[String]) -> bool:
	for id in ids:
		if tex(id) == null:
			return false
	return true


static func clear_cache() -> void:
	_cache.clear()
