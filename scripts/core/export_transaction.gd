extends Reference

const Geometry = preload("door_geometry.gd")
var state = "IDLE"
var id = ""
var snapshot = {}
var restore_entries = []
var image_bytes = PoolByteArray()
var callback_received = false
var path = ""
var cancelled = false
var failure = ""

func prepare(context, visuals, output_path):
	if state != "IDLE":
		return Geometry.failure("BUSY", "An animated export is already active.")
	state = "PREFLIGHT"
	id = str(OS.get_ticks_usec()) + "-" + str(get_instance_id())
	path = output_path
	snapshot = context
	restore_entries = []
	for visual in visuals:
		if not is_instance_valid(visual):
			cleanup()
			return Geometry.failure("STALE_DOOR", "A door disappeared during preparation.")
		# The installed Portal scene parents its light occluder under Sprite.
		# Hiding the Sprite would also hide that occluder. self_modulate affects
		# only the Sprite's own artwork and preserves child lighting/visibility.
		restore_entries.append({"node": weakref(visual), "self_modulate": visual.self_modulate})
	state = "PREPARED"
	return Geometry.success(id)

func suppress():
	if state != "PREPARED":
		return false
	for entry in restore_entries:
		var node = entry.node.get_ref()
		if not is_instance_valid(node):
			cleanup()
			return false
		var invisible = entry.self_modulate
		invisible.a = 0.0
		node.self_modulate = invisible
	state = "CAPTURING"
	return true

func accept_image(token, bytes, output_path, ppi):
	if state != "CAPTURING" or token != id or path != output_path or int(snapshot.ppi) != int(ppi) or callback_received:
		return false
	image_bytes = bytes
	callback_received = true
	return true

func restore_visuals():
	for entry in restore_entries:
		var node = entry.node.get_ref()
		if is_instance_valid(node):
			node.self_modulate = entry.self_modulate
	restore_entries.clear()

func cleanup():
	restore_visuals()
	snapshot = {}
	image_bytes = PoolByteArray()
	callback_received = false
	cancelled = false
	failure = ""
	path = ""
	id = ""
	state = "IDLE"
