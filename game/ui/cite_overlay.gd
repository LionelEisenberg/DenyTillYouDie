class_name CiteOverlay
extends Control
## Draws the red link between a cited rule and its evidence, following the
## documents as they're dragged.

var _a: Control
var _b: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func link(a: Control, b: Control) -> void:
	_a = a
	_b = b
	queue_redraw()


func clear() -> void:
	_a = null
	_b = null
	queue_redraw()


func _process(_delta: float) -> void:
	if _a != null:
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_a) or not is_instance_valid(_b) or not _a.is_visible_in_tree() or not _b.is_visible_in_tree():
		return
	var ra := _local_rect(_a)
	var rb := _local_rect(_b)
	draw_rect(ra.grow(2), Palette.RED, false, 3.0)
	draw_rect(rb.grow(2), Palette.RED, false, 3.0)
	draw_line(ra.get_center(), rb.get_center(), Color(Palette.RED, 0.85), 3.0)


func _local_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	r.position -= global_position
	return r
