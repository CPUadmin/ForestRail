extends RefCounted
# The end of a test script. Alone it quits Godot with the code; inside a group (tests/group_runner.gd) it hands the
# code to the group, which frees the test and starts the next one in the same Godot (one launch for many scripts).

static func quit(node: Node, code: int = 0) -> void:
	var root = node.get_tree().root
	if root.has_meta("qa_group"):
		root.get_meta("qa_group").part_done(node, code)
	else:
		node.get_tree().quit(code)
