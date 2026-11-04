extends SceneTree
## Renders every screen to PNG for a visual check. Needs a real window (not --headless):
##   godot --path game --resolution 1920x1080 --script res://tests/screenshot_tour.gd -- <out_dir>
## Run it again at the default window size into its own folder to check the
## scaled-down canvas (the font is smoothed there):
##   godot --path game --resolution 1600x900 --script res://tests/screenshot_tour.gd -- <other_dir>
## Without <out_dir> the shots go to user://tour_<width>x<height>.
##
## The tour lives in tour_runner.gd and is loaded at runtime: scripts compiled at
## startup can't see autoloads yet, and the screens use GameState.

const WATCHDOG_SECONDS := 360.0


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	create_timer(WATCHDOG_SECONDS).timeout.connect(func() -> void:
		push_error("screenshot tour timed out")
		quit(1))
	var runner: Node = (load("res://tests/tour_runner.gd") as GDScript).new()
	root.add_child(runner)
