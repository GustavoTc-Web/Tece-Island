extends "res://scripts/network/session.gd"
# Offline gameplay fixture only, excluded by the release preset.
var fixture_path := "res://.tools/native-fixture-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
func prepare_game(path: String) -> Node:
	var scene: Node = super.prepare_game(path)
	if scene != null and path == SOLO: scene.progress_path = fixture_path
	return scene
