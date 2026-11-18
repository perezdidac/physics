## A Node2D that delegates its drawing to a Callable (lets one painter object own several z-ordered draw passes).
class_name DrawLayer
extends Node2D

## Called as draw_fn.call(self) inside _draw().
var draw_fn: Callable = Callable()


func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
