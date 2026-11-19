## Boss-fight effects in world space: expanding rings where an attack lands and on a phase change, and the defeat celebration
## (a burst of confetti and gold rings). Owned by CombatView, fed by CombatScreen from the sim's boss signals.
class_name BossFx
extends RefCounted

const CONFETTI: Array[Color] = [Color("#ffd24a"), Color("#ff6b5b"), Color("#ffffff"), Color("#76e082"), Color("#d88aff"), Color("#8fd8f2")]
const GRAVITY: float = 520.0

var confetti: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func clear() -> void:
	confetti.clear()
	rings.clear()


## A ring that grows from `pos` to `radius` and fades (an attack landing, a phase change).
func ring(pos: Vector2, radius: float, color: Color, life: float = 0.7) -> void:
	rings.append({"pos": pos, "radius": radius, "color": color, "t": 0.0, "life": life})


func attack_landed(pos: Vector2) -> void:
	ring(pos, 60.0, Color("#ffb347"), 0.5)


func phase_changed(pos: Vector2) -> void:
	for k in 3:
		ring(pos, 150.0 + float(k) * 70.0, Color("#ff9e44"), 0.8 + float(k) * 0.2)


## The boss is down: gold rings and confetti flying up from `pos`.
func defeated(pos: Vector2) -> void:
	for k in 3:
		ring(pos, 120.0 + float(k) * 90.0, Color("#ffd24a"), 1.0 + float(k) * 0.3)
	for i in 150:
		var a: float = rng.randf_range(-PI * 0.95, -PI * 0.05)
		var sp: float = rng.randf_range(160.0, 560.0)
		confetti.append({
			"pos": pos + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0)),
			"vel": Vector2(cos(a), sin(a)) * sp,
			"rot": rng.randf() * TAU, "spin": rng.randf_range(-9.0, 9.0),
			"size": rng.randf_range(3.0, 7.0), "color": CONFETTI[i % CONFETTI.size()],
			"t": 0.0, "life": rng.randf_range(2.2, 3.8),
		})


func update(dt: float) -> void:
	for p in confetti:
		p["t"] = float(p["t"]) + dt
		var v: Vector2 = p["vel"]
		v.y += GRAVITY * dt
		v *= pow(0.5, dt)
		p["vel"] = v
		p["pos"] = (p["pos"] as Vector2) + v * dt
		p["rot"] = float(p["rot"]) + float(p["spin"]) * dt
	confetti = confetti.filter(func(p: Dictionary) -> bool: return float(p["t"]) < float(p["life"]))
	for r in rings:
		r["t"] = float(r["t"]) + dt
	rings = rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) < float(r["life"]))


func draw(ci: CanvasItem) -> void:
	for r in rings:
		var k: float = float(r["t"]) / float(r["life"])
		var col: Color = r["color"]
		var rad: float = float(r["radius"]) * (1.0 - pow(1.0 - k, 3.0))
		ci.draw_arc(r["pos"], maxf(1.0, rad), 0.0, TAU, 40, Color(col, (1.0 - k) * 0.9), 5.0 * (1.0 - k) + 1.0, true)
	for p in confetti:
		var fade: float = clampf((float(p["life"]) - float(p["t"])) / 0.6, 0.0, 1.0)
		var sz: float = float(p["size"])
		var xf := Transform2D(float(p["rot"]), Vector2(1.0, 0.45 + 0.55 * absf(sin(float(p["t"]) * 7.0 + float(p["rot"])))), 0.0, p["pos"])
		ci.draw_set_transform_matrix(xf)
		ci.draw_rect(Rect2(-sz, -sz * 0.6, sz * 2.0, sz * 1.2), Color(p["color"], fade))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
