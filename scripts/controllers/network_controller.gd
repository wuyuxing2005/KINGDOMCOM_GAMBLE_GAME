class_name NetworkController
extends PlayerController

var client: NetworkClient

func _init(network_client: NetworkClient = null) -> void:
	client = network_client

func submit_to_server(action: GameAction) -> void:
	if client != null:
		client.send_action(action)
