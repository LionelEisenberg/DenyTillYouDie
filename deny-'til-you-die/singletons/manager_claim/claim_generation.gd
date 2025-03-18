class_name ClaimGeneration

### STANDARD VALUES
const STANDARD_APPROVAL_MONEY_CHANGE : float = 20.0
const STANDARD_APPROVAL_GOODWILL_CHANGE : float = 0.05
const STANDARD_DENIAL_MONEY_CHANGE : float = 500.0
const STANDARD_DENIAL_GOODWILL_CHANGE : float = 1.0

### FRIVOLOUS VALUES
const FRIVOLOUS_APPROVAL_MONEY_CHANGE : float = 50.0
const FRIVOLOUS_APPROVAL_GOODWILL_CHANGE : float = 0.25
const FRIVOLOUS_DENIAL_MONEY_CHANGE : float = 2000.0
const FRIVOLOUS_DENIAL_GOODWILL_CHANGE : float = 0.5

### TRAGIC VALUES
const TRAGIC_APPROVAL_MONEY_CHANGE : float = 150.0
const TRAGIC_APPROVAL_GOODWILL_CHANGE : float = 2
const TRAGIC_DENIAL_MONEY_CHANGE : float = 1000.0
const TRAGIC_DENIAL_GOODWILL_CHANGE : float = 3.5

const MONEY_SCALE_FACTOR = 1.41
const GOODWILL_SCALE_FACTOR = 1.26

### Main Generation funcs

static func generate_new_claim(claim_scene_path : Resource, claim_save_data : ClaimData, goofyness_level : int, names_generator : NameGenerator) -> Claim:
	var new_claim = claim_scene_path.instantiate()
	var claim_type = _generate_claim_type(claim_save_data.claim_type_odds)
	new_claim.construct_claim(
		_generate_claim_title(), 
		_generate_claimant_name(names_generator), 
		_generate_claimant_age(),
		_generate_claimant_occupation(goofyness_level),
		_generate_claim_number(),
		_generate_claim_description(goofyness_level), 
		_generate_claim_coverage(),
		_generate_related_claims(),
		_generate_notes(),
		claim_type,
		_generate_approval_consequences(claim_type, claim_save_data),
		_generate_denial_consequences(claim_type, claim_save_data),
	)
	return new_claim

static func generate_new_claim_from_savegame(claim_scene_path : Resource, active_claim_dict : Dictionary) -> Claim:
	return claim_scene_path.instantiate().dict2inst(active_claim_dict)

### Sub Function

static func _generate_claim_title() -> String:
	return ClaimConstants.CLAIM_TITLES[randi_range(0, len(ClaimConstants.CLAIM_TITLES) - 1)]

static func _generate_claimant_name(names_generator : NameGenerator) -> String:
	return names_generator.new_name()[randi_range(0, 1)]

static func _generate_claimant_age() -> int:
	return randi_range(0, 100)

static func _generate_claimant_occupation(goofyness_level : int) -> String:
	return ClaimConstants.JOB_TITLES[goofyness_level][randi_range(0, len(ClaimConstants.JOB_TITLES[goofyness_level]) - 1)]

static func _generate_claim_number() -> String:
	return "00000"

static func _generate_claim_description(goofyness_level : int) -> String:
	return ClaimConstants.DESCRIPTIONS[goofyness_level][randi_range(0, len(ClaimConstants.DESCRIPTIONS[goofyness_level]) - 1)]

static func _generate_claim_coverage() -> int:
	return 1000

static func _generate_related_claims() -> Array[String]:
	return []

static func _generate_notes() -> String:
	return ""

static func _generate_claim_type(claim_type_odds: Dictionary) -> ClaimEnums.ClaimType:
	var rand_value = randf()
	var cumulative_probability = 0.0

	for claim_type in claim_type_odds:
		cumulative_probability += claim_type_odds[claim_type]
		if rand_value <= cumulative_probability:
			return claim_type

	return ClaimEnums.ClaimType.STANDARD

static func _generate_approval_consequences(claim_type : ClaimEnums.ClaimType, claim_save_data: ClaimData) -> Array[ClaimConsequence]:
	var approval_consequences : Array[ClaimConsequence] = [
		_generate_approval_money_consequence(claim_type, claim_save_data),
		_generate_approval_goodwill_consequence(claim_type, claim_save_data)
	]
	return approval_consequences

static func _generate_denial_consequences(claim_type : ClaimEnums.ClaimType, claim_save_data: ClaimData) -> Array[ClaimConsequence]:
	var denial_consequences : Array[ClaimConsequence] = [
		_generate_denial_money_consequence(claim_type, claim_save_data),
		_generate_denial_goodwill_consequence(claim_type, claim_save_data)
	]
	return denial_consequences

