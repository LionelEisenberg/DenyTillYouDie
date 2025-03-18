# ManagerUpgrade.gd
class_name ManagerUpgrade 
extends Node

static var ref: ManagerUpgrade  # Add the 'ref' property

@onready var save_game_data: SaveGameData = Game.ref.save_game_data

signal upgrade_purchased()

func _init() -> void:
	if not ref: ref = self
	else: queue_free()

func _ready() -> void:
	pass

func get_upgrade_tooltip(upgrade_id : UpgradeEnums.UpgradeID) -> String:
	var upgrade = UpgradeEnums.get_upgrade_object(upgrade_id)
	var upgrade_level = get_upgrade_level(upgrade_id)
	var tooltip_text = ""

	# Title with level
	var title = upgrade.name
	if upgrade_level > 0:
		title += " (Lvl " + str(upgrade_level) + ")"
	tooltip_text += "[center][b]" + title + "[/b][/center]\n"

	# Description
	tooltip_text += upgrade.description + "\n\n"

	# Cost
	var cost_value = upgrade.cost.calculate_cost(upgrade_level)
	var cost_bbcode =  "[center][b]Cost:[/b] " 
	match upgrade.cost.cost_resource:
		GameEnums.ResourceType.MONEY:
			cost_bbcode += "[img=24x24]res://assets/textures/resources/money_resource.png[/img] $%.2f[/center]" % cost_value  # Format as float
		GameEnums.ResourceType.GOODWILL:
			cost_bbcode += "[img=24x24]res://assets/textures/resources/goodwill_resource.png[/img] %.2f[/center]" % cost_value  # Format as float
	tooltip_text += cost_bbcode

	return tooltip_text

func get_upgrade_level(upgrade_id: UpgradeEnums.UpgradeID) -> int:
	return save_game_data.upgrade_data.get_upgrade_level(upgrade_id)

func get_upgrade_max_level(upgrade_id: UpgradeEnums.UpgradeID) -> int:
	return UpgradeEnums.get_upgrade_object(upgrade_id).max_level

func is_upgrade_maxed(upgrade_id: UpgradeEnums.UpgradeID, upgrade : Upgrade = null) -> bool:
	if upgrade == null:
		upgrade = UpgradeEnums.get_upgrade_object(upgrade_id)
	return get_upgrade_level(upgrade_id) == upgrade.max_level

func purchase_upgrade(upgrade_id: UpgradeEnums.UpgradeID) -> bool:
	var upgrade = UpgradeEnums.get_upgrade_object(upgrade_id)
	if upgrade == null:
		printerr("Invalid upgrade ID:", upgrade_id)
		return false

	if is_upgrade_maxed(upgrade_id, upgrade):
		return false

	if not ManagerMoney.ref.can_spend(upgrade.cost.calculate_cost(get_upgrade_level(upgrade_id))):
		return false  

	ManagerMoney.ref.spend(upgrade.cost.calculate_cost(get_upgrade_level(upgrade_id)))

	save_game_data.upgrade_data.set_upgrade_level(upgrade_id, get_upgrade_level(upgrade_id) + 1)
	_execute_consequence(upgrade_id)
	
	upgrade_purchased.emit()
	
	return true

func _execute_consequence(upgrade_id: UpgradeEnums.UpgradeID):
	var upgrade = UpgradeEnums.get_upgrade_object(upgrade_id)
	match upgrade.consequence_type:
		GameEnums.ConsequenceType.INCREASE_CLAIM_LEVEL:
			ManagerClaim.ref.increase_claim_level(upgrade.consequence_value)
		GameEnums.ConsequenceType.DECREASE_APPROVAL_LOCKOUT:
			ManagerClaim.ref.decrease_approval_lockout(upgrade.consequence_value)
		GameEnums.ConsequenceType.DECREASE_DENIAL_LOCKOUT:
			ManagerClaim.ref.decrease_denial_lockout(upgrade.consequence_value)
		GameEnums.ConsequenceType.UNLOCK_FEATURE:
			ManagerUnlock.ref.unlock_feature(upgrade.consequence_value)
		GameEnums.ConsequenceType.CHANGE_TRAGIC_CLAIM_CHANCE:
			ManagerClaim.ref.change_tragic_claim_chance(upgrade.consequence_value)
		GameEnums.ConsequenceType.CHANGE_FRIVOLOUS_CLAIM_CHANCE:
			ManagerClaim.ref.change_frivolous_claim_chance(upgrade.consequence_value)
		GameEnums.ConsequenceType.CHANGE_UPGRADE_APPROVAL_MONEY:
			ManagerClaim.ref.change_upgrade_approval_money(upgrade.consequence_value)
		GameEnums.ConsequenceType.CHANGE_UPGRADE_APPROVAL_GOODWILL:
			ManagerClaim.ref.change_upgrade_approval_goodwill(upgrade.consequence_value)
		GameEnums.ConsequenceType.CHANGE_UPGRADE_DENIAL_MONEY:
			ManagerClaim.ref.change_upgrade_denial_money(upgrade.consequence_value)
		GameEnums.ConsequenceType.CHANGE_UPGRADE_DENIAL_GOODWILL:
			ManagerClaim.ref.change_upgrade_denial_goodwill(upgrade.consequence_value)

func spend_resource(upgrade : Upgrade, upgrade_id : UpgradeEnums.UpgradeID) -> bool:
	var manager : ManagerResourceInterface
	match upgrade.cost.cost_resource:
		GameEnums.ResourceType.MONEY:
			manager = ManagerMoney.ref
		GameEnums.ResourceType.GOODWILL:
			manager = ManagerGoodwill.ref

	if not manager.can_spend(upgrade.cost.calculate_cost(get_upgrade_level(upgrade_id))):
		return false  

	return manager.ref.spend(upgrade.cost.calculate_cost(get_upgrade_level(upgrade_id)))
