extends Reference

const Component = preload("door_component.gd")
var kind = "door"
var map_component
var application_defaults = {}

func _init(component_kind, saved_map = null, app_defaults = {}):
	kind = component_kind
	map_component = saved_map
	application_defaults = app_defaults.duplicate(true)

func create(_node):
	if kind == "level":
		var label = preload("host_adapter.gd").property(_node, "Label", _node.name)
		var initial = preload("level_elevation.gd").label_info(label)
		initial.erase("level_name")
		return preload("level_elevation.gd").new(initial)
	if kind == "map":
		var initial = Component.defaults()
		for key in initial:
			if application_defaults.has(key):
				initial[key] = application_defaults[key]
		return Component.new({"schema_version": 6, "list_layer_id": application_defaults.get("list_layer_id", 2147483647), "defaults": initial}, "map")
	var values = map_component.data.defaults.duplicate(true) if map_component != null else Component.defaults()
	# Assignment is always explicit, even when an old map's defaults enabled
	# every portal. Defaults supply animation and axis choices without assigning assets.
	values.enabled = false
	# Automatic choices are resolved against the live artwork when declaring.
	# Unassigned records and exported doors always keep a concrete image axis.
	if not values.axis in ["width", "height"]:
		values.axis = "width"
	values["schema_version"] = 6
	values["animation_texture"] = Component.texture_name(_node)
	return Component.new(values)

func deserialize(_node, data):
	if kind == "level":
		return preload("level_elevation.gd").new(data)
	var component = Component.new(data, kind)
	if kind == "door" and not component.read_only:
		var filename = Component.texture_name(_node)
		if not filename.empty():
			component.data.animation_texture = filename
	return component
