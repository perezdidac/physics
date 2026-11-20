## Silk shop and reward: El Bolsó's card list scrolls on a phone (touch drag from a card or a buy button, a tap still buys, mouse wheel,
## the keyboard focus scrolls into view, the last card is reachable), and the results screen shows the silk of every won level (a chip
## with a count-up, the breakdown, or "already have these stars" on a replay), platform and boss levels included.
##   godot --path . res://tests/TestSilkShop.tscn   (also headless)
extends Node

var failures: int = 0
var routed: Array[String] = []


func _check(ok: bool, text: String) -> void:
	print(("OK    " if ok else "FAIL  ") + text)
	if not ok:
		failures += 1


func _ready() -> void:
	StoryProgress.save_path = "user://silk_shop_test.cfg"
	StoryProgress.reset_progress()
	var win: Window = get_window()
	var old_size: Vector2i = win.size
	TouchMetrics.force_dpi = 440.0
	TouchMetrics.force = 1
	win.size = Vector2i(2404, 1080)
	await _frames(4)
	await _hub()
	await _results()
	TouchMetrics.force = -1
	TouchMetrics.force_dpi = 0.0
	UiUtil.touch_seen = false
	win.size = old_size
	StoryProgress.reset_progress()
	GameState.story_level = null
	GameState.story_result = {}
	print("RESULT: ALL GOOD" if failures == 0 else "RESULT: %d FAILURES" % failures)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Centre of `c` in viewport coordinates.
func _center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _push(ev: InputEvent) -> void:
	get_viewport().push_input(ev, true)


func _touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	_push(t)


## A finger drag from `from` by `dy` (viewport units) in steps, one frame each, then lifted.
func _finger_drag(from: Vector2, dy: float, steps: int = 8) -> void:
	_touch(from, true)
	var pos: Vector2 = from
	for i in steps:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.relative = Vector2(0.0, dy / float(steps))
		pos += d.relative
		d.position = pos
		_push(d)
		await get_tree().process_frame
	_touch(pos, false)


