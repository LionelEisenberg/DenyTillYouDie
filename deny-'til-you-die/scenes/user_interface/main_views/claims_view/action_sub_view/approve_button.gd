extends Button

var wait_time : float = 1.0

@onready var _timer : Timer = $ApprovalTimer
@onready var _progress_bar : ProgressBar = $ProgressBar

func _ready() -> void:
	text = "Approve Claim"
	pressed.connect(_on_pressed)
	_timer.wait_time = wait_time
	_timer.timeout.connect(_on_timer_timeout)

func _on_pressed() -> void:
	wait_time = ManagerClaim.ref.approve_claim()
	
	disabled = true
	_timer.wait_time = wait_time
	_timer.start()

func _on_timer_timeout() -> void:
	_timer.stop()
	disabled = false

func _process(_delta: float) -> void:
	if get_progress() == 0: 
		_progress_bar.visible = false
	else: 
		_progress_bar.visible = true
		_progress_bar.value = get_progress()

func get_progress() -> float : 
	if _timer.is_stopped() : return 0
	
	var progress : float = 1 - (_timer.time_left / _timer.wait_time)
	progress = progress * 100
	
	return progress
