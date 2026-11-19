## Screenshots the UI screens at desktop and phone-landscape sizes to /tmp/claude-1000/cucs_ui_*.png. Needs a display.
##   godot --path . res://tools/CaptureUi.tscn
## The stage card is captured once per stage as /tmp/claude-1000/stage_<STAGE>[<CUCS_TAG>]_<w>x<h>.png:
##   CUCS_DPI=440 CUCS_SIZE=2000x900 godot --path . res://tools/CaptureUi.tscn -- stage_card
extends Node

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844), Vector2i(2000, 900)]
const SCREENS: Dictionary = {
	"boot": "res://ui/menus/Boot.tscn",
	"lobby": "res://ui/menus/Lobby.tscn",
	"rotate": "res://ui/menus/RotateOverlay.tscn",
	"hud": "res://combat/hud/HudPreview.tscn",
	"victory": "res://combat/hud/HudPreview.tscn",
	"story_map": "res://ui/story/StoryMap.tscn",
	"stage_card": "res://ui/story/StageCard.tscn",
	"level_intro": "res://ui/story/LevelIntro.tscn",
	"story_results": "res://ui/story/StoryResults.tscn",
	"nest_hub": "res://ui/story/NestHub.tscn",
}
const OUT_DIR := "/tmp/claude-1000"


func _ready() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	# CUCS_LEVEL=<level id> sets the level of the story screens. CUCS_DPI=486 simulates a phone screen (and the touch UI) at every size.
	if OS.get_environment("CUCS_DPI") != "":
		TouchMetrics.force_dpi = float(OS.get_environment("CUCS_DPI"))
		TouchMetrics.force = 1
	if OS.get_environment("CUCS_CUTOUT") != "": # e.g. CUCS_CUTOUT=110 simulates a camera hole of 110 px on the left edge
		TouchMetrics.force_cutout = Vector4(float(OS.get_environment("CUCS_CUTOUT")), 0, 0, 0)
	var sizes: Array[Vector2i] = SIZES
	if OS.get_environment("CUCS_SIZE") != "": # e.g. CUCS_SIZE=2000x900
		var wh: PackedStringArray = OS.get_environment("CUCS_SIZE").split("x")
		sizes = [Vector2i(int(wh[0]), int(wh[1]))]
	for sz in sizes:
		get_window().size = sz
		await get_tree().create_timer(0.3).timeout
		for screen_name: String in SCREENS:
			if not only.is_empty() and not only.has(screen_name):
				continue
			if not ResourceLoader.exists(SCREENS[screen_name]):
				continue
			if screen_name.begins_with("story_") or screen_name == "level_intro" or screen_name == "stage_card" or screen_name == "nest_hub":
				# CUCS_LEVEL=cuca_boss picks another level (default egg_1).
				var level_id: String = OS.get_environment("CUCS_LEVEL") if OS.get_environment("CUCS_LEVEL") != "" else "egg_1"
				GameState.story_level = load("res://data/levels/%s.tres" % level_id)
				GameState.story_result = {"level_id": level_id, "won": true, "survivors": 2, "stars": 2, "reason": "SURVIVED", "rounds": 4}
			var variants: Array[String] = [""]
			if screen_name == "stage_card":
				variants.assign(StoryUi.STAGES)
			for variant in variants:
				if variant != "":
					StageCard.request(variant, true) # opened like the "?" of the map: shows `variant` whatever the level
				var inst: Node = (load(SCREENS[screen_name]) as PackedScene).instantiate()
				if screen_name == "rotate":
					inst.force_phone = true
				if screen_name == "victory":
					inst.show_victory = true
					inst.drawer_open = false
				add_child(inst)
				for i in 12:
					await get_tree().process_frame
				await get_tree().create_timer(0.4).timeout
				var img: Image = get_viewport().get_texture().get_image()
				var path: String = "%s/cucs_ui%s_%s_%dx%d.png" % [OUT_DIR, OS.get_environment("CUCS_TAG"), screen_name, sz.x, sz.y]
				if variant != "":
					path = "%s/stage_%s%s_%dx%d.png" % [OUT_DIR, variant, OS.get_environment("CUCS_TAG"), sz.x, sz.y]
				img.save_png(path)
				print("saved ", path, " viewport ", get_viewport().get_visible_rect().size)
				inst.queue_free()
				await get_tree().process_frame
	get_tree().quit()
