## Full-screen background of the menus: a map picture under a dark radial gradient (stands in for the live world behind the original menus).
class_name MenuBackdrop
extends Control

var _picture: TextureRect
var _shade: TextureRect


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_shade = TextureRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)


## Shows the picture of map `idx`.
func set_map(idx: int) -> void:
	_picture.texture = UiMaps.background(idx)


## Splash look: radial gradient from rgba(14,18,26,.38) to rgba(5,7,10,.88), centre at 50% 38%.
func use_splash_shade() -> void:
	_shade.texture = UiUtil.radial_gradient(Color(14.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.38), Color(5.0 / 255.0, 7.0 / 255.0, 10.0 / 255.0, 0.88), Vector2(0.5, 0.38))


## Lobby look: radial gradient from rgba(18,23,33,.88) to rgba(6,8,12,.96), centre at 50% 20%.
func use_lobby_shade() -> void:
	_shade.texture = UiUtil.radial_gradient(Color(18.0 / 255.0, 23.0 / 255.0, 33.0 / 255.0, 0.88), Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.96), Vector2(0.5, 0.2))
