# ManagerObjective.gd
class_name ManagerObjective 
extends Node

static var ref : ManagerObjective

func _init() -> void:
	if not ref : ref = self
	else : queue_free()

@onready var save_game_data : SaveGameData = Game.ref.save_game_data
var current_objective : Objective 

signal objective_completed(objective : Objective)

func get_current_obejctive() -> Objective:
	return current_objective

func _ready() -> void:
	_initialize_objective()
	
	# Signal funcs
	if current_objective != null:
		ManagerMoney.ref.money_update.connect(_on_money_updated)
		ManagerGoodwill.ref.goodwill_update.connect(_on_goodwill_updated)
		ManagerClaim.ref.claim_update.connect(_on_claim_update)

func _initialize_objective() -> void:
	for objective_id in range(save_game_data.objective_data.completed_objectives.size()):
		if not save_game_data.objective_data.is_objective_completed(objective_id):
			current_objective = ObjectiveEnums.get_objective_object(objective_id)
			return

func _process_current_objective() -> void:
	if !_check_condition(current_objective):
		return  # The current objective is not yet completed

	_execute_consequence(current_objective)
	save_game_data.objective_data.complete_objective(current_objective.objective_id)

	# Get the next objective ID
	var next_objective_id_value = current_objective.objective_id + 1 
	if next_objective_id_value < ObjectiveEnums.ObjectiveID.values().size():
		current_objective = ObjectiveEnums.get_objective_object(ObjectiveEnums.ObjectiveID.values()[next_objective_id_value])
	else:
		current_objective = null

	if current_objective == null:
		_disconnect_signals()

	objective_completed.emit(current_objective)

func _check_condition(objective : Objective) -> bool:
	var condition_value = objective.condition_value
	match objective.condition_type:
		GameEnums.ConditionType.APPROVE_CLAIMS:
			return save_game_data.claim_data.num_claims_approved >= condition_value
		GameEnums.ConditionType.DENY_CLAIMS:
			return save_game_data.claim_data.num_claims_denied >= condition_value
	return false

func _execute_consequence(objective : Objective):
	match objective.consequence_type:
		GameEnums.ConsequenceType.UNLOCK_FEATURE:
			ManagerUnlock.ref.unlock_feature(objective.consequence_value)

func _disconnect_signals() -> void:
	ManagerMoney.ref.money_update.disconnect(_on_money_updated)
	ManagerGoodwill.ref.goodwill_update.disconnect(_on_goodwill_updated)
	ManagerClaim.ref.claim_update.disconnect(_on_claim_update)

func _on_money_updated() -> void:
	if _should_check_objective(GameEnums.ConditionType.REACH_MONEY):
		_process_current_objective()

func _on_goodwill_updated() -> void:
	if _should_check_objective(GameEnums.ConditionType.REACH_GOODWILL):
		_process_current_objective()

func _on_claim_update(claim : Claim) -> void:
	var condition_type : GameEnums.ConditionType
	if claim.status == ClaimEnums.ClaimStatus.APPROVED:
		condition_type = GameEnums.ConditionType.APPROVE_CLAIMS
	elif claim.status == ClaimEnums.ClaimStatus.DENIED:
		condition_type = GameEnums.ConditionType.DENY_CLAIMS
	if _should_check_objective(condition_type):
		_process_current_objective()

func _should_check_objective(condition_type: GameEnums.ConditionType) -> bool:
	return current_objective.condition_type == condition_type
