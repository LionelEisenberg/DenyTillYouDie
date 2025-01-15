extends Label

func _ready() -> void:
	ManagerClaim.ref.claim_update.connect(_on_claim_update)

func _on_claim_update(claim : Claim) -> void:
	match claim.status:
		ClaimEnums.ClaimStatus.APPROVED:
			text = "APPROVED"
		ClaimEnums.ClaimStatus.DENIED:
			text = "DENIED"
