class_name CoachPulse
extends Control
## The training coach's highlight: a pulsing yellow outline around each control the
## player should look at next. Redrawn every frame, so it follows dragged papers.
## The owner sizes it over the desk and tray; it never takes the mouse. A target
## inside a clipping parent (a paper half off the desk) is cut to that parent.

const WIDTH := 3.0
const HZ := 1.2
const ALPHA_MIN := 0.35
const ALPHA_MAX := 1.0

var targets: Array[Control] = []
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_targets(controls: Array[Control]) -> void:
	targets = controls.duplicate()
	queue_redraw()


func clear() -> void:
	targets.clear()
	queue_redraw()


## The outline's alpha right now, pulsing between ALPHA_MIN and ALPHA_MAX.
func pulse_alpha() -> float:
	var wave := 0.5 + 0.5 * sin(TAU * HZ * _time)
	return lerpf(ALPHA_MIN, ALPHA_MAX, wave)


func _process(delta: float) -> void:
	_time += delta
	if not targets.is_empty():
		queue_redraw()


func _draw() -> void:
	var color := Color(Palette.HIGHLIGHT, pulse_alpha())
	for target in targets:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			continue
		var r := _clipped_rect(target)
		if r.has_area():
			r.position -= global_position
			draw_rect(r.grow(WIDTH), color, false, WIDTH)


## The target's global rect, cut to every clipping ancestor it sits inside.
func _clipped_rect(target: Control) -> Rect2:
	var r := target.get_global_rect()
	var node := target.get_parent()
	while node is Control:
		var parent := node as Control
		if parent.clip_contents:
			r = r.intersection(parent.get_global_rect())
		node = parent.get_parent()
	return r
