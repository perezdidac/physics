## Captures the active fighter holding each weapon (zoom 2.5) into one montage: /tmp/claude-1000/sheet_weapons_held.png.
##   godot --path . res://tools/CaptureArtWeapons.tscn       (CUCS_MAP, CUCS_SEED as in capture_combat)
extends Node

const OUT := "/tmp/claude-1000/sheet_weapons_held.png"
const CROP := Vector2i(220, 170)

var _screen: CombatScreen = null
var _crops: Array[Image] = []


func _ready() -> void:
	_screen = load("res://combat/CombatScreen.tscn").instantiate() as CombatScreen
	_screen.auto_start = false
	add_child(_screen)
	var cfg := MatchConfig.new()
	cfg.map_idx = int(OS.get_environment("CUCS_MAP")) if OS.get_environment("CUCS_MAP") != "" else 0
	GameState.map_idx = cfg.map_idx
	cfg.game_mode = "2P_LOCAL"
	cfg.seed = int(OS.get_environment("CUCS_SEED"))
	cfg.worms_per_team = 4
	var sim := CombatSim.new()
	sim.setup(cfg)
	_screen.start(sim)
	_run(sim)


func _run(sim: CombatSim) -> void:
	for i in 8:
		await get_tree().process_frame
	var f: SimFighter = sim.active_fighter
	_screen.cam.locked = true
	_screen.cam.zoom = 2.5
	_screen.cam.x = f.x
	_screen.cam.y = f.y - 8.0
	for i in sim.weapons.size():
		var w: WeaponDef = sim.weapons[i]
		sim.selected_weapon_idx = i
		sim.aim_angle = -0.35
		for k in 3:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var c: Vector2 = Vector2(img.get_size()) * 0.5
		var r := Rect2i(Vector2i(c - Vector2(CROP) * 0.5), CROP)
		_crops.append(img.get_region(r))
		print("W ", i, " ", w.id)
	var cols: int = 5
	var rows: int = ceili(float(_crops.size()) / cols)
	var sheet := Image.create(cols * CROP.x, rows * CROP.y, false, Image.FORMAT_RGBA8)
	for i in _crops.size():
		sheet.blit_rect(_crops[i], Rect2i(Vector2i.ZERO, CROP), Vector2i((i % cols) * CROP.x, floori(float(i) / cols) * CROP.y))
	sheet.save_png(OUT)
	print("saved ", OUT)
	_sprite_sheet()
	get_tree().quit()


## All weapon sprites (held, projectiles, plane) on a dark ground at 160 px each: /tmp/claude-1000/sheet_weapons_sprites.png.
func _sprite_sheet() -> void:
	var files: Array[String] = []
	for fn in DirAccess.get_files_at("res://assets/sprites/weapons"):
		if fn.ends_with(".svg"):
			files.append(fn)
	files.sort()
	var cols: int = 6
	var cell: int = 170
	var rows: int = ceili(float(files.size()) / cols)
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#4a3a32"))
	for i in files.size():
		var tex: Texture2D = load("res://assets/sprites/weapons/" + files[i]) as Texture2D
		var img: Image = tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cell - 10, cell - 10, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 5, floori(float(i) / cols) * cell + 5))
	sheet.save_png("/tmp/claude-1000/sheet_weapons_sprites.png")
