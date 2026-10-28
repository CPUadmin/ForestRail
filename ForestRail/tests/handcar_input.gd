extends RefCounted

# Controller for journey/regression fixtures, not an acceptance test of mouse
# effort. It follows the visible mechanism rather than prescribing its phase.
static func pull(model, world_direction: int = 1, effort: float = 0.32) -> void:
	if not model.hand_drive.held: model.grab_pump()
	var pose=model.handcar.pose()
	var direction=signf(pose.dangle_dphase)*world_direction*int(model.state.direction)
	if direction!=0: model.set_pump_target(float(pose.angle)+direction*effort)
	if model.can_push_handcar():
		model.begin_push()
		model.push_handcar(0.10*world_direction)
