class_name Claim
extends Panel

const TOO_YOUNG = "bruh they're a child..."
const TOO_OLD = "bruh they're ancient..."

@onready var claim_description_label : RichTextLabel = %ClaimDescription

var claim_title : String
var claimant_name : String
var claimant_age : int
var claimant_occupation : String
var claim_number : String
var claim_description : String
var claim_coverage : int
var related_claims : Array[String]
var notes : String
var status : ClaimEnums.ClaimStatus

var claim_type : ClaimEnums.ClaimType
var approval_consequences: Array[ClaimConsequence]
var denial_consequences: Array[ClaimConsequence]

func _ready() -> void:
	claim_description_label.bbcode_enabled = true
	_update_text()

func construct_claim(
	_claim_title : String, 
	_claimant_name : String, 
	_claimant_age : int,
	_claimant_occupation : String,
	_claim_number : String,
	_claim_description : String,
	_claim_coverage : int,
	_related_claims : Array[String],
	_notes : String,
	_claim_type : ClaimEnums.ClaimType,
	_approval_consequences : Array[ClaimConsequence],
	_denial_consequences : Array[ClaimConsequence]
) -> void :
	self.claim_title = _claim_title
	self.claimant_name = _claimant_name
	self.claimant_age = _claimant_age
	self.claim_number = _claim_number
	self.claim_description = _claim_description
	self.claim_coverage = _claim_coverage
	self.related_claims = _related_claims
	self.notes = _notes
	self.status = ClaimEnums.ClaimStatus.UNDECIDED
	self.claim_type = _claim_type
	self.approval_consequences = _approval_consequences
	self.denial_consequences = _denial_consequences
	
	if claimant_age < 18: self.claimant_occupation = TOO_YOUNG
	elif claimant_age > 75: self.claimant_occupation = TOO_OLD
	else: self.claimant_occupation = _claimant_occupation

func inst2dict() -> Dictionary:
	var dict = {}
	dict["claim_title"] = claim_title
	dict["claimant_name"] = claimant_name
	dict["claimant_age"] = claimant_age
	dict["claimant_occupation"] = claimant_occupation
	dict["claim_number"] = claim_number
	dict["claim_description"] = claim_description
	dict["claim_coverage"] = claim_coverage
	dict["related_claims"] = related_claims
	dict["notes"] = notes
	dict["status"] = status
	dict["claim_type"] = claim_type

	# Convert ClaimConsequence objects to dictionaries
	var approval_consequences_dict = []
	for consequence in approval_consequences:
		var consequence_dict = {
			"type": consequence.type,
			"value": consequence.value
		}
		approval_consequences_dict.append(consequence_dict)
	dict["approval_consequences"] = approval_consequences_dict

	var denial_consequences_dict = []
	for consequence in denial_consequences:
		var consequence_dict = {
			"type": consequence.type,
			"value": consequence.value
		}
		denial_consequences_dict.append(consequence_dict)
	dict["denial_consequences"] = denial_consequences_dict

	return dict

func dict2inst(dict: Dictionary) -> Claim:
	self.claim_title = dict["claim_title"]
	self.claimant_name = dict["claimant_name"]
	self.claimant_age = dict["claimant_age"]
	self.claimant_occupation = dict["claimant_occupation"]
	self.claim_number = dict["claim_number"]
	self.claim_description = dict["claim_description"]
	self.claim_coverage = dict["claim_coverage"]
	self.related_claims = dict["related_claims"]
	self.notes = dict["notes"]
	self.status = dict["status"]
	self.claim_type = dict["claim_type"]

	# Convert dictionaries back to ClaimConsequence objects
	self.approval_consequences = []
	for consequence_dict in dict["approval_consequences"]:
		var consequence = ClaimConsequence.new(
			consequence_dict["type"],
			consequence_dict["value"]
		)
		self.approval_consequences.append(consequence)

	self.denial_consequences = []
	for consequence_dict in dict["denial_consequences"]:
		var consequence = ClaimConsequence.new(
			consequence_dict["type"],
			consequence_dict["value"]
		)
		self.denial_consequences.append(consequence)

	return self

func _generate_label_description() -> String:
	return "[center][b]" + self.claim_title + "[/b][/center]
	[b]Claim Form[/b]

	[b]Claimant:[/b] " + self.claimant_name + "
	[b]Age:[/b] " + str(self.claimant_age) + "
	[b]Occupation:[/b] " + self.claimant_occupation + "
	[b]Claim Number:[/b] " + self.claim_number + "

	[b]Claim Description:[/b]
	[i]" + self.claim_description + "[/i]

	[b]Requested Coverage:[/b]
	[i]" + str(self.claim_coverage) + "[/i]

	[b]Notes:[/b]
	[i]" + self.notes + "[/i]
	[i]" + str(self.approval_consequences) + "[/i]"

func _update_text() -> void:
	claim_description_label.text = _generate_label_description()
