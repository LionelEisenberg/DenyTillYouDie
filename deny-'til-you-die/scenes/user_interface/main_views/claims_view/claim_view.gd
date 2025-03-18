extends Control

func _ready() -> void:
	ManagerClaim.ref.claim_update.connect(_on_claim_update)
	if len(self.get_children()) == 0:
		_add_active_claim_child()

func _on_claim_update(_claim : Claim) -> void:
	_remove_claim_child()
	_add_active_claim_child()

func _remove_claim_child() -> void:
	ManagerClaim.ref.get_previous_claim().queue_free()
	self.remove_child(ManagerClaim.ref.get_previous_claim())


func _add_active_claim_child() -> void:
	self.add_child(ManagerClaim.ref.get_active_claim())
