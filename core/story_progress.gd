## Story-mode progress (stars per level), saved in user://story.cfg. See docs/story_contracts.md section 4.
extends Node

const LEVEL_LIST_PATH := "res://data/levels/level_list.tres"
const SECTION := "stars"
## Hub data of the save: the ids of the owned upgrades (an old save without it loads as "none owned").
const HUB_SECTION := "hub"
const UPGRADES_KEY := "upgrades"
## Stage cards already shown (ids of LevelDef.stage), saved with the progress.
const STAGES_SECTION := "stage_cards"
const STAGES_KEY := "seen"
const UPGRADE_LIST_PATH := "res://data/upgrades/upgrade_list.tres"
## Silk earned for each star won for the first time.
const SILK_PER_STAR := 6

## Where the progress is saved (tests point it elsewhere).
var save_path: String = "user://story.cfg"
var _stars: Dictionary = {}
var _owned: Array[String] = []
var _stages_seen: Array[String] = []


func _ready() -> void:
	load_progress()


## Every story level in campaign order.
func levels() -> Array[LevelDef]:
	var list: LevelList = load(LEVEL_LIST_PATH)
	var out: Array[LevelDef] = []
	if list != null:
		out.assign(list.levels)
	return out


## The first level is always open; each next one opens once the previous one is won. Levels not `playable` stay locked.
func is_unlocked(level: LevelDef) -> bool:
	if level == null or not level.playable:
		return false
	var all: Array[LevelDef] = levels()
	var idx: int = all.find(level)
	if idx < 0:
		for i in all.size():
			if all[i].id == level.id:
				idx = i
	if idx <= 0:
		return idx == 0
	return stars(all[idx - 1].id) >= 1


## Best stars (0-3) won on a level; 0 = never won.
func stars(level_id: String) -> int:
	return int(_stars.get(level_id, 0))


## Sum of the best stars of a list of levels.
func total_stars() -> int:
	var sum: int = 0
	for level in levels():
		sum += stars(level.id)
	return sum


## Ids of the weapons unlocked by the levels won so far.
func unlocked_weapons() -> Array[String]:
	var out: Array[String] = []
	for level in levels():
		if stars(level.id) >= 1:
			for w in level.unlocks:
				if not out.has(w):
					out.append(w)
	return out


## Stores the `game_over` stats of a story match (keeps the best stars) and saves. Returns the silk it earned: SILK_PER_STAR for every
## star won for the first time (0 when the result is not a win or beats nothing).
func record_result(stats: Dictionary) -> int:
	var level_id: String = str(stats.get("level_id", ""))
	if level_id.is_empty() or not bool(stats.get("won", false)):
		return 0
	var earned: int = clampi(int(stats.get("stars", 0)), 0, 3)
	var before: int = stars(level_id)
	if earned > before:
		_stars[level_id] = earned
		save_progress()
		return (earned - before) * SILK_PER_STAR
	return 0


## Every upgrade of the hub in shop order.
func upgrades() -> Array[UpgradeDef]:
	var list: UpgradeList = load(UPGRADE_LIST_PATH)
	var out: Array[UpgradeDef] = []
	if list != null:
		out.assign(list.upgrades)
	return out


## The upgrade with this id (null when unknown).
func upgrade(id: String) -> UpgradeDef:
	for u in upgrades():
		if u.id == id:
			return u
	return null


## Ids of the upgrades bought so far, in the order they were bought.
func owned_upgrades() -> Array[String]:
	return _owned.duplicate()


func owns(id: String) -> bool:
	return _owned.has(id)


## Silk earned in all: SILK_PER_STAR for every star of the best results (so an old save gets its silk too).
func silk_earned() -> int:
	return total_stars() * SILK_PER_STAR


## Silk to spend: what was earned minus the price of the owned upgrades.
func silk() -> int:
	var spent: int = 0
	for id in _owned:
		spent += upgrade(id).cost
	return maxi(0, silk_earned() - spent)


## True when the upgrade has no requirement or its tier I is owned.
func can_unlock(u: UpgradeDef) -> bool:
	return u.requires.is_empty() or _owned.has(u.requires)


## Silk a player gets with 3 stars in every level (the shop's total price must stay below it).
func silk_max() -> int:
	return levels().size() * 3 * SILK_PER_STAR


## Total price of the whole shop.
func shop_total() -> int:
	var sum: int = 0
	for u in upgrades():
		sum += u.cost
	return sum


## Buys an upgrade with silk and saves. False when the id is unknown, already owned or too expensive.
func buy(id: String) -> bool:
	var u: UpgradeDef = upgrade(id)
	if u == null or _owned.has(id) or u.cost > silk() or not can_unlock(u):
		return false
	_owned.append(id)
	save_progress()
	return true


## Gives every upgrade back (all the silk is free again) and saves; for tests and debugging.
func refund_all() -> void:
	_owned.clear()
	save_progress()


## True once the stage card of `stage` (how that life stage plays) has been shown.
func stage_intro_seen(stage: String) -> bool:
	return _stages_seen.has(stage)


## Remembers that the stage card of `stage` was shown (and saves).
func mark_stage_intro_seen(stage: String) -> void:
	if stage.is_empty() or _stages_seen.has(stage):
		return
	_stages_seen.append(stage)
	save_progress()


## Reads the save file (a missing or broken file means no progress).
func load_progress() -> void:
	_stars.clear()
	_owned.clear()
	_stages_seen.clear()
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	for key in cfg.get_section_keys(SECTION) if cfg.has_section(SECTION) else PackedStringArray():
		_stars[key] = clampi(int(cfg.get_value(SECTION, key, 0)), 0, 3)
	for stage in cfg.get_value(STAGES_SECTION, STAGES_KEY, []) if cfg.has_section(STAGES_SECTION) else []:
		if not _stages_seen.has(str(stage)):
			_stages_seen.append(str(stage))
	var saved: Variant = cfg.get_value(HUB_SECTION, UPGRADES_KEY, [])
	# An id that no longer exists (or whose tier I is missing) is dropped: silk is derived from the stars, so it is refunded.
	for id in saved if saved is Array else []:
		var u: UpgradeDef = upgrade(str(id))
		if u != null and not _owned.has(u.id) and (u.requires.is_empty() or _owned.has(u.requires)):
			_owned.append(u.id)


## Writes the save file.
func save_progress() -> void:
	var cfg := ConfigFile.new()
	for key: String in _stars:
		cfg.set_value(SECTION, key, _stars[key])
	cfg.set_value(HUB_SECTION, UPGRADES_KEY, _owned.duplicate())
	cfg.set_value(STAGES_SECTION, STAGES_KEY, _stages_seen.duplicate())
	cfg.save(save_path)


## Forgets all progress (tests, future "new game").
func reset_progress() -> void:
	_stars.clear()
	_owned.clear()
	_stages_seen.clear()
	save_progress()
