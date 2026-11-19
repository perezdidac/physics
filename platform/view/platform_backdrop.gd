## Parallax background of the platformer: the level's backdrop picture, scaled to cover the view and slid slower than the world,
## under a warm summer tint and a few drifting motes of light.
class_name PlatformBackdrop
extends Node2D

## Camera position as a fraction of the scrollable world (0..1 on each axis).
var progress: Vector2 = Vector2.ZERO
var t_now: float = 0.0
var texture: Texture2D = null
var view_size: Vector2 = Vector2(1280.0, 720.0)

const WARM_TINT := Color(1.0, 0.93, 0.78, 1.0)
const STORM_TINT := Color(0.66, 0.72, 0.84, 1.0)
const NIGHT_TINT := Color(0.30, 0.37, 0.62, 1.0)

## Storm amount 0..1: cools and darkens the sky.
var storm: float = 0.0
## Night amount 0..1 (FLY levels): a deep blue tint, stars, a moon and a few fireflies.
var night: float = 0.0
## Lightning brightness 0..1.
var flash: float = 0.0
## Where the last bolt struck (fraction of the width) and the zigzag of its fork.
var bolt_x: float = 0.5


## Sets the picture by its ArtCatalog key.
func set_background(key: String) -> void:
	texture = ArtCatalog.background(key)
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = view_size
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, vp), ViewColors.h("#e9c98a"))
	else:
		var ts: Vector2 = texture.get_size()
		var s: float = maxf(vp.x * 1.3 / ts.x, vp.y * 1.12 / ts.y)
		var size: Vector2 = ts * s
		var off := Vector2(-(size.x - vp.x) * progress.x, -(size.y - vp.y) * progress.y)
		var tint: Color = WARM_TINT.lerp(STORM_TINT, storm).lerp(NIGHT_TINT, night).lerp(Color(1.25, 1.28, 1.4, 1.0), flash * 0.7)
		draw_texture_rect(texture, Rect2(off, size), false, tint)
	# warm haze: bright at the top, a little green-brown at the bottom
	var top: Color = Color(1.0, 0.86, 0.5, 0.28).lerp(Color(0.2, 0.25, 0.38, 0.4), storm).lerp(Color(0.02, 0.04, 0.16, 0.5), night)
	var bottom: Color = Color(0.35, 0.28, 0.12, 0.18).lerp(Color(0.1, 0.13, 0.2, 0.3), storm).lerp(Color(0.02, 0.03, 0.1, 0.3), night)
	var haze := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0.0), vp, Vector2(0.0, vp.y)]), haze)
	if flash > 0.05:
		_draw_bolt(vp)
	if night > 0.0:
		_draw_night(vp)
		return
	if storm > 0.0:
		return
	for i in 14:
		var fi: float = float(i)
		var x: float = fposmod(fi * 197.0 + t_now * (6.0 + fi) - progress.x * 120.0 * (0.4 + fmod(fi, 3.0) * 0.3), vp.x + 40.0) - 20.0
		var y: float = fposmod(fi * 89.0 + sin(t_now * 0.4 + fi) * 24.0, vp.y)
		draw_circle(Vector2(x, y), 1.5 + fmod(fi, 3.0), Color(1.0, 0.95, 0.7, 0.2 + 0.1 * sin(t_now * 1.5 + fi)))


## A distant forked bolt that fades with the flash.
func _draw_bolt(vp: Vector2) -> void:
	var p := Vector2(vp.x * bolt_x, 0.0)
	var pts := PackedVector2Array([p])
	for k in 7:
		p += Vector2(sin(float(k) * 2.3 + bolt_x * 9.0) * 26.0, vp.y * 0.085)
		pts.append(p)
	draw_polyline(pts, Color(0.9, 0.95, 1.0, 0.35 * flash), 5.0, true)
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.9 * flash), 2.0, true)
	var fork := PackedVector2Array([pts[3], pts[3] + Vector2(34.0, vp.y * 0.07), pts[3] + Vector2(24.0, vp.y * 0.15)])
	draw_polyline(fork, Color(1.0, 1.0, 1.0, 0.7 * flash), 1.5, true)


## Stars (some twinkling), a hazy moon and drifting fireflies.
func _draw_night(vp: Vector2) -> void:
	for i in 70:
		var fi: float = float(i)
		var h1: float = fposmod(sin(fi * 91.7) * 4375.85, 1.0)
		var h2: float = fposmod(sin(fi * 37.1 + 5.0) * 2891.3, 1.0)
		var x: float = fposmod(h1 * vp.x * 1.4 - progress.x * 40.0 * (0.3 + h2), vp.x)
		var y: float = h2 * vp.y * 0.78
		var tw: float = 0.55 + 0.45 * sin(t_now * (1.0 + h1 * 2.5) + fi)
		var sz: float = 0.8 + h1 * 1.3
		var col := Color(0.95, 0.96, 1.0, (0.35 + 0.5 * h2) * tw * night)
		draw_circle(Vector2(x, y), sz, col)
		if h1 > 0.9:
			draw_line(Vector2(x - 3.0 * sz, y), Vector2(x + 3.0 * sz, y), Color(col, col.a * 0.6), 1.0)
			draw_line(Vector2(x, y - 3.0 * sz), Vector2(x, y + 3.0 * sz), Color(col, col.a * 0.6), 1.0)
	var mc := Vector2(vp.x * 0.82 - progress.x * 30.0, vp.y * 0.2)
	for k in 7:
		draw_circle(mc, 120.0 - float(k) * 14.0, Color(0.75, 0.85, 1.0, 0.018 * night * float(k + 1)))
	draw_circle(mc, 30.0, Color(0.96, 0.97, 0.9, 0.92 * night))
	draw_circle(mc + Vector2(8.0, -5.0), 26.0, Color(0.9, 0.93, 0.88, 0.0))
	for i in 8:
		var fi2: float = float(i)
		var fx: float = fposmod(fi2 * 211.0 + sin(t_now * 0.3 + fi2) * 60.0 - progress.x * 90.0, vp.x + 40.0) - 20.0
		var fy: float = vp.y * (0.45 + 0.5 * fposmod(fi2 * 0.37, 1.0)) + sin(t_now * 0.5 + fi2 * 2.0) * 18.0
		var gl: float = 0.5 + 0.5 * sin(t_now * 1.7 + fi2 * 3.0)
		draw_circle(Vector2(fx, fy), 4.0, Color(0.8, 1.0, 0.4, 0.07 * gl * night))
		draw_circle(Vector2(fx, fy), 1.4, Color(0.95, 1.0, 0.6, 0.7 * gl * night))
