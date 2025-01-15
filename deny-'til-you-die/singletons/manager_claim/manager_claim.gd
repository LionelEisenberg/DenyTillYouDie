class_name ManagerClaim
extends Node

static var ref : ManagerClaim

@onready var claim_scene_path = preload("res://scenes/user_interface/main_views/claims_view/claims_sub_view/claim.tscn")
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
		active_claim = _generate_new_claim_from_savegame()
	if active_claim == null:
		_cycle_claim()

func get_active_claim() -> Claim:
	return active_claim

func get_previous_clain() -> Claim: return previous_claim


# Approve and Deny claim return the lockout
func approve_claim() -> float:
	save_game_data.claim_data.num_claims_approved += 1
	active_claim.status = ClaimEnums.ClaimStatus.APPROVED
	_process_consequences(active_claim.approval_consequences)
	_cycle_claim()
	return _get_approval_lockout()

func deny_claim() -> float:
	save_game_data.claim_data.num_claims_denied += 1
	active_claim.status = ClaimEnums.ClaimStatus.DENIED
	_process_consequences(active_claim.denial_consequences)
	_cycle_claim()
	return _get_denial_lockout()

func _get_approval_lockout() -> float:
	return save_game_data.claim_data.approval_lockout

func _get_denial_lockout() -> float:
	return save_game_data.claim_data.denial_lockout

# claim_data editing funcs
func increase_claim_level(quantity : int) -> void:
	save_game_data.claim_data.claim_level += quantity

func decrease_approval_lockout(quantity : float) -> void:
	save_game_data.claim_data.approval_lockout -= quantity

func decrease_denial_lockout(quantity : float) -> void:
	save_game_data.claim_data.denial_lockout -= quantity

func _generate_new_claim() -> Claim:
	var new_claim = claim_scene_path.instantiate()
	var claim_type = _generate_claim_type()
	new_claim.construct_claim(
		_generate_claim_title(), 
		_generate_claimant_name(), 
		_generate_claimant_age(),
		_generate_claimant_occupation(),
		_generate_claim_number(),
		_generate_claim_description(), 
		_generate_claim_coverage(),
		_generate_related_claims(),
		_generate_notes(),
		claim_type,
		_generate_approval_consequences(claim_type),
		_generate_denial_consequences(claim_type),
	)
	return new_claim

func _generate_new_claim_from_savegame() -> Claim:
	return claim_scene_path.instantiate().dict2inst(save_game_data.claim_data.active_claim_dict)

func _process_consequences(consequences : Array[ClaimConsequence]) -> void:
	for consequence in consequences:
		match consequence.type:
			ClaimConsequence.ConsequenceType.GET_MONEY:
				ManagerMoney.ref.add_resource(consequence.value)
			ClaimConsequence.ConsequenceType.GET_GOODWILL:
				ManagerGoodwill.ref.add_resource(consequence.value)
			ClaimConsequence.ConsequenceType.START_EVENT:
				pass
			ClaimConsequence.ConsequenceType.SPEND_GOODWILL:
				if typeof(consequence.value) != TYPE_INT:
					printerr("CONSEQUENCE VALUE IS NOT AN INT")
				if ManagerGoodwill.ref.can_spend(consequence.value):
					ManagerGoodwill.ref.spend(consequence.value)
			_:
				printerr("UNKNOWN CONSEQUENCE TYPE")

func _cycle_claim() -> void:
	previous_claim = active_claim
	active_claim = _generate_new_claim()
	save_game_data.claim_data.active_claim_dict = active_claim.inst2dict()

	claim_update.emit(previous_claim)

func _generate_claim_title() -> String:
	return "Generic Claim"

func _generate_claimant_name() -> String:
	return names_generator.new_name()[randi_range(0, 1)]

func _generate_claimant_age() -> int:
	return randi_range(0, 100)

func _generate_claimant_occupation() -> String:
	return ClaimConstants.JOB_TITLES[save_game_data.goofyness_level][randi_range(0, len(ClaimConstants.JOB_TITLES[save_game_data.goofyness_level]) - 1)]

func _generate_claim_number() -> String:
	# TODO: Implement logic to generate claim number (e.g., a random ID)
	return "00000"

func _generate_claim_description() -> String:
	return ClaimConstants.DESCRIPTIONS[save_game_data.goofyness_level][randi_range(0, len(ClaimConstants.DESCRIPTIONS[save_game_data.goofyness_level]) - 1)]

func _generate_claim_coverage() -> int:
	# TODO: Implement logic to generate claim coverage amount (e.g., random value between $100 and $10,000)
	return 1000

func _generate_related_claims() -> Array[String]:
	# TODO: Implement logic to generate an array of related claims 
	# (e.g., ["#12345 - Broken Arm", "#67890 - Head Cold"])
	return []

func _generate_notes() -> String:
	# TODO: Implement logic to generate notes for the claim 
	# (e.g., "This claim seems suspicious...")
	return "No notes available." 

func _generate_claim_type() -> ClaimEnums.ClaimType:
	return ClaimEnums.ClaimType.STANDARD

func _generate_approval_consequences(_claim_type : ClaimEnums.ClaimType) -> Array[ClaimConsequence]:
	var approval_consequences : Array[ClaimConsequence] = [
		ClaimConsequence.new(ClaimConsequence.ConsequenceType.GET_MONEY, 10),
		ClaimConsequence.new(ClaimConsequence.ConsequenceType.GET_GOODWILL, 1)
	]
	return approval_consequences

func _generate_denial_consequences(_claim_type : ClaimEnums.ClaimType) -> Array[ClaimConsequence]:
	var denial_consequences : Array[ClaimConsequence] = [
		ClaimConsequence.new(ClaimConsequence.ConsequenceType.GET_MONEY, 100),
		ClaimConsequence.new(ClaimConsequence.ConsequenceType.SPEND_GOODWILL, 1)
	]
	return denial_consequences