### Consequence Generation

static func _generate_approval_money_consequence(claim_type: ClaimEnums.ClaimType, claim_save_data: ClaimData) -> ClaimConsequence:
	var claim_level = claim_save_data.claim_level
	var money_change : float = 0
	var consequence_type : ClaimConsequence.ConsequenceType
	
	match claim_type:
		ClaimEnums.ClaimType.STANDARD:
			money_change = STANDARD_APPROVAL_MONEY_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_MONEY
		ClaimEnums.ClaimType.FRIVOLOUS:
			money_change = FRIVOLOUS_APPROVAL_MONEY_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.SPEND_MONEY
		ClaimEnums.ClaimType.TRAGIC:
			money_change = TRAGIC_APPROVAL_MONEY_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_MONEY
		_:
			printerr("ClaimType not Found %s" %claim_type)
	
	# claim level scaling
	money_change *= pow(MONEY_SCALE_FACTOR, claim_level)

	# upgrade multiplier
	money_change *= claim_save_data.approval_money_upgrade_multiplier
	
	return ClaimConsequence.new(consequence_type, money_change)

static func _generate_approval_goodwill_consequence(claim_type: ClaimEnums.ClaimType, claim_save_data: ClaimData) -> ClaimConsequence:
	var claim_level = claim_save_data.claim_level
	var goodwill_change: float = 0
	var consequence_type: ClaimConsequence.ConsequenceType

	match claim_type:
		ClaimEnums.ClaimType.STANDARD:
			goodwill_change = STANDARD_APPROVAL_GOODWILL_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_GOODWILL
		ClaimEnums.ClaimType.FRIVOLOUS:
			goodwill_change = FRIVOLOUS_APPROVAL_GOODWILL_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_GOODWILL
		ClaimEnums.ClaimType.TRAGIC:
			goodwill_change = TRAGIC_APPROVAL_GOODWILL_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_GOODWILL
		_:
			printerr("ClaimType not Found %s" % claim_type)

	# claim level scaling
	goodwill_change *= pow(GOODWILL_SCALE_FACTOR, claim_level)

	# upgrade multiplier
	goodwill_change *= claim_save_data.approval_goodwill_upgrade_multiplier

	return ClaimConsequence.new(consequence_type, goodwill_change)

static func _generate_denial_money_consequence(claim_type: ClaimEnums.ClaimType, claim_save_data: ClaimData) -> ClaimConsequence:
	var claim_level = claim_save_data.claim_level
	var money_change: float = 0
	var consequence_type: ClaimConsequence.ConsequenceType

	match claim_type:
		ClaimEnums.ClaimType.STANDARD:
			money_change = STANDARD_DENIAL_MONEY_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_MONEY
		ClaimEnums.ClaimType.FRIVOLOUS:
			money_change = FRIVOLOUS_DENIAL_MONEY_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_MONEY
		ClaimEnums.ClaimType.TRAGIC:
			money_change = TRAGIC_DENIAL_MONEY_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.GET_MONEY
		_:
			printerr("ClaimType not Found %s" % claim_type)

	# claim level scaling
	money_change *= pow(MONEY_SCALE_FACTOR, claim_level)

	# upgrade multiplier
	money_change *= claim_save_data.denial_money_upgrade_multiplier

	return ClaimConsequence.new(consequence_type, money_change)

static func _generate_denial_goodwill_consequence(claim_type: ClaimEnums.ClaimType, claim_save_data: ClaimData) -> ClaimConsequence:
	var claim_level = claim_save_data.claim_level
	var goodwill_change: float = 0
	var consequence_type: ClaimConsequence.ConsequenceType

	match claim_type:
		ClaimEnums.ClaimType.STANDARD:
			goodwill_change = STANDARD_DENIAL_GOODWILL_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.SPEND_GOODWILL
		ClaimEnums.ClaimType.FRIVOLOUS:
			goodwill_change = FRIVOLOUS_DENIAL_GOODWILL_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.SPEND_GOODWILL
		ClaimEnums.ClaimType.TRAGIC:
			goodwill_change = TRAGIC_DENIAL_GOODWILL_CHANGE
			consequence_type = ClaimConsequence.ConsequenceType.SPEND_GOODWILL
		_:
			printerr("ClaimType not Found %s" % claim_type)

	# claim level scaling
	goodwill_change *= pow(GOODWILL_SCALE_FACTOR, claim_level)

	# upgrade multiplier
	goodwill_change *= claim_save_data.denial_goodwill_upgrade_multiplier

	return ClaimConsequence.new(consequence_type, goodwill_change)
