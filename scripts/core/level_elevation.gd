extends Reference

const G = preload("door_geometry.gd")
var data = {"schema_version": 1, "bottom": 0, "top": 0, "export_enabled": true}
var read_only = false
var issue = ""
var original

func _init(values = {}):
	original = values.duplicate(true) if values is Dictionary or values is Array else values
	if not values is Dictionary:
		read_only = true
	else:
		for key in values:
			data[key] = values[key]
		read_only = data.schema_version != 1 or not integer(data.bottom) or not integer(data.top) or not data.export_enabled is bool
	if read_only:
		issue = "Invalid level elevation settings; original data is preserved."

static func integer(value):
	return G.number(value) and value == int(value) and value >= -2147483648 and value <= 2147483647

static func label_info(label):
	var pattern = RegEx.new()
	pattern.compile("\\s*\\[\\s*(-?[0-9]+)\\s*,\\s*(-?[0-9]+)\\s*\\]\\s*$")
	var matched = pattern.search(label)
	if matched != null:
		var bottom = float(matched.get_string(1))
		var top = float(matched.get_string(2))
		if integer(bottom) and integer(top):
			return {"level_name": label.substr(0, matched.get_start()).strip_edges(), "bottom": int(bottom), "top": int(top)}
	return {"level_name": label, "bottom": 0, "top": 0}

func serialize(_node):
	return original if read_only else data.duplicate(true)

func component_node_removed(_node):
	pass
