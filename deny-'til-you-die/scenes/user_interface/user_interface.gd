class_name UserInterface
extends Control

static var ref : UserInterface

const UNLOCK_POPUP_PATH : String = "res://scenes/user_interface/unlock_popup/unlock_popup.tscn"

func _init() -> void:
	if not ref : ref = self
	else : queue_free()

@onready var main_view : TabContainer = %MainViewTabContainer

func _ready() -> void:
	ManagerUnlock.ref.feature_unlocked.connect(_on_feature_unlocked)

func change_view(i : int) -> Error:
	if i > main_view.get_tab_count(): return Error.FAILED
	main_view.current_tab = i
	return Error.OK

func _on_feature_unlocked(feature : FeatureEnums.Feature) -> void:
	var unlock_popup = load(UNLOCK_POPUP_PATH).instantiate()
	var unlock_text = ManagerUnlock.ref.get_feature_unlock_text(feature)
	unlock_popup.set_popup_text(unlock_text)
	add_child(unlock_popup)
