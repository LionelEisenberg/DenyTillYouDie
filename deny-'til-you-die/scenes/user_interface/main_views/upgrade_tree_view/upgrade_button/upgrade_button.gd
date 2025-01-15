extends TextureButton
class_name UpgradeButton

const TOOLTIP_PATH : String = "res://scenes/user_interface/main_views/upgrade_tree_view/upgrade_tooltip_container/upgrade_tooltip_container.tscn"

@export var upgrade_id : UpgradeEnums.UpgradeID

@onready var panel = $Panel
@onready var label = $MarginContainer/Label
@onready var line_2d = $Line2D
@onready var tooltip_container = $UpgradeTooltipContainer

var level : int
var max_level : int

func _ready():
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

	_update_tooltip()

	level = ManagerUpgrade.ref.get_upgrade_level(upgrade_id)
	max_level = ManagerUpgrade.ref.get_upgrade_max_level(upgrade_id)

	if level != 0:
		_turn_panel_on()

	if level < max_level:
		pressed.connect(_on_pressed)

	if level == max_level:
		_activate_children()

	_update_text()

	if get_parent() is UpgradeButton:
		line_2d.add_point(global_position + size/2)
		line_2d.add_point(get_parent().global_position + size/2)

func _update_text() -> void:
	label.text = str(level) + "/" + str(max_level)

func _update_tooltip() -> void:
	tooltip_container.label.text = ManagerUpgrade.ref.get_upgrade_tooltip(upgrade_id)

func _turn_panel_on() -> void:
	panel.show_behind_parent = true
	line_2d.default_color = Color(1, 1, 0.24705882370472)

func _activate_children() -> void:
	var upgrades = get_children()
	for upgrade in upgrades:
		if upgrade is UpgradeButton:
			upgrade.disabled = false

func _on_pressed():
	if ManagerUpgrade.ref.purchase_upgrade(upgrade_id):
		level = ManagerUpgrade.ref.get_upgrade_level(upgrade_id)
		_turn_panel_on()

	_update_text()
	_update_tooltip()

	if level == max_level:
		_activate_children()

func _on_mouse_entered() -> void:
	tooltip_container.visible = true

func _on_mouse_exited() -> void:
	tooltip_container.visible = false
