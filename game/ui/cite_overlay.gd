class_name CiteOverlay
extends Control
## Draws the red link between a cited rule and its evidence, following the
## documents as they're dragged. The owner sizes it to the desk; it clips its
## drawing to its own rect, so the link never spills past the desk's edge.
##
## A new link draws itself in: both boxes appear, then the line grows from the
## rule to the evidence over DRAW_TIME. It is drawn at once when reduce_motion is
## set, and inside a screen whose `fast` flag is on (tests and the screenshot
## tour skip animations).

const DRAW_TIME := 0.18
## Share of DRAW_TIME the boxes take to ink in before the line starts.
const BOX_SHARE := 0.3

## 0 when a link has just been made, 1 once it is fully drawn.
var progress: float = 1.0
var _a: Control
var _b: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func link(a: Control, b: Control) -> void:
	_a = a
	_b = b
	progress = 1.0 if _instant() else 0.0
	queue_redraw()


func clear() -> void:
	_a = null
	_b = null
	progress = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _a != null:
		if progress < 1.0:
			progress = minf(1.0, progress + delta / DRAW_TIME)
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_a) or not is_instance_valid(_b) or not _a.is_visible_in_tree() or not _b.is_visible_in_tree():
		return
	var ra := _local_rect(_a)
	var rb := _local_rect(_b)
	var ink := clampf(progress / BOX_SHARE, 0.0, 1.0)
	draw_rect(ra.grow(2), Color(Palette.RED, ink), false, 3.0)
	draw_rect(rb.grow(2), Color(Palette.RED, ink), false, 3.0)
	var reach := clampf((progress - BOX_SHARE) / (1.0 - BOX_SHARE), 0.0, 1.0)
	if reach > 0.0:
		var from := ra.get_center()
		draw_line(from, from.lerp(rb.get_center(), reach), Color(Palette.RED, 0.85), 3.0)


## Whether a new link skips its draw-in: under reduce_motion, or when an ancestor
## (the desk screen) has its `fast` flag on.
func _instant() -> bool:
	if Engine.get_meta("reduce_motion", false):
		return true
	var node := get_parent()
	while node != null:
		var fast: Variant = node.get("fast")
		if fast is bool and fast:
			return true
		node = node.get_parent()
	return false


func _local_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	r.position -= global_position
	return r
