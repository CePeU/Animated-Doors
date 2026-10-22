var script_class = "export_format"
var export_format_name = "PNG (without Animated Doors)"
var export_file_extension = "png"
var export_image_format = "png"
var format_key = "raster_png"
var show_quality_slider = false

func start():
	var formats = Engine.get_meta("AnimatedDoors.formats") if Engine.has_meta("AnimatedDoors.formats") else {}
	formats[format_key] = Script
	Engine.set_meta("AnimatedDoors.formats", formats)
	if not Global.Editor.owner.is_connected("tree_exiting", self, "_shutdown"):
		Global.Editor.owner.connect("tree_exiting", self, "_shutdown")

func _shutdown():
	if not Engine.has_meta("AnimatedDoors.formats"):
		return
	var formats = Engine.get_meta("AnimatedDoors.formats")
	if formats.get(format_key) == Script:
		formats.erase(format_key)
	if formats.empty():
		Engine.remove_meta("AnimatedDoors.formats")
	else:
		Engine.set_meta("AnimatedDoors.formats", formats)

func process(path: String, image: File, ppi: int):
	if not Engine.has_meta("AnimatedDoors.export_session"):
		print("[Animated Doors] Export rejected: no prepared door snapshot.")
		Global.Editor.call_deferred("Warn", "Animated Doors", "Export could not start. Check that the Animated Doors panel loaded successfully, then use Export Animated Doors in the export window.")
		return
	var session = Engine.get_meta("AnimatedDoors.export_session")
	if path != session.path or not is_instance_valid(session.controller):
		return
	if image.get_len() <= 0 or image.get_len() > 536870912:
		session.controller.call_deferred("receive_error", session.token, "Native image is empty or exceeds the 512 MiB encoded-image budget.")
		return
	var position = image.get_position()
	image.seek(0)
	var bytes = image.get_buffer(image.get_len())
	image.seek(position)
	if bytes.size() != image.get_len():
		session.controller.call_deferred("receive_error", session.token, "The native image could not be read completely.")
		return
	session.controller.call_deferred("receive_image", session.token, bytes, path, ppi)
