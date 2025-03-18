extends Button

var wait_time : float = 1.0

@onready var _timer : Timer = $ApprovalTimer
@onready var _progress_bar : ProgressBar = $ProgressBar
@onready var tooltip_container : TooltipContainer = $ApprovalTooltipContainer

func _ready() -> void:
	pressed.connect(_on_pressed)
	_timer.wait_time = ManagerClaim.ref.get_approval_lockout()
	_timer.timeout.connect(_on_timer_timeout)
	
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

func _on_mouse_entered() -> void:
	tooltip_container.visible = true

func _on_mouse_exited() -> void:
	tooltip_container.visible = false

func _on_pressed() -> void:
	wait_time = ManagerClaim.ref.approve_claim()
	
	disabled = true
	_timer.wait_time = wait_time
	_timer.start()

func _on_timer_timeout() -> void:
	_timer.stop()
	disabled = false

func _process(_delta: float) -> void:
	_update_tooltip()
	
	if get_progress() == 0: 
		_progress_bar.visible = false
		_update_tooltip_cooldown(_timer.wait_time)
	else: 
		_progress_bar.visible = true
		_progress_bar.value = get_progress()
		_update_tooltip_cooldown(_timer.time_left)

func _update_tooltip_cooldown(time_left : float):
	tooltip_container.cooldown.visible = true
	tooltip_container.cooldown.value = get_progress()
	tooltip_container.cooldown_label.text = "[center]%.01f[/center]" %time_left

func _update_tooltip() -> void:
	tooltip_container.size = size
	tooltip_container.global_position = Vector2(global_position.x, global_position.y - size.y)
	tooltip_container.label.text = ManagerClaim.ref.get_active_claim()._generate_approval_tooltip_text()

func get_progress() -> float : 
	if _timer.is_stopped() : return 0
	
	var progress : float = 1 - (_timer.time_left / _timer.wait_time)
	progress = progress * 100
	
	return progress
