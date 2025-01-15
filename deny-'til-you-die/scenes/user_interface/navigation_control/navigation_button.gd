extends Button

@export var view_to_show : int = 0

@onready var money_upgrades_unlocked : bool = ManagerUnlock.ref.is_feature_unlocked(FeatureEnums.Feature.MONEY_UPGRADES)

func _ready() -> void:
	pressed.connect(_on_pressed)

	if money_upgrades_unlocked:
		_update_visibility()
	else:
		ManagerUnlock.ref.feature_unlocked.connect(_on_feature_unlock)

func _on_feature_unlock(feature : FeatureEnums.Feature) -> void:
	if feature == FeatureEnums.Feature.MONEY_UPGRADES:
		_update_visibility()
		ManagerUnlock.ref.feature_unlocked.disconnect(_on_feature_unlock)

func _update_visibility() -> void:
	self.visible = true
	self.disabled = false

func _on_pressed() -> void:
	var err : Error = UserInterface.ref.change_view(view_to_show)
	if err == Error.FAILED: print(err)
