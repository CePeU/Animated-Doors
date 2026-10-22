extends Reference

# Small local adapters for the APIs this mod needs. Optional mods are never
# bundled. The component layout stays readable by _Lib when enabled later.
const Adapter = preload("host_adapter.gd")
var host
var components
var config
var provided = {}
var save_icon

func _init(global_dictionary):
	host = global_dictionary
	if not host.has("API"):
		host.API = {}
	if not host.API.has("ComponentsApi"):
		components = Components.new(host)
		host.API.ComponentsApi = components
		provided.ComponentsApi = components
	if not host.API.has("HistoryApi"):
		host.API.HistoryApi = History.new(host.Editor.History)
		provided.HistoryApi = host.API.HistoryApi
	if not host.API.has("LayerApi"):
		host.API.LayerApi = Layers.new()
		provided.LayerApi = host.API.LayerApi
	if not host.API.has("ModSignalingApi"):
		host.API.ModSignalingApi = Events.new()
		provided.ModSignalingApi = host.API.ModSignalingApi
	if not host.API.has("ModConfigApi"):
		config = Config.new()
		host.API.ModConfigApi = config
		provided.ModConfigApi = config

func attach(panel):
	if config != null:
		config.attach(panel)
	if components != null:
		var infobar = Adapter.property(host.Editor, "Infobar")
		var icon = Adapter.property(infobar, "busyIcon")
		if is_instance_valid(icon):
			save_icon = icon
			icon.connect("visibility_changed", components, "flush")
		# Persist before native save as well as immediately on every settings edit.
		if host.Editor.has_signal("OnSaveBegin"):
			host.Editor.connect("OnSaveBegin", components, "flush")

func flush():
	if components != null:
		components.flush()

func shutdown():
	if components != null:
		if is_instance_valid(save_icon) and save_icon.is_connected("visibility_changed", components, "flush"):
			save_icon.disconnect("visibility_changed", components, "flush")
		if is_instance_valid(host.Editor) and host.Editor.is_connected("OnSaveBegin", components, "flush"):
			host.Editor.disconnect("OnSaveBegin", components, "flush")
		components.host = null
		components.accessors.clear()
	for key in provided:
		if host.API.get(key) == provided[key]:
			host.API.erase(key)
	provided.clear()
	if config != null and is_instance_valid(config.content) and config.content.get_parent() == null:
		config.content.free()
	host = null

class Events:
	extends Reference
	signal save_begin

class History:
	extends Reference
	var native
	func _init(value):
		native = value
	func record(value):
		native.CreateCustomRecord(value)

class Layers:
	extends Reference
	func get_layers(level):
		var result = level.SaveLayers().duplicate()
		for entry in [[-500, "Terrain"], [-300, "Caves"], [-200, "Floor"], [0, "Water"], [500, "Portals"], [600, "Walls"], [800, "Roofs"]]:
			result[entry[0]] = entry[1]
		return result

class Components:
	extends Reference
	const FLAG_WORLD = 1
	const FLAG_LEVEL = 2
	const FLAG_PORTAL_FREE = 16
	const FLAG_PROP = 256
	var host
	var accessors = {}
	func _init(value):
		host = value
	func table():
		var current = host.ModMapData
		for key in ["CreepyCre._Lib", "ComponentsApi", "save_data", "AnimatedDoors"]:
			if not current.has(key):
				current[key] = {}
			current = current[key]
		return current
	func register(identifier, factory, flags, _lazy = true):
		var accessor = Accessor.new(host.World, factory, flags)
		for entry in table().get(identifier, []):
			var node = host.World if entry.type == 0 else accessor.resolve(str(int(entry.get("node_id", -1))))
			if entry.type == 1:
				var ordered = accessor.ordered_levels()
				var index = int(entry.get("level", -1))
				node = ordered[index] if index >= 0 and index < ordered.size() else null
			if is_instance_valid(node) and accessor.node_type(node) == int(entry.type):
				accessor.values[accessor.key(node)] = factory.deserialize(node, entry.data)
		accessors[identifier] = accessor
		return accessor
	func flush():
		var saved = table()
		for identifier in accessors:
			saved[identifier] = accessors[identifier].serialize()

class Accessor:
	extends Reference
	var world
	var factory
	var flags
	# Retain detached IDs in memory for native delete/undo, but save live nodes only.
	var values = {}
	var level_refs = {}
	func _init(map_world, component_factory, type_flags):
		world = map_world
		factory = component_factory
		flags = type_flags
	func key(node):
		if node != world and node in ordered_levels():
			var id = "level:" + str(node.get_instance_id())
			level_refs[id] = weakref(node)
			return id
		return "world" if node == world else str(int(node.get_meta("node_id")))
	func ordered_levels():
		return Adapter.property(world, "AllLevels", [])
	func resolve(id):
		if id == "world":
			return world
		if id.begins_with("level:"):
			return level_refs[id].get_ref() if level_refs.has(id) else null
		if world.has_method("HasNodeID") and not world.HasNodeID(int(id)):
			return null
		return world.GetNodeByID(int(id))
	func node_type(node):
		if node == world:
			return 0
		if node in ordered_levels():
			return 1
		if not node.has_meta("node_id") or node.get_parent() == null:
			return -1
		if node.get_parent().name == "Portals":
			return 4
		return 8 if node.get_parent().name == "Objects" else -1
	func has_component(node):
		return values.has(key(node))
	func get_component(node):
		var id = key(node)
		if not values.has(id):
			values[id] = factory.create(node)
		return values[id]
	func serialize():
		var result = []
		for id in values:
			var node = resolve(id)
			if not is_instance_valid(node) or not node.is_inside_tree():
				continue
			var type = node_type(node)
			if type < 0 or not ((1 << type) & flags):
				continue
			var entry = {"type": type, "data": values[id].serialize(node)}
			if type == 1:
				var index = ordered_levels().find(node)
				if index < 0:
					continue
				entry.level = index
			elif id != "world":
				entry.node_id = int(id)
			result.append(entry)
		return result

