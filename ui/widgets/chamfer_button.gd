## Button drawn as a chamfered gradient panel with arbitrary child controls (menu items, tactical cards, map cards, deploy and fire buttons).
## Behaves like a Button: emits `pressed` on click/tap or Enter/Space when focused. `selected` and `active` switch the look.
class_name ChamferButton
extends PanelContainer

signal pressed
signal hovered

## Looks are dictionaries with `top`, `bottom`, `border` colours (see the static presets).
var look_normal: Dictionary = {}
var look_hover: Dictionary = {}
var look_selected: Dictionary = {}
var cuts: Vector4 = Vector4(0, 0, 0, 0)
var border_width: float = 1.0
## When > 0 the shape is a rounded rectangle (flat colour = look `top`) instead of a chamfered gradient.
var radius: float = 0.0
var padding: Vector4 = Vector4(10, 10, 10, 10)
var disabled: bool = false:
	set(value):
		disabled = value
		modulate.a = 0.26 if value else 1.0
		queue_redraw()
## Chosen option of a group (lobby cards).
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Cursor of a menu (splash menu item under the cursor): same look as selected.
var active: bool = false:
	set(value):
		active = value
		queue_redraw()
## Whether a focus ring is drawn when this control has keyboard focus.
var draw_focus_ring: bool = true
var _hover: bool = false
var _down: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	apply_padding()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Updates the inner padding after changing `padding`.
func apply_padding() -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = padding.x
	empty.content_margin_top = padding.y
	empty.content_margin_right = padding.z
	empty.content_margin_bottom = padding.w
	add_theme_stylebox_override("panel", empty)


## Triggers the button as if it was clicked.
func press() -> void:
	if not disabled:
		pressed.emit()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_down = true
			elif _down:
				_down = false
				if Rect2(Vector2.ZERO, size).has_point(mb.position):
					pressed.emit()
			accept_event()
	elif event.is_action_pressed("ui_accept") and has_focus():
		pressed.emit()
		accept_event()


func _on_mouse_entered() -> void:
	_hover = true
	hovered.emit()
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false
	_down = false
	queue_redraw()


func _draw() -> void:
	var look: Dictionary = look_normal
	if selected or active:
		look = look_selected
	elif _hover and not disabled:
		look = look_hover
	var rect := Rect2(Vector2.ZERO, size)
	var top: Color = look.get("top", Color.TRANSPARENT)
	var bottom: Color = look.get("bottom", top)
	var border: Color = look.get("border", Color.TRANSPARENT)
	if radius > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = top
		sb.border_color = border
		sb.set_border_width_all(int(ceilf(border_width)))
		sb.set_corner_radius_all(int(minf(radius, size.y * 0.5)))
		sb.anti_aliasing = true
		draw_style_box(sb, rect)
	else:
		ChamferShape.draw(self, rect, cuts, top, bottom, border, border_width)
	if draw_focus_ring and has_focus():
		var pts: PackedVector2Array = ChamferShape.points(rect.grow(-1.0), cuts)
		var loop: PackedVector2Array = pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Palette.FOCUS_RING, 6.0, true)
		draw_polyline(loop, Palette.FOCUS_OUTLINE, 2.5, true)


# ---- presets (each returns a configured, empty ChamferButton) -----------------------------------

static func _look(top: Color, bottom: Color, border: Color) -> Dictionary:
	return {"top": top, "bottom": bottom, "border": border}


## Splash menu item (.updown-item): 12 px cuts at top-right and bottom-left.
static func make_menu_item() -> ChamferButton:
	var b := ChamferButton.new()
	b.cuts = Vector4(0, 12, 0, 12)
	b.padding = Vector4(22, 15, 22, 15)
	b.look_normal = _look(Color(20.0 / 255.0, 25.0 / 255.0, 34.0 / 255.0, 0.92), Color(11.0 / 255.0, 14.0 / 255.0, 20.0 / 255.0, 0.96), Palette.BRASS_BORDER_SOFT)
	b.look_hover = b.look_normal
	b.look_selected = _look(Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.28), Color(22.0 / 255.0, 27.0 / 255.0, 38.0 / 255.0, 0.96), Palette.BRASS_BRIGHT)
	b.border_width = 1.5
	b.draw_focus_ring = false
	return b


## Lobby option card (.tactical-card): 7 px cut at the top-right.
static func make_card() -> ChamferButton:
	var b := ChamferButton.new()
	b.cuts = Vector4(0, 7, 0, 0)
	b.padding = Vector4(10, 8, 10, 8)
	b.look_normal = _look(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.025), Palette.IVORY_FAINT)
	b.look_hover = _look(Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.10), Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.10), Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.45))
	b.look_selected = _look(Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.24), Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.08), Palette.BRASS_BRIGHT)
	return b


## Map card (.theatre-card): 10 px cuts at top-right and bottom-left.
static func make_theatre_card() -> ChamferButton:
	var b := ChamferButton.new()
	b.cuts = Vector4(0, 10, 0, 10)
	b.padding = Vector4(0, 0, 0, 0)
	b.look_normal = _look(Color.TRANSPARENT, Color.TRANSPARENT, Palette.IVORY_FAINT)
	b.look_hover = _look(Color.TRANSPARENT, Color.TRANSPARENT, Palette.BRASS)
	b.look_selected = _look(Color.TRANSPARENT, Color.TRANSPARENT, Palette.BRASS_BRIGHT)
	b.border_width = 1.0
	return b


## Gold call-to-action (.btn-gold-deploy): 8 px cuts at top-right and bottom-left.
static func make_deploy() -> ChamferButton:
	var b := ChamferButton.new()
	b.cuts = Vector4(0, 8, 0, 8)
	b.padding = Vector4(28, 11, 28, 11)
	b.look_normal = _look(Palette.DEPLOY_TOP, Palette.DEPLOY_BOTTOM, Palette.DEPLOY_BORDER)
	b.look_hover = _look(Palette.DEPLOY_TOP.lightened(0.08), Palette.DEPLOY_BOTTOM.lightened(0.08), Palette.DEPLOY_BORDER)
	b.look_selected = b.look_hover
	return b


## Touch fire button (.mc-btn-fire): orange gradient, light brass border.
static func make_fire() -> ChamferButton:
	var b := ChamferButton.new()
	b.cuts = Vector4(0, 0, 0, 0)
	b.padding = Vector4(4, 4, 4, 4)
	b.look_normal = _look(Palette.FIRE_TOP, Palette.FIRE_BOTTOM, Palette.FOCUS_BORDER)
	b.look_hover = b.look_normal
	b.look_selected = _look(Palette.FIRE_TOP.lightened(0.15), Palette.FIRE_BOTTOM.lightened(0.15), Palette.FOCUS_BORDER)
	b.border_width = 2.0
	b.draw_focus_ring = false
	b.focus_mode = Control.FOCUS_NONE
	return b
