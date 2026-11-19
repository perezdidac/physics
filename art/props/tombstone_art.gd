## A fallen fighter's tombstone: assets/sprites/props/tombstone.svg; the name (on the plaque) and the team cap are drawn in code.
class_name TombstoneArt
extends SpriteArt


func _init() -> void:
	super("props", "tombstone", 36.0, TombstoneVectorArt.new())
	anchor = Vector2(64.0, 112.0)


## The sim position is the stone's centre; it stands 10 below it.
func _origin(state: Variant, _ctx: ArtContext) -> Vector2:
	return ViewUtil.pos(state) + Vector2(0.0, 10.0)


func _overlay(ci: CanvasItem, state: Variant, _ctx: ArtContext) -> void:
	ArtKit.place(ci, ViewUtil.pos(state))
	var nm: String = ViewUtil.gs(state, "name")
	if nm != "":
		ViewUtil.text(ci, nm.substr(0, 7).to_upper(), Vector2(0, 6.8), 6, ArtKit.hex("#e2dfd7"))
	var hat: Color = ArtKit.hex("#d93228") if ViewUtil.gi(state, "team") != 1 else ArtKit.hex("#3b82f6")
	var cap := PackedVector2Array()
	cap.append_array(ArtKit.quad_pts(Vector2(-5, -11.5), Vector2(0, -18), Vector2(7, -14), 6))
	cap.append_array(ArtKit.quad_pts(Vector2(7, -14), Vector2(3, -11), Vector2(4, -11.5), 4))
	ArtKit.poly(ci, cap, hat, ArtKit.hex("#18161b"), 1.0)
	ArtKit.poly(ci, ArtKit.quad_pts(Vector2(-3.5, -12.5), Vector2(-1, -15.5), Vector2(2, -15.5), 4), Color(1, 1, 1, 0.22))
	ArtKit.reset(ci)