func _mouse_button(pos: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = button
	mb.position = pos
	mb.global_position = pos
	mb.pressed = pressed
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	_push(mb)


func _mouse_drag(from: Vector2, dy: float, steps: int = 8) -> void:
	_mouse_button(from, true)
	var pos: Vector2 = from
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.relative = Vector2(0.0, dy / float(steps))
		pos += m.relative
		m.position = pos
		m.global_position = pos
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		_push(m)
		await get_tree().process_frame
	_mouse_button(pos, false)


func _open_hub() -> Control:
	var hub: Control = (load("res://ui/story/NestHub.tscn") as PackedScene).instantiate()
	hub.go_callable = func(target: String) -> void: routed.append(target)
	add_child(hub)
	await _frames(6)
	return hub


func _wait_fling(scroll: ScrollContainer) -> void:
	var last: int = -1
	for i in 120:
		await get_tree().process_frame
		if scroll.scroll_vertical == last:
			return
		last = scroll.scroll_vertical


func _hub() -> void:
	for id in ["egg_1", "egg_2", "egg_3", "egg_4"]:
		StoryProgress.record_result({"level_id": id, "won": true, "stars": 3})
	var silk: int = StoryProgress.silk()
	UiUtil.touch_seen = true
	var hub: Control = await _open_hub()
	var scroll: ScrollContainer = hub.scroll
	var content: Control = scroll.get_child(0)
	var view_h: float = scroll.size.y
	_check(hub.columns == 2, "phone 2404x1080 at 440 dpi: two columns of cards (%d)" % hub.columns)
	_check(content.size.y > view_h + 50.0 and scroll.scroll_vertical == 0, "the card list is taller than its area (%.0f > %.0f) and opens at the top" % [content.size.y, view_h])
	var top_card: Control = hub.cards[0]
	# a drag that starts on a card's text scrolls the list
	await _finger_drag(_center(top_card) + Vector2(-top_card.size.x * 0.3, 0.0), -160.0)
	await _wait_fling(scroll)
	var after_card: int = scroll.scroll_vertical
	_check(after_card > 40, "a finger drag starting on a card scrolls the list (%d)" % after_card)
	# a drag that starts on a buy button scrolls too and does not buy
	scroll.scroll_vertical = 0
	await _frames(2)
	var buy_id: String = ""
	for u in StoryProgress.upgrades():
		if hub.buy_buttons.has(u.id) and not bool(hub.buy_buttons[u.id].get("disabled")):
			buy_id = u.id
			break
	var button: Control = hub.buy_buttons[buy_id]
	await _finger_drag(_center(button), -160.0)
	await _wait_fling(scroll)
	_check(scroll.scroll_vertical > 40, "a finger drag starting on a buy button scrolls the list (%d)" % scroll.scroll_vertical)
	scroll.scroll_vertical = 0
	await _frames(2)
	await _mouse_drag(_center(button), -160.0) # the same gesture as mouse events (touch emulation, or a desktop mouse)
	await _wait_fling(scroll)
	_check(scroll.scroll_vertical > 40, "a mouse drag starting on a buy button scrolls the list (%d)" % scroll.scroll_vertical)
	_check(not StoryProgress.owns(buy_id) and StoryProgress.silk() == silk, "the drags that started on %s did not buy it" % buy_id)
	# a plain tap (press and release on the button, no travel) still buys
	scroll.scroll_vertical = 0
	await _frames(2)
	var keep: int = 0
	_mouse_button(_center(button), true)
	await _frames(1)
	_mouse_button(_center(button), false)
	await _frames(4)
	_check(StoryProgress.owns(buy_id) and StoryProgress.silk() == silk - StoryProgress.upgrade(buy_id).cost, "a tap on the buy button buys %s" % buy_id)
	# buying keeps the list where it was
	scroll = hub.scroll
	scroll.scroll_vertical = 200
	keep = scroll.scroll_vertical
	var next_id: String = ""
	for u in StoryProgress.upgrades():
		if hub.buy_buttons.has(u.id) and not bool(hub.buy_buttons[u.id].get("disabled")):
			next_id = u.id
	if next_id != "":
		hub.buy(next_id)
		await _frames(6)
		_check(hub.scroll.scroll_vertical == keep, "after a purchase the list stays where it was (%d, was %d)" % [hub.scroll.scroll_vertical, keep])
	scroll = hub.scroll
	# the mouse wheel scrolls even over a button
	scroll.scroll_vertical = 0
	await _frames(2)
	_mouse_button(_center(hub.cards[1]), true, MOUSE_BUTTON_WHEEL_DOWN)
	_mouse_button(_center(hub.cards[1]), false, MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(2)
	_check(scroll.scroll_vertical > 0, "the mouse wheel over a card scrolls the list (%d)" % scroll.scroll_vertical)
	# the last card is fully reachable: scrolled to the end it sits inside the list area, above the safe-area bottom
	scroll.scroll_vertical = 100000
	await _frames(3)
	var last: Control = hub.cards[hub.cards.size() - 1]
	var last_bottom: float = (last.get_global_transform_with_canvas() * Vector2(0.0, last.size.y)).y
	var list_bottom: float = (scroll.get_global_transform_with_canvas() * Vector2(0.0, scroll.size.y)).y
	var safe_bottom: float = TouchMetrics.safe_rect(get_viewport().get_visible_rect().size).end.y
	_check(last_bottom <= list_bottom - 4.0 and list_bottom <= safe_bottom + 0.5, "scrolled to the end, the last card ends at %.0f, inside the list (%.0f) and the safe area (%.0f)" % [last_bottom, list_bottom, safe_bottom])
	# keyboard focus scrolls its card into view
	scroll.scroll_vertical = 0
	await _frames(2)
	var focus_target: Control = null
	for u in StoryProgress.upgrades():
		if hub.buy_buttons.has(u.id):
			focus_target = hub.buy_buttons[u.id]
	focus_target.grab_focus()
	await _frames(3)
	var card: Control = focus_target
	for c in hub.cards:
		if c.is_ancestor_of(focus_target):
			card = c
	var xf: Transform2D = scroll.get_global_transform_with_canvas().affine_inverse() * card.get_global_transform_with_canvas()
	var card_top: float = xf.origin.y
	var card_bottom: float = card_top + card.size.y
	_check(scroll.scroll_vertical > 0 and card_top >= -0.5 and card_bottom <= scroll.size.y + 0.5, "focusing a buy button low in the list scrolls its card into view (%.0f..%.0f of %.0f)" % [card_top, card_bottom, scroll.size.y])
	hub.queue_free()
	await _frames(2)
	StoryProgress.refund_all()


func _results() -> void:
	StoryProgress.reset_progress()
	# a platform level (the egg): first win with 2 stars
	var res: Control = await _open_results({"level_id": "egg_1", "won": true, "stars": 2, "reason": "REACHED_GOAL", "nutrients": 5, "nutrients_total": 8, "hearts_left": 2})
	_check(res.silk_earned == 15 and res.silk_chip != null and res.hub_button != null, "egg_1 (platform), first win with 2 stars: +15 silk chip and the hub button")
	_check(res.silk_label.text == UiUtil.fmt("STORY_RESULT_SILK_GAIN", [0]) or res.silk_shown < 15.0, "the chip counts up from zero")
	await get_tree().create_timer(res.SILK_COUNT_DELAY + res.SILK_COUNT_TIME + 0.2).timeout
	_check(res.silk_label.text == UiUtil.fmt("STORY_RESULT_SILK_GAIN", [15]), "... to +15 (%s)" % res.silk_label.text)
	var texts: String = _texts(res)
	_check(texts.contains(UiUtil.fmt("STORY_RESULT_SILK_TOTAL", [15])) and res.silk_note.text.contains(UiUtil.fmt("SILK_PART_WIN", [5])) and res.silk_note.text.contains(UiUtil.fmt("SILK_PART_STARS", [2, 10])), "it says the new total and the breakdown (%s)" % res.silk_note.text)
	await _close(res)
	# a replay that beats nothing
	res = await _open_results({"level_id": "egg_1", "won": true, "stars": 1, "reason": "REACHED_GOAL", "hearts_left": 1})
	_check(res.silk_earned == 0 and res.silk_chip == null and res.silk_note != null and res.silk_note.text.contains(tr("STORY_RESULT_SILK_NONE")) and res.silk_note.text.contains(UiUtil.fmt("STORY_RESULT_SILK_BEST", [2])), "a replay below the best: no silk, and it says so (%s)" % (res.silk_note.text if res.silk_note else ""))
	await _close(res)
	# a better replay pays only the new stars
	res = await _open_results({"level_id": "egg_1", "won": true, "stars": 3, "reason": "REACHED_GOAL", "hearts_left": 3})
	_check(res.silk_earned == 5 and res.silk_parts() == [UiUtil.fmt("SILK_PART_STARS", [1, 5])], "a better replay: +5 for the new star only (%s)" % str(res.silk_parts()))
	await _close(res)
	# a boss level adds its bonus
	res = await _open_results({"level_id": "egg_boss", "won": true, "stars": 1, "reason": "HATCHED", "hearts_left": 1})
	_check(res.silk_earned == 25 and res.silk_parts().has(UiUtil.fmt("SILK_PART_BOSS", [15])), "egg_boss, 1 star: 5 + 5 + 15 boss = 25")
	await _close(res)
	# a loss shows no silk line
	res = await _open_results({"level_id": "egg_2", "won": false, "stars": 0, "reason": "LOST", "hearts_left": 0})
	_check(res.silk_earned == 0 and res.silk_chip == null and res.silk_note == null, "a lost level shows no silk")
	await _close(res)


func _open_results(stats: Dictionary) -> Control:
	GameState.story_result = stats
	var res: Control = (load("res://ui/story/StoryResults.tscn") as PackedScene).instantiate()
	res.go_callable = func(target: String) -> void: routed.append(target)
	add_child(res)
	await _frames(3)
	return res


func _close(res: Control) -> void:
	res.queue_free()
	await _frames(2)


func _texts(node: Node) -> String:
	var out: Array[String] = []
	_collect(node, out)
	return "\n".join(out)


func _collect(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect(c, out)
