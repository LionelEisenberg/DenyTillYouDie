extends SceneTree
## Headless test runner.
##
## Usage (from the repo root):
##   godot --headless --path game --script res://tests/run_tests.gd [-- filter]
##
## Loads every res://tests/test_*.gd, instantiates it, injects `t` (a TestContext)
## and calls each `test_*` method, awaiting coroutines. Exits 1 on any failure.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		filter = user_args[0]

	var ctx := TestContext.new()
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var ran := 0
	for file_name in _test_files():
		var script: GDScript = load(TEST_DIR + file_name)
		if script == null or not script.can_instantiate():
			ctx.failures.append("%s: failed to load or compile" % file_name)
			print("  FAIL  %s (does not compile)" % file_name)
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var method_name: String = m["name"]
			if method_name.begins_with("test_") and not methods.has(method_name):
				methods.append(method_name)
		for method_name in methods:
			var label := "%s::%s" % [file_name.get_basename(), method_name]
			if filter != "" and not label.contains(filter):
				continue
			var instance: Object = script.new()
			instance.set("t", ctx)
			if instance.has_method("before_each"):
				await instance.call("before_each")
			ctx.current = label
			var before := ctx.failures.size()
			catcher.take()
			await instance.call(method_name)
			if instance.has_method("after_each"):
				await instance.call("after_each")
			for err in catcher.take():
				ctx.failures.append("%s: engine error: %s" % [label, err])
			ran += 1
			print(("  ok    " if ctx.failures.size() == before else "  FAIL  ") + label)
			if instance is Node and is_instance_valid(instance):
				(instance as Node).queue_free()

	print("")
	print("%d tests, %d checks, %d failures" % [ran, ctx.checks, ctx.failures.size()])
	for f in ctx.failures:
		print("FAILED " + f)
	if ctx.failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		quit(1)


func _test_files() -> PackedStringArray:
	var files: PackedStringArray = []
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_context.gd":
			files.append(file_name)
	files.sort()
	return files
