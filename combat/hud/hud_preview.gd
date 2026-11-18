## Preview scene: top HUD, bottom HUD and (optionally) the victory modal bound to a HudFakeSim over a map picture.
## Used by tools/capture_ui.gd and the UI tests. Not part of the game flow.
extends Control

var fake_sim: HudFakeSim
var show_victory: bool = false
var drawer_open: bool = true


func _ready() -> void:
	theme = UiUtil.get_theme()
	var bg := MenuBackdrop.new()
	add_child(bg)
	bg.set_map(0)
	fake_sim = HudFakeSim.new()
	var top: TopHud = (load("res://combat/hud/TopHud.tscn") as PackedScene).instantiate()
	var bottom: BottomHud = (load("res://combat/hud/BottomHud.tscn") as PackedScene).instantiate()
	var victory: VictoryModal = (load("res://combat/hud/VictoryModal.tscn") as PackedScene).instantiate()
	add_child(top)
	add_child(bottom)
	add_child(victory)
	top.bind(fake_sim)
	bottom.bind(fake_sim)
	victory.bind(fake_sim)
	if drawer_open:
		bottom.set_drawer_open(true, false)
	if show_victory:
		victory.show_result(0)
