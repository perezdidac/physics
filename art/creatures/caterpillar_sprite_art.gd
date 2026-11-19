## The caterpillar fighter (the hero) as two cut-out rigs (assets/sprites/creatures/caterpillar/): the six trailing segments, each with
## prolegs, a fur ruff behind, a tinted body (three-tone from the fighter's body colours), a rim shade, a dorsal patch and a front bristle tuft;
## and the thorax + head group (thorax reuses the segment shapes, a head with antennae and beak, optional jet / metamorphosis wings).
## The SVGs are neutral shapes tinted per fighter (body colours, dorsal colour, team colour, bristles turning purple while urticating).
## Eyes, brows, blink, dizzy crosses, the custom face texture, hats, itch sparks and dizzy stars are code over the sprites.
## Body only: the weapon in the hands, the nameplate and the convoy marks stay in CaterpillarArt.
class_name CaterpillarSpriteArt
extends CritterSpriteArt

const BOX: float = 48.0
const U: float = 128.0 / BOX ## viewBox units per world px
const ANCHOR := Vector2(64.0, 64.0)
const MAX_SEGS: int = 6
const SEG_LAYERS: Array[String] = ["proleg_a", "proleg_b", "hair", "body", "light", "shade", "gloss", "dorsal", "tuft"]
const SEG_SOURCE: Dictionary = {"proleg_a": "proleg", "proleg_b": "proleg"}
const HEAD_COL: Array[Color] = [Color("#4f5666"), Color("#252932"), Color("#0f1116")]
const WATER_COL: Array[Color] = [Color("#7ab4d6"), Color("#3d6987"), Color("#1d3547")]

var head_rig: CreatureRig = null


func _init() -> void:
	var r := CreatureRig.new("caterpillar", BOX)
	for i in range(MAX_SEGS - 1, -1, -1):
		for layer in SEG_LAYERS:
			r.add_instance("g%d_%s" % [i, layer], SEG_SOURCE.get(layer, "seg_" + layer), ANCHOR)
	head_rig = CreatureRig.new("caterpillar", BOX)
	head_rig.add_part("wing", ANCHOR)
	for layer in ["hair", "body", "light", "shade", "gloss"]:
		head_rig.add_instance("t_" + layer, "seg_" + layer, ANCHOR)
	head_rig.add_instance("t_band", "seg_dorsal", ANCHOR)
	for layer in ["body", "light", "shade", "gloss"]:
		head_rig.add_part("head_" + layer, ANCHOR)
	head_rig.add_part("antenna_b", Vector2(64.0 - 2.0 * U, 64.0 - 8.0 * U))
	head_rig.add_part("antenna_a", Vector2(64.0 + 2.0 * U, 64.0 - 8.0 * U))
	head_rig.add_part("beak", ANCHOR)
	var segs: Array = []
	for s in MAX_SEGS:
		segs.append(Vector2(-(s + 1) * 5.2, 4.0))
	var sample := {"x": 0.0, "y": -9.0, "r": 9.0, "facing": 1.0, "grounded": true, "id": 0, "team": 0, "kind": "CATERPILLAR", "segs": segs, "walk_cycle": 0.0}
	super(r, CritterVectorArt.new("caterpillar", sample, Vector2(70, 40)), sample)


func is_sprite_complete() -> bool:
	return rig.is_complete() and head_rig.is_complete()


