## ServerManager.gd
extends PeerManager

## A dictionary of connected peers (peer id, player info)
var connected_peers: Dictionary[int, Dictionary] = {}

var player_info: Dictionary = {
	"name": "Player"
}


func activate() -> void:
	super.activate()
