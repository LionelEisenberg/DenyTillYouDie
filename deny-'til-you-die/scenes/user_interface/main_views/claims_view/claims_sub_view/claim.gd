class_name Claim
extends Panel

const TOO_YOUNG = "bruh they're a child..."
const TOO_OLD = "bruh they're ancient..."

@onready var claim_description_label : RichTextLabel = %ClaimDescription
@onready var claim_level_texture : TextureRect = $MarginContainer/ClaimLevel
@onready var claim_type_texture : TextureRect = $MarginContainer/ClaimType

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
	_update_claim_level()
	_update_claim_type()

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
	var bbcode_text = ""

	# Claim Title (Large and bold with outline, using AvenirLTStd-Black.otf)
	bbcode_text += "[center][font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=50][outline_size=6]%s[/outline_size][/font_size][/font][/center]\n\n" % claim_title 

	# Claimant Information (using claim_description.ttf with subtitle font for labels)
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Heavy.otf][font_size=18]"
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Claimant:[/outline_size][/font_size][/font] " + self.claimant_name + "\n"
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Age:[/outline_size][/font_size][/font] " + str(self.claimant_age) + "\n"
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Occupation:[/outline_size][/font_size][/font] " + self.claimant_occupation + "\n"
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Claim Number:[/outline_size][/font_size][/font] " + self.claim_number + "\n\n"

	# Claim Description (using claim_description.ttf)
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Claim Description:[/outline_size][/font_size][/font]\n"
	bbcode_text += "[i]" + self.claim_description + "[/i]\n\n"

	# Requested Coverage (using claim_description.ttf)
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Requested Coverage:[/outline_size][/font_size][/font]\n"
	bbcode_text += "[i]" + str(self.claim_coverage) + "[/i]\n\n"

	# Notes (using claim_description.ttf)
	bbcode_text += "[font=res://assets/fonts/claim/AvenirLTStd-Black.otf][font_size=24][outline_size=3]Notes:[/outline_size][/font_size][/font]\n"
	bbcode_text += "[i]" + self.notes + "[/i]\n"

	bbcode_text += "[/font_size][/font]"  # Close the font and size tags

	return bbcode_text
	
func _update_text() -> void:
	claim_description_label.text = _generate_label_description()
	pass

func _update_claim_level() -> void:
	claim_level_texture.texture = load("res://assets/textures/numbers/icons8-"+ str(ManagerClaim.ref.get_claim_level()) +"-100.png")

func _update_claim_type() -> void:
	match self.claim_type:
		ClaimEnums.ClaimType.FRIVOLOUS:
			claim_type_texture.texture = load("res://assets/textures/claims/claim_types/frivolous_stamp.png")
			claim_type_texture.visible = true
		ClaimEnums.ClaimType.TRAGIC:
			claim_type_texture.texture = load("res://assets/textures/claims/claim_types/tragic_stamp.png")
			claim_type_texture.visible = true
		_:
			claim_type_texture.visible = false

func _generate_approval_tooltip_text() -> String:
	var bbcode_text : String = ""
	var approval_bbcode = consequences_to_bbcode(approval_consequences)
	if approval_bbcode:  # Only add if there are consequences
		bbcode_text += "\n[center]" + approval_bbcode + "[/center]"

	return bbcode_text

func _generate_denial_tooltip_text() -> String:
	var bbcode_text : String = ""
	var denial_bbcode = consequences_to_bbcode(denial_consequences)
	if denial_bbcode:  # Only add if there are consequences
		bbcode_text += "\n[center]" + denial_bbcode + "[/center]"
	
	return bbcode_text

static func consequences_to_bbcode(consequences: Array[ClaimConsequence]) -> String:
	var bbcode_text : String = ""
	for consequence in consequences:
		match consequence.type:
			ClaimConsequence.ConsequenceType.GET_MONEY:
				bbcode_text += "[color=green][img]res://assets/textures/resources/money_resource.png[/img]+$%.02f[/color]  " % consequence.value
			ClaimConsequence.ConsequenceType.GET_GOODWILL:
				bbcode_text += "[color=green][img]res://assets/textures/resources/goodwill_resource.png[/img] +%.02f[/color]  " % consequence.value
			ClaimConsequence.ConsequenceType.SPEND_MONEY:
				bbcode_text += "[color=red][img]res://assets/textures/resources/money_resource_negative.png[/img]-%.02f[/color]  " % consequence.value
			ClaimConsequence.ConsequenceType.SPEND_GOODWILL:
				bbcode_text += "[color=red][img]res://assets/textures/resources/goodwill_resource_negative.png[/img] -%.02f[/color]  " % consequence.value
			ClaimConsequence.ConsequenceType.START_EVENT:
				# Add logic for event icons/text if needed
				bbcode_text += "[color=yellow]Event![/color]  " 
	return bbcode_text
