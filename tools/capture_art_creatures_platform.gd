## Captures the platformer creatures (sprite rigs on top, the vector fallback below) at zoom 1 and 2.5:
## /tmp/claude-1000/sheet_creatures_platform_{0,1}.png.   godot --path . res://tools/CaptureArtCreaturesPlatform.tscn
extends Node2D

const OUT := "/tmp/claude-1000/sheet_creatures_platform"
const COLS: int = 6
var _cases: Array = []


func _ready() -> void:
	await get_tree().create_timer(0.3).timeout
	_cases = _build()
	# page 0: everything at 1x; pages 1..: one family at 2.4x
	var families: Array = [["pupa"], ["moth"], ["nightjar"], ["bat"], ["hoopoe"]]
	_run(0, 1.0, _cases, 8)
	await _shot("%s_0.png" % OUT)
	_run(0, 1.0, _cases, 8, true)
	await _shot("%s_vector.png" % OUT)
	for i in families.size():
		var sub: Array = []
		for cs in _cases:
			if str(cs[0]).ends_with(families[i][0]):
				sub.append(cs)
		_run(i + 1, 2.0, sub, 4)
		await _shot("%s_%s.png" % [OUT, families[i][0]])
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_vp.get_texture().get_image().save_png(path)


func _build() -> Array:
	var feet := Transform2D(0.0, Vector2.ONE, 0.0, Vector2.ZERO)
	var b := func(o: Dictionary) -> Dictionary:
		o["base"] = Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0.0, -12.0))
		return o
	var c: Array = []
	var t: float = 0.7
	c.append(["platform:pupa", {"r": 11.0, "o": b.call({})}, t, "idle"])
	c.append(["platform:pupa", {"r": 11.0, "o": b.call({"dig": Vector2(1, 0), "wiggle": 1.0, "facing": 1.0})}, t, "dig right"])
	c.append(["platform:pupa", {"r": 11.0, "o": b.call({"hurt": 1.0})}, t, "hurt"])
	c.append(["platform:pupa", {"r": 11.0, "o": b.call({"blink": 1.0, "dig": Vector2(0, 1), "wiggle": 1.0})}, t, "blink/dig down"])
	c.append(["platform:moth", {"r": 13.0, "o": b.call({"flap": 0.9})}, t, "flap down"])
	c.append(["platform:moth", {"r": 13.0, "o": b.call({"flap": -0.9, "glow": 1.0})}, t, "flap up + glow"])
	c.append(["platform:moth", {"r": 13.0, "o": b.call({"glide": true})}, t, "glide"])
	c.append(["platform:moth", {"r": 13.0, "o": b.call({"stun": 1.0})}, t, "stun"])
	c.append(["platform:moth", {"r": 13.0, "o": b.call({"hurt": 1.0, "glide": true, "facing": -1.0})}, t, "hurt, facing left"])
	c.append(["platform:nightjar", {"r": 16.0, "o": b.call({"flap": 0.9})}, t, "flap down"])
	c.append(["platform:nightjar", {"r": 16.0, "o": b.call({"flap": -0.9, "alert": 1.0})}, t, "alert, up"])
	c.append(["platform:nightjar", {"r": 16.0, "o": b.call({"flap": 0.0, "chase": true, "alert": 1.0, "vy": 200.0})}, t, "chase"])
	for st in ["PATROL", "PULSE", "MARK", "SWOOP"]:
		c.append(["platform:bat", b.call({"state": st, "flap": 0.6}), t, st])
	c.append(["platform:bat", b.call({"state": "PATROL", "flap": -0.8, "open": 1.0}), t, "PATROL up, open"])
	c.append(["platform:bat", b.call({"state": "MARK", "flap": 0.0, "angle": 0.3}), t, "MARK level"])
	c.append(["platform:hoopoe", {"base": feet}, t, "idle"])
	c.append(["platform:hoopoe", {"base": feet, "crest": 1.0, "wing": 1.0, "walk": 1.0}, t, "crest + wing up"])
	c.append(["platform:hoopoe", {"base": feet, "crest": 1.0, "lean": 0.5, "alarm": 1.0, "beak_pitch": -0.5, "walk": 2.0}, t, "lean, alarm"])
	c.append(["platform:hoopoe", {"base": feet, "crest": 0.5, "lean": 0.3, "hide_beak": true}, t, "no beak"])
	return c


var _vp: SubViewport = null


func _run(_page: int, zoom: float, cases: Array, cols: int, vec: bool = false) -> void:
	if _vp != null:
		_vp.queue_free()
	var cell := Vector2(150.0 * zoom + 40.0, 125.0 * zoom + 50.0)
	var rows: int = ceili(float(cases.size()) / float(cols))
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(cell.x) * mini(cols, cases.size()), int(cell.y) * rows)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var bg := Bg.new()
	bg.size = Vector2(_vp.size)
	_vp.add_child(bg)
	for i in cases.size():
		var layer := Cell.new()
		layer.id = cases[i][0]
		layer.state = cases[i][1]
		layer.ctx = ArtContext.sample(float(cases[i][2]))
		layer.label = "%s %s" % [str(cases[i][0]).trim_prefix("platform:"), cases[i][3]]
		layer.position = Vector2((float(i % cols) + 0.5) * cell.x, (floorf(float(i) / cols) + 1.0) * cell.y - 55.0)
		layer.vector = vec
		layer.scale = Vector2(zoom, zoom)
		_vp.add_child(layer)


class Bg extends Node2D:
	var size := Vector2.ZERO

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#33474a"))


class Cell extends Node2D:
	var id: String = ""
	var state: Variant = null
	var ctx: ArtContext = null
	var label: String = ""
	var vector: bool = false

	func _draw() -> void:
		draw_line(Vector2(-60, 0), Vector2(60, 0), Color(1, 1, 1, 0.2), 1.0 / scale.x)
		PlatformPupaArt.use_sprites(not vector)
		PlatformMothArt.use_sprites(not vector)
		PlatformBatArt.use_sprites(not vector)
		PlatformBirdArt.use_sprites(not vector)
		ArtRegistry.draw(id, self, state, ctx)
		ViewUtil.text(self, label, Vector2(0.0, 30.0 / scale.x), int(12.0 / scale.x), Color.WHITE)
