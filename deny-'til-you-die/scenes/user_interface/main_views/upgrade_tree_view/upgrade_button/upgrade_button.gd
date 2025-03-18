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
	
	if level == 0:
		_disable_children()

	if level != 0:
		_turn_panel_on()
		_activate_children()

	if level < max_level:
		pressed.connect(_on_pressed)
	
	_update_text()

	_update_line_position()
	tooltip_container.set_process(false)

func _process(_delta : float) -> void:
	_update_line_position()

func _update_line_position():
	if get_parent() is UpgradeButton:
		# Get the center position of this button
		var this_center = global_position + size / 2

		# Get the center position of the parent button
		var parent_center = get_parent().global_position + get_parent().size / 2

		# Calculate the direction vector from parent to this button
		var direction = (this_center - parent_center).normalized()

		# Calculate the starting point of the line (offset from the parent's center)
		var start_point = parent_center + direction * (get_parent().size.x / 2)

		# Calculate the end point of the line (offset from this button's center)
		var end_point = this_center - direction * (size.x / 2)

		# Set the line points
		line_2d.points = [start_point, end_point]

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
			upgrade.visible = true

func _disable_children() -> void:
	var upgrades = get_children()
	for upgrade in upgrades:
		if upgrade is UpgradeButton:
			upgrade.disabled = true
			upgrade.visible = false

func _on_pressed():
	if ManagerUpgrade.ref.purchase_upgrade(upgrade_id):
		level = ManagerUpgrade.ref.get_upgrade_level(upgrade_id)
		_turn_panel_on()

	_update_text()
	_update_tooltip()

	if level > 0:
		_activate_children()

func _on_mouse_entered() -> void:
	tooltip_container.set_process(true)
	tooltip_container.visible = true

func _on_mouse_exited() -> void:
	tooltip_container.visible = false
	tooltip_container.set_process(false)