class PreferenceEntry:
	extends Reference
	signal updated(value)
	var control
	var kind
	var options
	var value
	func _init(widget, type, initial, choices = []):
		control = widget
		kind = type
		value = initial
		options = choices
	func read_control():
		if kind == "color":
			return control.color
		if kind == "text":
			return control.text.strip_edges()
		if kind == "option":
			return options[control.selected].meta
		if kind == "bool":
			return control.pressed
		return control.value if control.step < 1 else int(control.value)
	func load_value(saved):
		if kind == "color" and saved is Color:
			control.color = saved
		elif kind == "text" and saved is String:
			control.text = saved
		elif kind == "option":
			for index in range(options.size()):
				if options[index].meta == saved:
					control.select(index)
		elif kind == "bool" and typeof(saved) == TYPE_BOOL:
			control.pressed = saved
		elif kind == "int" and (saved is int or saved is float):
			control.value = saved
		value = read_control()

class Preferences:
	extends Reference
	var entries = {}
	func _get(property):
		if property.begins_with("_"):
			return entries.get(property.substr(1))
		return entries[property].value if entries.has(property) else null

class Config:
	extends Reference
	const PATH = "user://animated_doors_settings.cfg"
	var path = PATH
	var content = VBoxContainer.new()
	var preferences = Preferences.new()
	var last_control
	var target
	var target_stack = []
	var dialog
	func create_config():
		return self
	func add_node(control):
		(target if target != null else content).add_child(control)
		last_control = control
		return self
	func enter():
		target_stack.append(target)
		target = last_control.get_target()
		return self
	func exit():
		target = target_stack.pop_back()
		return self
	func get_current():
		return last_control
	func with(property, value):
		last_control.set(property, value)
		return self
	func option_button(key, selected, options):
		var control = OptionButton.new()
		for option in options:
			control.add_item(option.label)
		control.select(selected)
		preferences.entries[key] = PreferenceEntry.new(control, "option", options[selected].meta, options)
		return add_node(control)
	func check_box(key, value, label):
		var control = CheckBox.new()
		control.text = label
		control.pressed = value
		preferences.entries[key] = PreferenceEntry.new(control, "bool", value)
		return add_node(control)
	func spin_box(key, value):
		var control = SpinBox.new()
		control.min_value = -2147483648
		control.max_value = 2147483647
		control.step = 1
		control.value = value
		preferences.entries[key] = PreferenceEntry.new(control, "int", value)
		return add_node(control)
	func line_edit(key, value, _require_enter = false):
		var control = LineEdit.new()
		control.text = value
		preferences.entries[key] = PreferenceEntry.new(control, "text", value)
		return add_node(control)
	func color_picker_button(key, value):
		var control = ColorPickerButton.new()
		control.color = value
		control.rect_min_size.y = 28
		preferences.entries[key] = PreferenceEntry.new(control, "color", value)
		return add_node(control)
	func get_root():
		return content
	func build():
		var file = ConfigFile.new()
		file.load(path)
		var missing_compatibility = not file.has_section_key("settings", "export_dialog_compatibility")
		for key in preferences.entries:
			var entry = preferences.entries[key]
			entry.load_value(file.get_value("settings", key, entry.value))
		if missing_compatibility and preferences.entries.has("export_dialog_compatibility") and not preferences.export_dialog_compatibility.empty():
			file.set_value("settings", "export_dialog_compatibility", preferences.export_dialog_compatibility)
			if file.save(path) != OK:
				push_error("Could not persist initial export dialog compatibility setting.")
		return preferences
	func attach(panel):
		dialog = AcceptDialog.new()
		dialog.window_title = "Animated Doors settings"
		dialog.rect_min_size = Vector2(460, 550)
		var scroll = ScrollContainer.new()
		scroll.rect_min_size = Vector2(430, 500)
		scroll.scroll_horizontal_enabled = false
		dialog.add_child(scroll)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(content)
		panel.add_child(dialog)
		dialog.connect("confirmed", self, "save")
		var windows = Engine.get_meta("_up_block_windows") if Engine.has_meta("_up_block_windows") else []
		if not windows is Array:
			windows = []
		windows.append(weakref(dialog))
		Engine.set_meta("_up_block_windows", windows)
		var button = Button.new()
		button.text = "Global settings"
		button.connect("pressed", self, "open")
		panel.add_child(button)
	func open():
		for entry in preferences.entries.values():
			entry.load_value(entry.value)
		dialog.popup_centered()
	func save():
		var file = ConfigFile.new()
		for key in preferences.entries:
			file.set_value("settings", key, preferences.entries[key].read_control())
		if file.save(path) != OK:
			dialog.dialog_text = "Could not save global settings."
			dialog.popup_centered()
			return
		# Update all values before notifying listeners of interdependent settings.
		for entry in preferences.entries.values():
			entry.value = entry.read_control()
		for entry in preferences.entries.values():
			entry.emit_signal("updated", entry.value)
