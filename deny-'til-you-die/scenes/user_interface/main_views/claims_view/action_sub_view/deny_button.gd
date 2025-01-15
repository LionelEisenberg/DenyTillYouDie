extends Button

@onready var _timer : Timer = $DenialTimer
@onready var _progress_bar : ProgressBar = $ProgressBar

var wait_time : float = 10.0

func _ready() -> void:
	text = "Deny Claim"
	pressed.connect(_on_pressed)

	_timer.wait_time = wait_time
	_timer.timeout.connect(_on_timer_timeout)

	if not ManagerUnlock.ref.is_feature_unlocked(FeatureEnums.Feature.CLAIM_DENIAL):
		ManagerUnlock.ref.feature_unlocked.connect(_on_feature_unlocked)
	_update_visibility()  # Initial visibility check

func _on_feature_unlocked(feature):
	if feature == FeatureEnums.Feature.CLAIM_DENIAL:  # Replace with the actual feature
		_update_visibility()

func _update_visibility():
	if ManagerUnlock.ref.is_feature_unlocked(FeatureEnums.Feature.CLAIM_DENIAL):
		self.visible = true
		self.disabled = false
	else:
		self.visible = false
		self.disabled = true


func _on_pressed() -> void:
	wait_time = ManagerClaim.ref.deny_claim()

	disabled = true
	_timer.wait_time = wait_time
	_timer.start()

func _on_timer_timeout() -> void:
	_timer.stop()
	disabled = false

func _process(_delta: float) -> void:
	if _get_progress() == 0: 
		_progress_bar.visible = false
	else: 
		_progress_bar.visible = true
		_progress_bar.value = _get_progress()

func _get_progress() -> float : 
	if _timer.is_stopped() : return 0
	
	var progress : float = 1 - (_timer.time_left / _timer.wait_time)
	progress = progress * 100
	
	return progress
