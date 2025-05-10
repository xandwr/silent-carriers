## ClientManager.gd
extends PeerManager

## The client manager's local peer id
var local_peer_id: int


func activate() -> void:
	super.activate()
