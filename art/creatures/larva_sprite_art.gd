## The larvae L1..L5 as one cut-out rig (assets/sprites/creatures/larva/): furry body segments (hair, tinted body, rim shade, dorsal stripe,
## urticating spot from L3, gloss), a thorax and a big head. The SVGs are neutral white shapes tinted per instar from LarvaArt.LOOKS (cream and
## fluffy L1 to the dark, orange-haired L5), the rig is scaled by `unit.art_scale`. Face, blink, team beads, silk thread, dizzy stars and itch
## sparks are code. Segment wave, neck bob and hair sway follow the same phases as LarvaArt.
class_name LarvaSpriteArt
extends CritterSpriteArt

const BOX: float = 40.0
const U: float = 3.2 ## viewBox units per world px
const ANCHOR := Vector2(64.0, 64.0)
const MAX_SEGS: int = 6
const SEG_LAYERS: Array[String] = ["hair", "body", "shade", "dorsal", "spot", "gloss"]


func _init() -> void:
	var r := CreatureRig.new("larva", BOX)
	for i in range(MAX_SEGS, -1, -1):
		for layer in SEG_LAYERS:
			r.add_instance("s%d_%s" % [i, layer], "seg_" + layer, ANCHOR)
	r.add_part("head_hair", ANCHOR)
	r.add_part("head_body", ANCHOR)
	r.add_part("head_shade", ANCHOR)
	r.add_part("head_gloss", ANCHOR)
	var sample := {"x": 0.0, "y": -9.0, "r": 9.0, "walk_cycle": 0.0, "facing": 1.0, "grounded": true, "id": 1, "team": 0, "kind": "LARVA_L3", "unit": {"art_scale": 1.0}}
	super(r, CritterVectorArt.new("larva", sample, Vector2(60, 40)), sample)


## Sprite (or the vector fallback) plus the weapon in the hands of the active larva.
func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	super(ci, state, ctx)
	if ctx.combat != null:
		CaterpillarArt.draw_larva_held(ci, state, ctx.combat)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var look: Dictionary = LarvaArt.LOOKS[LarvaArt.instar(ViewUtil.gs(f, "kind", "LARVA_L1"))]
	var t: float = vc.t_now
	var team_col: Color = ViewColors.team(ViewUtil.gi(f, "team"))
	var walk: float = vc.walk_of(f)
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var r: float = ViewUtil.gf(f, "r", 9.0)
	var s: float = LarvaArt.scale_of(f)
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var dizzy: float = ViewUtil.gf(f, "dizzy_timer")
	var urticating: bool = ViewUtil.gi(f, "urticating_ticks") > 0
	var fx: float = ViewUtil.gf(f, "x")
	var feet := Vector2(fx, ViewUtil.gf(f, "y") + r - (4.0 if drowning else 0.0))
	var rot: float = ViewUtil.gf(f, "flip_angle")
	var vel: float = Vector2(ViewUtil.gf(f, "vx"), ViewUtil.gf(f, "vy")).length()
	if rot == 0.0 and not grounded and not drowning and vel > 210.0:
		rot = sin(t * 14.0) * 0.35
	var root := Transform2D(rot, Vector2(facing * ViewUtil.gf(f, "squash_x", 1.0) * s, ViewUtil.gf(f, "squash_y", 1.0) * s), 0.0, feet)
	var mid: Color = ViewColors.h(look["mid"])
	var edge: Color = ViewColors.h(look["edge"])
	var dorsal: Color = ViewColors.h(look["dorsal"])
	var head_col: Color = ViewColors.h(look["head"])
	var hair: Color = ViewColors.h(look["hair"])
	if urticating:
		hair = ViewColors.BRISTLE_URTICATING
	if drowning:
		mid = mid.lerp(ViewColors.h("#7ab4d6"), 0.55)
		edge = edge.lerp(ViewColors.h("#3d6987"), 0.55)
		head_col = head_col.lerp(ViewColors.h("#6a9ab8"), 0.55)
	var segments: int = int(look.get("segments", 4))
	var hair_len: float = float(look["hair_len"])
	var spot: Color = ViewColors.h(str(look["spot"])) if look.has("spot") else Color.WHITE
	var moving: float = 1.0 if grounded else 0.0
	var bob: float = sin(walk) * 1.1 * moving
	rig.reset_poses()
	rig.modulate = Color.WHITE
	# silk thread under the body
	ci.draw_set_transform_matrix(root)
	if grounded and not drowning:
		ci.draw_line(Vector2(-LarvaArt.SPACING * segments - 4.0, 0.6), Vector2(8.0, 0.6), Color(0.96, 0.95, 0.92, 0.3), 1.4, true)
	var beads: Array = []
	for i in range(MAX_SEGS, -1, -1):
		var used: bool = i <= segments
		var c: Vector2
		var seg_r: float
		var wave: float
		if i == 0:
			c = Vector2(0.0, -6.4 + bob)
			seg_r = 6.4
			wave = sin(walk * 1.5) * moving
		else:
			wave = sin(walk * 1.5 - float(i) * 0.9) * moving
			seg_r = 6.2 - float(i) * 0.38
			c = Vector2(-float(i) * LarvaArt.SPACING + 1.0, -seg_r - 0.5 - maxf(0.0, wave) * 1.5)
		for layer in SEG_LAYERS:
			var part: String = "s%d_%s" % [i, layer]
			if not used:
				rig.set_visible_part(part, false)
				continue
			var k: float = seg_r / 6.2
			var sway: float = 0.0
			var kk: float = k
			if layer == "hair":
				kk = k * (seg_r + hair_len) / (seg_r + 4.1)
				sway = sin(t * 3.0 + float(i)) * 0.05
			if layer == "spot" and (i == 0 or not look.has("spot")):
				rig.set_visible_part(part, false)
				continue
			rig.set_pose(part, sway, c * U, Vector2(kk, kk))
			rig.set_part_tint(part, _tint(layer, mid, edge, dorsal, hair, spot))
		if used:
			beads.append([c + Vector2(0.0, seg_r * 0.45 + wave * 0.2)])
	var hc := Vector2(4.6, -10.6 + bob)
	rig.set_pose("head_hair", sin(t * 3.0) * 0.04, hc * U)
	rig.set_part_tint("head_hair", hair)
	rig.set_pose("head_body", 0.0, hc * U, Vector2(7.6 / 7.5, 7.6 / 7.5))
	rig.set_part_tint("head_body", head_col.lightened(0.1))
	rig.set_pose("head_shade", 0.0, hc * U, Vector2(7.6 / 7.5, 7.6 / 7.5))
	rig.set_part_tint("head_shade", head_col.darkened(0.45))
	rig.set_pose("head_gloss", 0.0, hc * U)
	rig.draw(ci, root, ANCHOR)
	ci.draw_set_transform_matrix(root)
	for b in beads:
		ci.draw_circle((b as Array)[0] as Vector2, 1.1, team_col)
	_face(ci, f, hc, team_col, t, hurt, dizzy, vc)
	if hurt > 0.0:
		ArtKit.fill_ellipse(ci, hc, 8.0, 8.0, Color(1.0, 0.25, 0.2, clampf(hurt, 0.0, 1.0) * 0.4))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	if dizzy > 0.0 and not drowning:
		for k in 3:
			var a2: float = t * 6.5 + float(k) * TAU / 3.0
			ci.draw_circle(Vector2(fx + cos(a2) * 11.0, feet.y - 30.0 * s + sin(a2) * 3.5), 2.2, ViewColors.h("#ffe066") if k % 2 == 0 else Color.WHITE)
	if urticating and not drowning:
		for k in 3:
			var a: float = t * 9.0 + float(k) * 2.1
			ci.draw_line(feet + Vector2(cos(a) * 11.0, -10.0 + sin(a) * 7.0), feet + Vector2(cos(a) * 15.0, -10.0 + sin(a) * 10.0), ViewColors.BRISTLE_URTICATING, 1.4, true)


