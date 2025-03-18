class_name ManagerClaim
extends Node

static var ref : ManagerClaim

const FRIVOLOUS_BASE_CHANCE : float = 0.05
const TRAGIC_BASE_CHANCE : float = 0.05

@onready var claim_scene_path : Resource = preload("res://scenes/user_interface/main_views/claims_view/claims_sub_view/claim.tscn")
@onready var names_generator = NameGenerator.new()
@onready var save_game_data : SaveGameData = Game.ref.save_game_data
var active_claim : Claim
var previous_claim : Claim
var claim_container : Control

signal claim_update(claim : Claim)

func _init() -> void:
	if not ref : ref = self
	else : queue_free()

func _ready() -> void:
	if !save_game_data.claim_data.active_claim_dict.is_empty():
		active_claim = ClaimGeneration.generate_new_claim_from_savegame(claim_scene_path, save_game_data.claim_data.active_claim_dict)
	if active_claim == null:
		_cycle_claim()

func get_active_claim() -> Claim:
	return active_claim

func get_previous_claim() -> Claim: return previous_claim

func get_claim_level() -> int: return save_game_data.claim_data.claim_level

func get_claim_type_odds() -> Dictionary: return save_game_data.claim_data.claim_type_odds

# Approve and Deny claim return the lockout
func approve_claim() -> float:
	save_game_data.claim_data.num_claims_approved += 1
	active_claim.status = ClaimEnums.ClaimStatus.APPROVED
	_process_consequences(active_claim.approval_consequences)
	_cycle_claim()
	return get_approval_lockout()

func deny_claim() -> bool:
	save_game_data.claim_data.num_claims_denied += 1
	active_claim.status = ClaimEnums.ClaimStatus.DENIED
	
	if _can_process_consequences(active_claim.denial_consequences):
		_process_consequences(active_claim.denial_consequences)
		_cycle_claim()
		return true
	return false

func get_approval_lockout() -> float:
	return save_game_data.claim_data.approval_lockout

func get_denial_lockout() -> float:
	return save_game_data.claim_data.denial_lockout

# claim_data editing funcs
func increase_claim_level(quantity : int) -> void:
	save_game_data.claim_data.claim_level += quantity

func decrease_approval_lockout(quantity : float) -> void:
	save_game_data.claim_data.approval_lockout -= quantity

func decrease_denial_lockout(quantity : float) -> void:
	save_game_data.claim_data.denial_lockout -= quantity
	
func change_tragic_claim_chance(quantity : float) -> void:
	save_game_data.claim_data.claim_type_odds[ClaimEnums.ClaimType.STANDARD] -= quantity
	save_game_data.claim_data.claim_type_odds[ClaimEnums.ClaimType.TRAGIC] += quantity

func change_frivolous_claim_chance(quantity : float) -> void:
	save_game_data.claim_data.claim_type_odds[ClaimEnums.ClaimType.STANDARD] -= quantity
	save_game_data.claim_data.claim_type_odds[ClaimEnums.ClaimType.FRIVOLOUS] += quantity

func change_upgrade_approval_money(quantity : float) -> void:
	save_game_data.claim_data.approval_money_upgrade_multiplier += quantity
	
func change_upgrade_approval_goodwill(quantity : float) -> void:
	save_game_data.claim_data.approval_goodwill_upgrade_multiplier += quantity
	
func change_upgrade_denial_money(quantity : float) -> void:
	save_game_data.claim_data.denial_money_upgrade_multiplier += quantity

func change_upgrade_denial_goodwill(quantity : float) -> void:
	save_game_data.claim_data.denial_goodwill_upgrade_multiplier += quantity

func unlock_claim_type(type : ClaimEnums.ClaimType) -> void:
	match type:
		ClaimEnums.ClaimType.FRIVOLOUS:
			change_frivolous_claim_chance(FRIVOLOUS_BASE_CHANCE)
		ClaimEnums.ClaimType.TRAGIC:
			change_tragic_claim_chance(TRAGIC_BASE_CHANCE)
		_:
			pass

func _can_process_consequences(consequences : Array[ClaimConsequence]) -> bool:
	for consequence in consequences:
		match consequence.type:
			ClaimConsequence.ConsequenceType.GET_MONEY:
				pass 
			ClaimConsequence.ConsequenceType.GET_GOODWILL:
				pass
			ClaimConsequence.ConsequenceType.SPEND_MONEY:
				if typeof(consequence.value) != TYPE_FLOAT:
					printerr("CONSEQUENCE VALUE IS NOT AN FLOAT")
				if not ManagerMoney.ref.can_spend(consequence.value):
					return false
			ClaimConsequence.ConsequenceType.START_EVENT:
				pass
			ClaimConsequence.ConsequenceType.SPEND_GOODWILL:
				if typeof(consequence.value) != TYPE_FLOAT:
					printerr("CONSEQUENCE VALUE IS NOT AN FLOAT")
				if not ManagerGoodwill.ref.can_spend(consequence.value):
					return false
			_:
				printerr("UNKNOWN CONSEQUENCE TYPE")
	return true

func _process_consequences(consequences : Array[ClaimConsequence]) -> void:
	for consequence in consequences:
		match consequence.type:
			ClaimConsequence.ConsequenceType.GET_MONEY:
				ManagerMoney.ref.add_resource(consequence.value)
			ClaimConsequence.ConsequenceType.GET_GOODWILL:
				ManagerGoodwill.ref.add_resource(consequence.value)
			ClaimConsequence.ConsequenceType.SPEND_MONEY:
				if typeof(consequence.value) != TYPE_FLOAT:
					printerr("CONSEQUENCE VALUE IS NOT AN FLOAT")
				if ManagerMoney.ref.can_spend(consequence.value):
					ManagerMoney.ref.spend(consequence.value)
			ClaimConsequence.ConsequenceType.START_EVENT:
				pass
			ClaimConsequence.ConsequenceType.SPEND_GOODWILL:
				if typeof(consequence.value) != TYPE_FLOAT:
					printerr("CONSEQUENCE VALUE IS NOT AN FLOAT")
				if ManagerGoodwill.ref.can_spend(consequence.value):
					ManagerGoodwill.ref.spend(consequence.value)
			_:
				printerr("UNKNOWN CONSEQUENCE TYPE")

func _cycle_claim() -> void:
	previous_claim = active_claim
	active_claim = ClaimGeneration.generate_new_claim(claim_scene_path, save_game_data.claim_data, save_game_data.goofyness_level, names_generator)
	save_game_data.claim_data.active_claim_dict = active_claim.inst2dict()
	
	print(active_claim.claim_type)
	print(save_game_data.claim_data.claim_type_odds)
	
	claim_update.emit(previous_claim)
