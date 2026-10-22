var script_class = "tool"
var controller
var standalone

func start():
	if Engine.has_signal("_lib_register_mod"):
		Engine.emit_signal("_lib_register_mod", self)
	if Engine.has_meta("AnimatedDoors.controller"):
		var old = Engine.get_meta("AnimatedDoors.controller")
		if is_instance_valid(old):
			if not old.stopped and old.host.Editor == Global.Editor:
				# CreateModTool uses Dictionary.Add; registering the same tool twice
				# in one editor would throw. Keep the existing session on repeats.
				controller = old
				return
			old.shutdown()
	standalone = load(Global.Root.plus_file("scripts/core/standalone_api.gd")).new(Global)
	var script = load(Global.Root.plus_file("scripts/core/controller.gd"))
	if script == null:
		Global.Editor.Warn("Animated Doors", "Could not load the Animated Doors controller.")
		return
	controller = script.new()
	controller.standalone = standalone
	Engine.set_meta("AnimatedDoors.controller", controller)
	var result = controller.initialize(Global, self)
	if not result.ok:
		Global.Editor.Warn("Animated Doors", result.message)
		controller.shutdown()

func on_tool_enable(_tool_id):
	if is_instance_valid(controller) and not controller.stopped:
		controller._refresh()

func on_tool_disable(_tool_id):
	if is_instance_valid(controller) and is_instance_valid(controller.overlay):
		controller.overlay.hide()
		if is_instance_valid(controller.selection_overlay):
			controller.selection_overlay.hide()

func on_content_input(_event):
	pass

func _notification(what):
	if what == 1 and is_instance_valid(controller):
		controller.shutdown()