static func _tint(layer: String, mid: Color, edge: Color, dorsal: Color, hair: Color, spot: Color) -> Color:
	match layer:
		"hair": return hair
		"body": return mid
		"shade": return edge
		"dorsal": return dorsal
		"spot": return spot
	return Color.WHITE


## Antennae, eyes (blink, crosses when hurt or dizzy), blush and mouth over the head sprite (head space = `c`).
static func _face(ci: CanvasItem, f: Variant, c: Vector2, team_col: Color, t: float, hurt: float, dizzy: float, vc: ViewCtx) -> void:
	var line: Color = ViewColors.h("#1a1412")
	var wig: float = sin(t * 7.0 + ViewUtil.gf(f, "x")) * 1.0
	var tip: Vector2 = c + Vector2(7.6 + wig, -10.4)
	ci.draw_polyline(ViewUtil.quad_pts(c + Vector2(3.0, -6.0), c + Vector2(5.0, -10.0), tip, 6), line, 1.1, true)
	ci.draw_circle(tip, 1.2, team_col)
	var blink: bool = fmod(t * 0.9 + float(ViewUtil.gi(f, "id")) * 1.73, 4.2) > 4.05
	var white := ViewColors.h("#fffaf0")
	var e1: Vector2 = c + Vector2(0.6, -1.0)
	var e2: Vector2 = c + Vector2(4.4, -1.0)
	if hurt > 0.2 or dizzy > 0.0:
		for e in [e1, e2]:
			var ec: Vector2 = e
			ci.draw_line(ec + Vector2(-1.3, -1.3), ec + Vector2(1.3, 1.3), line, 1.2, true)
			ci.draw_line(ec + Vector2(1.3, -1.3), ec + Vector2(-1.3, 1.3), line, 1.2, true)
	elif blink:
		ci.draw_line(e1 + Vector2(-1.6, 0.0), e1 + Vector2(1.6, 0.0), line, 1.2, true)
		ci.draw_line(e2 + Vector2(-1.6, 0.0), e2 + Vector2(1.6, 0.0), line, 1.2, true)
	else:
		ArtKit.fill_ellipse(ci, e1, 2.5, 3.0, white)
		ArtKit.fill_ellipse(ci, e2, 2.2, 2.7, white)
		ci.draw_circle(e1 + Vector2(0.5, 0.2), 1.5, line)
		ci.draw_circle(e2 + Vector2(0.5, 0.2), 1.35, line)
		ci.draw_circle(e1 + Vector2(0.0, -0.6), 0.55, Color.WHITE)
		ci.draw_circle(e2 + Vector2(0.0, -0.6), 0.5, Color.WHITE)
	ArtKit.fill_ellipse(ci, c + Vector2(-1.2, 2.6), 1.7, 1.0, Color(1.0, 0.5, 0.5, 0.45))
	ArtKit.fill_ellipse(ci, c + Vector2(5.4, 2.6), 1.5, 0.9, Color(1.0, 0.5, 0.5, 0.45))
	var near_danger: bool = false
	for p in vc.projectiles:
		if ViewUtil.pos(p).distance_to(ViewUtil.pos(f)) < 90.0:
			near_danger = true
			break
	if near_danger or hurt > 0.2 or vc.is_lost(f):
		ArtKit.fill_ellipse(ci, c + Vector2(2.9, 4.2), 1.1, 1.3, line)
	else:
		ci.draw_arc(c + Vector2(2.9, 2.6), 1.7, 0.2, PI - 0.2, 8, line, 1.0, true)
