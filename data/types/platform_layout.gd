## Hand-made layout of a platformer level (egg stage). World pixels, y down, origin top-left. See docs/platform_contracts.md.
## Every field is plain data; PlatformSim reads it and never changes it.
class_name PlatformLayout
extends Resource

## World size in pixels. Perleta cannot leave through the sides; falling below `size.y` is a pit.
@export var size: Vector2 = Vector2(3200.0, 720.0)
## Solid blocks (ground, rocks, walls). Solid from every side.
@export var solids: Array[Rect2] = []
## One-way platforms (pine needles): only the top edge (`position.y`) counts, from `position.x` to `end.x`.
## You land on them from above and jump through them from below. The height is only for drawing.
@export var platforms: Array[Rect2] = []
## Slopes. Each entry is a PackedVector2Array of exactly 2 points [left, right] on the walking surface.
## The solid is the right triangle under that line: its vertical side is at the higher end and its
## flat side at the lower end's y (so a ramp rising to a plateau meets the plateau's side).
## Keep them gentle (up to about 35 degrees); steeper ones are not walkable.
@export var slopes: Array[PackedVector2Array] = []
## Where Perleta starts (her centre).
@export var start: Vector2 = Vector2(120.0, 600.0)
## Area that finishes the level (the sunny spot). Perleta's centre must be inside.
@export var goal: Rect2 = Rect2(3000.0, 520.0, 120.0, 140.0)
## Checkpoints: the ground point at the foot of the flag. Passing one (within 36 px sideways, from 260 px above the foot to the foot) activates it;
## after a pit Perleta reappears on the last one, with her centre just above it.
@export var checkpoints: Array[Vector2] = []
## Nutrient (sap drop) centres. Order is free; the sim keeps `nutrients_taken` in the same order.
@export var nutrients: Array[Vector2] = []
## Needle tufts (hiding areas): standing still with the centre inside hides Perleta.
@export var tufts: Array[Rect2] = []
## Ants, one entry per ant: Rect2(x_min, feet_y, x_max - x_min, speed). The ant patrols between x_min and x_max
## on the surface whose top is at feet_y, at `speed` px/s (it chases at 1.6 times that).
@export var ants: Array[Rect2] = []
## Background key for ArtCatalog.background().
@export var background_key: String = "pedraforca"

## --- Storm (docs/platform_contracts.md §7) ---
## Marks a stormy level (the view draws rain streaks, lightning and a dark sky). The sim does not need it.
@export var storm: bool = false
## Wind zones (world rects). While Perleta's centre is inside one she drifts sideways; tufts shelter her (no wind inside a tuft).
@export var wind_zones: Array[Rect2] = []
## Acceleration of each wind zone, same order as `wind_zones`, in px/s². Positive blows right. The sim turns it into a drift speed
## (about 0.2 s of it in the air, 0.6 of that on the ground).
@export var wind_force: Array[float] = []
## Gust period of each wind zone in seconds, same order (missing or 0 = steady). A gusting zone is calm (20 % strength) for half of the
## period and swells to full strength for the other half; zones are offset from each other.
@export var wind_period: Array[float] = []
## Raindrops spawned per second around Perleta (0 = no rain). A drop knocks her back but costs no heart.
@export var rain_rate: float = 0.0
## Puddles, drawn sitting on the ground: Rect2(x, ground_y - h, w, h). Walking in one (feet within 8 px of the rect) slows her down.
@export var puddles: Array[Rect2] = []

## --- Boss ("" = none, "WASP"; DIG mode: "HOOPOE"; FLY mode: "BAT") ---
@export var boss: String = ""
## Seconds to survive for the egg to hatch (starts after the 2 s intro).
@export var boss_time: float = 60.0
## The boss arena. The wasp flies in a figure eight in the top part and dives down to the ground inside it.
@export var arena: Rect2 = Rect2()

## --- Game mode (docs/platform2_contracts.md) ---
## "" = the classic egg platformer (everything above). "DIG" = Crisàlide, digging through soil (PlatformDig).
## "FLY" = Papallona, night flight (PlatformFly). The mode decides which of the fields below the sim reads.
@export var mode: String = ""

## --- DIG mode ---
## In DIG mode the world is a grid of 4 px cells (`PlatformDig.CELL`). The mask is built at setup from these rect lists, in this
## order (a later list overwrites an earlier one): `soil` (value 1, diggable), `solids` (value 2, ROCK: never diggable), `roots` (value 3,
## undiggable, drawn as roots), then `gaps` (value 0, air: pre-dug galleries and chambers). A cell is filled when its centre is inside a rect.
## Everything outside every list is air. Keep galleries at least 32 px tall and wide (the pupa is 24 px across). `platforms` and `slopes`
## are ignored in DIG mode. Close the world with rock rects on the sides and the bottom.
@export var soil: Array[Rect2] = []
@export var roots: Array[Rect2] = []
@export var gaps: Array[Rect2] = []
## Falling stones: the centre of each 28x28 stone, sitting on soil. It falls when the soil under it is dug away.
@export var stones: Array[Vector2] = []
## Flood: the water surface starts at `flood_start` (world y; 0 = the bottom of the world), waits `flood_delay` seconds and then
## rises (y decreases) at `flood_rate` px/s. 0 = no flood.
@export var flood_rate: float = 0.0
@export var flood_start: float = 0.0
@export var flood_delay: float = 3.0
## HOOPOE boss: world y of the top of the ground; the hoopoe walks on it and digs its beak down from it.
@export var surface_y: float = 0.0

## --- FLY mode ---
## Street lamps: Vector3(x, y, pull_radius). Inside the radius the moth is pulled towards the lamp; touching it stuns her and costs a heart.
@export var lights: Array[Vector3] = []
## Pheromone traps (sticky boxes): touching one costs a heart and respawns her at the last checkpoint.
@export var traps: Array[Rect2] = []
## Nightjars, one path per bird: waypoints it patrols back and forth along (at least 2 points).
@export var nightjars: Array[PackedVector2Array] = []
## Shadows (rects): the moth is hidden while her centre is inside an ACTIVE shadow. Optional parallel arrays (missing = static):
## `shadow_period[i]` seconds of a cycle (0 = static); `shadow_blink[i]` true = the shadow is off during the last 35 % of the cycle;
## `shadow_slide[i]` = the shadow slides by up to this offset (sine over the cycle).
@export var shadows: Array[Rect2] = []
@export var shadow_period: Array[float] = []
@export var shadow_blink: Array[bool] = []
@export var shadow_slide: Array[Vector2] = []