func draw(ci: CanvasItem, state: Variant, ctx: ArtContext) -> void:
	if not (rig.is_complete() and head_rig.is_complete()):
		if fallback != null:
			fallback.draw(ci, state, ctx)
		return
	_draw_rig(ci, state, ctx.combat if ctx.combat != null else ViewCtx.new())
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_rig(ci: CanvasItem, f: Variant, vc: ViewCtx) -> void:
	var t: float = vc.t_now
	var team: int = ViewUtil.gi(f, "team")
	var fx: float = ViewUtil.gf(f, "x")
	var fy: float = ViewUtil.gf(f, "y")
	var drowning: bool = ViewUtil.gb(f, "drowning")
	var grounded: bool = ViewUtil.gb(f, "grounded", true)
	var team_col: Color = ViewColors.team(team)
	var dorsal_v: Variant = ViewUtil.g(f, "dorsal_color")
	var dorsal_def: Color = ViewColors.DORSAL_0 if team == 0 else ViewColors.DORSAL_1
	var dorsal_col: Color = ViewColors.parse(dorsal_v, dorsal_def) if dorsal_v != null else dorsal_def
	var body_cols: Array[Color] = CaterpillarArt._body_colors(ViewUtil.g(f, "body_colors"))
	var urticating: bool = ViewUtil.gi(f, "urticating_ticks") > 0
	var bristle: Color = ViewColors.BRISTLE_URTICATING if urticating else ViewColors.BRISTLE
	var walk: float = vc.walk_of(f)
	var segs: Variant = ViewUtil.g(f, "segs", [])
	rig.reset_poses()
	rig.modulate = Color.WHITE
	var tone: Array[Color] = [body_cols[0], body_cols[1], body_cols[2]]
	if drowning:
		tone = [WATER_COL[0], WATER_COL[1], WATER_COL[2]]
	var n: int = segs.size()
	# 1. segments tail -> neck
	if n > 0 and grounded and not drowning:
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		var thread := PackedVector2Array([Vector2(fx, fy + 8.0)])
		for s in segs:
			thread.append(ViewUtil.pos(s) + Vector2(0, 5.0))
		ci.draw_polyline(thread, Color(0.9608, 0.949, 0.9216, 0.28), 1.4, true)
	for i in MAX_SEGS:
		for layer in SEG_LAYERS:
			if i >= n:
				rig.set_visible_part("g%d_%s" % [i, layer], false)
		if i >= n:
			continue
		var p: Vector2 = ViewUtil.pos(segs[i])
		var seg_r: float = 6.8 - float(i) * 0.45
		var k: float = seg_r / 6.8
		var step_wave: float = sin(walk * 1.5 - float(i) * 0.9)
		var sc := Vector2(k, k)
		_pose_seg(rig, "g%d_" % i, p, sc, t, i, step_wave, seg_r, drowning, tone, bristle, dorsal_col)
	rig.draw(ci, Transform2D.IDENTITY, ANCHOR)
	# 2. thorax + head group
	var bob: float = sin(walk) * 1.8 if grounded else 0.0
	var rot: float = 0.0
	var flip: float = ViewUtil.gf(f, "flip_angle")
	var facing: float = ViewUtil.gf(f, "facing", 1.0)
	var vel: float = Vector2(ViewUtil.gf(f, "vx"), ViewUtil.gf(f, "vy")).length()
	if flip != 0.0:
		rot = flip
	elif ViewUtil.gb(f, "sliding") and grounded:
		rot = ViewUtil.gf(f, "slide_angle") + facing * 0.32
	elif not grounded and not drowning and vel > 210.0:
		rot = sin(t * 14.0) * 0.35
	var grp := Transform2D(rot, Vector2(facing * ViewUtil.gf(f, "squash_x", 1.0), ViewUtil.gf(f, "squash_y", 1.0)), 0.0, Vector2(fx, fy))
	_pose_head(f, vc, bob, grounded, drowning, bristle, team_col, tone)
	head_rig.draw(ci, grp, ANCHOR)
	_head_code(ci, grp, f, vc, bob, team_col, drowning)
	# 3. itch sparks, 4. dizzy stars (unflipped, around the fighter)
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, 0.0, Vector2(fx, fy)))
	if urticating and not drowning:
		for i in 3:
			var a: float = t * 9.0 + float(i) * 2.1
			ci.draw_line(Vector2(cos(a) * 13.0, -8.0 + sin(a) * 8.0), Vector2(cos(a) * 18.0, -8.0 + sin(a) * 11.0), ViewColors.BRISTLE_URTICATING, 1.5, true)
	if ViewUtil.gf(f, "dizzy_timer") > 0.0 and not drowning:
		for i in 3:
			var a2: float = t * 6.5 + float(i) * TAU / 3.0
			ci.draw_circle(Vector2(cos(a2) * 14.0, -24.0 + sin(a2) * 4.5), 2.6, ViewColors.h("#ffe066") if i % 2 == 0 else Color.WHITE)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Poses and tints the layers of one body round (segment or thorax): `c` is its centre in the rig's space (px), `sc` the size ratio to a segment of r 6.8.
func _pose_seg(r: CreatureRig, pre: String, c: Vector2, sc: Vector2, t: float, i: int, step_wave: float, seg_r: float, drowning: bool,
		tone: Array[Color], bristle: Color, dorsal: Color) -> void:
	var rest: Vector2 = c * U
	r.set_pose(pre + "hair", sin(t * 6.0 + float(i)) * 0.045, rest, sc)
	r.set_part_tint(pre + "hair", bristle)
	r.set_pose(pre + "body", 0.0, rest, sc)
	r.set_part_tint(pre + "body", tone[1])
	r.set_pose(pre + "light", 0.0, rest, sc)
	r.set_part_tint(pre + "light", tone[0])
	r.set_pose(pre + "shade", 0.0, rest, sc)
	r.set_part_tint(pre + "shade", tone[2])
	r.set_pose(pre + "gloss", 0.0, rest, sc)
	if drowning:
		for layer in ["proleg_a", "proleg_b", "dorsal", "tuft"]:
			r.set_visible_part(pre + layer, false)
		return
	r.set_pose(pre + "tuft", sin(t * 6.0 + float(i) * 1.3) * 0.06, rest, sc)
	r.set_part_tint(pre + "tuft", bristle)
	r.set_pose(pre + "dorsal", 0.0, rest, sc)
	r.set_part_tint(pre + "dorsal", dorsal)
	r.set_pose(pre + "proleg_a", 0.0, (c + Vector2(-1.2, seg_r - 0.5 + maxf(0.0, step_wave * 1.4))) * U)
	r.set_part_tint(pre + "proleg_a", ViewColors.PROLEG)
	r.set_pose(pre + "proleg_b", 0.0, (c + Vector2(1.5, seg_r - 0.5 + maxf(0.0, -step_wave * 1.4))) * U)
	r.set_part_tint(pre + "proleg_b", ViewColors.PROLEG)


