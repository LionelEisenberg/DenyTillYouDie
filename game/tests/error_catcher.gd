class_name ErrorCatcher
extends Logger
## Collects engine and script errors so the test runner can fail the test that
## raised them (GDScript has no try/catch).

var errors: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var text := rationale if rationale != "" else code
	_mutex.lock()
	errors.append("%s (%s:%d in %s)" % [text, file.get_file(), line, function])
	_mutex.unlock()


func take() -> PackedStringArray:
	_mutex.lock()
	var copy := errors.duplicate()
	errors.clear()
	_mutex.unlock()
	return copy
