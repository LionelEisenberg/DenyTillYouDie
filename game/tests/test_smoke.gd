extends RefCounted

var t: TestContext


func test_truth() -> void:
	t.ok(true)


func test_autoloads_present() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	t.ok(tree.root.has_node("GameState"), "GameState autoload")
	t.ok(tree.root.has_node("Sfx"), "Sfx autoload")


func test_coroutine_tests_are_awaited() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var start := Engine.get_process_frames()
	await tree.process_frame
	await tree.process_frame
	t.ok(Engine.get_process_frames() >= start + 1, "frames advanced while awaiting")
