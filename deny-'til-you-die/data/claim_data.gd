class_name ClaimData
extends Resource

@export var num_claims_approved : int = 0
@export var num_claims_denied : int = 0

@export var active_claim_dict : Dictionary = {}

@export var claim_level : int = 0

@export var approval_lockout : float = 1.0
@export var denial_lockout : float = 10.0

@export var claim_type_odds : Dictionary = {
	ClaimEnums.ClaimType.STANDARD : 1.0,
	ClaimEnums.ClaimType.TRAGIC : 0,
	ClaimEnums.ClaimType.FRIVOLOUS : 0,
}

@export var approval_money_upgrade_multiplier : float = 1.0
@export var approval_goodwill_upgrade_multiplier : float = 1.0
@export var denial_money_upgrade_multiplier : float = 1.0
@export var denial_goodwill_upgrade_multiplier : float = 1.0
