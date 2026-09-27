extends SceneTree

const DIRECTORY := "res://tests"


func _initialize() -> void:
	var failed := 0
	var total := 0
	for file in DirAccess.get_files_at(DIRECTORY):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("%s/%s" % [DIRECTORY, file])
		if script == null or not script.can_instantiate():
			failed += 1
			printerr("FAIL %s does not compile" % file)
			continue
		for method in script.get_script_method_list():
			if not String(method.name).begins_with("test_"):
				continue
			total += 1
			var suite: Suite = script.new()
			suite.call(method.name)
			if not suite.failures.is_empty():
				failed += 1
				printerr("FAIL %s::%s\n  %s" % [file, method.name, "\n  ".join(suite.failures)])
	print("%d passed, %d failed" % [total - failed, failed])
	quit(1 if failed else 0)
