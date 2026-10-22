extends Node

const Component = preload("door_component.gd")
const Matcher = preload("portal_matcher.gd")
const Geometry = preload("door_geometry.gd")
const KEY = "animated_doors_clipboard"
var controller_ref
var adapter
var selection_snapshot = {}
var last_clipboard = ""
var pending_nodes = []
var pending_document = {}

func install(controller):
	controller_ref = weakref(controller)
	adapter = controller.adapter
	get_tree().connect("node_added", self, "_node_added")
	last_clipboard = OS.clipboard
	remember_selection()

func _input(event):
	if not event is InputEventKey and not event is InputEventMouseButton:
		return
	# Capture before native Copy/Cut changes selection or destroys its sources.
	sync_clipboard()
	remember_selection()
	if event is InputEventKey and event.pressed and not event.echo and event.control and event.scancode in [KEY_C, KEY_X]:
		last_clipboard = ""
		call_deferred("sync_clipboard")

func _process(_delta):
	sync_clipboard()

func remember_selection():
	var controller = controller_ref.get_ref()
	if controller == null or controller.stopped:
		return
	var tool = adapter.host.Editor.Tools.get("SelectTool")
	var raw = adapter.property(tool, "RawSelectables", [])
	var eligible = adapter.list_assets()
	var snapshot = {"objects": [], "portals": []}
	for selected in raw:
		var node = adapter.property(selected, "Thing")
		if not is_instance_valid(node) or not node in eligible or not node.has_method("Save"):
			continue
		var kind = "portals" if adapter.source_kind(node) == "portal" else "objects"
		var settings = controller.doors.get_component(node).serialize(node) if controller.doors.has_component(node) else null
		snapshot[kind].append({"native": node.Save(true).duplicate(true), "position": Geometry.json_point(node.position), "settings": settings})
	selection_snapshot = snapshot

func annotate(document, snapshot):
	if not document is Dictionary or not document.has("dungeondraft_clipboard") or document.has(KEY):
		return false
	var records = {}
	var declared = false
	for kind in ["objects", "portals"]:
		var native = document.get(kind, [])
		var sources = snapshot.get(kind, [])
		if not native is Array or native.size() != sources.size():
			return false
		records[kind] = []
		for index in range(native.size()):
			if not Matcher.equivalent(native[index], sources[index].native, 0.00001):
				return false
			var settings = sources[index].settings
			records[kind].append({"settings": settings, "position": sources[index].position})
			declared = declared or (settings is Dictionary and settings.get("enabled", false) == true)
	if not declared:
		return false
	document[KEY] = {"version": 1, "records": records}
	return true

func sync_clipboard():
	var text = OS.clipboard
	if text == last_clipboard:
		return
	last_clipboard = text
	if text.length() > 16777216 or not "dungeondraft_clipboard" in text:
		return
	var parsed = JSON.parse(text)
	if parsed.error != OK:
		return
	var annotated = annotate(parsed.result, selection_snapshot)
	if not annotated:
		# Copies made by another mod may have no corresponding input event.
		remember_selection()
		annotated = annotate(parsed.result, selection_snapshot)
	if annotated:
		last_clipboard = JSON.print(parsed.result)
		OS.clipboard = last_clipboard

func _node_added(node):
	if adapter.property(adapter.host.Editor, "ActiveTool") != adapter.host.Editor.Tools.get("SelectTool"):
		return
	if not is_instance_valid(adapter.current_level()):
		return
	var level = adapter.current_level()
	if not node.get_parent() in [adapter.property(level, "Objects"), adapter.property(level, "Portals")]:
		return
	if pending_nodes.empty():
		# Also covers Copy and Paste occurring before the next process frame.
		sync_clipboard()
		var text = OS.clipboard
		if text.length() > 16777216 or not KEY in text:
			return
		var parsed = JSON.parse(text)
		if parsed.error != OK or not parsed.result is Dictionary:
			return
		pending_document = parsed.result
		call_deferred("_finish_paste")
	pending_nodes.append(weakref(node))

func inherited_records(document, nodes, selected):
	# Require a complete native paste cohort, its final selection, unchanged
	# artwork properties and one common translation. Ordinary asset placement
	# must never inherit settings just because it happens to use the same image.
	var extension = document.get(KEY, {})
	if not extension is Dictionary or extension.get("version") != 1 or not extension.get("records") is Dictionary:
		return []
	var records = extension.records
	var result = []
	var offset = null
	for kind in ["objects", "portals"]:
		var originals = document.get(kind, [])
		var settings = records.get(kind, [])
		var created = []
		for node in nodes:
			if (adapter.source_kind(node) == "portal") == (kind == "portals"):
				created.append(node)
		if not originals is Array or not settings is Array or created.size() != originals.size() or settings.size() != originals.size():
			return []
		for index in range(created.size()):
			var node = created[index]
			var data = settings[index]
			if not node in selected or not node.has_method("Save") or not data is Dictionary or not Geometry.point(data.get("position")) or not originals[index] is Dictionary:
				return []
			var old = originals[index].duplicate(true)
			var current = node.Save(true).duplicate(true)
			old.erase("position")
			current.erase("position")
			if not Matcher.equivalent(old, current, 0.00001):
				return []
			var delta = node.position - Geometry.vector(data.position)
			if offset != null and delta.distance_to(offset) > 0.01:
				return []
			offset = delta
			if data.get("settings") != null:
				var component = Component.new(data.settings)
				if component.read_only:
					return []
				result.append({"node": node, "data": component.data})
	return result

func _finish_paste():
	var nodes = []
	for ref in pending_nodes:
		var node = ref.get_ref()
		if is_instance_valid(node) and node in adapter.list_assets():
			nodes.append(node)
	pending_nodes.clear()
	var controller = controller_ref.get_ref()
	if controller == null or controller.stopped or controller.transaction.state != "IDLE":
		return
	var selected = []
	for id in adapter.selected_assets():
		selected.append(adapter.resolve_node(id))
	var inherited = inherited_records(pending_document, nodes, selected)
	for entry in inherited:
		var component = controller.doors.get_component(entry.node)
		if not component.read_only:
			component.data = entry.data.duplicate(true)
	if not inherited.empty():
		if controller.standalone != null:
			controller.standalone.flush()
		controller._refresh()
	pending_document = {}

func detach():
	set_process(false)
	set_process_input(false)
	if get_tree().is_connected("node_added", self, "_node_added"):
		get_tree().disconnect("node_added", self, "_node_added")
