## The path a procession leader walked (SimConvoy): ground points in the order it stood on them, with the distance walked up to each one
## (`s`, in px). A jump or a fall leaves a "gap" between two points: the leader was in the air between them, so the distance does not grow
## across it and the followers, who cannot fly, cross it in their own way (see SimConvoy._cross_gap).
class_name SimTrail
extends RefCounted

## The leader adds a point every time it moved this far (px). A move this long after being airborne is a gap.
const STEP: float = 4.0
const GAP_MIN: float = 14.0

var points: Array[Vector2] = []
## Distance walked up to each point (never decreases; equal to the previous one across a gap).
var s: Array[float] = []
## gap[i]: the leader was airborne between point i-1 and point i.
var gap: Array[bool] = []


## Adds the leader's standing point `p`; `airborne`: it was in the air (or sliding) since the previous call. False when nothing was added.
func record(p: Vector2, airborne: bool) -> bool:
	if points.is_empty():
		points.append(p)
		s.append(0.0)
		gap.append(false)
		return true
	var d: float = points[points.size() - 1].distance_to(p)
	if d < STEP:
		return false
	var is_gap: bool = airborne and d > GAP_MIN
	points.append(p)
	s.append(s[s.size() - 1] + (0.0 if is_gap else d))
	gap.append(is_gap)
	return true


## Distance walked up to the leader standing at `head` (the last point plus the way from it; nothing more while it is in the air).
func head_s(head: Vector2, airborne: bool) -> float:
	if points.is_empty():
		return 0.0
	var last: int = points.size() - 1
	return s[last] + (0.0 if airborne else points[last].distance_to(head))


## The point where the leader was after walking `at` px (clamped to the first and last points).
func sample(at: float) -> Vector2:
	var i: int = points.size() - 1
	if i < 0:
		return Vector2.ZERO
	if at >= s[i]:
		return points[i]
	while i > 0 and s[i - 1] > at:
		i -= 1
	if i == 0:
		return points[0]
	if gap[i]:
		return points[i - 1] if s[i] > at else points[i]
	var span: float = s[i] - s[i - 1]
	return points[i - 1].lerp(points[i], (at - s[i - 1]) / span) if span > 0.0 else points[i]


## Index of the first gap point whose distance lies in (from, to] (the followers cross it going from `from` to `to`); -1 when none.
func gap_between(from: float, to: float) -> int:
	for i in range(1, points.size()):
		if gap[i] and s[i] > from and s[i] <= to:
			return i
	return -1


## Forgets the points older than `keep` px behind distance `head`.
func trim(head: float, keep: float) -> void:
	var cut: int = 0
	while cut + 2 < points.size() and s[cut + 1] < head - keep:
		cut += 1
	if cut > 0:
		points = points.slice(cut)
		s = s.slice(cut)
		gap = gap.slice(cut)
