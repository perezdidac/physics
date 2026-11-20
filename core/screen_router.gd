## The only place that changes screens. Screens are registered by name so callers never write scene paths.
## It also keeps the UI readable on small windows: below 1280x720 it raises the content scale so logical pixels stay near physical ones.
extends Node

## Screen name → scene path.
const SCREENS: Dictionary = {
	"boot": "res://ui/menus/Boot.tscn",
	"lobby": "res://ui/menus/Lobby.tscn",
	"combat": "res://combat/CombatScreen.tscn",
	"platform": "res://platform/PlatformScreen.tscn",
	"story_map": "res://ui/story/StoryMap.tscn",
	"stage_card": "res://ui/story/StageCard.tscn",
	"level_intro": "res://ui/story/LevelIntro.tscn",
	"story_results": "res://ui/story/StoryResults.tscn",
	"nest_hub": "res://ui/story/NestHub.tscn",
}
const BASE_SIZE := Vector2(1280.0, 720.0)
const MAX_UI_SCALE := 3.5


func _ready() -> void:
	var window: Window = get_window()
	if window != null:
		window.size_changed.connect(_update_content_scale)
		_update_content_scale()


## Switches to the screen registered as `screen_name`.
func go(screen_name: String) -> void:
	if not SCREENS.has(screen_name):
		push_error("ScreenRouter: unknown screen '%s'" % screen_name)
		return
	get_tree().change_scene_to_file(SCREENS[screen_name])


## Content scale factor for a window of `size`: 1 on windows of 1280x720 or more, up to MAX_UI_SCALE on small ones.
func content_scale_for(size: Vector2) -> float:
	var base_scale: float = minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	if base_scale <= 0.0 or base_scale >= 1.0:
		return 1.0
	return minf(1.0 / base_scale, MAX_UI_SCALE)


func _update_content_scale() -> void:
	var window: Window = get_window()
	window.content_scale_factor = content_scale_for(Vector2(window.size))
