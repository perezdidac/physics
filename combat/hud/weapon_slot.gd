## One slot of the arsenal drawer (.ord-slot): hotkey, ammo, icon and name. States: active (selected), cursor (keyboard), depleted.
class_name WeaponSlot
extends Control

signal pressed(index: int)

var index: int = 0
var ammo: int = -1
var is_active: bool = false
var has_cursor: bool = false
var compact: bool = false
## Story: the weapon was unlocked by the last level won ("NEW!" badge).
var is_new: bool = false
var _hover: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(62, 54)


## Sets what the slot shows (`ammo` -1 = infinite).
func setup(weapon_idx: int, ammo_left: int, selected: bool, cursor: bool, compact_layout: bool, fresh: bool = false) -> void:
	var changed: bool = is_new != fresh or index != weapon_idx or ammo != ammo_left or is_active != selected or has_cursor != cursor or compact != compact_layout
	index = weapon_idx
	ammo = ammo_left
	is_active = selected
	has_cursor = cursor
	compact = compact_layout
	is_new = fresh
	custom_minimum_size = Vector2(48, 44) if compact else Vector2(62, 54)
	mouse_default_cursor_shape = Control.CURSOR_ARROW if is_depleted() else Control.CURSOR_POINTING_HAND
	if changed:
		queue_redraw()


## True when the weapon cannot be used (no ammo).
func is_depleted() -> bool:
	return ammo == 0


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if is_depleted():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit(index)
			accept_event()


func _draw() -> void:
	var alpha: float = 0.26 if is_depleted() else 1.0
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	sb.bg_color = Palette.SLOT_BG
	sb.border_color = Palette.SLOT_BORDER
	if has_cursor:
		sb.bg_color = Palette.SLOT_CURSOR_BG
		sb.border_color = Color.WHITE
		sb.set_border_width_all(2)
	elif is_active:
		sb.bg_color = Palette.SLOT_ACTIVE_BG
		sb.border_color = Palette.BRASS_BRIGHT
	elif _hover and not is_depleted():
		sb.bg_color = Palette.SLOT_HOVER_BG
		sb.border_color = Palette.SLOT_HOVER_BORDER
	var rect := Rect2(Vector2.ZERO, size)
	if has_cursor:
		rect = rect.grow(1.0)
		rect.position.y -= 2.0
	draw_style_box(sb, rect)
	var mono: Font = get_theme_font("font", "MonoHeavyLabel")
	var body: Font = get_theme_font("font", "BodyBoldLabel")
	if not compact:
		draw_string(mono, Vector2(5, 12), HudWeapons.hotkey_label(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Palette.IVORY, 0.45 * alpha))
	var ammo_text: String = "∞" if ammo < 0 else str(ammo)
	draw_string(mono, Vector2(0, 12), ammo_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5.0, 9, Color(Palette.BRASS_BRIGHT, alpha))
	var icon: Texture2D = HudWeapons.icon(index)
	if icon != null:
		var iw: float = 26.0 if compact else 32.0
		var ih: float = iw * 22.0 / 36.0
		draw_texture_rect(icon, Rect2((size.x - iw) * 0.5, size.y * 0.5 - ih * 0.5 - 2.0, iw, ih), false, Color(1, 1, 1, alpha))
	var label: String = tr(HudWeapons.name_key(index)).to_upper()
	draw_string(body, Vector2(0, size.y - 4.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2.0, 9 if not compact else 8, Color(Palette.IVORY, alpha))
	if is_new:
		var bw: float = 30.0
		var badge := Rect2((size.x - bw) * 0.5, -5.0, bw, 11.0)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Palette.TEAM_GOLD
		bsb.set_corner_radius_all(6)
		bsb.anti_aliasing = true
		draw_style_box(bsb, badge)
		draw_string(mono, Vector2(badge.position.x, badge.position.y + 8.5), tr("HUD_NEW"), HORIZONTAL_ALIGNMENT_CENTER, bw, 8, Palette.INK_ON_BRASS)