func _pose_head(f: Variant, vc: ViewCtx, bob: float, grounded: bool, drowning: bool, bristle: Color, team_col: Color, tone: Array[Color]) -> void:
	var t: float = vc.t_now
	var hr: CreatureRig = head_rig
	hr.reset_poses()
	hr.modulate = Color.WHITE
	var jet: float = ViewUtil.gf(f, "jet_fuel")
	var metamorphosed: bool = ViewUtil.gb(f, "metamorphosed")
	if metamorphosed or jet > 0.0:
		var flap: float = sin(t * 32.0) * 0.38 if not grounded else sin(t * 5.0) * 0.12
		hr.set_pose("wing", 0.6 + flap, Vector2(-1.5, -4.5) * U + Vector2(0.0, bob * U), Vector2(1.0, 1.0))
		hr.set_part_tint("wing", Color(1, 1, 1, 0.8) if metamorphosed else Color(0.82, 0.72, 0.55, 0.85))
	else:
		hr.set_visible_part("wing", false)
	# thorax: a segment-like round, slightly bigger, with the team colour as a band on the back
	var tc := Vector2(-1.0, 1.0 + bob)
	var thorax_tone: Array[Color] = [ViewColors.THORAX.lightened(0.18), ViewColors.THORAX, ViewColors.THORAX.darkened(0.55)]
	if drowning:
		thorax_tone = tone
	var sc := Vector2(8.0 / 6.8, 8.0 / 6.8)
	for layer in ["hair", "body", "light", "shade", "gloss"]:
		var part: String = "t_" + layer
		hr.set_pose(part, sin(t * 6.0) * 0.04 if layer == "hair" else 0.0, tc * U, sc)
	hr.set_part_tint("t_hair", bristle)
	hr.set_part_tint("t_body", thorax_tone[1])
	hr.set_part_tint("t_light", thorax_tone[0])
	hr.set_part_tint("t_shade", thorax_tone[2])
	if drowning:
		hr.set_visible_part("t_band", false)
	else:
		var band := Vector2(1.25, 1.25)
		hr.set_pose("t_band", 0.0, Vector2(-1.0, -4.0 + bob) * U - Vector2(0.0, -8.0 * band.y), band)
		hr.set_part_tint("t_band", team_col)
	# head
	var hc := Vector2(2.0, -8.0 + bob)
	var custom_face: bool = ViewUtil.as_texture(vc.face_of(f)) != null
	var hp: Array[Color] = HEAD_COL
	if drowning:
		hp = WATER_COL
	for layer in ["body", "light", "shade", "gloss"]:
		var part: String = "head_" + layer
		if custom_face:
			hr.set_visible_part(part, false)
			continue
		hr.set_pose(part, 0.0, hc * U)
	hr.set_part_tint("head_body", hp[1])
	hr.set_part_tint("head_light", hp[0])
	hr.set_part_tint("head_shade", hp[2])
	if custom_face:
		for part in ["antenna_a", "antenna_b", "beak"]:
			hr.set_visible_part(part, false)
		return
	var wig: float = sin(t * 8.0 + ViewUtil.gf(f, "x")) * 1.4
	hr.set_pose("antenna_a", wig * 0.1, hc * U)
	hr.set_pose("antenna_b", -wig * 0.1, hc * U)
	hr.set_part_tint("antenna_a", Color(0.7, 0.75, 0.85) if drowning else Color.WHITE)
	hr.set_pose("beak", 0.0, hc * U)


