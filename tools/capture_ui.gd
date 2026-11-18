## Screenshots the UI screens at desktop and phone-landscape sizes to /tmp/claude-1000/cucs_ui_*.png. Needs a display.
##   godot --path . res://tools/CaptureUi.tscn
extends Node

const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844)]
const SCREENS: Dictionary = {
	"boot": "res://ui/menus/Boot.tscn",
	"lobby": "res://ui/menus/Lobby.tscn",
	"rotate": "res://ui/menus/RotateOverlay.tscn",
	"hud": "res://combat/hud/HudPreview.tscn",
	"victory": "res://combat/hud/HudPreview.tscn",
}
const OUT_DIR := "/tmp/claude-1000"


func _ready() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	for sz in SIZES:
		get_window().size = sz
		await get_tree().create_timer(0.3).timeout
		for screen_name: String in SCREENS:
			if not only.is_empty() and not only.has(screen_name):
				continue
			if not ResourceLoader.exists(SCREENS[screen_name]):
				continue
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
			var path: String = "%s/cucs_ui_%s_%dx%d.png" % [OUT_DIR, screen_name, sz.x, sz.y]
			img.save_png(path)
			print("saved ", path, " viewport ", get_viewport().get_visible_rect().size)
			inst.queue_free()
			await get_tree().process_frame
	get_tree().quit()