## Face code over the head sprite: antenna beads, brow, eyes (blink, danger, squint, crosses) and moustache; or the custom face texture; then the hat.
func _head_code(ci: CanvasItem, grp: Transform2D, f: Variant, vc: ViewCtx, bob: float, team_col: Color, drowning: bool) -> void:
	var t: float = vc.t_now
	var hc := Vector2(2.0, -8.0 + bob)
	ci.draw_set_transform_matrix(grp * Transform2D(0.0, Vector2.ONE, 0.0, hc))
	var face: Texture2D = ViewUtil.as_texture(vc.face_of(f))
	if face != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			pts.append(Vector2(cos(a), sin(a)) * 10.5)
			uvs.append(Vector2(cos(a), sin(a)) * (10.5 / 22.0) + Vector2(0.5, 0.5))
		ci.draw_colored_polygon(pts, Color.WHITE, uvs, face)
		ci.draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 24, team_col, 2.0, true)
	else:
		var wig: float = sin(t * 8.0 + ViewUtil.gf(f, "x")) * 1.4
		var base_a := Vector2(2.0, -8.0)
		var base_b := Vector2(-2.0, -8.0)
		ci.draw_circle(base_a + Vector2(6.0, -5.0).rotated(wig * 0.1), 1.7, team_col)
		ci.draw_circle(base_b + Vector2(4.0, -6.0).rotated(-wig * 0.1), 1.5, team_col)
		_eyes(ci, f, vc, team_col, drowning, t)
		if ViewUtil.gb(f, "has_mustache"):
			var mc := ViewColors.h("#181412")
			ci.draw_polyline(ViewUtil.quad_pts(Vector2(4.5, 3.0), Vector2(1.0, 3.5), Vector2(-1.5, 1.0), 8), mc, 1.4, true)
			ci.draw_polyline(ViewUtil.quad_pts(Vector2(5.5, 3.0), Vector2(9.0, 3.2), Vector2(10.8, 0.8), 8), mc, 1.4, true)
	var team: int = ViewUtil.gi(f, "team")
	var hat_team: String = str(vc.team_hats[team]) if team < vc.team_hats.size() else "CATALAN"
	var chosen: String = ViewUtil.gs(f, "individual_hat", "CATALAN") if hat_team == "VARIED" else hat_team
	CaterpillarArt.draw_hat(ci, chosen)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _eyes(ci: CanvasItem, f: Variant, vc: ViewCtx, team_col: Color, drowning: bool, t: float) -> void:
	var dizzy: float = ViewUtil.gf(f, "dizzy_timer")
	var hurt: float = ViewUtil.gf(f, "hurt_timer")
	var blink: bool = fmod(t * 0.9 + float(ViewUtil.gi(f, "id")) * 1.73, 4.2) > 4.04 and dizzy <= 0.0 and hurt <= 0.0
	var fpos: Vector2 = ViewUtil.pos(f)
	var near_danger: bool = false
	for p in vc.projectiles:
		if ViewUtil.pos(p).distance_to(fpos) < 115.0:
			near_danger = true
			break
	if not near_danger:
		for m in vc.mines:
			if ViewUtil.gb(m, "triggered") and ViewUtil.pos(m).distance_to(fpos) < 115.0:
				near_danger = true
				break
	var squint: bool = f == vc.active and vc.is_charging
	var ey: float = 0.12 if blink else (1.22 if near_danger else (0.78 if squint else 1.0))
	var white := ViewColors.h("#fff8e7")
	ArtKit.fill_ellipse(ci, Vector2(3.4, -1.2), 2.7, 3.3 * ey, white)
	ArtKit.fill_ellipse(ci, Vector2(7.1, -1.2), 2.2, 2.8 * ey, white)
	if dizzy > 0.0 or hurt > 0.2:
		var xc := ViewColors.h("#181412")
		ci.draw_line(Vector2(2.2, -2.4), Vector2(4.6, 0.0), xc, 1.3, true)
		ci.draw_line(Vector2(4.6, -2.4), Vector2(2.2, 0.0), xc, 1.3, true)
		ci.draw_line(Vector2(6.0, -2.2), Vector2(8.2, 0.0), xc, 1.3, true)
		ci.draw_line(Vector2(8.2, -2.2), Vector2(6.0, 0.0), xc, 1.3, true)
	elif not blink:
		var pr: float = 0.82 if (ViewUtil.gb(f, "sliding") or drowning or near_danger) else 1.35
		ci.draw_circle(Vector2(4.2, -1.2), pr, ViewColors.h("#141110"))
		ci.draw_circle(Vector2(7.7, -1.2), pr * 0.85, ViewColors.h("#141110"))
		ci.draw_circle(Vector2(3.7, -2.0), 0.65, Color.WHITE)
		ci.draw_circle(Vector2(7.3, -1.9), 0.55, Color.WHITE)
		if near_danger:
			ci.draw_line(Vector2(1.0, -3.6), Vector2(8.4, -5.0), team_col, 1.6, true)
		elif squint:
			ci.draw_line(Vector2(0.8, -5.0), Vector2(8.8, -2.5), team_col, 1.6, true)
		else:
			ci.draw_line(Vector2(1.0, -4.6), Vector2(8.6, -3.2), team_col, 1.6, true)
